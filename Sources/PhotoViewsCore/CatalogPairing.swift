import Foundation
import CSQLite

extension Catalog {
    public func pairMembers(_ id: UUID) throws -> [IndexedAsset] {
        let stmt = try statement("SELECT asset_id FROM photo_assets WHERE photo_id=(SELECT photo_id FROM photo_assets WHERE asset_id=?) ORDER BY asset_id")
        defer { sqlite3_finalize(stmt) }; try bind(id.uuidString,to:1,in:stmt)
        var members: [IndexedAsset] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let member = UUID(uuidString:text(stmt,0)), let asset = try indexedAssets(assetID:member).first { members.append(asset) }
        }
        return members
    }
    public func separatePair(containing id: UUID) throws {
        let members = try pairMembers(id).map(\.id).sorted { $0.uuidString < $1.uuidString }
        guard members.count == 2 else { return }
        try execute("BEGIN IMMEDIATE")
        do {
            try run("INSERT OR IGNORE INTO pair_exclusions VALUES(?,?)",members.map(\.uuidString))
            // Delete by membership instead of assuming a particular primary member.
            try run("DELETE FROM photo_assets WHERE asset_id IN (?,?)",members.map(\.uuidString))
            try execute("DELETE FROM photos WHERE NOT EXISTS(SELECT 1 FROM photo_assets WHERE photo_id=photos.id)")
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
    public func restorePairing(sourceID: UUID) throws {
        try run("DELETE FROM pair_exclusions WHERE first_asset_id IN (SELECT id FROM assets WHERE source_id=?)",[sourceID.uuidString])
        try reconcilePairs(sourceID:sourceID)
    }
    /// Only one RAW and one JPEG with the same folder/stem and complete matching capture identity qualify.
    /// Associations are catalog-only. Missing originals keep their cached identity; changed metadata can dissolve a pair.
    public func reconcilePairs(sourceID: UUID) throws {
        let assets = try indexedAssets(sourceIDs:[sourceID],limit:Int.max)
        let grouped = Dictionary(grouping:assets) { URL(fileURLWithPath:$0.asset.relativePath).deletingPathExtension().path }
        var pairs: [(UUID,UUID)] = []
        let fmt = DateFormatter(); fmt.locale = Locale(identifier:"en_US_POSIX"); fmt.timeZone = TimeZone(secondsFromGMT:0); fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"; fmt.isLenient = false
        for members in grouped.values where members.count == 2 {
            let raw = members.filter { ImagePipeline.rawExtensions.contains(URL(fileURLWithPath:$0.filename).pathExtension.lowercased()) }
            let jpeg = members.filter { ["jpg","jpeg"].contains(URL(fileURLWithPath:$0.filename).pathExtension.lowercased()) }
            guard raw.count == 1, jpeg.count == 1, let a = raw[0].metadata, let b = jpeg[0].metadata,
                  let camera = a.camera?.trimmingCharacters(in:.whitespacesAndNewlines), !camera.isEmpty, camera == b.camera?.trimmingCharacters(in:.whitespacesAndNewlines),
                  let capture = a.captureDateText, capture == b.captureDateText, let date = fmt.date(from:capture), fmt.string(from:date) == capture,
                  (a.captureTimezone == nil || b.captureTimezone == nil || a.captureTimezone == b.captureTimezone) else { continue }
            let ids = [raw[0].id.uuidString,jpeg[0].id.uuidString].sorted()
            let stmt = try statement("SELECT 1 FROM pair_exclusions WHERE first_asset_id=? AND second_asset_id=?"); defer { sqlite3_finalize(stmt) }
            try bind(ids[0],to:1,in:stmt); try bind(ids[1],to:2,in:stmt)
            if sqlite3_step(stmt) != SQLITE_ROW { pairs.append((raw[0].id,jpeg[0].id)) }
        }
        try execute("BEGIN IMMEDIATE")
        do {
            try run("DELETE FROM photo_assets WHERE asset_id IN (SELECT id FROM assets WHERE source_id=?)",[sourceID.uuidString])
            try execute("DELETE FROM photos WHERE NOT EXISTS(SELECT 1 FROM photo_assets WHERE photo_id=photos.id)")
            for (raw,jpeg) in pairs {
                try run("INSERT INTO photos VALUES(?,?)",[raw.uuidString,raw.uuidString])
                for id in [raw,jpeg] { try run("INSERT INTO photo_assets VALUES(?,?)",[raw.uuidString,id.uuidString]) }
            }
            try execute("COMMIT")
        } catch { try? execute("ROLLBACK"); throw error }
    }
}
