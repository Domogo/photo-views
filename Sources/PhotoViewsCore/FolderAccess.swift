import Foundation

public enum FolderAccess {
    public struct Resolution {
        public var url: URL
        public var stale: Bool
    }
    public static func source(for url: URL) throws -> CatalogSource {
        let normalized = url.standardizedFileURL.resolvingSymlinksInPath()
        let values = try normalized.resourceValues(forKeys: [.isDirectoryKey,.volumeUUIDStringKey,.volumeURLKey])
        guard values.isDirectory == true else { throw CocoaError(.fileReadUnsupportedScheme) }
        let bookmark = try normalized.bookmarkData(options: [.withSecurityScope,.securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
        let base = values.volume?.standardizedFileURL.path ?? "/"
        let relative = normalized.path.hasPrefix(base + "/") ? String(normalized.path.dropFirst(base.count + 1)) : normalized.path
        return CatalogSource(name: normalized.lastPathComponent, bookmark: bookmark, volumeID: values.volumeUUIDString,
                             relativePath: relative, lastKnownPath: normalized.path)
    }
    private static func identity(for url: URL) throws -> (volumeID: String?, relativePath: String) {
        let normalized = url.standardizedFileURL.resolvingSymlinksInPath()
        let values = try normalized.resourceValues(forKeys:[.volumeUUIDStringKey,.volumeURLKey])
        let base = values.volume?.standardizedFileURL.path ?? "/"
        return (values.volumeUUIDString,normalized.path.hasPrefix(base+"/") ? String(normalized.path.dropFirst(base.count+1)) : normalized.path)
    }
    public static func resolve(_ source: CatalogSource) throws -> Resolution {
        var stale = false
        if let url = try? URL(resolvingBookmarkData:source.bookmark,options:[.withSecurityScope,.withoutUI,.withoutMounting],relativeTo:nil,bookmarkDataIsStale:&stale) {
            if !FileManager.default.fileExists(atPath:url.path) { return Resolution(url:url,stale:stale) }
            let identity = try self.identity(for:url)
            guard identity.volumeID == source.volumeID && identity.relativePath == source.relativePath else { throw CocoaError(.fileReadNoPermission) }
            return Resolution(url:url,stale:stale)
        }
        // A remounted volume may have a different mount pathname. Never match merely by drive name.
        if let volumeID = source.volumeID, !source.relativePath.hasPrefix("/"), !source.relativePath.split(separator:"/").contains("..") {
            for volume in FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys:[.volumeUUIDStringKey],options:[]) ?? [] {
                guard try volume.resourceValues(forKeys:[.volumeUUIDStringKey]).volumeUUIDString == volumeID else { continue }
                let candidate = volume.appendingPathComponent(source.relativePath,isDirectory:true)
                let identity = try self.identity(for:candidate)
                guard identity.volumeID == source.volumeID && identity.relativePath == source.relativePath else { continue }
                return Resolution(url:candidate,stale:true)
            }
        }
        throw CocoaError(.fileReadNoPermission)
    }
}
