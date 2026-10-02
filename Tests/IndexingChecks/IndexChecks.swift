import Foundation
import PhotoViewsCore
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import Darwin

struct Failure: Error, CustomStringConvertible { let description: String }
func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try value() else { throw Failure(description:message) }
}
func sql(_ url: URL, _ command: String) throws {
    let process = Process(); process.executableURL = URL(fileURLWithPath:"/usr/bin/sqlite3"); process.arguments = [url.path,command]
    try process.run(); process.waitUntilExit(); try check(process.terminationStatus == 0,"SQLite fixture setup failed")
}
func fixture(_ url: URL, orientation: Int = 1) throws {
    let space = CGColorSpace(name:CGColorSpace.sRGB)!
    let context = CGContext(data:nil,width:480,height:320,bitsPerComponent:8,bytesPerRow:0,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red:0.15,green:0.45,blue:0.8,alpha:1)); context.fill(CGRect(x:0,y:0,width:480,height:320))
    context.setFillColor(CGColor(red:0.9,green:0.4,blue:0.15,alpha:1)); context.fill(CGRect(x:0,y:0,width:180,height:320))
    let destination = CGImageDestinationCreateWithURL(url as CFURL,UTType.jpeg.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(destination,context.makeImage()!,[kCGImagePropertyOrientation:orientation,kCGImagePropertyTIFFDictionary:[kCGImagePropertyTIFFModel:"Fixture camera"],kCGImagePropertyExifDictionary:[kCGImagePropertyExifDateTimeOriginal:"2025:04:03 12:30:00",kCGImagePropertyExifISOSpeedRatings:[200],kCGImagePropertyExifFNumber:2.8]] as CFDictionary)
    try check(CGImageDestinationFinalize(destination),"Could not create synthetic fixture")
}
func index(_ coordinator: IndexCoordinator, catalog: URL, cache: URL, source: CatalogSource, limit: Int64 = 2*1024*1024*1024, event: @escaping (IndexEvent) -> Void = { _ in }) throws {
    let done = DispatchSemaphore(value:0)
    let lock = NSLock(); var failure: String?
    try check(coordinator.start(catalogURL:catalog,cacheURL:cache,sources:[source],cacheLimit:limit,onEvent:{ value in
        event(value)
        if case .finished(let message) = value { lock.lock(); failure = message; lock.unlock(); done.signal() }
    }),"Worker already running")
    try check(done.wait(timeout:.now()+180) == .success,"Indexer timed out")
    lock.lock(); let message = failure; lock.unlock()
    if let message { throw Failure(description:message) }
}

@main struct IndexChecks {
    static func main() throws {
        if CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "--m7-volume" {
            let root = URL(fileURLWithPath:CommandLine.arguments[2]), folder = URL(fileURLWithPath:CommandLine.arguments[3])
            let db = root.appendingPathComponent("catalog.sqlite"), store = try Catalog(url:db)
            let source = try store.sources().first ?? store.register(FolderAccess.source(for:folder))
            var fallback = source; fallback.bookmark = Data("invalidated bookmark".utf8); fallback.lastKnownPath = "/Volumes/Old Mount/Photos"
            try check(try FolderAccess.resolve(fallback).url.standardizedFileURL == folder.standardizedFileURL,"Mounted volume UUID fallback failed")
            try index(IndexCoordinator(),catalog:db,cache:root.appendingPathComponent("previews"),source:source)
            if try store.savedViews().isEmpty {
                var recipe = ViewRecipe(); recipe.sourceIDs = [source.id]; recipe.search = "DSC_0105"; recipe.searchMode = "filename"; recipe.grouping = .month
                try store.save(SavedView(name:"Live paired photos",recipe:recipe)); try store.storeWorkspaceRecipe(recipe)
                for member in try store.indexedAssets() { try store.addManualTag("cars",to:member.id) }
            }
            print("Volume integration:",try store.progress()[0].state,"assets",try store.indexedAssets().count,"pair members",try store.pairMembers(store.indexedAssets()[0].id).count)
            return
        }
        if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--m7-archive" {
            let store = try Catalog(url:URL(fileURLWithPath:CommandLine.arguments[2]))
            for source in try store.sources() {
                do { print("Resolved source:",try FolderAccess.resolve(source).url.path) } catch { print("Resolution error:",error) }
                try store.reconcilePairs(sourceID:source.id)
                let all = try store.indexedAssets(sourceIDs:[source.id],limit:Int.max)
                var ids = Set<UUID>(), pair: [IndexedAsset] = []
                for asset in all { let members = try store.pairMembers(asset.id); if members.count == 2 { ids.insert(members.map(\.id).sorted { $0.uuidString < $1.uuidString }[0]); if pair.isEmpty { pair = members } } }
                print("Actual cached associations:",ids.count)
                for member in pair { let url = URL(fileURLWithPath:source.lastKnownPath).appendingPathComponent(member.asset.relativePath); print(member.asset.relativePath,"SHA256",try ImagePipeline.hash(url)) }
            }
            return
        }
        if CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "--live-view" {
            let root = URL(fileURLWithPath:CommandLine.arguments[2]), phase = CommandLine.arguments[3]
            let photos = root.appendingPathComponent("Photos"), db = root.appendingPathComponent("catalog.sqlite")
            try FileManager.default.createDirectory(at:photos,withIntermediateDirectories:true)
            let store = try Catalog(url:db)
            if phase == "setup" {
                try fixture(photos.appendingPathComponent("matching-one.jpg"))
                let source = try store.register(FolderAccess.source(for:photos))
                try index(IndexCoordinator(),catalog:db,cache:root.appendingPathComponent("previews"),source:source)
                var recipe = ViewRecipe(); recipe.sourceIDs = [source.id]; recipe.search = "matching"; recipe.searchMode = "filename"
                recipe.filters.camera = "Fixture camera"; recipe.grouping = .month; recipe.sorting = .filename
                try store.save(SavedView(name:"Matching photos",recipe:recipe))
                recipe.search = ""; recipe.searchMode = "visual"; recipe.referenceAssetID = try store.indexedAssets()[0].id
                recipe.modelVersion = "openclip-vit-b32-1a25a446712ba5ee05982a381eed697ef9b435cf:imageio-m2-v1:search-v1"; recipe.rankingVersion = "rrf-k60-v1"
                try store.save(SavedView(name:"Similar fixture photos",recipe:recipe))
            } else if phase == "add" {
                try fixture(photos.appendingPathComponent("matching-two.jpg"))
                try index(IndexCoordinator(),catalog:db,cache:root.appendingPathComponent("previews"),source:store.sources()[0])
            } else { throw Failure(description:"Unknown live-view fixture phase") }
            print("PASS: native live-view fixture phase "+phase); return
        }
        if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--interrupt-worker" {
            let base = URL(fileURLWithPath:CommandLine.arguments[2])
            let db = base.appendingPathComponent("catalog.sqlite")
            let source = try Catalog(url:db).sources()[0]
            let semaphore = DispatchSemaphore(value:0)
            let worker = IndexCoordinator()
            worker.start(catalogURL:db,cacheURL:base.appendingPathComponent("Cache"),sources:[source],onEvent:{ event in
                if case .checkpoint(_, .metadata) = event { _exit(17) }
                if case .finished = event { semaphore.signal() }
            })
            _ = semaphore.wait(timeout:.now()+30); throw Failure(description:"Interrupt checkpoint not reached")
        }
        if CommandLine.arguments.count == 5 && CommandLine.arguments[1] == "--fixtures" {
            try realFixtures(manifest:URL(fileURLWithPath:CommandLine.arguments[2]),sourceRoot:URL(fileURLWithPath:CommandLine.arguments[3]),output:URL(fileURLWithPath:CommandLine.arguments[4])); return
        }
        try checkM7()
        var exposure = MetadataRecord()
        exposure.shutterSeconds = 1.0 / 8000
        try check(exposure.exposureDescription == "1/8000 s", "Fast shutter speed lost precision")
        exposure.shutterSeconds = 2.5
        try check(exposure.exposureDescription == 2.5.formatted(.number.precision(.significantDigits(1...6))) + " s", "Long exposure lost precision")
        exposure.shutterSeconds = .nan
        try check(exposure.exposureDescription == nil, "Invalid exposure should be unknown")
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("PhotoViews-IndexChecks-"+UUID().uuidString)
        try fm.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? fm.removeItem(at:root) }
        let photos = root.appendingPathComponent("Photos"), cache = root.appendingPathComponent("Cache"), db = root.appendingPathComponent("catalog.sqlite")
        try fm.createDirectory(at:photos,withIntermediateDirectories:true)
        let original = photos.appendingPathComponent("a-oriented.jpg")
        try fixture(original,orientation:6)
        try fixture(photos.appendingPathComponent("b.jpg"))
        try Data("damaged RAW fixture".utf8).write(to:photos.appendingPathComponent("broken.nef"))
        try Data("AppleDouble".utf8).write(to:photos.appendingPathComponent("._a-oriented.jpg"))
        let before = try ImagePipeline.hash(original)
        let source = try Catalog(url:db).register(FolderAccess.source(for:photos))
        let worker = IndexCoordinator()
        // Pause immediately after a durable preview checkpoint; resume must reuse its derivative.
        var first: UUID?
        try index(worker,catalog:db,cache:cache,source:source,event:{ event in
            if case .checkpoint(let id,.preview) = event, first == nil { first = id; worker.pause() }
        })
        var store = try Catalog(url:db)
        try check(try store.progress().first?.state == "paused","Pause was not persisted")
        let checkpoint = try store.indexedAssets().first { $0.id == first }!
        let preview = URL(fileURLWithPath:checkpoint.thumbnailPath!)
        let checkpointDate = try preview.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate
        // A reopened coordinator and connection simulate resume from persisted checkpoints.
        try index(IndexCoordinator(),catalog:db,cache:cache,source:source)
        store = try Catalog(url:db)
        var assets = try store.indexedAssets()
        try check(assets.count == 3,"Discovery included hidden sidecars or omitted damaged files")
        try check(assets.filter { $0.previewState == .complete }.count == 2,"Usable files did not complete")
        try check(assets.filter { $0.previewState == .failed && $0.error != nil }.count == 1,"Failure was not isolated and actionable")
        try check(try preview.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate == checkpointDate,"Completed preview was regenerated on resume")
        let oriented = assets.first { $0.filename == "a-oriented.jpg" }!
        try check(try store.indexedAssets(limit:1,assetID:oriented.id).first?.id == oriented.id, "Selected asset lookup lost its identity outside pagination")
        try check(try store.indexedAssets(assetID:UUID()).isEmpty, "Unknown selection returned unrelated photos")
        let image = CGImageSourceCreateWithURL(URL(fileURLWithPath:oriented.analysisPath!) as CFURL,nil)!
        let p = CGImageSourceCopyPropertiesAtIndex(image,0,nil)! as NSDictionary
        try check(p[kCGImagePropertyPixelWidth] as? Int == 320 && p[kCGImagePropertyPixelHeight] as? Int == 480,"Orientation transform failed")
        try check(oriented.metadata?.camera == "Fixture camera" && oriented.metadata?.iso == 200,"Original metadata was not retained")
        try check(try ImagePipeline.hash(original) == before,"Original changed during indexing")
        // Unchanged refresh must reuse completed output and failed-file status.
        try index(IndexCoordinator(),catalog:db,cache:cache,source:source)
        try check(try preview.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate == checkpointDate,"Unchanged file was decoded again")
        let moved = photos.appendingPathComponent("renamed.jpg")
        try fm.moveItem(at:original,to:moved)
        try index(IndexCoordinator(),catalog:db,cache:cache,source:source)
        assets = try store.indexedAssets()
        try check(assets.first { $0.filename == "renamed.jpg" }?.id == oriented.id,"Move lost stable asset identity")
        try check(assets.count == 3,"Move created an unnecessary duplicate")
        try store.addManualTag("cars",to:oriented.id)
        let corrected = try store.tags(for:oriented.id)[0]
        try store.setTagDecision(corrected.id,decision:.rejected)
        try store.addManualTag("animals",to:oriented.id)
        try store.setFavorite(oriented.id,true)
        let picks = try store.createCollection(name:"Preserved picks")
        try store.setMembership(oriented.id,collection:picks.id,member:true)
        try fixture(moved,orientation:1)
        try index(IndexCoordinator(),catalog:db,cache:cache,source:source)
        let changed = try store.indexedAssets().first { $0.id == oriented.id }!
        let changedImage = CGImageSourceCreateWithURL(URL(fileURLWithPath:changed.analysisPath!) as CFURL,nil)!
        let changedProperties = CGImageSourceCopyPropertiesAtIndex(changedImage,0,nil)! as NSDictionary
        try check(changedProperties[kCGImagePropertyPixelWidth] as? Int == 480,"Changed content did not reindex")
        try check(try store.tags(for:oriented.id).first(where:{ $0.tag == "cars" })?.decision == .rejected,"Reindex undid a rejection")
        try check(try store.tags(for:oriented.id).first(where:{ $0.tag == "animals" })?.isConfirmed == true,"Reindex lost a confirmed correction")
        try check(try store.isFavorite(oriented.id) && store.collectionIDs(for:oriented.id).contains(picks.id),"Reindex lost manual organization")
        // Recovery of a process-interrupted running job.
        try sql(db,"UPDATE index_jobs SET state='running' WHERE asset_id='\(oriented.id.uuidString)' AND stage='preview'; UPDATE source_scans SET state='indexing';")
        try index(IndexCoordinator(),catalog:db,cache:cache,source:source)
        try check(try store.indexedAssets().first { $0.id == oriented.id }?.previewState == .complete,"Interrupted job was not recovered")
        // Terminate an actual separate worker process after its durable metadata checkpoint.
        try fixture(photos.appendingPathComponent("c-interrupted.jpg"))
        let child = Process(); child.executableURL = URL(fileURLWithPath:CommandLine.arguments[0])
        child.arguments = ["--interrupt-worker",root.path]
        try child.run(); child.waitUntilExit()
        try check(child.terminationStatus == 17,"Child did not terminate at its checkpoint")
        let interruptedAsset = try store.indexedAssets().first { $0.filename == "c-interrupted.jpg" }!
        try check(interruptedAsset.metadata != nil && interruptedAsset.previewState == .pending,"Crash lost completed metadata or invented a preview")
        try index(IndexCoordinator(),catalog:db,cache:cache,source:source)
        try check(try store.indexedAssets().first { $0.id == interruptedAsset.id }?.previewState == .complete,"True process interruption did not resume")
        // Removing one file marks only that asset unavailable after a successful scan.
        try fm.removeItem(at:photos.appendingPathComponent("b.jpg"))
        try index(IndexCoordinator(),catalog:db,cache:cache,source:source)
        try check(try store.indexedAssets().first { $0.filename == "b.jpg" }?.available == false,"Missing file still available")
        // A source that cannot resolve cannot be treated as an empty/deleted source.
        let disconnected = CatalogSource(id:source.id,name:source.name,bookmark:Data(),volumeID:source.volumeID,relativePath:source.relativePath,lastKnownPath:source.lastKnownPath)
        let count = try store.indexedAssets().count
        try index(IndexCoordinator(),catalog:db,cache:cache,source:disconnected)
        try check(try store.indexedAssets().count == count,"Disconnected source lost records")
        try check(try store.indexedAssets().first { $0.id == oriented.id }?.thumbnailPath != nil,"Offline cache disappeared")
        // Cache eviction never removes assets, metadata, or originals.
        let originalHash = try ImagePipeline.hash(moved)
        try PreviewCache(root:cache,limitBytes:0).prune(catalog:store)
        try check(try store.indexedAssets().count == count,"Eviction removed catalog assets")
        try check(try store.indexedAssets().allSatisfy { $0.thumbnailPath == nil && $0.analysisPath == nil },"Quota eviction left derivatives")
        try check(try ImagePipeline.hash(moved) == originalHash,"Eviction touched an original")
        // Reconstruct the M1 schema and prove its source/recipe records migrate intact.
        var recipe = ViewRecipe(); recipe.sourceIDs = [source.id]; try store.storeWorkspaceRecipe(recipe)
        try sql(db,"DROP TABLE pair_exclusions; DROP INDEX tag_asset_name; DROP TABLE tag_runs; ALTER TABLE tag_assignments DROP COLUMN score; ALTER TABLE tag_assignments DROP COLUMN threshold; ALTER TABLE tag_assignments DROP COLUMN vocabulary_version; DROP INDEX job_asset_stage_version; DROP TABLE derivatives; DROP TABLE source_scans; DROP INDEX asset_file_identity; ALTER TABLE assets DROP COLUMN scan_token; ALTER TABLE assets DROP COLUMN content_hash; ALTER TABLE metadata DROP COLUMN capture_date; PRAGMA user_version=1;")
        let migrated = try Catalog(url:db)
        try check(try migrated.version == Catalog.schemaVersion && migrated.sources().first?.id == source.id && migrated.workspaceRecipe() == recipe,"M1 migration lost records")
        print("PASS: orientation, original metadata/integrity, failure isolation, hidden sidecars, pause/reopen/resume, unchanged reuse, stable moves, changed-file reindex, interrupted jobs and actual worker-process termination, missing/disconnected semantics, cache quota, and M1 migration.")
    }
    static func realFixtures(manifest: URL, sourceRoot: URL, output: URL) throws {
        let entries = try JSONSerialization.jsonObject(with:Data(contentsOf:manifest)) as! [[String:Any]]
        let cache = try PreviewCache(root:output.appendingPathComponent("previews"))
        guard !cache.root.path.hasPrefix(sourceRoot.standardizedFileURL.resolvingSymlinksInPath().path+"/") else { throw Failure(description:"Fixture output must be outside originals") }
        var formats: [String:Int] = [:], cameras: [String:Int] = [:]
        let start = Date()
        for entry in entries {
            try autoreleasepool {
                guard let relative = entry["relativePath"] as? String, !relative.hasPrefix("/"), !relative.split(separator:"/").contains("..") else { throw Failure(description:"Invalid fixture path") }
                let original = sourceRoot.appendingPathComponent(relative)
                let before = try ImagePipeline.hash(original)
                let metadata = try ImagePipeline.metadata(original)
                let result = try ImagePipeline.previews(original,id:UUID(),cache:cache)
                let image = CGImageSourceCreateWithURL(URL(fileURLWithPath:result.analysisPath!) as CFURL,nil)!
                let p = CGImageSourceCopyPropertiesAtIndex(image,0,nil)! as NSDictionary
                let width = p[kCGImagePropertyPixelWidth] as! Int, height = p[kCGImagePropertyPixelHeight] as! Int
                try check(max(width,height) <= 1600 && min(width,height) >= 224,"Unusable actual-fixture preview")
                if let w = entry["previewWidth"] as? Int, let h = entry["previewHeight"] as? Int {
                    // RAW sensor dimensions can differ from the camera's intentional embedded-preview crop.
                    try check(abs(Double(width)/Double(height)-Double(w)/Double(h)) < 0.03,"Actual fixture differs from the validated M0 preview geometry")
                }
                try check(try ImagePipeline.hash(original) == before,"Actual original changed")
                formats[metadata.format ?? "Unknown",default:0] += 1
                cameras[metadata.camera ?? "Unknown",default:0] += 1
            }
        }
        let report: [String:Any] = ["pipeline":ImagePipeline.version,"fixtures":entries.count,"formats":formats,"cameras":cameras,"M0PreviewGeometryMatches":entries.count,"originalHashChecksPassed":entries.count,"elapsedSeconds":Date().timeIntervalSince(start)]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("summary.json"),options:.atomic)
        print(String(data:try JSONSerialization.data(withJSONObject:report,options:.sortedKeys),encoding:.utf8)!)
    }

}
