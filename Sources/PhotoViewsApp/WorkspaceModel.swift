import AppKit
import Foundation
import PhotoViewsCore

@MainActor final class WorkspaceModel: ObservableObject {
    @Published var sources: [CatalogSource] = []
    @Published var savedViews: [SavedView] = []
    @Published var recipe = ViewRecipe()
    @Published var selectedSavedView: UUID?
    @Published var showInspector = true
    @Published var errorMessage: String?
    @Published var availability: [UUID: String] = [:]
    @Published var isReady = false
    @Published var assets: [IndexedAsset] = []
    @Published var indexProgress: [SourceProgress] = []
    @Published var indexing = false
    @Published var selectedAssetID: UUID?
    @Published var previewPresented = false
    @Published var pausing = false
    @Published private var retainedSelection: IndexedAsset?
    @Published var assetLimit = 500
    private let indexer = IndexCoordinator()
    private var queuedSources: [CatalogSource] = []
    let cacheURL: URL
    private var catalog: Catalog?
    private var scopedURLs: [UUID: URL] = [:]
    let catalogURL: URL

    init() {
        let support = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
        // Isolate manual QA catalogs without touching the user's normal catalog.
        let override = ProcessInfo.processInfo.environment["PHOTO_VIEWS_DATA_DIR"]
        cacheURL = override.map { URL(fileURLWithPath:$0,isDirectory:true).appendingPathComponent("previews",isDirectory:true) }
            ?? FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("PhotoViews/previews",isDirectory:true)
        catalogURL = (override.map { URL(fileURLWithPath:$0,isDirectory:true) } ?? support.appendingPathComponent("Photo Views",isDirectory:true))
            .appendingPathComponent("catalog.sqlite")
        do {
            let store = try Catalog(url:catalogURL)
            catalog = store
            sources = try store.sources()
            savedViews = try store.savedViews()
            recipe = try store.workspaceRecipe()
            isReady = true
            refreshAccess()
            refreshAssets()
            let interrupted = sources.filter { source in indexProgress.contains { $0.sourceID == source.id && ["discovering","indexing"].contains($0.state) } }
            if !interrupted.isEmpty { startIndexing(interrupted) }
        } catch { errorMessage = error.localizedDescription }
    }
    var selectedSource: CatalogSource? {
        sources.first { recipe.sourceIDs.contains($0.id) }
    }
    var currentTitle: String {
        if let saved = savedViews.first(where:{$0.id == selectedSavedView}) { return saved.name }
        if let selectedSource, recipe.sourceIDs.count == 1 { return selectedSource.name }
        return "All photos"
    }
    var hasUnsavedChanges: Bool {
        savedViews.first(where:{$0.id == selectedSavedView}).map { $0.recipe != recipe } ?? false
    }
    func persistRecipe() {
        guard let catalog else { return }
        do { try catalog.storeWorkspaceRecipe(recipe); refreshAssets() } catch { errorMessage = error.localizedDescription }
    }
    func selectAll() { selectedSavedView = nil; assetLimit = 500; recipe.sourceIDs = []; persistRecipe() }
    func selectSource(_ source: CatalogSource) { selectedSavedView = nil; assetLimit = 500; recipe.sourceIDs = [source.id]; persistRecipe() }
    func selectView(_ view: SavedView) { selectedSavedView = view.id; assetLimit = 500; recipe = view.recipe; persistRecipe() }

    func chooseFolder(reauthorizing source: CatalogSource? = nil) {
        let panel = NSOpenPanel()
        panel.title = source == nil ? "Add a photo folder" : "Restore folder access"
        panel.message = "Photos stay in their existing folders. Photo Views stores its catalog on this Mac."
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = source == nil
        panel.prompt = source == nil ? "Add Folder" : "Restore Access"
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK else { return }
            self?.registerFolders(panel.urls, reauthorizing:source)
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for:window,completionHandler:completion) }
        else { panel.begin(completionHandler:completion) }
    }
    private func registerFolders(_ urls: [URL], reauthorizing source: CatalogSource?) {
        var added: [CatalogSource] = []
        for url in urls {
            do {
                let active = url.startAccessingSecurityScopedResource()
                defer { if active { url.stopAccessingSecurityScopedResource() } }
                var registration = try FolderAccess.source(for:url)
                if let source {
                    // Never associate a source's existing assets with an unrelated replacement folder.
                    guard registration.volumeID == source.volumeID && registration.relativePath == source.relativePath else {
                        throw NSError(domain:"PhotoViews",code:1,userInfo:[NSLocalizedDescriptionKey:"Choose the original source folder to restore access. Add a different folder as a new source."])
                    }
                    registration = CatalogSource(id:source.id,name:source.name,bookmark:registration.bookmark,
                        volumeID:registration.volumeID,relativePath:registration.relativePath,lastKnownPath:registration.lastKnownPath,createdAt:source.createdAt)
                }
                guard let catalog else { return }
                let stored = try catalog.register(registration)
                sources = try catalog.sources()
                selectSource(stored)
                added.append(stored)
            } catch { errorMessage = error.localizedDescription }
        }
        refreshAccess()
        startIndexing(added)
    }
    func refreshAccess() {
        guard let catalog else { return }
        for source in sources {
            if let active = scopedURLs.removeValue(forKey:source.id) { active.stopAccessingSecurityScopedResource() }
            do {
                let resolution = try FolderAccess.resolve(source)
                let scoped = resolution.url.startAccessingSecurityScopedResource()
                if scoped { scopedURLs[source.id] = resolution.url }
                var directory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath:resolution.url.path,isDirectory:&directory)
                if !exists || !directory.boolValue { availability[source.id] = "Disconnected or missing" }
                else if !FileManager.default.isReadableFile(atPath:resolution.url.path) { availability[source.id] = "Access needed" }
                else { availability[source.id] = "Connected" }
                if exists && (resolution.stale || resolution.url.path != source.lastKnownPath) {
                    let refreshed = try FolderAccess.source(for:resolution.url)
                    _ = try catalog.register(CatalogSource(id:source.id,name:source.name,bookmark:refreshed.bookmark,
                        volumeID:refreshed.volumeID,relativePath:refreshed.relativePath,lastKnownPath:resolution.url.path,createdAt:source.createdAt))
                }
            } catch { availability[source.id] = "Access needed" }
        }
        do { sources = try catalog.sources() } catch { errorMessage = error.localizedDescription }
        refreshAssets()
    }
    @discardableResult func saveView(name: String, update: Bool = false) -> Bool {
        guard let catalog else { return false }
        do {
            let existing = update ? savedViews.first(where:{$0.id == selectedSavedView}) : nil
            let view = SavedView(id:existing?.id ?? UUID(),name:name,recipe:recipe,createdAt:existing?.createdAt ?? Date())
            try catalog.save(view); savedViews = try catalog.savedViews(); selectedSavedView = view.id
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func revealSource() {
        guard let source = selectedSource else { return }
        let url: URL
        do { url = try FolderAccess.resolve(source).url }
        catch {
            errorMessage = "Folder access could not be restored. Use Restore Access from the source menu, or reconnect the source drive."
            return
        }
        guard FileManager.default.fileExists(atPath:url.path) else {
            errorMessage = "Reconnect the source drive to open this folder in Finder."; return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    var selectedAsset: IndexedAsset? { assets.first { $0.id == selectedAssetID } ?? retainedSelection }
    var scopedSources: [CatalogSource] { sources.filter { recipe.sourceIDs.isEmpty || recipe.sourceIDs.contains($0.id) } }
    var scopedProgress: [SourceProgress] { indexProgress.filter { recipe.sourceIDs.isEmpty || recipe.sourceIDs.contains($0.sourceID) } }
    var totalAssets: Int { scopedProgress.reduce(0) { $0+$1.total } }
    var browseableAssets: Int { completedPreviews+failedPreviews }
    var completedPreviews: Int { scopedProgress.reduce(0) { $0+$1.completed } }
    var failedPreviews: Int { scopedProgress.reduce(0) { $0+$1.failed } }
    var metadataReady: Int { scopedProgress.reduce(0) { $0+$1.metadataReady } }
    var paused: Bool { scopedProgress.contains { $0.state == "paused" } }
    var discovering: Bool { scopedProgress.contains { $0.state == "discovering" } }
    func sourceStatus(_ source: CatalogSource) -> String {
        guard availability[source.id] == "Connected" else { return availability[source.id] ?? "Checking access…" }
        guard let p = indexProgress.first(where: { $0.sourceID == source.id }) else { return "Ready to index" }
        switch p.state {
        case "discovering": return "Discovering photos…"
        case "indexing": return "\(p.completed) of \(p.total) previews"
        case "paused": return "Paused · \(p.completed) of \(p.total)"
        case "failed": return "Scan needs attention"
        default: return p.total == 0 ? "Ready to index" : "\(p.total) photos"
        }
    }
    func refreshAssets() {
        guard let catalog else { return }
        do {
            indexProgress = try catalog.progress()
            assets = try catalog.indexedAssets(sourceIDs:recipe.sourceIDs,sort:recipe.sorting,limit:assetLimit,readyOnly:true,selectedID:selectedAssetID).map { value in
                var asset = value
                if let path = asset.thumbnailPath, !FileManager.default.fileExists(atPath:path) { asset.thumbnailPath = nil }
                if let path = asset.analysisPath, !FileManager.default.fileExists(atPath:path) { asset.analysisPath = nil }
                return asset
            }
            if let id = selectedAssetID {
                let selected = try catalog.indexedAssets(limit:1,assetID:id).first
                if var selected, recipe.sourceIDs.isEmpty || recipe.sourceIDs.contains(selected.asset.sourceID) {
                    if let path = selected.thumbnailPath, !FileManager.default.fileExists(atPath:path) { selected.thumbnailPath = nil }
                    if let path = selected.analysisPath, !FileManager.default.fileExists(atPath:path) { selected.analysisPath = nil }
                    retainedSelection = selected
                }
                else { selectedAssetID = nil; retainedSelection = nil; previewPresented = false }
            }
        } catch { errorMessage = error.localizedDescription }
    }
    func loadMore() { guard assetLimit < browseableAssets else { return }; assetLimit += 500; refreshAssets() }
    func startIndexing(_ requested: [CatalogSource]? = nil) {
        let targets = requested ?? scopedSources
        guard !targets.isEmpty, isReady else { return }
        if indexing {
            if requested != nil { for target in targets where !queuedSources.contains(where: { $0.id == target.id }) { queuedSources.append(target) } }
            return
        }
        let started = indexer.start(catalogURL:catalogURL,cacheURL:cacheURL,sources:targets,onEvent:{ [weak self] event in
            if case .checkpoint = event { return }
            DispatchQueue.main.async {
                guard let self else { return }
                if case .finished(let error) = event {
                    self.indexing = false; self.pausing = false
                    if let error { self.errorMessage = error }
                    self.refreshAccess()
                    if !self.queuedSources.isEmpty {
                        let queued = self.queuedSources; self.queuedSources = []; self.startIndexing(queued)
                    }
                }
                self.refreshAssets()
            }
        })
        if started { indexing = true; pausing = false }
    }
    func pauseIndexing() { pausing = true; indexer.pause() }
    func selectAsset(_ id: UUID) {
        selectedAssetID = id
        retainedSelection = assets.first { $0.id == id } ?? (try? catalog?.indexedAssets(limit:1,assetID:id).first)
        try? catalog?.touchPreviews([id])
    }
    func originalAvailable(_ asset: IndexedAsset) -> Bool { asset.available && availability[asset.asset.sourceID] == "Connected" }
    func revealPhoto() {
        guard let asset = selectedAsset, let source = sources.first(where: { $0.id == asset.asset.sourceID }) else { return }
        guard originalAvailable(asset) else { errorMessage = "Reconnect the source drive or restore access to reveal this original. Cached previews remain available."; return }
        do {
            let root = try FolderAccess.resolve(source).url
            let url = root.appendingPathComponent(asset.asset.relativePath)
            guard FileManager.default.fileExists(atPath:url.path) else { errorMessage = "This original is missing. Refresh the folder after reconnecting or restoring it."; return }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch { errorMessage = "Restore source access to reveal this original." }
    }
    func retrySelectedPreview() {
        guard let asset = selectedAsset, let source = sources.first(where: { $0.id == asset.asset.sourceID }), !indexing else { return }
        do { try catalog?.queuePreview(asset.id); startIndexing([source]) }
        catch { errorMessage = error.localizedDescription }
    }

}
