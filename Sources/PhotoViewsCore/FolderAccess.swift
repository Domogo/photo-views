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
    public static func resolve(_ source: CatalogSource) throws -> Resolution {
        var stale = false
        let url = try URL(resolvingBookmarkData: source.bookmark, options: [.withSecurityScope,.withoutUI,.withoutMounting],
                          relativeTo: nil, bookmarkDataIsStale: &stale)
        return Resolution(url:url,stale:stale)
    }
}
