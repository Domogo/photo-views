import Foundation
import CSQLite

public enum CatalogError: LocalizedError {
    case sqlite(String), unsupportedVersion(Int), invalidName
    public var errorDescription: String? {
        switch self {
        case .sqlite(let message): return "The local catalog could not be read or saved: \(message)"
        case .unsupportedVersion(let version): return "This catalog uses version \(version), which this build cannot open. Use a newer app build."
        case .invalidName: return "Enter a name before saving."
        }
    }
}

/// Single-threaded store. The app owns it on the main actor; indexing will use a separate connection.
public final class Catalog {
    var db: OpaquePointer?
    public let url: URL
    public static let schemaVersion = 2
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let error = CatalogError.sqlite(db.map { String(cString: sqlite3_errmsg($0)) } ?? "Cannot open database")
            if let db { sqlite3_close(db) }; db = nil
            throw error
        }
        do {
            sqlite3_busy_timeout(db, 5000)
            try execute("PRAGMA foreign_keys=ON")
            let version = try scalar("PRAGMA user_version")
            guard version <= Self.schemaVersion else { throw CatalogError.unsupportedVersion(version) }
            if version == 0 { try migrate() }
            if try scalar("PRAGMA user_version") == 1 { try migrateIndexing() }
            try execute("PRAGMA journal_mode=WAL")
        } catch {
            if let db { sqlite3_close(db) }; db = nil
            throw error
        }
    }
    deinit { if let db { sqlite3_close(db) } }
    public var version: Int { get throws { try scalar("PRAGMA user_version") } }

    private func migrateIndexing() throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("""
            ALTER TABLE assets ADD COLUMN scan_token TEXT;
            ALTER TABLE assets ADD COLUMN content_hash TEXT;
            ALTER TABLE metadata ADD COLUMN capture_date REAL;
            CREATE INDEX asset_file_identity ON assets(source_id,file_id);
            CREATE UNIQUE INDEX job_asset_stage_version ON index_jobs(asset_id,stage,pipeline_version);
            CREATE TABLE derivatives(asset_id TEXT PRIMARY KEY REFERENCES assets(id), thumbnail_path TEXT,
              analysis_path TEXT, pipeline_version TEXT NOT NULL, preview_source TEXT NOT NULL,
              last_access REAL NOT NULL, byte_size INTEGER NOT NULL);
            CREATE TABLE source_scans(source_id TEXT PRIMARY KEY REFERENCES sources(id), state TEXT NOT NULL,
              error TEXT, updated_at REAL NOT NULL);
            PRAGMA user_version=2;
            """)
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
    private func migrate() throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("""
            CREATE TABLE sources(id TEXT PRIMARY KEY, name TEXT NOT NULL, bookmark BLOB NOT NULL,
              volume_id TEXT, relative_path TEXT NOT NULL, last_known_path TEXT NOT NULL, created_at REAL NOT NULL);
            CREATE UNIQUE INDEX source_volume_path ON sources(volume_id,relative_path) WHERE volume_id IS NOT NULL;
            CREATE TABLE assets(id TEXT PRIMARY KEY, source_id TEXT NOT NULL REFERENCES sources(id),
              relative_path TEXT NOT NULL, file_id TEXT, byte_size INTEGER NOT NULL, modified_at REAL,
              available INTEGER NOT NULL DEFAULT 1, favorite INTEGER NOT NULL DEFAULT 0,
              UNIQUE(source_id,relative_path));
            CREATE TABLE photos(id TEXT PRIMARY KEY, primary_asset_id TEXT REFERENCES assets(id));
            CREATE TABLE photo_assets(photo_id TEXT NOT NULL REFERENCES photos(id), asset_id TEXT NOT NULL UNIQUE REFERENCES assets(id),
              PRIMARY KEY(photo_id,asset_id));
            CREATE TABLE metadata(asset_id TEXT PRIMARY KEY REFERENCES assets(id), payload BLOB NOT NULL, pipeline_version TEXT NOT NULL);
            CREATE TABLE embeddings(asset_id TEXT NOT NULL REFERENCES assets(id), model_version TEXT NOT NULL,
              dimensions INTEGER NOT NULL, vector BLOB NOT NULL, PRIMARY KEY(asset_id,model_version));
            CREATE TABLE tag_assignments(id TEXT PRIMARY KEY, asset_id TEXT NOT NULL REFERENCES assets(id), tag TEXT NOT NULL,
              provenance TEXT NOT NULL, decision TEXT NOT NULL, model_version TEXT);
            CREATE TABLE collections(id TEXT PRIMARY KEY, name TEXT NOT NULL);
            CREATE TABLE collection_assets(collection_id TEXT NOT NULL REFERENCES collections(id), asset_id TEXT NOT NULL REFERENCES assets(id),
              PRIMARY KEY(collection_id,asset_id));
            CREATE TABLE saved_views(id TEXT PRIMARY KEY, name TEXT NOT NULL, recipe BLOB NOT NULL, created_at REAL NOT NULL);
            CREATE TABLE index_jobs(id TEXT PRIMARY KEY, source_id TEXT NOT NULL REFERENCES sources(id), asset_id TEXT REFERENCES assets(id),
              stage TEXT NOT NULL, state TEXT NOT NULL, error TEXT, pipeline_version TEXT, updated_at REAL NOT NULL);
            CREATE TABLE workspace_state(key TEXT PRIMARY KEY,payload BLOB NOT NULL);
            PRAGMA user_version=1;
            """)
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
    func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }
    func failure() -> CatalogError { .sqlite(String(cString: sqlite3_errmsg(db))) }
    func statement(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw failure() }
        return stmt
    }
    func bind(_ value: String?, to index: Int32, in stmt: OpaquePointer) throws {
        let result = value.map { sqlite3_bind_text(stmt, index, $0, -1, transient) } ?? sqlite3_bind_null(stmt, index)
        guard result == SQLITE_OK else { throw failure() }
    }
    func bind(_ data: Data, to index: Int32, in stmt: OpaquePointer) throws {
        let result = data.withUnsafeBytes { sqlite3_bind_blob(stmt, index, $0.baseAddress, Int32($0.count), transient) }
        guard result == SQLITE_OK else { throw failure() }
    }
    func scalar(_ sql: String) throws -> Int {
        let stmt = try statement(sql); defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw failure() }
        return Int(sqlite3_column_int(stmt, 0))
    }
    func text(_ stmt: OpaquePointer, _ index: Int32) -> String {
        sqlite3_column_text(stmt, index).map { String(cString: $0) } ?? ""
    }
    func data(_ stmt: OpaquePointer, _ index: Int32) -> Data {
        guard let bytes = sqlite3_column_blob(stmt, index) else { return Data() }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, index)))
    }
    func finish(_ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw failure() }
    }

    public func sources() throws -> [CatalogSource] {
        let stmt = try statement("SELECT id,name,bookmark,volume_id,relative_path,last_known_path,created_at FROM sources ORDER BY created_at,id")
        defer { sqlite3_finalize(stmt) }
        var results: [CatalogSource] = []
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW, let id = UUID(uuidString: text(stmt,0)) else { throw failure() }
            results.append(CatalogSource(id: id, name: text(stmt,1), bookmark: data(stmt,2),
                volumeID: sqlite3_column_type(stmt,3) == SQLITE_NULL ? nil : text(stmt,3), relativePath: text(stmt,4),
                lastKnownPath: text(stmt,5), createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt,6))))
        }
        return results
    }
    @discardableResult public func register(_ source: CatalogSource) throws -> CatalogSource {
        let existing = try sources().first {
            if let volume = source.volumeID, $0.volumeID == volume { return $0.relativePath == source.relativePath }
            return $0.lastKnownPath == source.lastKnownPath
        }
        var stored = source
        if let existing { stored = CatalogSource(id: existing.id, name: source.name, bookmark: source.bookmark,
            volumeID: source.volumeID, relativePath: source.relativePath, lastKnownPath: source.lastKnownPath, createdAt: existing.createdAt) }
        let stmt = try statement("INSERT INTO sources VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,bookmark=excluded.bookmark,volume_id=excluded.volume_id,relative_path=excluded.relative_path,last_known_path=excluded.last_known_path")
        defer { sqlite3_finalize(stmt) }
        try bind(stored.id.uuidString,to:1,in:stmt); try bind(stored.name,to:2,in:stmt)
        try bind(stored.bookmark,to:3,in:stmt); try bind(stored.volumeID,to:4,in:stmt)
        try bind(stored.relativePath,to:5,in:stmt); try bind(stored.lastKnownPath,to:6,in:stmt)
        sqlite3_bind_double(stmt,7,stored.createdAt.timeIntervalSince1970)
        try finish(stmt)
        return stored
    }
    public func save(_ view: SavedView) throws {
        let name = view.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CatalogError.invalidName }
        let stmt = try statement("INSERT INTO saved_views VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,recipe=excluded.recipe")
        defer { sqlite3_finalize(stmt) }
        try bind(view.id.uuidString,to:1,in:stmt); try bind(name,to:2,in:stmt)
        try bind(encoder.encode(view.recipe),to:3,in:stmt)
        sqlite3_bind_double(stmt,4,view.createdAt.timeIntervalSince1970)
        try finish(stmt)
    }
    public func savedViews() throws -> [SavedView] {
        let stmt = try statement("SELECT id,name,recipe,created_at FROM saved_views ORDER BY created_at,id")
        defer { sqlite3_finalize(stmt) }
        var results: [SavedView] = []
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { break }
            guard step == SQLITE_ROW, let id = UUID(uuidString:text(stmt,0)) else { throw failure() }
            results.append(SavedView(id:id,name:text(stmt,1),recipe:try decoder.decode(ViewRecipe.self,from:data(stmt,2)),createdAt:Date(timeIntervalSince1970:sqlite3_column_double(stmt,3))))
        }
        return results
    }
    public func storeSelectedView(_ id: UUID?) throws {
        let stmt = try statement("INSERT INTO workspace_state VALUES('selectedView',?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload")
        defer { sqlite3_finalize(stmt) }; try bind(encoder.encode(id),to:1,in:stmt); try finish(stmt)
    }
    public func selectedView() throws -> UUID? {
        let stmt = try statement("SELECT payload FROM workspace_state WHERE key='selectedView'")
        defer { sqlite3_finalize(stmt) }
        let step = sqlite3_step(stmt)
        if step == SQLITE_DONE { return nil }
        guard step == SQLITE_ROW else { throw failure() }
        return try decoder.decode(UUID?.self,from:data(stmt,0))
    }
    public func storeWorkspaceRecipe(_ recipe: ViewRecipe) throws {
        let stmt = try statement("INSERT INTO workspace_state VALUES('recipe',?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload")
        defer { sqlite3_finalize(stmt) }; try bind(encoder.encode(recipe),to:1,in:stmt); try finish(stmt)
    }
    public func workspaceRecipe() throws -> ViewRecipe {
        let stmt = try statement("SELECT payload FROM workspace_state WHERE key='recipe'")
        defer { sqlite3_finalize(stmt) }
        let step = sqlite3_step(stmt)
        if step == SQLITE_DONE { return ViewRecipe() }
        guard step == SQLITE_ROW else { throw failure() }
        return try decoder.decode(ViewRecipe.self,from:data(stmt,0))
    }
}
