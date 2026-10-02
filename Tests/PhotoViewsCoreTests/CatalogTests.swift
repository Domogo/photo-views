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
        for check in [suite.testSourceIdentityAndBookmarkSurviveReopening, suite.testViewAndWorkspaceRecipeRoundTrip, suite.testBlankViewNameRejectedWithoutWriting, suite.testFutureSchemaRefusedWithoutDowngrade] {
            try suite.setUpWithError()
            do { try check(); try suite.tearDownWithError() }
            catch { try? suite.tearDownWithError(); throw error }
        }
        print("PASS: source/bookmark persistence, duplicate source identity, saved recipe update/round-trip, workspace persistence, invalid-name rejection, and future-schema refusal.")
    }
}
