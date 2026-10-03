import SwiftUI
import PhotoViewsCore
import AppKit

private enum Workbench {
    static let controlGap: CGFloat = 8
    static let contentInset: CGFloat = 20
    static let sectionGap: CGFloat = 24
}
struct WorkspaceView: View {
    @ObservedObject var model: WorkspaceModel
    @AppStorage("gallerySidebarVisible") private var sidebarVisible = false
    @FocusState private var searchFocused: Bool
    @State private var saving = false
    @State private var creatingCollection = false
    @State private var collectionName = ""
    @State private var viewName = ""
    @State private var filtersVisible = false
    @State private var indexingDetails = false
    @State private var queryHelp = false
    var availableHeight: CGFloat = 760
    @State private var confirmedTagDraft = ""
    private let timer = Timer.publish(every:15,on:.main,in:.common).autoconnect()

    var body: some View {
        HSplitView {
            if sidebarVisible {
                sidebar.frame(minWidth:180,idealWidth:220,maxWidth:300)
            }
            VStack(spacing:0) {
                recipeBar.fixedSize(horizontal:false,vertical:true)
                Divider()
                indexingBar
                content.frame(maxWidth:.infinity,maxHeight:.infinity)
            }
            .frame(minWidth:360,maxWidth:.infinity,maxHeight:.infinity)
            .background(Color(nsColor:.textBackgroundColor))
            if model.showInspector {
                inspector.frame(minWidth:220,idealWidth:260,maxWidth:340)
            }
        }
        .navigationTitle(model.currentTitle)
        .toolbar {
            ToolbarItem(placement:.navigation) {
                Button { sidebarVisible.toggle() } label: { Label("Sidebar",systemImage:"sidebar.left") }
                    .help("Show or hide sources and saved views")
            }
            ToolbarItem {
                Button { searchFocused = true } label: { Label("Search",systemImage:"magnifyingglass") }.keyboardShortcut("f",modifiers:.command)
            }
            ToolbarItem(placement:.primaryAction) {
                Button { model.chooseFolder() } label: { Label("Add Folder",systemImage:"folder.badge.plus") }
                    .disabled(!model.isReady)
            }
            ToolbarItem {
                Button { model.showInspector.toggle() } label: { Label("Inspector",systemImage:"sidebar.right") }
                    .help("Show or hide details")
            }
        }
        .onChange(of:model.selectedAssetID) { _,id in if id == nil { model.showInspector = false } }
        .onChange(of:model.recipe.search) { _,text in if model.queryPlan?.input != text { model.queryPlan = nil } }
        .onChange(of:model.searchMode) { _,_ in model.queryPlan = nil }
        .onChange(of:model.recipe) { _,_ in model.persistRecipe() }
        .onReceive(timer) { _ in if NSApp.isActive { model.refreshAccess() } }
        .alert("Photo Views",isPresented:Binding(get:{ model.errorMessage != nil },set:{ if !$0 { model.errorMessage = nil } })) {
            Button("OK",role:.cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .sheet(isPresented:$saving) { SaveLiveViewSheet(model:model,saving:$saving,viewName:$viewName) }
        .sheet(isPresented:$creatingCollection) { CreateCollectionSheet(model:model,presented:$creatingCollection,name:$collectionName) }
        .sheet(isPresented:$model.previewPresented) { PhotoPreview(model:model) }
    }
    private var sidebarSelection: Binding<String?> {
        Binding(get: {
            if let id = model.selectedSavedView { return "view:\(id.uuidString)" }
            if let id = model.recipe.collectionID { return "collection:\(id.uuidString)" }
            if model.recipe.favoritesOnly == true { return "favorites" }
            if let id = model.recipe.sourceIDs.first { return "source:\(id.uuidString)" }
            return "all"
        }, set: { value in
            guard let value else { return }
            if value == "all" { model.selectAll() }
            else if value == "favorites" { model.selectFavorites() }
            else if value == "newCollection" { collectionName = ""; creatingCollection = true }
            else if let collection = model.collections.first(where:{ "collection:\($0.id.uuidString)" == value }) { model.selectCollection(collection) }
            else if let source = model.sources.first(where: { "source:\($0.id.uuidString)" == value }) { model.selectSource(source) }
            else if let view = model.savedViews.first(where: { "view:\($0.id.uuidString)" == value }) { model.selectView(view) }
        })
    }
    private var sidebar: some View {
        List(selection: sidebarSelection) {
            Label("All photos",systemImage:"photo.on.rectangle").tag("all")
            Label("Favorites",systemImage:"heart").tag("favorites")
            Section("Sources") {
                if model.sources.isEmpty { Text("No folders added").foregroundStyle(.secondary) }
                ForEach(model.sources) { source in
                    HStack(alignment:.top,spacing:8) {
                            Image(systemName:"folder").padding(.top,2)
                            VStack(alignment:.leading,spacing:3) {
                                Text(source.name).lineLimit(1)
                                Text(model.sourceStatus(source))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer(minLength:0)
                        }
                    .tag("source:\(source.id.uuidString)")
                    .contextMenu {
                        Button("Restore Access…") { model.chooseFolder(reauthorizing:source) }
                        Button("Check Availability") { model.refreshAccess() }
                    }
                }
            }
            Section("Saved Views") {
                if model.savedViews.isEmpty { Text("No saved views").foregroundStyle(.secondary) }
                ForEach(model.savedViews) { view in
                    Label(view.name,systemImage:"line.3.horizontal.decrease.circle")
                        .tag("view:\(view.id.uuidString)")
                }
            }
            Section("Collections") {
                ForEach(model.collections) { collection in
                    Label(collection.name,systemImage:"square.stack").tag("collection:\(collection.id.uuidString)")
                }
                Button { collectionName = ""; creatingCollection = true } label: { Label("New Collection…",systemImage:"plus") }.tag("newCollection").disabled(!model.isReady)
            }
        }
        .buttonStyle(.plain)
        .listStyle(.sidebar)
        .safeAreaInset(edge:.bottom) {
            VStack(alignment:.leading,spacing:6) {
                Divider()
                Label("Catalog stored on this Mac",systemImage:"internaldrive")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal,12).padding(.bottom,12)
            }
        }
    }
    private var recipeBar: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(spacing:8) {
                if let reference = model.referencePhoto {
                    CachedPhoto(path:reference.thumbnailPath,revision:reference.id.uuidString).frame(width:32,height:24)
                    Text("Similar photo").font(.subheadline)
                    Spacer()
                    Button("Exit Similar") { model.exitSimilar() }
                } else {
                    Image(systemName:"magnifyingglass").foregroundStyle(.secondary)
                    TextField(model.searchMode == "visual" ? "Describe a photo…" : "Search filenames or folders…",text:$model.recipe.search)
                        .textFieldStyle(.plain).accessibilityLabel("Search photos")
                        .disabled(!model.isReady || model.sources.isEmpty)
                        .focused($searchFocused).onSubmit { model.submitSearch() }
                    if !model.recipe.search.isEmpty {
                        Button { model.recipe.search = "" } label: { Image(systemName:"xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("Clear search")
                    }
                }
                Button { filtersVisible.toggle() } label: { Label("Filters",systemImage:"line.3.horizontal.decrease") }
                    .help("Expand photo filters").accessibilityValue(filtersVisible ? "Expanded" : model.hasFilters || model.recipe.palette != nil ? "Active filters" : "Collapsed")
                viewOptions
                if model.hasUnsavedChanges { Image(systemName:"circle.fill").font(.system(size:5)).accessibilityLabel("Unsaved view changes").help("Unsaved view changes") }
                if model.searching { ProgressView().controlSize(.small).accessibilityLabel("Searching photos") }
            }
            if model.recipe.palette != nil && model.paletteCoverage.prepared < model.paletteCoverage.total {
                HStack {
                    Text("Palette analyzed: \(model.paletteCoverage.prepared) / \(model.paletteCoverage.total) files").font(.caption).foregroundStyle(.secondary)
                    if model.paletteIndexing { ProgressView().controlSize(.small) }
                    else { Button("Analyze Palettes") { model.startPaletteIndexing(retry:true) }.controlSize(.small) }
                }
            }
            if model.needsCurrentSearchModel {
                VStack(alignment:.leading,spacing:8) {
                    Text("This view uses a different search model. Changing it may change the results.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                    Button("Use Current Search Model") { model.useCurrentSearchModel() }
                }
            }
            if let plan = model.queryPlan {
                if plan.canApply {
                    HStack {
                        Text("Press Return to apply recognized constraints").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Search") { model.applyQueryPlan(); model.persistRecipe() }.controlSize(.small)
                    }
                } else {
                VStack(alignment:.leading,spacing:8) {
                    HStack { Text(plan.canApply ? "Press Return to search" : "Review query").font(.headline); Spacer(); Button("Dismiss") { model.queryPlan = nil; queryHelp = false } }
                    ScrollView {
                        VStack(alignment:.leading,spacing:8) {
                            TextField("Visual intent",text:Binding(get:{ model.queryPlan?.visualIntent ?? "" },set:{ model.queryPlan?.visualIntent = $0 })).textFieldStyle(.roundedBorder).accessibilityLabel("Interpreted visual intent")
                            let summary = model.filterDescription(plan.filters)
                            Text(summary.isEmpty ? "No exact constraints recognized" : summary).font(.caption).fixedSize(horizontal:false,vertical:true)
                            if let palette = plan.palette { Text("Dominant \(palette.color) · at least \(Int(palette.minimumFraction*100))% of image area").font(.caption) }
                            if let grouping = plan.grouping { Text("Group by: \(grouping.title)").font(.caption) }
                            ForEach(plan.ambiguities,id:\.self) { Text($0).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
                            ForEach(plan.unsupported,id:\.self) { Text("Unsupported clause: "+$0).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
                            Text("Only listed clauses become exact filters. Remaining words stay visual. Edit constraints in Filters after applying.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                        }
                    }
                    HStack { Button("Apply Plan") { model.applyQueryPlan(); model.persistRecipe(); queryHelp = false }.disabled(!plan.canApply); Button("Syntax Help") { queryHelp.toggle() } }
                }.padding(.top,8).frame(height:180)
            }
                }
            if queryHelp {
                ScrollView { Text("Examples: cars at night camera:\"NIKON Z f\" folder:Japan group by month; on:2025-11-06; iso>=400; aperture<=2.8; shutter<=1/500; width>=4000; tag:cars. Quote multiword values. today/yesterday use this Mac’s timezone. Strict >/< and arbitrary date phrases need manual filters.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }.frame(height:70)
            }
            if filtersVisible {
                Divider()
                ScrollView { filterControls.frame(maxWidth:.infinity,alignment:.leading) }.frame(height:max(120,min(280,availableHeight - 250)))
            }
            if model.hasFilters || model.recipe.palette != nil {
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:6) {
                        ForEach(model.activeFilterChips,id:\.key) { chip in
                            Button { model.removeFilter(chip.key) } label: { HStack(spacing:4) { Text(chip.title); Image(systemName:"xmark").font(.caption2) } }
                                .controlSize(.small).accessibilityLabel("Remove filter: "+chip.title)
                        }
                        if let palette = model.recipe.palette {
                            Button { model.recipe.palette = nil } label: { HStack(spacing:4) { Text("Dominant \(palette.color) ≥ \(Int(palette.minimumFraction*100))%"); Image(systemName:"xmark").font(.caption2) } }
                                .controlSize(.small).accessibilityLabel("Remove overall palette filter")
                        }
                    }
                }
            }
        }.padding(.horizontal,12).padding(.vertical,10)
    }
    private var viewOptions: some View {
        Menu(model.usesVisualVectors && model.recipe.grouping == .folder ? "View · Similar shots" : model.recipe.grouping == .none ? "View" : "View · \(model.recipe.grouping.title)") {
                    Picker("Search",selection:Binding(get:{ model.searchMode },set:{ model.searchMode = $0 })) {
                        Text("Natural language").tag("visual")
                        Text("Filename or keyword").tag("filename")
                    }
                    Divider()
                    Picker("Group by",selection:$model.recipe.grouping) {
                        ForEach(Grouping.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Sort",selection:$model.recipe.sorting) {
                        ForEach(PhotoSort.allCases.filter { $0 != .relevance }) { Text($0.title).tag($0) }
                    }.disabled(model.isRankedSearch)
                    Divider()
                    Button("Save View…") { viewName = model.selectedSavedView == nil ? "" : model.currentTitle; saving = true }
                        .disabled(model.sources.isEmpty || !model.isReady)
                    if model.selectedSavedView != nil {
                        Button("Update View") { model.saveView(name:model.currentTitle,update:true) }.disabled(!model.hasUnsavedChanges)
                        Button("Revert Changes") { if let view = model.savedViews.first(where:{ $0.id == model.selectedSavedView }) { model.selectView(view) } }.disabled(!model.hasUnsavedChanges)
                    }
                    Divider()
                    Toggle("Collapse RAW + JPEG",isOn:Binding(get:{ model.recipe.collapsePairs != false },set:{ model.recipe.collapsePairs = $0 }))
                    Button("Restore Automatic Pairs") { model.restorePairs() }
                    Button("Refresh Results") { model.refreshAssets() }
                }.help("Group, sort or save this view")
    }
    private var filterControls: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Text("Filter photos").font(.headline); Spacer(); Button("Done") { filtersVisible = false } }
            if model.searchMode == "visual" {
                VStack(alignment:.leading,spacing:6) {
                    HStack {
                        Text("Minimum match score")
                        Slider(value:Binding(get:{ model.recipe.minimumSimilarity ?? (model.recipe.referenceAssetID == nil ? 0.20 : 0.75) },set:{ model.recipe.minimumSimilarity = $0 }),in:0...1,step:0.01)
                        Text(String(format:"%.2f",model.recipe.minimumSimilarity ?? (model.recipe.referenceAssetID == nil ? 0.20 : 0.75))).monospacedDigit().frame(width:40)
                    }
                    Text("Higher scores exclude weaker matches. Similarity is not a confidence percentage.").font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment:.leading,spacing:8) {
                Text("Overall palette").font(.subheadline)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:70))],spacing:6) {
                    ForEach(PaletteSearch.colors,id:\.self) { color in
                        Button { model.recipe.palette = PaletteSearch(color:color,minimumFraction:model.recipe.palette?.minimumFraction ?? 0.25) } label: {
                            HStack(spacing:4) { Circle().fill(paletteColor(color)).frame(width:10,height:10).overlay(Circle().stroke(.secondary,lineWidth:0.5)); Text(color.capitalized); if model.recipe.palette?.color == color { Image(systemName:"checkmark").font(.caption2) } }
                        }.controlSize(.small).tint(model.recipe.palette?.color == color ? .accentColor : nil)
                            .accessibilityValue(model.recipe.palette?.color == color ? "Selected" : "Not selected")
                    }
                }
                if let palette = model.recipe.palette {
                    HStack {
                        Text("Image area")
                        Slider(value:Binding(get:{ model.recipe.palette?.minimumFraction ?? 0.25 },set:{ model.recipe.palette?.minimumFraction = $0 }),in:0.05...1,step:0.05)
                            .accessibilityLabel("Minimum area occupied by overall palette color")
                        Text("\(Int((palette.minimumFraction*100).rounded()))%").monospacedDigit().frame(width:40)
                    }
                    Button("Clear Color") { model.recipe.palette = nil }.controlSize(.small)
                }
                Text("Finds the largest color family in the image. Image area sets its minimum share.").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Picker("Camera",selection:Binding(get:{ model.recipe.filters.camera ?? "" },set:{ model.recipe.filters.camera = $0.isEmpty ? nil : $0 })) {
                Text("Any camera").tag("")
                ForEach(Array(Set(model.cameras + [model.recipe.filters.camera].compactMap { $0 })).sorted(),id:\.self) { Text($0).tag($0) }
            }
            TextField("Folder contains",text:Binding(get:{ model.recipe.filters.folder ?? "" },set:{ model.recipe.filters.folder = $0.isEmpty ? nil : $0 }))
                .textFieldStyle(.roundedBorder).accessibilityLabel("Folder path contains")
            VStack(alignment:.leading,spacing:8) {
                Text("Capture date").font(.subheadline)
                Toggle("From",isOn:Binding(get:{ model.recipe.filters.fromDate != nil },set:{ model.recipe.filters.fromDate = $0 ? Date() : nil }))
                if model.recipe.filters.fromDate != nil { DatePicker("From date",selection:Binding(get:{ model.recipe.filters.fromDate ?? Date() },set:{ model.recipe.filters.fromDate = $0 }),displayedComponents:.date) }
                Toggle("Through",isOn:Binding(get:{ model.recipe.filters.toDate != nil },set:{ model.recipe.filters.toDate = $0 ? Date() : nil }))
                if model.recipe.filters.toDate != nil { DatePicker("Through date",selection:Binding(get:{ model.recipe.filters.toDate ?? Date() },set:{ model.recipe.filters.toDate = $0 }),displayedComponents:.date) }
                Text("Uses dates recorded by the camera. Unknown dates are excluded when a date filter is active.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
            VStack(alignment:.leading,spacing:8) {
                Text("Confirmed tags").font(.subheadline)
                TextField("Comma-separated tags",text:$confirmedTagDraft)
                    .onAppear { confirmedTagDraft = model.recipe.filters.confirmedTags.joined(separator:", ") }
                    .onSubmit { applyConfirmedTags() }
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Confirmed tags, all required")
                Button("Apply Tags") { applyConfirmedTags() }
                Text("Every tag must be confirmed. Suggestions do not satisfy this filter.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
            DisclosureGroup("More metadata") {
                VStack(alignment:.leading,spacing:12) {
                    Picker("Lens",selection:Binding(get:{ model.recipe.filters.lens ?? "" },set:{ model.recipe.filters.lens = $0.isEmpty ? nil : $0 })) {
                        Text("Any lens").tag("")
                        ForEach(Array(Set(model.lenses + [model.recipe.filters.lens].compactMap { $0 })).sorted(),id:\.self) { Text($0).tag($0) }
                    }
                    Picker("Format",selection:Binding(get:{ model.recipe.filters.format ?? "" },set:{ model.recipe.filters.format = $0.isEmpty ? nil : $0 })) {
                        Text("Any format").tag("")
                        ForEach(Array(Set(model.formats + [model.recipe.filters.format].compactMap { $0 })).sorted(),id:\.self) { Text($0).tag($0) }
                    }
                    MetadataRange(title:"ISO",low:$model.recipe.filters.minISO,high:$model.recipe.filters.maxISO)
                    MetadataRange(title:"Aperture (f-number)",low:$model.recipe.filters.minAperture,high:$model.recipe.filters.maxAperture)
                    MetadataRange(title:"Shutter (seconds)",low:$model.recipe.filters.minShutterSeconds,high:$model.recipe.filters.maxShutterSeconds)
                    MetadataRange(title:"Width (pixels)",low:$model.recipe.filters.minWidth,high:$model.recipe.filters.maxWidth)
                    MetadataRange(title:"Height (pixels)",low:$model.recipe.filters.minHeight,high:$model.recipe.filters.maxHeight)
                    Text("Limits are inclusive. Blank means any value. Photos with unknown metadata are excluded when that constraint is active. Width and height use original recorded dimensions.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                }.padding(.top,8)
            }
            Button("Clear All Filters") { confirmedTagDraft = ""; model.clearFilters(); model.recipe.palette = nil }.disabled(!model.hasFilters && model.recipe.palette == nil)
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
    }
    private func paletteColor(_ name: String) -> Color {
        switch name {
        case "red": return .red; case "orange": return .orange; case "yellow": return .yellow
        case "green": return .green; case "cyan": return .cyan; case "blue": return .blue
        case "purple": return .purple; case "pink": return .pink; case "brown": return .brown
        case "black": return .black; case "white": return .white; default: return .gray
        }
    }
    private func applyConfirmedTags() {
        model.recipe.filters.confirmedTags = Array(Set(confirmedTagDraft.split(separator:",").map { $0.trimmingCharacters(in:.whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })).sorted()
    }
    @ViewBuilder private var content: some View {
        if !model.isReady {
            emptyState(icon:"exclamationmark.triangle",title:"The catalog couldn’t open",detail:"Restart Photo Views after resolving the catalog error. Your original photos haven’t been changed.") {
                Text(model.catalogURL.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        } else if model.sources.isEmpty {
            emptyState(icon:"photo.on.rectangle.angled",title:"Your photos, in place",detail:"Add a folder to start your catalog. Originals stay where they are; views will give you new ways to find them.") {
                Button("Add Folder…") { model.chooseFolder() }.buttonStyle(.borderedProminent)
                    .keyboardShortcut("o",modifiers:[.command])
            }
        } else if let error = model.searchError {
            emptyState(icon:"exclamationmark.triangle",title:"Search needs attention",detail:error) {
                Button("Try Again") { model.refreshAssets() }
            }
        } else if let plan = model.queryPlan {
            emptyState(icon:"magnifyingglass",title:plan.canApply ? "Ready to search" : "Search needs correction",detail:plan.canApply ? "Press Return or Search to apply the recognized constraints." : "Edit the unsupported or ambiguous clauses above. This search has not run.") { EmptyView() }
        } else if model.assets.isEmpty && model.searching {
            emptyState(icon:"magnifyingglass",title:"Loading photos…",detail:"Preparing your local results.") { ProgressView().controlSize(.small) }
        } else if model.assets.isEmpty && (model.recipe.collectionID != nil || model.recipe.favoritesOnly == true) && !model.hasSearch && !model.hasFilters {
            emptyState(icon:model.recipe.favoritesOnly == true ? "heart" : "square.stack",title:model.recipe.favoritesOnly == true ? "No favorites yet" : "This collection is empty",detail:"Select a photo in All photos and add it using the details sidebar. Manual collections keep only the photos you choose.") {
                Button("Browse All Photos") { model.selectAll() }
            }
        } else if model.assets.isEmpty && (model.hasSearch || model.hasFilters) {
            emptyState(icon:"magnifyingglass",title:model.searching ? "Searching photos…" : "No matching photos",detail:model.usesVisualVectors && model.visualCoverage.total > 0 && model.visualCoverage.embedded == 0 ? "Visual indexing needs to finish some photos first. You can use Filename search now." : "Try another search or edit the filters. Your filters have not been relaxed.") {
                if model.hasFilters { Button("Clear Filters") { model.clearFilters() } }
                if model.hasSearch { Button("Clear Search") { model.exitSimilar() } }
            }
        } else if !model.assets.isEmpty {
            PhotoGrid(model:model)
        } else {
            emptyState(icon:"folder",title:model.indexing ? "Discovering your photos" : "Ready to browse",detail:model.indexing ? "Photos will appear as their previews are ready. Originals stay in their folders." : "Start indexing this folder to build previews and read camera metadata. Originals stay where they are.") {
                HStack {
                    Button("Add Another Folder…") { model.chooseFolder() }
                    Button(model.paused ? "Resume Indexing" : "Start Indexing") { model.startIndexing() }.disabled(model.indexing)
                }
            }
        }
    }
    private func emptyState<Actions:View>(icon:String,title:String,detail:String,@ViewBuilder actions:() -> Actions) -> some View {
        VStack(spacing:16) {
            Image(systemName:icon).font(.system(size:36,weight:.light)).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(title).font(.title2.weight(.semibold))
            Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth:380).fixedSize(horizontal:false,vertical:true)
            actions().padding(.top,4)
        }.padding(Workbench.sectionGap)
    }
    private var inspector: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:Workbench.sectionGap) {
                Text("Details").font(.headline)
                if let asset = model.selectedAsset {
                    photoDetails(asset)
                } else if let source = model.selectedSource {
                    VStack(alignment:.leading,spacing:12) {
                        Label(source.name,systemImage:"folder").font(.body.weight(.medium))
                        LabeledContent("Availability",value:model.availability[source.id] ?? "Checking…")
                        LabeledContent("Files",value:String(model.indexProgress.first { $0.sourceID == source.id }?.total ?? 0))
                        Text(source.lastKnownPath).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        Button("Reveal in Finder") { model.revealSource() }
                        if model.availability[source.id] != "Connected" {
                            Text("Cached previews, metadata and search stay available. Reconnect the drive to resume indexing and open originals.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                            Button("Check Drive") { model.refreshAccess() }
                        }
                        if model.availability[source.id] == "Access needed" {
                            Button("Restore Access…") { model.chooseFolder(reauthorizing:source) }
                        }
                    }
                } else {
                    Text("Select a photo to inspect its metadata, or select a source for folder details.")
                        .foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                }
                Divider()
                VStack(alignment:.leading,spacing:12) {
                    Text("View recipe").font(.subheadline.weight(.semibold))
                    LabeledContent("Sources",value:model.recipe.sourceIDs.isEmpty ? "All sources" : "Selected sources")
                    LabeledContent("Group by",value:model.recipe.grouping.title)
                    LabeledContent("Sort",value:model.resultOrderingTitle)
                    if model.selectedSavedView != nil {
                        Text(model.hasUnsavedChanges ? "Changes haven’t been saved." : "Saved view settings")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.padding(Workbench.contentInset)
        }
        .background(Color(nsColor:.controlBackgroundColor))
    }
    private var indexingBar: some View {
        Group {
            if !model.sources.isEmpty {
                DisclosureGroup(isExpanded:$indexingDetails) {
                    VStack(alignment:.leading,spacing:10) {
                        HStack {
                            Text("Previews: \(model.completedPreviews) of \(model.totalAssets)").font(.caption)
                            Spacer()
                            Button(model.indexing ? (model.pausing ? "Pausing…" : "Pause Previews") : "Resume Previews") { if model.indexing { model.pauseIndexing() } else { model.startIndexing() } }.disabled(model.pausing)
                        }
                        HStack {
                            Text("Visual search: \(model.visualCoverage.embedded) of \(model.visualCoverage.total)").font(.caption)
                            Spacer()
                            Button(model.visualIndexing ? (model.visualPaused ? "Pausing…" : "Pause Visual Indexing") : "Build Visual Index") { if model.visualIndexing { model.pauseVisualIndexing() } else { model.startVisualIndexing() } }.disabled(model.visualIndexing && model.visualPaused)
                        }
                        HStack {
                            Text("Palette: \(model.paletteCoverage.prepared) / \(model.paletteCoverage.total) files · \(model.paletteCoverage.failed) unavailable")
                            Spacer()
                            Button(model.paletteIndexing ? "Analyzing…" : "Retry Palette Analysis") { model.startPaletteIndexing(retry:true) }.disabled(model.paletteIndexing)
                        }.font(.caption)
                        if let error = model.paletteError { Text(error).font(.caption).foregroundStyle(.secondary) }
                        Text("Files with tag suggestions: \(model.tagCoverage.prepared) of \(model.tagCoverage.total)").font(.caption).foregroundStyle(.secondary)
                        if model.visualCoverage.failed > 0 {
                            Text("\(model.visualCoverage.failed) photos need attention").font(.caption)
                            ForEach(model.visualCoverage.failures ?? [],id:\.assetID) { failure in
                                VStack(alignment:.leading,spacing:4) {
                                    Button(failure.filename) { model.selectAsset(failure.assetID) }
                                    Text(failure.error).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                                }
                            }
                            Button("Retry Failed Photos") { model.retryVisualFailures() }.disabled(model.visualIndexing)
                        }
                        if let error = model.scopedProgress.compactMap({ $0.error }).first { Text(error).font(.caption).foregroundStyle(.secondary) }
                        Text("Photos stay in their folders. Indexing resumes from saved progress.").font(.caption).foregroundStyle(.secondary)
                    }.padding(.top,8)
                } label: {
                    HStack(spacing:8) {
                        if model.indexing || model.visualIndexing { ProgressView().controlSize(.small) }
                        Text(model.queryPlan != nil ? "Search not run" : model.isRankedSearch ? "\(model.assets.count) of \(model.resultCount) matching photos" : "\(model.resultCount) photos")
                        Spacer()
                        Text("Indexed \(model.visualCoverage.embedded) / \(model.visualCoverage.total)")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                }.padding(.horizontal,12).padding(.vertical,6)
            }
        }
    }
    private func photoDetails(_ asset: IndexedAsset) -> some View {
        VStack(alignment:.leading,spacing:12) {
            Text(asset.filename).font(.body.weight(.medium)).textSelection(.enabled)
            CachedPhoto(path:asset.thumbnailPath,revision:String(asset.asset.modifiedAt?.timeIntervalSince1970 ?? 0)).frame(height:128)
            if model.selectedPairMembers.count == 2 {
                Text("RAW + JPEG").font(.subheadline.weight(.semibold))
                ForEach(model.selectedPairMembers) { member in
                    Button { model.selectAsset(member.id) } label: {
                        HStack { Text(member.filename).lineLimit(1); Spacer(); Text(model.originalAvailable(member) ? "Available" : "Offline").font(.caption).foregroundStyle(.secondary); if member.id == asset.id { Image(systemName:"checkmark") } }
                    }.help("Inspect this member’s metadata, tags and original")
                }
                Text("Metadata, tags, favorites and collection membership belong to the selected file.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Button("Separate Pair") { model.separateSelectedPair() }
            }
            Button("Open Preview") { model.previewPresented = true }
            Button { model.toggleFavorite() } label: { Label(model.selectedFavorite ? "Remove Favorite" : "Favorite",systemImage:model.selectedFavorite ? "heart.fill" : "heart") }
            Menu("Collections") {
                if model.collections.isEmpty { Text("Create a collection in the sidebar") }
                ForEach(model.collections) { collection in
                    Button { model.toggleCollection(collection) } label: { if model.selectedCollections.contains(collection.id) { Label(collection.name,systemImage:"checkmark") } else { Text(collection.name) } }
                }
            }
            Button("Find Similar") { model.findSimilar() }
                .disabled(model.visualCoverage.embedded == 0)
            Button("Reveal Original in Finder") { model.revealPhoto() }
            PhotoTags(model:model)
            Divider()
            LabeledContent("Original",value:model.originalAvailable(asset) ? "Available" : model.availability[asset.asset.sourceID] == "Connected" ? "Missing or unreadable" : "Drive disconnected or access needed")
            if let metadata = asset.metadata {
                LabeledContent("Camera",value:metadata.camera ?? "Unknown")
                LabeledContent("Captured",value:metadata.captureDateText ?? "Unknown")
                if metadata.captureDateText != nil && metadata.captureTimezone == nil { Text("Camera timezone not recorded").font(.caption).foregroundStyle(.secondary) }
                LabeledContent("Lens",value:metadata.lens ?? "Unknown")
                LabeledContent("ISO",value:metadata.iso.map { String(Int($0)) } ?? "Unknown")
                LabeledContent("Aperture",value:metadata.aperture.map { "f/\($0.formatted())" } ?? "Unknown")
                LabeledContent("Exposure",value:metadata.exposureDescription ?? "Unknown")
                LabeledContent("Size",value:metadata.width.flatMap { width in metadata.height.map { "\(width) × \($0)" } } ?? "Unknown")
                LabeledContent("Format",value:metadata.format ?? "Unknown")
            }
            if let error = asset.error {
                Label("Preview failed",systemImage:"exclamationmark.triangle").font(.subheadline.weight(.semibold))
                Text(error).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Button("Retry Preview") { model.retrySelectedPreview() }.disabled(model.indexing || !model.originalAvailable(asset))
            } else if asset.thumbnailPath == nil && asset.previewState == .complete {
                Text("The preview cache was cleared to stay within its limit. Metadata and the original are preserved.").font(.caption).foregroundStyle(.secondary)
                Button("Rebuild Preview") { model.retrySelectedPreview() }.disabled(model.indexing || !model.originalAvailable(asset))
            } else if let source = asset.previewSource { Text("\(source) · sRGB").font(.caption).foregroundStyle(.secondary) }
            Text(asset.asset.relativePath).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }
}
private struct SaveLiveViewSheet: View {
    @ObservedObject var model: WorkspaceModel
    @Binding var saving: Bool
    @Binding var viewName: String
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            Text("Save this live view").font(.title3.weight(.semibold))
            Text("Saves the recipe, not a fixed set of photos. New matching photos appear as indexing finishes.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            TextField("View name",text:$viewName).textFieldStyle(.roundedBorder)
            if let palette = model.recipe.palette { Text("Dominant \(palette.color) ≥ \(Int(palette.minimumFraction*100))% of image area").font(.caption) }
            Text("\(model.recipe.sourceIDs.isEmpty ? "All sources" : "Selected sources") · Group by \(model.recipe.grouping.title.lowercased()) · \(model.resultOrderingTitle)")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancel",role:.cancel) { saving = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save View") { if model.saveView(name:viewName) { saving = false } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(viewName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width:400)
    }
}

private struct CreateCollectionSheet: View {
    @ObservedObject var model: WorkspaceModel
    @Binding var presented: Bool
    @Binding var name: String
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            Text("New collection").font(.title3.weight(.semibold))
            Text("A manual collection contains only photos you add. Originals stay in their folders.").font(.caption).foregroundStyle(.secondary)
            TextField("Collection name",text:$name).textFieldStyle(.roundedBorder)
            HStack { Button("Cancel",role:.cancel) { presented = false }.keyboardShortcut(.cancelAction); Spacer()
                Button("Create Collection") { if model.createCollection(name:name) { presented = false } }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width:400)
    }
}
private struct PhotoTags: View {
    @ObservedObject var model: WorkspaceModel
    @State private var draft = ""
    @State private var replacing: UUID?
    private var confirmed: [TagAssignmentRecord] { model.selectedTags.filter(\.isConfirmed) }
    private var suggested: [TagAssignmentRecord] { model.selectedTags.filter { model.tagVocabularyVersion != nil && $0.provenance == .suggested && $0.decision == .unconfirmed && $0.vocabularyVersion == model.tagVocabularyVersion } }
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text("Confirmed tags").font(.subheadline.weight(.semibold))
            if confirmed.isEmpty { Text("No confirmed tags").font(.caption).foregroundStyle(.secondary) }
            ForEach(confirmed) { tag in
                HStack { Text(tag.tag).lineLimit(1); Spacer(minLength:0)
                    Button { draft = tag.tag; replacing = tag.id } label: { Image(systemName:"pencil") }.accessibilityLabel("Edit confirmed tag \(tag.tag)")
                    Button { model.setTagDecision(tag,.rejected) } label: { Image(systemName:"minus.circle") }.accessibilityLabel("Remove confirmed tag \(tag.tag)")
                }
            }
            HStack(spacing:8) {
                TextField(replacing == nil ? "Add a tag" : "Edit tag",text:$draft).textFieldStyle(.roundedBorder).onSubmit { saveTag() }
                Button(replacing == nil ? "Add" : "Save") { saveTag() }.disabled(draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            }
            if replacing != nil { Button("Cancel Edit") { replacing = nil; draft = "" }.font(.caption) }
            Text("Suggested tags").font(.subheadline.weight(.semibold)).padding(.top,4)
            Text("Local model suggestions. Confirm only what you can see.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            if suggested.isEmpty { Text("No suggestions yet, or none passed the cutoff.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
            ForEach(suggested) { tag in
                VStack(alignment:.leading,spacing:6) {
                    Text(tag.tag).font(.body)
                    HStack(spacing:8) {
                        Button("Accept") { model.setTagDecision(tag,.accepted) }.accessibilityLabel("Accept suggested tag \(tag.tag)")
                        Button("Reject") { model.setTagDecision(tag,.rejected) }.accessibilityLabel("Reject suggested tag \(tag.tag)")
                        Button("Edit") { draft = tag.tag; replacing = tag.id }.accessibilityLabel("Edit suggested tag \(tag.tag)")
                    }
                }.help("Cosine similarity \(tag.score?.formatted(.number.precision(.fractionLength(3))) ?? "unknown"); cutoff \(tag.threshold?.formatted(.number.precision(.fractionLength(3))) ?? "unknown"). This is not a probability.")
            }
        }.onChange(of:model.selectedAssetID) { _,_ in draft = ""; replacing = nil }
    }
    private func saveTag() { if model.addTag(draft,replacing:replacing) { draft = ""; replacing = nil } }
}

private struct MetadataRange: View {
    var title: String
    @Binding var low: Double?
    @Binding var high: Double?
    private var formatter: NumberFormatter { let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 8; return f }
    var body: some View {
        VStack(alignment:.leading,spacing:6) {
            Text(title).font(.subheadline)
            HStack {
                TextField("Minimum",value:$low,formatter:formatter).accessibilityLabel(title+" minimum")
                TextField("Maximum",value:$high,formatter:formatter).accessibilityLabel(title+" maximum")
            }.textFieldStyle(.roundedBorder)
        }
    }
}
