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
    @State private var sidebarVisible = true
    @State private var saving = false
    @State private var viewName = ""
    @State private var filtersVisible = false
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
            ToolbarItem(placement:.primaryAction) {
                Button { model.chooseFolder() } label: { Label("Add Folder",systemImage:"folder.badge.plus") }
                    .disabled(!model.isReady)
            }
            ToolbarItem {
                Button { model.showInspector.toggle() } label: { Label("Inspector",systemImage:"sidebar.right") }
                    .help("Show or hide details")
            }
        }
        .onChange(of:model.recipe) { _,_ in model.persistRecipe() }
        .onReceive(timer) { _ in if NSApp.isActive { model.refreshAccess() } }
        .alert("Photo Views",isPresented:Binding(get:{ model.errorMessage != nil },set:{ if !$0 { model.errorMessage = nil } })) {
            Button("OK",role:.cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .sheet(isPresented:$saving) { saveSheet }
        .sheet(isPresented:$model.previewPresented) { PhotoPreview(model:model) }
    }
    private var sidebarSelection: Binding<String?> {
        Binding(get: {
            if let id = model.selectedSavedView { return "view:\(id.uuidString)" }
            if let id = model.recipe.sourceIDs.first { return "source:\(id.uuidString)" }
            return "all"
        }, set: { value in
            guard let value else { return }
            if value == "all" { model.selectAll() }
            else if let source = model.sources.first(where: { "source:\($0.id.uuidString)" == value }) { model.selectSource(source) }
            else if let view = model.savedViews.first(where: { "view:\($0.id.uuidString)" == value }) { model.selectView(view) }
        })
    }
    private var sidebar: some View {
        List(selection: sidebarSelection) {
            Label("All photos",systemImage:"photo.on.rectangle").tag("all")
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
                Text("No collections yet").foregroundStyle(.secondary)
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
        VStack(alignment:.leading,spacing:12) {
            HStack(spacing:Workbench.controlGap) {
                Image(systemName:"magnifyingglass").foregroundStyle(.secondary)
                TextField("Describe a photo or enter a keyword",text:$model.recipe.search)
                    .textFieldStyle(.plain).accessibilityLabel("Photo search")
                    .disabled(true)
                    .help("Visual search is coming next. Browse photos and camera metadata now.")
                if model.hasUnsavedChanges { Text("Edited").font(.caption).foregroundStyle(.secondary) }
                if model.selectedSavedView != nil && model.hasUnsavedChanges {
                    Button("Update View") { model.saveView(name:model.currentTitle,update:true) }
                }
                Button("Save View…") { viewName = model.selectedSavedView == nil ? "" : model.currentTitle; saving = true }
                    .disabled(model.sources.isEmpty || !model.isReady)
            }
            ViewThatFits(in:.horizontal) {
                HStack(spacing:12) { scopeAndFilters; Spacer(minLength:8); groupPicker; sortPicker }
                VStack(alignment:.leading,spacing:12) {
                    scopeAndFilters
                    HStack(spacing:12) { groupPicker; sortPicker }
                }
                VStack(alignment:.leading,spacing:12) { scopeAndFilters; groupPicker; sortPicker }
            }

        }
        .padding(Workbench.contentInset)
    }
    private var scopeAndFilters: some View {
        HStack(spacing:12) {
            Text(model.recipe.sourceIDs.isEmpty ? "All sources" : "Selected source")
                .font(.caption).foregroundStyle(.secondary)
            Button { filtersVisible.toggle() } label: { Label("Filters",systemImage:"line.3.horizontal.decrease") }
                .popover(isPresented:$filtersVisible) {
                    VStack(alignment:.leading,spacing:8) {
                        Text("Metadata filters").font(.headline)
                        Text("Metadata filters are coming next. You can group by camera, month, or folder now.")
                            .foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                    }.padding(16).frame(width:260)
                }
        }.fixedSize(horizontal:true,vertical:false)
    }
    private var groupPicker: some View {
        Picker("Group by",selection:$model.recipe.grouping) {
            ForEach(Grouping.allCases) { item in Text(item.title).tag(item).disabled(item == .subject) }
        }.frame(width:165).help("Group photos in this view.")
    }
    private var sortPicker: some View {
        Picker("Sort",selection:$model.recipe.sorting) {
            ForEach(PhotoSort.allCases) { item in Text(item.title).tag(item).disabled(item == .relevance) }
        }.frame(width:185)
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
                        LabeledContent("Photos",value:String(model.indexProgress.first { $0.sourceID == source.id }?.total ?? 0))
                        Text(source.lastKnownPath).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        Button("Reveal in Finder") { model.revealSource() }
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
                    LabeledContent("Sort",value:model.recipe.sorting.title)
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
        VStack(alignment:.leading,spacing:8) {
            if !model.sources.isEmpty {
                HStack(spacing:8) {
                    if model.indexing { ProgressView().controlSize(.small) }
                    Text(model.discovering ? "Discovering photos…" : "\(model.completedPreviews) of \(model.totalAssets) previews indexed\(model.paused ? " · Paused" : "")")
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    if model.failedPreviews > 0 { Text("\(model.failedPreviews) failed").font(.caption).foregroundStyle(.secondary) }
                    Spacer(minLength:0)
                    if model.indexing {
                        Button(model.pausing ? "Pausing…" : "Pause") { model.pauseIndexing() }.disabled(model.pausing)
                    } else {
                        Button(model.paused ? "Resume" : model.totalAssets == 0 ? "Start Indexing" : "Refresh Folders") { model.startIndexing() }
                    }
                }
                if model.pausing { Text("Pausing after the current photo…").font(.caption).foregroundStyle(.secondary) }
                if model.recipe.grouping == .subject { Text("Subject grouping is coming with tags; photos are currently ungrouped.").font(.caption).foregroundStyle(.secondary) }
                if model.recipe.sorting == .relevance { Text("Relevance sorting is coming with search; photos currently use newest first.").font(.caption).foregroundStyle(.secondary) }
                if model.totalAssets > 0 {
                    Text("\(model.metadataReady) metadata records ready · Visual search comes next")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let error = model.scopedProgress.compactMap({ $0.error }).first { Text(error).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
            }
        }.padding(.horizontal,20).padding(.vertical,model.sources.isEmpty ? 0 : 12)
    }
    private func photoDetails(_ asset: IndexedAsset) -> some View {
        VStack(alignment:.leading,spacing:12) {
            Text(asset.filename).font(.body.weight(.medium)).textSelection(.enabled)
            CachedPhoto(path:asset.thumbnailPath,revision:String(asset.asset.modifiedAt?.timeIntervalSince1970 ?? 0)).frame(height:128)
            Button("Open Preview") { model.previewPresented = true }
            Button("Reveal Original in Finder") { model.revealPhoto() }
            LabeledContent("Original",value:model.originalAvailable(asset) ? "Available" : asset.available ? "Drive disconnected" : "Missing")
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
    private var saveSheet: some View {
        VStack(alignment:.leading,spacing:20) {
            Text("Save this view").font(.title3.weight(.semibold))
            TextField("View name",text:$viewName).textFieldStyle(.roundedBorder)
            Text("\(model.recipe.sourceIDs.isEmpty ? "All sources" : "Selected sources") · Group by \(model.recipe.grouping.title.lowercased()) · \(model.recipe.sorting.title)")
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
