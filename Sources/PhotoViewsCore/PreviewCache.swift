import Foundation

public final class PreviewCache {
    public let root: URL
    public let limitBytes: Int64
    public init(root: URL, limitBytes: Int64 = 2*1024*1024*1024) throws {
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
        self.limitBytes = max(0,limitBytes)
        try FileManager.default.createDirectory(at:self.root,withIntermediateDirectories:true)
    }
    func paths(_ id: UUID) -> (thumbnail: URL, analysis: URL) {
        let stem = "\(id.uuidString)-\(ImagePipeline.version)"
        return (root.appendingPathComponent(stem+"-thumb.jpg"),root.appendingPathComponent(stem+"-analysis.jpg"))
    }
    func size(_ url: URL) throws -> Int64 { Int64(try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0) }
    /// Only generated files immediately inside this cache may be removed.
    private func remove(_ path: String?) throws {
        guard let path else { return }
        let url = URL(fileURLWithPath:path).standardizedFileURL.resolvingSymlinksInPath()
        guard url.deletingLastPathComponent() == root, url.lastPathComponent.hasSuffix(".jpg"), UUID(uuidString:String(url.lastPathComponent.prefix(36))) != nil else {
            throw PipelineError.failed("Refusing to remove a file outside the preview cache.")
        }
        if FileManager.default.fileExists(atPath:path) { try FileManager.default.removeItem(at:url) }
    }
    @discardableResult public func prune(catalog: Catalog) throws -> Int64 {
        var records = try catalog.derivativeRows()
        // Account for actual disk usage, including derivatives orphaned by interrupted writes or invalidation.
        let files = try FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:[.fileSizeKey,.isRegularFileKey]).map { $0.standardizedFileURL.resolvingSymlinksInPath() }
        let referenced = Set(records.flatMap { [$0.thumbnailPath,$0.analysisPath].compactMap { $0 } })
        for file in files where !referenced.contains(file.path) && UUID(uuidString:String(file.lastPathComponent.prefix(36))) != nil && file.pathExtension == "jpg" { try remove(file.path) }
        func bytes(_ path: String?) -> Int64 { guard let path else { return 0 }; return (try? size(URL(fileURLWithPath:path))) ?? 0 }
        var total = records.reduce(Int64(0)) { $0 + bytes($1.thumbnailPath) + bytes($1.analysisPath) }
        // Keep offline browse thumbnails longer than large analysis previews.
        for i in records.indices where total > limitBytes {
            total -= bytes(records[i].analysisPath); try remove(records[i].analysisPath); records[i].analysisPath = nil
            records[i].byteSize = bytes(records[i].thumbnailPath); try catalog.saveDerivative(records[i])
        }
        for i in records.indices where total > limitBytes {
            total -= bytes(records[i].thumbnailPath); try remove(records[i].thumbnailPath); records[i].thumbnailPath = nil
            records[i].byteSize = 0; try catalog.saveDerivative(records[i])
        }
        return total
    }
}
