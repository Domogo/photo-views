import Foundation

public enum IndexEvent { case changed, checkpoint(UUID, IndexStage), finished(String?) }

/// One worker at a time keeps disk reads bounded and keeps ImageIO off the UI thread.
public final class IndexCoordinator: @unchecked Sendable {
    private let queue = DispatchQueue(label:"PhotoViews.indexing",qos:.utility)
    private let lock = NSLock()
    private var active = false
    private var pauseRequested = false
    public var isRunning: Bool { lock.lock(); defer { lock.unlock() }; return active }
    private var shouldPause: Bool { lock.lock(); defer { lock.unlock() }; return pauseRequested }
    public init() {}
    public func pause() { lock.lock(); pauseRequested = true; lock.unlock() }
    @discardableResult public func start(catalogURL: URL, cacheURL: URL, sources: [CatalogSource], cacheLimit: Int64 = 2*1024*1024*1024, onEvent: @escaping (IndexEvent) -> Void) -> Bool {
        lock.lock()
        guard !active else { lock.unlock(); return false }
        active = true; pauseRequested = false; lock.unlock()
        queue.async { [self] in
            var lastNotification = Date.distantPast
            func changed(force: Bool = false) {
                if force || Date().timeIntervalSince(lastNotification) >= 0.4 { lastNotification = Date(); onEvent(.changed) }
            }
            var terminalError: String?
            do {
                let store = try Catalog(url:catalogURL)
                let cache = try PreviewCache(root:cacheURL,limitBytes:cacheLimit)
                for source in sources {
                    if shouldPause { try store.scanState(source.id,"paused"); continue }
                    do { try index(source,store:store,cache:cache,changed:changed,checkpoint:{ onEvent(.checkpoint($0,$1)) }) }
                    catch {
                        try store.scanState(source.id,"failed",error:error.localizedDescription)
                        terminalError = error.localizedDescription
                    }
                    changed(force:true)
                }
                try cache.prune(catalog:store)
            } catch { terminalError = error.localizedDescription }
            lock.lock(); active = false; lock.unlock()
            onEvent(.finished(terminalError))
        }
        return true
    }
    private func index(_ source: CatalogSource, store: Catalog, cache: PreviewCache, changed: (Bool) -> Void, checkpoint: (UUID, IndexStage) -> Void) throws {
        let resolved: FolderAccess.Resolution
        do { resolved = try FolderAccess.resolve(source) }
        catch { try store.scanState(source.id,"disconnected",error:"Reconnect the drive or restore access. Cached photos remain available."); return }
        let root = resolved.url.standardizedFileURL.resolvingSymlinksInPath()
        let scoped = root.startAccessingSecurityScopedResource(); defer { if scoped { root.stopAccessingSecurityScopedResource() } }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath:root.path,isDirectory:&isDirectory), isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath:root.path) else {
            try store.scanState(source.id,"disconnected",error:"Reconnect the source drive to continue indexing."); return
        }
        guard cache.root != root, !cache.root.path.hasPrefix(root.path+"/") else { throw PipelineError.failed("The preview cache must be outside the source folder.") }
        try store.recoverJobs(sourceID:source.id)
        try store.scanState(source.id,"discovering"); changed(true)
        let token = UUID().uuidString
        var enumerationError: Error?
        let keys: [URLResourceKey] = [.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey,.contentModificationDateKey,.fileResourceIdentifierKey]
        guard let enumerator = FileManager.default.enumerator(at:root,includingPropertiesForKeys:keys,options:[.skipsHiddenFiles,.skipsPackageDescendants],errorHandler:{ _,error in enumerationError = error; return true }) else { throw PipelineError.failed("The source folder could not be scanned.") }
        for case let url as URL in enumerator {
            if shouldPause { try store.scanState(source.id,"paused"); changed(true); return }
            guard !url.lastPathComponent.hasPrefix("._"), ImagePipeline.extensions.contains(url.pathExtension.lowercased()) else { continue }
            do {
                let v = try url.resourceValues(forKeys:Set(keys))
                guard v.isRegularFile == true, v.isSymbolicLink != true else { continue }
                let normalized = url.standardizedFileURL.resolvingSymlinksInPath()
                guard normalized.path.hasPrefix(root.path+"/") else { continue }
                let path = String(normalized.path.dropFirst(root.path.count+1))
                let fileID: String?
                if let data = v.fileResourceIdentifier as? Data { fileID = data.base64EncodedString() }
                else if let number = v.fileResourceIdentifier as? NSNumber { fileID = number.stringValue }
                else { fileID = nil }
                try store.discover(source:source,root:root,relativePath:path,fileID:fileID,size:Int64(v.fileSize ?? 0),modified:v.contentModificationDate.map { Date(timeIntervalSince1970:($0.timeIntervalSince1970*1000).rounded()/1000) },token:token,hash:{ try ImagePipeline.hash(url) })
            } catch { enumerationError = error }
            changed(false)
        }
        if shouldPause { try store.scanState(source.id,"paused"); return }
        // A partially unreadable enumeration cannot prove that an unseen file was deleted.
        if enumerationError == nil { try store.finishDiscovery(sourceID:source.id,token:token) }
        try store.scanState(source.id,"indexing",error:enumerationError.map { "Some folders could not be scanned: \($0.localizedDescription)" }); changed(true)
        let pending = try store.pendingAssets(sourceID:source.id)
        for (index,asset) in pending.enumerated() {
            if shouldPause { try store.scanState(source.id,"paused"); changed(true); return }
            let url = root.appendingPathComponent(asset.relativePath)
            do {
                try autoreleasepool {
                    if try store.jobState(asset.id,.metadata) == .pending {
                        try store.job(asset.id,stage:.metadata,state:.running)
                        let metadata = try ImagePipeline.metadata(url)
                        // Hash only when no stable filesystem identity is available; this supports conservative move fallback.
                        if asset.fileID == nil { try store.rememberHash(asset.id,ImagePipeline.hash(url)) }
                        try store.execute("BEGIN IMMEDIATE")
                        do { try store.saveMetadata(metadata,id:asset.id); try store.job(asset.id,stage:.metadata,state:.complete); try store.execute("COMMIT") }
                        catch { try? store.execute("ROLLBACK"); throw error }
                        checkpoint(asset.id,.metadata)
                    }
                    if shouldPause { return }
                    guard try store.jobState(asset.id,.preview) == .pending else { return }
                    try store.job(asset.id,stage:.preview,state:.running)
                    let derivative = try ImagePipeline.previews(url,id:asset.id,cache:cache)
                    let after = try url.resourceValues(forKeys:[.fileSizeKey,.contentModificationDateKey])
                    guard Int64(after.fileSize ?? 0) == asset.byteSize, after.contentModificationDate.map({ Date(timeIntervalSince1970:($0.timeIntervalSince1970*1000).rounded()/1000) }) == asset.modifiedAt else {
                        throw PipelineError.failed("This file changed while indexing. Refresh the folder to read its latest version.")
                    }
                    try store.execute("BEGIN IMMEDIATE")
                    do { try store.saveDerivative(derivative); try store.job(asset.id,stage:.preview,state:.complete); try store.execute("COMMIT") }
                    catch { try? store.execute("ROLLBACK"); throw error }
                    checkpoint(asset.id,.preview)
                }
            } catch {
                if try store.jobState(asset.id,.metadata) == .running { try store.job(asset.id,stage:.metadata,state:.failed,error:error.localizedDescription) }
                try store.job(asset.id,stage:.preview,state:.failed,error:error.localizedDescription)
            }
            if index % 32 == 31 { try cache.prune(catalog:store) }
            changed(false)
        }
        try store.scanState(source.id,shouldPause ? "paused" : enumerationError == nil ? "complete" : "failed",error:enumerationError?.localizedDescription)
    }
}
