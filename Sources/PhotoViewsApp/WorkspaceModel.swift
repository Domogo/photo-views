import AppKit
import Foundation
import PhotoViewsCore

@MainActor final class WorkspaceModel: ObservableObject {
    @Published var sources: [CatalogSource] = []
    @Published var collections: [CollectionRecord] = []
    @Published var tagCoverage = TagCoverage(total:0,prepared:0)
    @Published var tagVocabularyVersion: String?
    @Published var selectedTags: [TagAssignmentRecord] = []
    @Published var selectedCollections = Set<UUID>()
    @Published var selectedFavorite = false
    @Published var savedViews: [SavedView] = []
    @Published var recipe = ViewRecipe()
    @Published var selectedSavedView: UUID?
    @Published var showInspector = false
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
    var searchMode: String { get { recipe.searchMode ?? "visual" } set { recipe.searchMode = newValue } }
    @Published var searching = false
    @Published var searchError: String?
    @Published var resultCount = 0
    @Published var cameras: [String] = []
    @Published var lenses: [String] = []
    @Published var formats: [String] = []
    @Published var queryPlan: QueryPlan?
    @Published var visualCoverage = SearchCoverage(total:0,embedded:0,failed:0)
    @Published var paletteCoverage = PaletteCoverage(total:0,prepared:0,failed:0)
    @Published var paletteIndexing = false
    @Published var paletteError: String?
    @Published var visualIndexing = false
    @Published var visualPaused = false
    static let modelVersion = "openclip-vit-b32-1a25a446712ba5ee05982a381eed697ef9b435cf:imageio-m2-v1:search-v1"
    static let rankingVersion = "rrf-k60-v1"
    private var persistedRecipe: ViewRecipe?
    private var searchGeneration = 0
    private var lastVisualRefresh = Date.distantPast
    private var searchTask: Task<Void,Never>?
    private lazy var searchBridge = SearchBridge(catalogURL:catalogURL)
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
            collections = try store.collections()
            recipe = try store.workspaceRecipe()
            persistedRecipe = recipe
            if let id = try store.selectedView(), savedViews.contains(where:{ $0.id == id }) { selectedSavedView = id }
            visualPaused = UserDefaults.standard.bool(forKey:"visualIndexingPaused")
            isReady = true
            indexProgress = try store.progress()
            refreshAccess()
            accessTimer = Timer.scheduledTimer(withTimeInterval:5,repeats:true) { [weak self] _ in Task { @MainActor in self?.refreshAccess() } }
            for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
                mountObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.refreshAccess() } })
            }
            refreshAssets()
            startPaletteIndexing()
            visualPaused = UserDefaults.standard.bool(forKey:"visualIndexingPaused")
            if !visualPaused { startVisualIndexing() }
            let interrupted = sources.filter { source in indexProgress.contains { $0.sourceID == source.id && ["discovering","indexing"].contains($0.state) } }
            if !interrupted.isEmpty { startIndexing(interrupted) }
        } catch { errorMessage = error.localizedDescription }
    }
    var selectedSource: CatalogSource? {
        sources.first { recipe.sourceIDs.contains($0.id) }
    }
    var currentTitle: String {
        if let saved = savedViews.first(where:{$0.id == selectedSavedView}) { return saved.name }
        if let collection = collections.first(where:{ $0.id == recipe.collectionID }) { return collection.name }
        if recipe.favoritesOnly == true { return "Favorites" }
        if let selectedSource, recipe.sourceIDs.count == 1 { return selectedSource.name }
        return "All photos"
    }
    var hasUnsavedChanges: Bool {
        savedViews.first(where:{$0.id == selectedSavedView}).map { $0.recipe != recipe } ?? false
    }
    var needsCurrentSearchModel: Bool {
        usesVisualVectors && ((recipe.modelVersion != nil && recipe.modelVersion != Self.modelVersion) ||
            (recipe.rankingVersion != nil && recipe.rankingVersion != Self.rankingVersion))
    }
    func useCurrentSearchModel() {
        recipe.modelVersion = Self.modelVersion; recipe.rankingVersion = Self.rankingVersion
    }
    func persistRecipe() {
        guard let catalog else { return }
        do {
            let previous = persistedRecipe
            try catalog.storeWorkspaceRecipe(recipe)
            try catalog.storeSelectedView(selectedSavedView)
            persistedRecipe = recipe
            // Regrouping is pure presentation. Preserve loaded membership and don't call the worker.
            if var previous {
                previous.grouping = recipe.grouping
                if previous == recipe { return }
            }
            var previousMembership = previous
            previousMembership?.grouping = recipe.grouping; previousMembership?.sorting = recipe.sorting
            if previousMembership != recipe { assetLimit = 500 }
            refreshAssets()
        } catch { errorMessage = error.localizedDescription }
    }
    func selectAll() { selectedSavedView = nil; recipe.collectionID = nil; recipe.favoritesOnly = nil; recipe.sourceIDs = []; persistRecipe() }
    func selectSource(_ source: CatalogSource) { selectedSavedView = nil; recipe.collectionID = nil; recipe.favoritesOnly = nil; recipe.sourceIDs = [source.id]; persistRecipe() }
    func selectView(_ view: SavedView) { selectedSavedView = view.id; assetLimit = 500; recipe = view.recipe; persistRecipe(); refreshAssets() }

    func selectFavorites() { selectedSavedView = nil; recipe = ViewRecipe(); recipe.favoritesOnly = true; persistRecipe() }
    func selectCollection(_ collection: CollectionRecord) { selectedSavedView = nil; recipe = ViewRecipe(); recipe.collectionID = collection.id; persistRecipe() }
    @discardableResult func createCollection(name: String) -> Bool {
        guard let catalog else { return false }
        do { let collection = try catalog.createCollection(name:name); collections = try catalog.collections(); selectCollection(collection); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }
    func refreshSelectedOrganization() {
        guard let catalog, let id = selectedAssetID else { selectedTags = []; selectedCollections = []; selectedFavorite = false; return }
        do {
            selectedTags = try catalog.tags(for:id); selectedCollections = try catalog.collectionIDs(for:id)
            selectedFavorite = try catalog.isFavorite(id)
        } catch { errorMessage = error.localizedDescription }
    }
    func setTagDecision(_ tag: TagAssignmentRecord, _ decision: TagDecision) {
        do { try catalog?.setTagDecision(tag.id,decision:decision); refreshSelectedOrganization(); refreshAssets() }
        catch { errorMessage = error.localizedDescription }
    }
    @discardableResult func addTag(_ name: String, replacing prior: UUID? = nil) -> Bool {
        guard let catalog, let id = selectedAssetID else { return false }
        do { try catalog.addManualTag(name,to:id,replacing:prior); refreshSelectedOrganization(); refreshAssets(); return true }
        catch { errorMessage = error.localizedDescription; return false }
    }
    func toggleFavorite() {
        guard let id = selectedAssetID else { return }
        do { try catalog?.setFavorite(id,!selectedFavorite); selectedFavorite.toggle(); refreshAssets() }
        catch { errorMessage = error.localizedDescription }
    }
    func toggleCollection(_ collection: CollectionRecord) {
        guard let id = selectedAssetID else { return }
        do { try catalog?.setMembership(id,collection:collection.id,member:!selectedCollections.contains(collection.id)); refreshSelectedOrganization(); refreshAssets() }
        catch { errorMessage = error.localizedDescription }
    }
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
    private var accessTimer: Timer?
    private var mountObservers: [NSObjectProtocol] = []
    private var resolvedRoots: [UUID:URL] = [:]
    func refreshAccess(rescanOnReconnect: Bool = true) {
        guard let catalog else { return }
        var reconnected: [CatalogSource] = []
        let priorAvailability = availability
        for source in sources {
            resolvedRoots[source.id] = nil
            if let active = scopedURLs.removeValue(forKey:source.id) { active.stopAccessingSecurityScopedResource() }
            do {
                let resolution = try FolderAccess.resolve(source)
                resolvedRoots[source.id] = resolution.url
                let scoped = resolution.url.startAccessingSecurityScopedResource()
                if scoped { scopedURLs[source.id] = resolution.url }
                var directory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath:resolution.url.path,isDirectory:&directory)
                if !exists || !directory.boolValue { availability[source.id] = "Disconnected or missing" }
                else if !FileManager.default.isReadableFile(atPath:resolution.url.path) { availability[source.id] = "Access needed" }
                else {
                    availability[source.id] = "Connected"
                    let wasDisconnected = priorAvailability[source.id] != nil && priorAvailability[source.id] != "Connected"
                    let interrupted = indexProgress.contains { $0.sourceID == source.id && ["disconnected","discovering","indexing","complete"].contains($0.state) }
                    let movedMount = resolution.url.path != source.lastKnownPath
                    if rescanOnReconnect && (wasDisconnected || movedMount || (priorAvailability[source.id] == nil && interrupted)) { reconnected.append(source) }
                }
                if exists && (resolution.stale || resolution.url.path != source.lastKnownPath) {
                    let refreshed = try? FolderAccess.source(for:resolution.url)
                    _ = try catalog.register(CatalogSource(id:source.id,name:source.name,bookmark:refreshed?.bookmark ?? source.bookmark,
                        volumeID:source.volumeID,relativePath:source.relativePath,lastKnownPath:resolution.url.path,createdAt:source.createdAt))
                }
            } catch { availability[source.id] = FolderAccess.isVolumeMounted(source) == false ? "Disconnected" : "Access needed" }
            if availability[source.id] != "Connected", priorAvailability[source.id] != availability[source.id] {
                do { try catalog.markSourceUnavailable(source.id) } catch { errorMessage = error.localizedDescription }
            }
        }
        do { sources = try catalog.sources() } catch { errorMessage = error.localizedDescription }
        if priorAvailability != availability { refreshAssets() }
        if !reconnected.isEmpty { startIndexing(reconnected) }
    }
    @discardableResult func saveView(name: String, update: Bool = false) -> Bool {
        guard let catalog else { return false }
        do {
            let existing = update ? savedViews.first(where:{$0.id == selectedSavedView}) : nil
            if hasSearch && !needsCurrentSearchModel {
                recipe.modelVersion = Self.modelVersion; recipe.rankingVersion = Self.rankingVersion
            }
            let view = SavedView(id:existing?.id ?? UUID(),name:name,recipe:recipe,createdAt:existing?.createdAt ?? Date())
            try catalog.save(view); savedViews = try catalog.savedViews(); selectedSavedView = view.id
            try catalog.storeSelectedView(view.id); try catalog.storeWorkspaceRecipe(recipe); persistedRecipe = recipe
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
        default: return p.total == 0 ? "Ready to index" : "\(p.total) files"
        }
    }
    var hasSearch: Bool { !recipe.search.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || recipe.referenceAssetID != nil }
    var hasFilters: Bool { recipe.filters != ExactFilters() }
    var usesVisualVectors: Bool { recipe.referenceAssetID != nil || (hasSearch && searchMode == "visual") }
    var resultOrderingTitle: String { recipe.palette != nil ? (usesVisualVectors ? "Visual + palette" : "Palette coverage") : isRankedSearch ? "Similarity" : recipe.sorting.title }
    var isRankedSearch: Bool { recipe.palette != nil || recipe.referenceAssetID != nil || (hasSearch && searchMode == "visual") }
    var referencePhoto: IndexedAsset? {
        guard let id = recipe.referenceAssetID else { return nil }
        return try? catalog?.indexedAssets(limit:1,assetID:id).first
    }
    var filterSummary: String { filterDescription(recipe.filters) }
    func filterDescription(_ filters: ExactFilters) -> String {
        var parts: [String] = []
        if let camera = filters.camera { parts.append(camera) }
        if let folder = filters.folder, !folder.isEmpty { parts.append("Folder: "+folder) }
        let dates = DateFormatter(); dates.dateStyle = .medium
        if let date = filters.fromDate { parts.append("From "+dates.string(from:date)) }
        if let date = filters.toDate { parts.append("Through "+dates.string(from:date)) }
        if let lens = filters.lens { parts.append(lens) }
        if let iso = filters.minISO { parts.append("ISO ≥ "+iso.formatted()) }
        if let iso = filters.maxISO { parts.append("ISO ≤ "+iso.formatted()) }
        for (name,low,high) in [("f-number",filters.minAperture,filters.maxAperture),("Shutter seconds",filters.minShutterSeconds,filters.maxShutterSeconds),("Width",filters.minWidth,filters.maxWidth),("Height",filters.minHeight,filters.maxHeight)] {
            if let low { parts.append(name+" ≥ "+low.formatted()) }; if let high { parts.append(name+" ≤ "+high.formatted()) }
        }
        parts += filters.confirmedTags
        if let format = filters.format { parts.append(format) }
        return parts.joined(separator:" · ")
    }
    @discardableResult func resolveSearchInput(apply: Bool = true) -> Bool {
        guard searchMode == "visual", recipe.referenceAssetID == nil else { return false }
        let extracted = PaletteSearch.extract(from:recipe.search)
        var plan = QueryInterpreter.interpret(extracted.intent,filters:recipe.filters,cameras:cameras,lenses:lenses,formats:formats)
        plan.input = recipe.search; plan.palette = extracted.palette ?? recipe.palette
        if extracted.ambiguous { plan.ambiguities.append("Choose one overall palette color in Filters.") }
        guard extracted.palette != nil || extracted.ambiguous || !plan.canApply || plan.grouping != nil || plan.filters != recipe.filters || plan.visualIntent != recipe.search.trimmingCharacters(in:.whitespacesAndNewlines) else { return false }
        queryPlan = plan; searchError = nil
        if plan.canApply && apply { applyQueryPlan(); persistRecipe() }
        else { searching = false; assets = []; resultCount = 0 }
        return true
    }
    func submitSearch() { if !resolveSearchInput() { refreshAssets() } }
    func interpretQuery() { _ = resolveSearchInput() }
    func applyQueryPlan() {
        guard var plan = queryPlan else { return }
        QueryInterpreter.validate(&plan)
        guard plan.canApply else { queryPlan = plan; return }
        recipe.search = plan.visualIntent; recipe.filters = plan.filters; recipe.palette = plan.palette
        if let group = plan.grouping { recipe.grouping = group }
        searchMode = "visual"; queryPlan = nil
    }
    func clearFilters() { recipe.filters = ExactFilters() }
    func exitSimilar() { recipe.referenceAssetID = nil; recipe.search = "" }
    func findSimilar() {
        guard let id = selectedAssetID else { return }
        recipe.referenceAssetID = id; recipe.search = ""; searchMode = "visual"
    }
    private func requestRecipe() -> [String:Any] {
        guard let data = try? JSONEncoder().encode(recipe), var value = try? JSONSerialization.jsonObject(with:data) as? [String:Any] else { return [:] }
        var filters = value["filters"] as? [String:Any] ?? [:]
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier:.gregorian); formatter.locale = Locale(identifier:"en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        if let date = recipe.filters.fromDate { filters["fromDay"] = formatter.string(from:date) }
        if let date = recipe.filters.toDate { filters["toDay"] = formatter.string(from:date) }
        value["filters"] = filters; return value
    }
    func refreshAssets() {
        guard let catalog else { return }
        indexProgress = (try? catalog.progress()) ?? []
        searchGeneration += 1; let generation = searchGeneration
        searchTask?.cancel()
        let requestedSelection = selectedAssetID
        let payload: [String:Any] = ["op":"query","recipe":requestRecipe(),"mode":searchMode,"limit":assetLimit,"selectedAssetID":selectedAssetID?.uuidString ?? ""]
        searching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds:180_000_000)
            guard !Task.isCancelled, let self else { return }
            if self.resolveSearchInput(apply:false) { return }
            self.searchBridge.request(payload,as:SearchResult.self) { [weak self] response in
                guard let self, self.searchGeneration == generation else { return }
                self.searching = false
                switch response {
                case .success(let result):
                    self.searchError = nil
                    self.paletteCoverage = result.paletteCoverage ?? PaletteCoverage(total:0,prepared:0,failed:0)
                    self.tagCoverage = result.tagCoverage ?? TagCoverage(total:0,prepared:0)
                    self.tagVocabularyVersion = result.tagVersion
                    self.assets = result.assets.map { self.normalizeCache($0) }
                    self.refreshSelectedOrganization()
                    self.resultCount = result.resultCount; self.cameras = result.cameras; self.lenses = result.lenses ?? []; self.formats = result.formats ?? []; self.visualCoverage = result.coverage
                    if let id = self.selectedAssetID {
                        if let selected = self.assets.first(where:{ $0.id == id }) { self.retainedSelection = selected }
                        else if id != requestedSelection { self.refreshAssets() } // Selection changed while this request was in flight.
                        else if let selected = result.selectedAsset, selected.id == id { self.retainedSelection = self.normalizeCache(selected) }
                        else { self.selectedAssetID = nil; self.retainedSelection = nil; self.previewPresented = false }
                    }
                    self.refreshSelectedOrganization()
                case .failure(let error):
                    self.searchError = error.localizedDescription; self.assets = []; self.resultCount = 0
                }
            }
        }
    }
    private func normalizeCache(_ value: IndexedAsset) -> IndexedAsset {
        var asset = value
        if let path = asset.thumbnailPath, !FileManager.default.fileExists(atPath:path) { asset.thumbnailPath = nil }
        if let path = asset.analysisPath, !FileManager.default.fileExists(atPath:path) { asset.analysisPath = nil }
        return asset
    }
    func startPaletteIndexing(retry: Bool = false) {
        guard isReady, !paletteIndexing else { return }
        paletteIndexing = true; paletteError = nil
        indexPaletteBatch(retry:retry)
    }
    private func indexPaletteBatch(retry: Bool = false) {
        searchBridge.request(["op":"palettes","limit":32,"retry":retry],as:PaletteProgress.self) { [weak self] response in
            guard let self else { return }
            switch response {
            case .success(let progress):
                if progress.processed == 0 || progress.remaining == 0 {
                    self.paletteIndexing = false; self.refreshAssets()
                } else {
                    if self.recipe.palette != nil { self.refreshAssets() }
                    self.indexPaletteBatch()
                }
            case .failure(let error): self.paletteIndexing = false; self.paletteError = error.localizedDescription
            }
        }
    }
    func startVisualIndexing() {
        guard isReady, !visualIndexing else { return }
        visualPaused = false; UserDefaults.standard.set(false,forKey:"visualIndexingPaused")
        visualIndexing = true; searchError = nil
        indexVisualBatch()
    }
    func retryVisualFailures() {
        guard !visualIndexing else { return }
        searchBridge.request(["op":"retry"],as:SearchCoverage.self) { [weak self] response in
            guard let self else { return }
            switch response {
            case .success: self.startVisualIndexing()
            case .failure(let error): self.searchError = error.localizedDescription
            }
        }
    }
    func pauseVisualIndexing() {
        visualPaused = true; UserDefaults.standard.set(true,forKey:"visualIndexingPaused")
    }
    private func indexVisualBatch() {
        if visualPaused { visualIndexing = false; return }
        searchBridge.request(["op":"index","limit":16],as:EmbeddingProgress.self) { [weak self] response in
            guard let self else { return }
            switch response {
            case .success(let progress):
                self.visualCoverage = SearchCoverage(total:progress.total,embedded:progress.embedded,failed:progress.failed)
                if progress.processed == 0 || Date().timeIntervalSince(self.lastVisualRefresh) >= 1 {
                    self.lastVisualRefresh = Date(); if !self.searching { self.refreshAssets() }
                }
                if progress.processed == 0 || self.visualPaused { self.visualIndexing = false }
                else { self.indexVisualBatch() }
            case .failure(let error): self.visualIndexing = false; self.searchError = error.localizedDescription
            }
        }
    }
    func loadMore() { guard assetLimit < resultCount else { return }; assetLimit += 500; refreshAssets() }
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
                    self.refreshAccess(rescanOnReconnect:false)
                    if !self.visualPaused { self.startVisualIndexing() }
                    if !self.queuedSources.isEmpty {
                        let queued = self.queuedSources; self.queuedSources = []; self.startIndexing(queued)
                    }
                }
                if !self.searching { self.refreshAssets() }
                self.startPaletteIndexing()
                if !self.visualPaused { self.startVisualIndexing() }
            }
        })
        if started { indexing = true; pausing = false }
    }
    func pauseIndexing() { pausing = true; indexer.pause() }
    func selectAsset(_ id: UUID) {
        selectedAssetID = id; showInspector = true
        retainedSelection = assets.first { $0.id == id } ?? (try? catalog?.indexedAssets(limit:1,assetID:id).first)
        refreshSelectedOrganization()
        try? catalog?.touchPreviews([id])
    }
    func isGallerySelection(_ asset: IndexedAsset) -> Bool {
        guard let id = selectedAssetID else { return false }
        return asset.id == id || (recipe.collapsePairs != false && asset.pairedAssetIDs?.contains(id) == true)
    }
    var selectedGalleryID: UUID? { assets.first(where:{ isGallerySelection($0) })?.id }
    var selectedPairMembers: [IndexedAsset] {
        guard let id = selectedAssetID else { return [] }
        return ((try? catalog?.pairMembers(id)) ?? []).map { normalizeCache($0) }
    }
    func separateSelectedPair() {
        guard let id = selectedAssetID else { return }
        do { try catalog?.separatePair(containing:id); refreshAssets() } catch { errorMessage = error.localizedDescription }
    }
    func restorePairs() {
        do { for source in scopedSources { try catalog?.restorePairing(sourceID:source.id) }; refreshAssets() }
        catch { errorMessage = error.localizedDescription }
    }
    func originalAvailable(_ asset: IndexedAsset) -> Bool {
        guard asset.available, availability[asset.asset.sourceID] == "Connected", let root = resolvedRoots[asset.asset.sourceID] else { return false }
        return FileManager.default.isReadableFile(atPath:root.appendingPathComponent(asset.asset.relativePath).path)
    }
    func openOriginal(in application: URL) {
        guard let asset = selectedAsset, originalAvailable(asset), let root = resolvedRoots[asset.asset.sourceID] else {
            errorMessage = "Reconnect the source drive or restore access to open this original."
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([root.appendingPathComponent(asset.asset.relativePath)],withApplicationAt:application,configuration:configuration) { [weak self] _,error in
            if let error { DispatchQueue.main.async { self?.errorMessage = "Could not open the original: " + error.localizedDescription } }
        }
    }
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
