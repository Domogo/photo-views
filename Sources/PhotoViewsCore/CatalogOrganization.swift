import Foundation
import CSQLite

extension Catalog {
    public func tags(for id: UUID) throws -> [TagAssignmentRecord] {
        let stmt = try statement("SELECT id,tag,provenance,decision,model_version,score,threshold,vocabulary_version FROM tag_assignments WHERE asset_id=? ORDER BY tag COLLATE NOCASE,id")
        defer { sqlite3_finalize(stmt) }; try bind(id.uuidString,to:1,in:stmt)
        var result: [TagAssignmentRecord] = []
        while true {
            let step = sqlite3_step(stmt); if step == SQLITE_DONE { return result }
            guard step == SQLITE_ROW, let tagID = UUID(uuidString:text(stmt,0)), let provenance = TagProvenance(rawValue:text(stmt,2)), let decision = TagDecision(rawValue:text(stmt,3)) else { throw failure() }
            func optional(_ i: Int32) -> String? { sqlite3_column_type(stmt,i) == SQLITE_NULL ? nil : text(stmt,i) }
            result.append(TagAssignmentRecord(id:tagID,assetID:id,tag:text(stmt,1),provenance:provenance,decision:decision,modelVersion:optional(4),score:sqlite3_column_type(stmt,5) == SQLITE_NULL ? nil : sqlite3_column_double(stmt,5),threshold:sqlite3_column_type(stmt,6) == SQLITE_NULL ? nil : sqlite3_column_double(stmt,6),vocabularyVersion:optional(7)))
        }
    }
    public func setTagDecision(_ tag: UUID, decision: TagDecision) throws {
        try run("UPDATE tag_assignments SET decision=? WHERE id=?",[decision.rawValue,tag.uuidString])
    }
    /// A rejected tag is a durable tombstone, including when a confirmed tag is removed.
    public func addManualTag(_ name: String, to asset: UUID, replacing prior: UUID? = nil) throws {
        let name = name.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        guard !name.isEmpty, name.count <= 80 else { throw CatalogError.invalidName }
        try execute("BEGIN IMMEDIATE")
        do {
            if let prior { try run("UPDATE tag_assignments SET decision='rejected' WHERE id=? AND asset_id=?",[prior.uuidString,asset.uuidString]) }
            let existing = try tags(for:asset).first { $0.tag.caseInsensitiveCompare(name) == .orderedSame }
            if let existing {
                try run("UPDATE tag_assignments SET provenance='manual',decision='accepted',model_version=NULL,score=NULL,threshold=NULL,vocabulary_version=NULL WHERE id=?",[existing.id.uuidString])
            } else {
                try run("INSERT INTO tag_assignments(id,asset_id,tag,provenance,decision) VALUES(?,?,?,'manual','accepted')",[UUID().uuidString,asset.uuidString,name])
            }
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
    public func isFavorite(_ id: UUID) throws -> Bool {
        let stmt = try statement("SELECT favorite FROM assets WHERE id=?"); defer { sqlite3_finalize(stmt) }; try bind(id.uuidString,to:1,in:stmt)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return false }; return sqlite3_column_int(stmt,0) == 1
    }
    public func setFavorite(_ id: UUID, _ favorite: Bool) throws { try run("UPDATE assets SET favorite=? WHERE id=?",[favorite ? "1" : "0",id.uuidString]) }
    public func collections() throws -> [CollectionRecord] {
        let stmt = try statement("SELECT id,name FROM collections ORDER BY name COLLATE NOCASE,id"); defer { sqlite3_finalize(stmt) }
        var result: [CollectionRecord] = []
        while true {
            let step = sqlite3_step(stmt); if step == SQLITE_DONE { return result }
            guard step == SQLITE_ROW, let id = UUID(uuidString:text(stmt,0)) else { throw failure() }
            result.append(CollectionRecord(id:id,name:text(stmt,1)))
        }
    }
    @discardableResult public func createCollection(name: String) throws -> CollectionRecord {
        let name = name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80 else { throw CatalogError.invalidName }
        let record = CollectionRecord(name:name)
        try run("INSERT INTO collections VALUES(?,?)",[record.id.uuidString,record.name]); return record
    }
    public func collectionIDs(for asset: UUID) throws -> Set<UUID> {
        let stmt = try statement("SELECT collection_id FROM collection_assets WHERE asset_id=?"); defer { sqlite3_finalize(stmt) }; try bind(asset.uuidString,to:1,in:stmt)
        var result = Set<UUID>()
        while true {
            let step = sqlite3_step(stmt); if step == SQLITE_DONE { return result }
            guard step == SQLITE_ROW, let id = UUID(uuidString:text(stmt,0)) else { throw failure() }; result.insert(id)
        }
    }
    public func setMembership(_ asset: UUID, collection: UUID, member: Bool) throws {
        try run(member ? "INSERT OR IGNORE INTO collection_assets VALUES(?,?)" : "DELETE FROM collection_assets WHERE collection_id=? AND asset_id=?",[collection.uuidString,asset.uuidString])
    }
}
