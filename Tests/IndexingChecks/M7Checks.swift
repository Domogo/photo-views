import Foundation
import PhotoViewsCore

func checkM7() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("PhotoViews-M7-"+UUID().uuidString)
    try fm.createDirectory(at:root,withIntermediateDirectories:true); defer { try? fm.removeItem(at:root) }
    let photos = root.appendingPathComponent("Photos"), db = root.appendingPathComponent("catalog.sqlite"), cache = root.appendingPathComponent("Cache")
    try fm.createDirectory(at:photos,withIntermediateDirectories:true)
    for name in ["a.jpg","b.jpg","c.jpg"] { try fixture(photos.appendingPathComponent(name)) }
    let before = try ImagePipeline.hash(photos.appendingPathComponent("a.jpg"))
    let store = try Catalog(url:db), source = try store.register(FolderAccess.source(for:photos))
    var detached = false
    let absent = root.appendingPathComponent("Detached")
    try index(IndexCoordinator(),catalog:db,cache:cache,source:source,event:{ event in
        if case .checkpoint(_, .preview) = event, !detached { detached = true; try! fm.moveItem(at:photos,to:absent) }
    })
    try check(try store.progress()[0].state == "disconnected","Mid-index disconnect was misreported as corrupt files")
    let checkpoint = try store.indexedAssets().first { $0.previewState == .complete }!
    try store.addManualTag("water",to:checkpoint.id); try store.setFavorite(checkpoint.id,true)
    var recipe = ViewRecipe(); recipe.sourceIDs = [source.id]; recipe.filters.confirmedTags = ["water"]; recipe.collapsePairs = true
    try store.save(SavedView(name:"Offline water",recipe:recipe)); try store.storeWorkspaceRecipe(recipe)
    let reopened = try Catalog(url:db)
    try check(try reopened.indexedAssets().count == 3 && reopened.savedViews()[0].recipe == recipe,"Restart while disconnected lost records or recipe")
    try check(checkpoint.thumbnailPath.map { fm.fileExists(atPath:$0) } == true,"Offline cached preview missing")
    try fm.moveItem(at:absent,to:photos)
    try index(IndexCoordinator(),catalog:db,cache:cache,source:source)
    try check(try reopened.indexedAssets().allSatisfy { $0.previewState == .complete },"Reconnect did not resume pending jobs")
    try check(try reopened.tags(for:checkpoint.id)[0].isConfirmed && reopened.isFavorite(checkpoint.id),"Reconnect lost manual organization")
    try check(try ImagePipeline.hash(photos.appendingPathComponent("a.jpg")) == before,"Reconnect changed original")
    var wrong = source; wrong.volumeID = "unrelated-volume"
    do { _ = try FolderAccess.resolve(wrong); throw Failure(description:"Wrong-volume pathname was accepted") }
    catch is CocoaError { }
    // Synthetic metadata isolates association rules from any camera decoder's behavior.
    var metadata = MetadataRecord(); metadata.camera = "Fixture camera"; metadata.captureDateText = "2025:04:03 12:30:00"
    let encoded = String(data:try JSONEncoder().encode(metadata),encoding:.utf8)!.replacingOccurrences(of:"'",with:"''")
    let raw = UUID(), jpeg = UUID()
    for (id,path) in [(raw,"pair.NEF"),(jpeg,"pair.JPG")] {
        try sql(db,"INSERT INTO assets(id,source_id,relative_path,byte_size,available) VALUES('\(id.uuidString)','\(source.id.uuidString)','\(path)',10,0); INSERT INTO metadata VALUES('\(id.uuidString)',CAST('\(encoded)' AS BLOB),'imageio-m2-v1',0);")
    }
    try store.reconcilePairs(sourceID:source.id)
    try check(try store.pairMembers(raw).count == 2,"Conservative pair was not formed")
    try store.separatePair(containing:jpeg); try store.reconcilePairs(sourceID:source.id)
    try check(try Catalog(url:db).pairMembers(raw).isEmpty,"Manual separation did not survive rescan/restart")
    try store.restorePairing(sourceID:source.id)
    try check(try store.pairMembers(raw).count == 2,"Separate pair could not be reversed")
    let extra = UUID()
    try sql(db,"INSERT INTO assets(id,source_id,relative_path,byte_size) VALUES('\(extra.uuidString)','\(source.id.uuidString)','pair.jpeg',10); INSERT INTO metadata VALUES('\(extra.uuidString)',CAST('\(encoded)' AS BLOB),'imageio-m2-v1',0);")
    try store.reconcilePairs(sourceID:source.id)
    try check(try store.pairMembers(raw).isEmpty,"Ambiguous RAW/two JPEG group collapsed")
    try sql(db,"DELETE FROM metadata WHERE asset_id='\(extra.uuidString)'; DELETE FROM assets WHERE id='\(extra.uuidString)'; UPDATE metadata SET payload=CAST('{\"camera\":\"Different\",\"captureDateText\":\"2025:04:03 12:30:00\"}' AS BLOB) WHERE asset_id='\(jpeg.uuidString)';")
    try store.reconcilePairs(sourceID:source.id)
    try check(try store.pairMembers(raw).isEmpty,"Different camera paired")
    try sql(db,"UPDATE metadata SET payload=CAST('\(encoded)' AS BLOB) WHERE asset_id='\(jpeg.uuidString)';")
    try store.reconcilePairs(sourceID:source.id)
    try check(try store.pairMembers(jpeg).count == 2,"Valid offline cached pair lost association")
    try check(try store.indexedAssets().count == 5 && store.savedViews()[0].recipe == recipe,"Pairing modified asset/view membership")
    print("PASS M7: mid-index detach/restart/reconnect, original hash, cached preview, confirmed tag/favorite/saved recipe, wrong-volume refusal, conservative offline pair, ambiguity/camera mismatch, durable separation and reversible restoration.")
}
