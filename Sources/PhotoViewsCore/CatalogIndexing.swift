import Foundation
import CSQLite

extension Catalog {
    func run(_ sql: String, _ values: [String?] = []) throws {
        let stmt = try statement(sql); defer { sqlite3_finalize(stmt) }
        for (index, value) in values.enumerated() { try bind(value,to:Int32(index+1),in:stmt) }
        try finish(stmt)
    }
    func assetRows(_ sql: String, _ values: [String?]) throws -> [AssetRecord] {
        let stmt = try statement(sql); defer { sqlite3_finalize(stmt) }
        for (index,value) in values.enumerated() { try bind(value,to:Int32(index+1),in:stmt) }
        var result: [AssetRecord] = []
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { return result }
            guard step == SQLITE_ROW, let id = UUID(uuidString:text(stmt,0)), let source = UUID(uuidString:text(stmt,1)) else { throw failure() }
            result.append(AssetRecord(id:id,sourceID:source,relativePath:text(stmt,2),fileID:sqlite3_column_type(stmt,3) == SQLITE_NULL ? nil : text(stmt,3),byteSize:sqlite3_column_int64(stmt,4),modifiedAt:sqlite3_column_type(stmt,5) == SQLITE_NULL ? nil : Date(timeIntervalSince1970:sqlite3_column_double(stmt,5))))
        }
    }
    func contentHash(_ id: UUID) throws -> String? {
        let stmt = try statement("SELECT content_hash FROM assets WHERE id=?"); defer { sqlite3_finalize(stmt) }
        try bind(id.uuidString,to:1,in:stmt)
        guard sqlite3_step(stmt) == SQLITE_ROW, sqlite3_column_type(stmt,0) != SQLITE_NULL else { return nil }
        return text(stmt,0)
    }
    func rememberHash(_ id: UUID, _ hash: String) throws { try run("UPDATE assets SET content_hash=? WHERE id=?",[hash,id.uuidString]) }
    /// Move reconciliation only uses an unambiguous identity whose old pathname is absent.
    func movedAsset(source: CatalogSource, root: URL, fileID: String?, size: Int64, modified: Date?, hash: () throws -> String) throws -> AssetRecord? {
        let candidates = try assetRows("SELECT id,source_id,relative_path,file_id,byte_size,modified_at FROM assets WHERE source_id=? AND byte_size=?",[source.id.uuidString,String(size)]).filter {
            $0.modifiedAt == modified && !FileManager.default.fileExists(atPath:root.appendingPathComponent($0.relativePath).path)
        }
        if let fileID {
            let exact = candidates.filter { $0.fileID == fileID }
            if exact.count == 1 { return exact[0] }
        }
        let hashed = try candidates.filter { try contentHash($0.id) != nil }
        guard !hashed.isEmpty else { return nil }
        let newHash = try hash()
        let matches = try hashed.filter { try contentHash($0.id) == newHash }
        return matches.count == 1 ? matches[0] : nil
    }
    @discardableResult func discover(source: CatalogSource, root: URL, relativePath: String, fileID: String?, size: Int64, modified: Date?, token: String, hash: () throws -> String) throws -> UUID {
        let prior = try assetRows("SELECT id,source_id,relative_path,file_id,byte_size,modified_at FROM assets WHERE source_id=? AND relative_path=?",[source.id.uuidString,relativePath]).first
        let existing = try prior ?? movedAsset(source:source,root:root,fileID:fileID,size:size,modified:modified,hash:hash)
        let id = existing?.id ?? UUID()
        let changed = existing == nil || existing?.byteSize != size || existing?.modifiedAt != modified || (prior != nil && existing?.fileID?.hasPrefix("inode-v1:") == true && existing?.fileID != fileID)
        try execute("BEGIN IMMEDIATE")
        do {
            try run("""
            INSERT INTO assets(id,source_id,relative_path,file_id,byte_size,modified_at,scan_token,available)
            VALUES(?,?,?,?,?,?,?,1) ON CONFLICT(id) DO UPDATE SET relative_path=excluded.relative_path,
            file_id=excluded.file_id,byte_size=excluded.byte_size,modified_at=excluded.modified_at,scan_token=excluded.scan_token,available=1
            """,[id.uuidString,source.id.uuidString,relativePath,fileID,String(size),modified.map { String($0.timeIntervalSince1970) },token])
            if changed || existing?.relativePath != relativePath {
                try run("DELETE FROM photo_assets WHERE photo_id=(SELECT photo_id FROM photo_assets WHERE asset_id=?)",[id.uuidString])
                try execute("DELETE FROM photos WHERE NOT EXISTS(SELECT 1 FROM photo_assets WHERE photo_id=photos.id)")
            }
            if changed {
                try run("DELETE FROM metadata WHERE asset_id=?",[id.uuidString])
                try run("DELETE FROM derivatives WHERE asset_id=?",[id.uuidString])
                try run("DELETE FROM embeddings WHERE asset_id=?",[id.uuidString])
                try run("DELETE FROM tag_runs WHERE asset_id=?",[id.uuidString])
                try run("DELETE FROM tag_assignments WHERE asset_id=? AND provenance='suggested' AND decision='unconfirmed'",[id.uuidString])
                try run("UPDATE assets SET content_hash=NULL WHERE id=?",[id.uuidString])
                try run("DELETE FROM index_jobs WHERE asset_id=?",[id.uuidString])
            }
            for stage in [IndexStage.metadata,.preview] {
                try run("INSERT OR IGNORE INTO index_jobs VALUES(?,?,?,?,?,?,?,?)",[UUID().uuidString,source.id.uuidString,id.uuidString,stage.rawValue,IndexState.pending.rawValue,nil,ImagePipeline.version,String(Date().timeIntervalSince1970)])
            }
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
        return id
    }
    func finishDiscovery(sourceID: UUID, token: String) throws {
        try run("UPDATE assets SET available=0 WHERE source_id=? AND (scan_token IS NULL OR scan_token<>?)",[sourceID.uuidString,token])
    }
    public func markSourceUnavailable(_ id: UUID) throws { try scanState(id,"disconnected",error:"Reconnect the drive or restore access. Cached photos remain available.") }
    func recoverJobs(sourceID: UUID) throws {
        try run("UPDATE index_jobs SET state='pending' WHERE source_id=? AND state IN ('running','paused')",[sourceID.uuidString])
    }
    public func queuePreview(_ id: UUID) throws {
        try run("DELETE FROM tag_runs WHERE asset_id=?",[id.uuidString])
        try run("UPDATE index_jobs SET state='pending',error=NULL WHERE asset_id=? AND stage='metadata' AND state='failed'",[id.uuidString])
        try run("UPDATE index_jobs SET state='pending',error=NULL WHERE asset_id=? AND stage='preview' AND pipeline_version=?",[id.uuidString,ImagePipeline.version])
    }
    func pendingAssets(sourceID: UUID) throws -> [AssetRecord] {
        try assetRows("""
        SELECT a.id,a.source_id,a.relative_path,a.file_id,a.byte_size,a.modified_at FROM assets a
        WHERE a.source_id=? AND a.available=1 AND EXISTS(SELECT 1 FROM index_jobs j WHERE j.asset_id=a.id
        AND j.pipeline_version=? AND j.state='pending') ORDER BY a.relative_path
        """,[sourceID.uuidString,ImagePipeline.version])
    }
    func jobState(_ id: UUID, _ stage: IndexStage) throws -> IndexState? {
        let stmt = try statement("SELECT state FROM index_jobs WHERE asset_id=? AND stage=? AND pipeline_version=?"); defer { sqlite3_finalize(stmt) }
        try bind(id.uuidString,to:1,in:stmt); try bind(stage.rawValue,to:2,in:stmt); try bind(ImagePipeline.version,to:3,in:stmt)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return IndexState(rawValue:text(stmt,0))
    }
    func job(_ id: UUID, stage: IndexStage, state: IndexState, error: String? = nil) throws {
        try run("UPDATE index_jobs SET state=?,error=?,updated_at=? WHERE asset_id=? AND stage=? AND pipeline_version=?",[state.rawValue,error,String(Date().timeIntervalSince1970),id.uuidString,stage.rawValue,ImagePipeline.version])
    }
    func saveMetadata(_ value: MetadataRecord, id: UUID) throws {
        let stmt = try statement("INSERT INTO metadata(asset_id,payload,pipeline_version,capture_date) VALUES(?,?,?,?) ON CONFLICT(asset_id) DO UPDATE SET payload=excluded.payload,pipeline_version=excluded.pipeline_version,capture_date=excluded.capture_date"); defer { sqlite3_finalize(stmt) }
        try bind(id.uuidString,to:1,in:stmt); try bind(encoder.encode(value),to:2,in:stmt); try bind(ImagePipeline.version,to:3,in:stmt); try bind(value.captureDate.map { String($0.timeIntervalSince1970) },to:4,in:stmt); try finish(stmt)
    }
    func saveDerivative(_ value: DerivativeRecord) throws {
        try run("""
        INSERT INTO derivatives VALUES(?,?,?,?,?,?,?) ON CONFLICT(asset_id) DO UPDATE SET
        thumbnail_path=excluded.thumbnail_path,analysis_path=excluded.analysis_path,pipeline_version=excluded.pipeline_version,
        preview_source=excluded.preview_source,last_access=excluded.last_access,byte_size=excluded.byte_size
        """,[value.assetID.uuidString,value.thumbnailPath,value.analysisPath,value.pipelineVersion,value.previewSource,String(value.lastAccess.timeIntervalSince1970),String(value.byteSize)])
    }
    public func touchPreviews(_ ids: [UUID]) throws {
        for id in ids { try run("UPDATE derivatives SET last_access=? WHERE asset_id=?",[String(Date().timeIntervalSince1970),id.uuidString]) }
    }
    func derivativeRows() throws -> [DerivativeRecord] {
        let stmt = try statement("SELECT * FROM derivatives ORDER BY last_access,asset_id"); defer { sqlite3_finalize(stmt) }
        var result: [DerivativeRecord] = []
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { return result }
            guard step == SQLITE_ROW, let id = UUID(uuidString:text(stmt,0)) else { throw failure() }
            result.append(DerivativeRecord(assetID:id,thumbnailPath:sqlite3_column_type(stmt,1) == SQLITE_NULL ? nil : text(stmt,1),analysisPath:sqlite3_column_type(stmt,2) == SQLITE_NULL ? nil : text(stmt,2),pipelineVersion:text(stmt,3),previewSource:text(stmt,4),lastAccess:Date(timeIntervalSince1970:sqlite3_column_double(stmt,5)),byteSize:sqlite3_column_int64(stmt,6)))
        }
    }
    func scanState(_ sourceID: UUID, _ state: String, error: String? = nil) throws {
        try run("INSERT INTO source_scans VALUES(?,?,?,?) ON CONFLICT(source_id) DO UPDATE SET state=excluded.state,error=excluded.error,updated_at=excluded.updated_at",[sourceID.uuidString,state,error,String(Date().timeIntervalSince1970)])
    }
    public func progress() throws -> [SourceProgress] {
        let stmt = try statement("""
        SELECT s.id,COALESCE(r.state,'idle'),r.error,
        (SELECT count(*) FROM assets a WHERE a.source_id=s.id),
        (SELECT count(*) FROM metadata m JOIN assets a ON a.id=m.asset_id WHERE a.source_id=s.id),
        (SELECT count(*) FROM index_jobs j WHERE j.source_id=s.id AND j.stage='preview' AND j.state='complete' AND j.pipeline_version=?),
        (SELECT count(*) FROM index_jobs j WHERE j.source_id=s.id AND j.stage='preview' AND j.state='failed' AND j.pipeline_version=?)
        FROM sources s LEFT JOIN source_scans r ON r.source_id=s.id
        """); defer { sqlite3_finalize(stmt) }
        try bind(ImagePipeline.version,to:1,in:stmt); try bind(ImagePipeline.version,to:2,in:stmt)
        var results: [SourceProgress] = []
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { return results }
            guard step == SQLITE_ROW, let id = UUID(uuidString:text(stmt,0)) else { throw failure() }
            results.append(SourceProgress(sourceID:id,state:text(stmt,1),total:Int(sqlite3_column_int(stmt,3)),metadataReady:Int(sqlite3_column_int(stmt,4)),completed:Int(sqlite3_column_int(stmt,5)),failed:Int(sqlite3_column_int(stmt,6)),error:sqlite3_column_type(stmt,2) == SQLITE_NULL ? nil : text(stmt,2)))
        }
    }
    public func indexedAssets(sourceIDs: [UUID] = [], sort: PhotoSort = .captureNewest, limit: Int = 500, readyOnly: Bool = false, selectedID: UUID? = nil, assetID: UUID? = nil) throws -> [IndexedAsset] {
        let order = sort == .filename ? "a.relative_path COLLATE NOCASE,a.id" : "COALESCE(m.capture_date,a.modified_at,0) \(sort == .captureOldest ? "ASC" : "DESC"),a.id"
        var predicates: [String] = []
        if !sourceIDs.isEmpty { predicates.append("a.source_id IN (\(Array(repeating:"?",count:sourceIDs.count).joined(separator:",")))") }
        if let assetID { predicates.append("a.id='\(assetID.uuidString)'") }
        if readyOnly { predicates.append("(j.state IN ('complete','failed')\(selectedID.map { " OR a.id='\($0.uuidString)'" } ?? ""))") }
        let whereClause = predicates.isEmpty ? "" : " WHERE "+predicates.joined(separator:" AND ")
        let stmt = try statement("""
        SELECT a.id,a.source_id,a.relative_path,a.file_id,a.byte_size,a.modified_at,a.available,
        m.payload,d.thumbnail_path,d.analysis_path,d.pipeline_version,d.preview_source,j.state,j.error
        FROM assets a LEFT JOIN metadata m ON m.asset_id=a.id LEFT JOIN derivatives d ON d.asset_id=a.id
        LEFT JOIN index_jobs j ON j.asset_id=a.id AND j.stage='preview' AND j.pipeline_version='\(ImagePipeline.version)'
        \(whereClause) ORDER BY \(order) LIMIT \(max(1,limit))
        """); defer { sqlite3_finalize(stmt) }
        for (index,id) in sourceIDs.enumerated() { try bind(id.uuidString,to:Int32(index+1),in:stmt) }
        var result: [IndexedAsset] = []
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW, let id = UUID(uuidString:text(stmt,0)), let sourceID = UUID(uuidString:text(stmt,1)) else { throw failure() }
            func optional(_ index: Int32) -> String? { sqlite3_column_type(stmt,index) == SQLITE_NULL ? nil : text(stmt,index) }
            result.append(IndexedAsset(asset:AssetRecord(id:id,sourceID:sourceID,relativePath:text(stmt,2),fileID:optional(3),byteSize:sqlite3_column_int64(stmt,4),modifiedAt:sqlite3_column_type(stmt,5) == SQLITE_NULL ? nil : Date(timeIntervalSince1970:sqlite3_column_double(stmt,5))),metadata:sqlite3_column_type(stmt,7) == SQLITE_NULL ? nil : try decoder.decode(MetadataRecord.self,from:data(stmt,7)),thumbnailPath:optional(8),analysisPath:optional(9),pipelineVersion:optional(10),previewSource:optional(11),available:sqlite3_column_int(stmt,6) == 1,previewState:optional(12).flatMap(IndexState.init(rawValue:)),error:optional(13)))
        }
        return result
    }
}
