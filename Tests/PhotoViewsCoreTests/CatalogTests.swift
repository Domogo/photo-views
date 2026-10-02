import Foundation
import PhotoViewsCore

final class CatalogTests {
    var root: URL!
    func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    }
    func tearDownWithError() throws { try FileManager.default.removeItem(at:root) }
    func testSourceIdentityAndBookmarkSurviveReopening() throws {
        let folder = root.appendingPathComponent("Photos")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let source = try FolderAccess.source(for:folder)
        let url = root.appendingPathComponent("catalog.sqlite")
        var store: Catalog? = try Catalog(url:url)
        try expectEqual(try store!.version,Catalog.schemaVersion)
        let first = try store!.register(source)
        let duplicate = try store!.register(FolderAccess.source(for:folder))
        try expectEqual(first.id,duplicate.id)
        try expectEqual(try store!.sources().count,1)
        store = nil
        let restored = try Catalog(url:url).sources()
        try expectEqual(restored.first?.id,first.id)
        try expectEqual(try FolderAccess.resolve(restored[0]).url.standardizedFileURL.path,folder.standardizedFileURL.path)
    }
    func testViewAndWorkspaceRecipeRoundTrip() throws {
        let url = root.appendingPathComponent("catalog.sqlite")
        var store: Catalog? = try Catalog(url:url)
        var recipe = ViewRecipe()
        recipe.sourceIDs = [UUID()]; recipe.search = "dogs outdoors"
        recipe.filters.camera = "Nikon"; recipe.filters.confirmedTags = ["dog"]
        recipe.filters.fromDate = Date(timeIntervalSince1970:1640995200)
        recipe.grouping = .month; recipe.sorting = .relevance
        recipe.modelVersion = "test-model-v1"; recipe.rankingVersion = "test-ranking-v1"
        var view = SavedView(name:"Dogs' outdoor photos",recipe:recipe,createdAt:Date(timeIntervalSince1970:1700000000))
        try store!.save(view); try store!.storeWorkspaceRecipe(recipe)
        store = nil
        let reopened = try Catalog(url:url)
        try expectEqual(try reopened.savedViews(),[view])
        try expectEqual(try reopened.workspaceRecipe(),recipe)
        view.recipe.grouping = .camera; try reopened.save(view)
        try expectEqual(try reopened.savedViews().count,1)
        try expectEqual(try reopened.savedViews().first?.recipe.grouping,.camera)
    }
    func testGroupingIdentityUnknownAndDeterminism() throws {
        let sourceA = CatalogSource(name:"Same name",bookmark:Data(),volumeID:nil,relativePath:"",lastKnownPath:"")
        let sourceB = CatalogSource(name:"Same name",bookmark:Data(),volumeID:nil,relativePath:"",lastKnownPath:"")
        func asset(_ source: CatalogSource, _ camera: String?, _ date: String?) throws -> IndexedAsset {
            var metadata = MetadataRecord(); metadata.camera = camera; metadata.captureDateText = date
            let payload: [String:Any] = ["asset":["id":UUID().uuidString,"sourceID":source.id.uuidString,"relativePath":"trip/a.jpg","byteSize":1],"available":false]
            var value = payload; value["metadata"] = try JSONSerialization.jsonObject(with:JSONEncoder().encode(metadata))
            return try JSONDecoder().decode(IndexedAsset.self,from:JSONSerialization.data(withJSONObject:value))
        }
        let photos = try [asset(sourceA,"Z camera","2025:11:06 23:00:00"),asset(sourceB,"A camera","2024:01:01"),asset(sourceA," ","2025:02:30"),asset(sourceA,nil,nil)]
        let ids = Set(photos.map(\.id))
        for grouping in [Grouping.none,.folder,.month,.camera] {
            let grouped = ResultGrouping.groups(photos,by:grouping,sources:[sourceA,sourceB],ranked:false,sorting:.captureNewest)
            try expectEqual(Set(grouped.flatMap { $0.assets.map(\.id) }),ids)
            try expectEqual(grouped.reduce(0) { $0+$1.assets.count },photos.count)
            let repeatGroups = ResultGrouping.groups(photos,by:grouping,sources:[sourceA,sourceB],ranked:false,sorting:.captureNewest)
            try expectEqual(grouped.map(\.id),repeatGroups.map(\.id))
        }
        let folders = ResultGrouping.groups(photos,by:.folder,sources:[sourceA,sourceB],ranked:false,sorting:.filename)
        try expectEqual(folders.count,2) // Same labels must never merge source identities.
        let months = ResultGrouping.groups(photos,by:.month,sources:[],ranked:false,sorting:.captureNewest)
        try expectEqual(months.map(\.title),["2025-11","2024-01","Unknown date"])
        let cameras = ResultGrouping.groups(photos,by:.camera,sources:[],ranked:true,sorting:.relevance)
        try expectEqual(cameras.map(\.title),["Z camera","A camera","Unknown camera"])
        try expectEqual(cameras.last?.assets.map(\.id),Array(photos.suffix(2)).map(\.id))
        try expectEqual(ResultGrouping.captureMonth("2024:02:29"),"2024-02")
        try expectEqual(ResultGrouping.captureMonth("2025:02:29"),nil)
    }
    func testSavedDefinitionSeparateFromDraftAndIdentityRestores() throws {
        let url = root.appendingPathComponent("catalog.sqlite")
        var store: Catalog? = try Catalog(url:url)
        var original = ViewRecipe(); original.search = "cars"; original.searchMode = "visual"; original.grouping = .month
        original.modelVersion = "pinned-model"; original.rankingVersion = "pinned-ranking"
        let view = SavedView(name:"Cars",recipe:original,createdAt:Date(timeIntervalSince1970:1700000000))
        try store!.save(view); try store!.storeSelectedView(view.id)
        var draft = original; draft.grouping = .camera; draft.filters.camera = "Nikon"
        try store!.storeWorkspaceRecipe(draft); store = nil
        let reopened = try Catalog(url:url)
        try expectEqual(try reopened.selectedView(),view.id)
        try expectEqual(try reopened.workspaceRecipe(),draft)
        try expectEqual(try reopened.savedViews().first?.recipe,original)
        var updated = view; updated.recipe = draft; try reopened.save(updated)
        try expectEqual(try reopened.savedViews(),[updated])
        try reopened.storeSelectedView(nil); try expectEqual(try reopened.selectedView(),nil)
    }
    func testOrganizationPersistenceAndExplicitDecisions() throws {
        let url = root.appendingPathComponent("catalog.sqlite")
        let store = try Catalog(url:url)
        let folder = root.appendingPathComponent("Photos"); try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let source = try store.register(FolderAccess.source(for:folder)), asset = UUID()
        let process = Process(); process.executableURL = URL(fileURLWithPath:"/usr/bin/sqlite3")
        process.arguments = [url.path,"INSERT INTO assets(id,source_id,relative_path,byte_size) VALUES('\(asset.uuidString)','\(source.id.uuidString)','photo.jpg',1)"]
        try process.run(); process.waitUntilExit(); try expectEqual(process.terminationStatus,0)
        try store.addManualTag(" Cars ",to:asset)
        let tag = try store.tags(for:asset)[0]; try expectTrue(tag.isConfirmed); try expectEqual(tag.tag,"cars")
        try store.setTagDecision(tag.id,decision:.rejected); try expectTrue(try !store.tags(for:asset)[0].isConfirmed)
        try store.addManualTag("Animals",to:asset,replacing:tag.id)
        try expectEqual(try store.tags(for:asset).filter(\.isConfirmed).map(\.tag),["animals"])
        try store.setFavorite(asset,true)
        let collection = try store.createCollection(name:"Manual picks")
        try store.setMembership(asset,collection:collection.id,member:true); try store.setMembership(asset,collection:collection.id,member:true)
        let reopened = try Catalog(url:url)
        try expectTrue(try reopened.isFavorite(asset)); try expectEqual(try reopened.collectionIDs(for:asset),[collection.id])
        try expectEqual(try reopened.collections(),[collection]); try expectEqual(try reopened.tags(for:asset).filter(\.isConfirmed).map(\.tag),["animals"])
        try reopened.setMembership(asset,collection:collection.id,member:false); try expectTrue(try reopened.collectionIDs(for:asset).isEmpty)
        try expectThrows(try reopened.addManualTag(" ",to:asset)); try expectThrows(try reopened.createCollection(name:" "))
    }
    func testBlankViewNameRejectedWithoutWriting() throws {
        let store = try Catalog(url:root.appendingPathComponent("catalog.sqlite"))
        try expectThrows(try store.save(SavedView(name:" \n ",recipe:ViewRecipe())))
        try expectTrue(try store.savedViews().isEmpty)
    }
    func testFutureSchemaRefusedWithoutDowngrade() throws {
        let url = root.appendingPathComponent("future.sqlite")
        do { _ = try Catalog(url:url) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath:"/usr/bin/sqlite3")
        process.arguments = [url.path,"PRAGMA user_version=99;"]
        try process.run(); process.waitUntilExit()
        try expectEqual(process.terminationStatus,0)
        try expectThrows(try Catalog(url:url))
        let verify = Process(); let pipe = Pipe()
        verify.executableURL = process.executableURL; verify.arguments = [url.path,"PRAGMA user_version;"]
        verify.standardOutput = pipe; try verify.run(); verify.waitUntilExit()
        let result = String(data:pipe.fileHandleForReading.readDataToEndOfFile(),encoding:.utf8)
        try expectEqual(result?.trimmingCharacters(in:.whitespacesAndNewlines),"99")
    }

}

func expectEqual<T: Equatable>(_ left: @autoclosure () throws -> T, _ right: @autoclosure () throws -> T) throws {
    let a = try left(); let b = try right()
    guard a == b else { throw CheckFailure.failed("Values differ: \(a) / \(b)") }
}
func expectTrue(_ value: @autoclosure () throws -> Bool) throws {
    guard try value() else { throw CheckFailure.failed("Expected true") }
}
func expectThrows<T>(_ operation: @autoclosure () throws -> T) throws {
    do { _ = try operation() } catch { return }
    throw CheckFailure.failed("Expected an error")
}
enum CheckFailure: Error { case failed(String) }
@main struct CatalogChecks {
    static func main() throws {
        let suite = CatalogTests()
        for check in [suite.testSourceIdentityAndBookmarkSurviveReopening, suite.testViewAndWorkspaceRecipeRoundTrip, suite.testGroupingIdentityUnknownAndDeterminism, suite.testSavedDefinitionSeparateFromDraftAndIdentityRestores, suite.testOrganizationPersistenceAndExplicitDecisions, suite.testBlankViewNameRejectedWithoutWriting, suite.testFutureSchemaRefusedWithoutDowngrade] {
            try suite.setUpWithError()
            do { try check(); try suite.tearDownWithError() }
            catch { try? suite.tearDownWithError(); throw error }
        }
        print("PASS: source/bookmark persistence, duplicate source identity, saved recipe update/round-trip, workspace persistence, invalid-name rejection, and future-schema refusal.")
    }
}
