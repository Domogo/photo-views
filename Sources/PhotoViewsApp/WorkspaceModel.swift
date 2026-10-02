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
    private var catalog: Catalog?
    private var scopedURLs: [UUID: URL] = [:]
    let catalogURL: URL

    init() {
        let support = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
        // Isolate manual QA catalogs without touching the user's normal catalog.
        let override = ProcessInfo.processInfo.environment["PHOTO_VIEWS_DATA_DIR"]
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
        do { try catalog.storeWorkspaceRecipe(recipe) } catch { errorMessage = error.localizedDescription }
    }
    func selectAll() { selectedSavedView = nil; recipe.sourceIDs = []; persistRecipe() }
    func selectSource(_ source: CatalogSource) { selectedSavedView = nil; recipe.sourceIDs = [source.id]; persistRecipe() }
    func selectView(_ view: SavedView) { selectedSavedView = view.id; recipe = view.recipe; persistRecipe() }

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
            } catch { errorMessage = error.localizedDescription }
        }
        refreshAccess()
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
                else { availability[source.id] = "Ready to index" }
                if exists && (resolution.stale || resolution.url.path != source.lastKnownPath) {
                    let refreshed = try FolderAccess.source(for:resolution.url)
                    _ = try catalog.register(CatalogSource(id:source.id,name:source.name,bookmark:refreshed.bookmark,
                        volumeID:refreshed.volumeID,relativePath:refreshed.relativePath,lastKnownPath:resolution.url.path,createdAt:source.createdAt))
                }
            } catch { availability[source.id] = "Access needed" }
        }
        do { sources = try catalog.sources() } catch { errorMessage = error.localizedDescription }
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
}
