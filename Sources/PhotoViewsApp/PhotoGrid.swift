import SwiftUI
import AppKit
import PhotoViewsCore

@MainActor private enum ThumbnailMemory {
    static let cache: NSCache<NSString,NSImage> = {
        let cache = NSCache<NSString,NSImage>(); cache.totalCostLimit = 64*1024*1024; cache.countLimit = 256; return cache
    }()
}
struct CachedPhoto: View {
    let path: String?
    let revision: String
    @State private var image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage:image).resizable().scaledToFit() }
            else { Image(systemName:"photo").font(.title2).foregroundStyle(.secondary).frame(maxWidth:.infinity,maxHeight:.infinity) }
        }
        .task(id:(path ?? "")+revision) {
            image = nil
            guard let path else { return }
            let key = (path+revision) as NSString
            if let existing = ThumbnailMemory.cache.object(forKey:key) { image = existing; return }
            let loaded = await Task.detached(priority:.utility) { NSImage(contentsOfFile:path) }.value
            guard !Task.isCancelled else { return }
            if let loaded { ThumbnailMemory.cache.setObject(loaded,forKey:key,cost:Int(loaded.size.width*loaded.size.height)*4) }
            image = loaded
        }
    }
}
private struct VisiblePhotos: PreferenceKey {
    static var defaultValue: [UUID:CGFloat] = [:]
    static func reduce(value: inout [UUID:CGFloat], nextValue: () -> [UUID:CGFloat]) { value.merge(nextValue(),uniquingKeysWith:{ _,new in new }) }
}
struct PhotoGrid: View {
    @ObservedObject var model: WorkspaceModel
    @FocusState private var focused: Bool
    @State private var visibleAnchor: UUID?
    private var groups: [PhotoResultGroup] {
        ResultGrouping.groups(model.assets,by:model.recipe.grouping,sources:model.sources,ranked:model.isRankedSearch,sorting:model.recipe.sorting)
    }
    var body: some View {
        GeometryReader { geometry in
            let columns = max(1,Int((geometry.size.width-40+16)/176))
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:24) {
                        Text(model.isRankedSearch ? "\(model.assets.count) nearest results · Ranked by similarity" : "\(model.assets.count) of \(model.resultCount) \(model.recipe.collapsePairs == false ? "files" : "photos") shown")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(groups) { group in
                            if !group.title.isEmpty {
                                HStack { Text(group.title).font(.headline).lineLimit(1); Text("\(group.assets.count) loaded").font(.caption).foregroundStyle(.secondary) }
                            }
                            LazyVGrid(columns:[GridItem(.adaptive(minimum:160),spacing:16)],spacing:20) {
                                ForEach(group.assets) { asset in
                                    Button {
                                        model.selectAsset(asset.id); focused = true
                                    } label: {
                                        CachedPhoto(path:asset.thumbnailPath,revision:String(asset.asset.modifiedAt?.timeIntervalSince1970 ?? 0))
                                            .frame(maxWidth:.infinity).frame(height:128)
                                            .background(Color(nsColor:.controlBackgroundColor))
                                            .overlay { if model.selectedAssetID == asset.id { Rectangle().strokeBorder(Color.accentColor,lineWidth:2) } }
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .id(asset.id)
                                    .background(GeometryReader { frame in
                                        Color.clear.preference(key:VisiblePhotos.self,value:[asset.id:frame.frame(in:.named("photoScroll")).maxY])
                                    })
                                    .accessibilityLabel("\(asset.filename), \(asset.previewState == .failed ? "preview failed" : model.originalAvailable(asset) ? "original available" : "original offline")")
                                    .contextMenu {
                                        Button("Preview") { model.selectAsset(asset.id); model.previewPresented = true }
                                        Button("Find Similar") { model.selectAsset(asset.id); model.findSimilar() }
                                        Button("Reveal Original in Finder") { model.selectAsset(asset.id); model.revealPhoto() }
                                    }
                                    .simultaneousGesture(TapGesture(count:2).onEnded { model.selectAsset(asset.id); model.previewPresented = true })
                                }
                            }
                        }
                        if model.assets.count < model.resultCount {
                            Button("Load More Photos") { model.loadMore() }.onAppear { model.loadMore() }
                        }
                    }.padding(20)
                }
                .coordinateSpace(name:"photoScroll")
                .onPreferenceChange(VisiblePhotos.self) { positions in
                    visibleAnchor = positions.filter { $0.value > 0 }.min { a,b in a.value == b.value ? a.key.uuidString < b.key.uuidString : a.value < b.value }?.key
                }
                .onChange(of:model.recipe.grouping) { _,_ in
                    if let id = model.selectedAssetID ?? visibleAnchor, model.assets.contains(where:{ $0.id == id }) { scroll.scrollTo(id,anchor:.center) }
                }
                .focusable().focusEffectDisabled().focused($focused)
                .onKeyPress(.space) { guard model.selectedAsset != nil else { return .ignored }; model.previewPresented = true; return .handled }
                .onKeyPress(.leftArrow) { move(-1,scroll:scroll); return .handled }
                .onKeyPress(.rightArrow) { move(1,scroll:scroll); return .handled }
                .onKeyPress(.upArrow) { move(-columns,scroll:scroll); return .handled }
                .onKeyPress(.downArrow) { move(columns,scroll:scroll); return .handled }
            }
        }
    }
    private func move(_ offset: Int, scroll: ScrollViewProxy) {
        let ordered = groups.flatMap { $0.assets }
        guard !ordered.isEmpty else { return }
        let current = ordered.firstIndex { $0.id == model.selectedAssetID } ?? (offset > 0 ? -1 : ordered.count)
        let next = ordered[max(0,min(ordered.count-1,current+offset))]
        model.selectAsset(next.id); scroll.scrollTo(next.id,anchor:.center)
    }
}
struct PhotoPreview: View {
    @ObservedObject var model: WorkspaceModel
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Text(model.selectedAsset?.filename ?? "Photo preview").font(.headline).lineLimit(1)
                Spacer()
                Button("Close") { model.previewPresented = false }.keyboardShortcut(.cancelAction)
            }
            if let asset = model.selectedAsset {
                if asset.analysisPath != nil || asset.thumbnailPath != nil {
                    CachedPhoto(path:asset.analysisPath ?? asset.thumbnailPath,revision:String(asset.asset.modifiedAt?.timeIntervalSince1970 ?? 0))
                        .frame(maxWidth:.infinity,maxHeight:.infinity)
                } else {
                    VStack(spacing:12) {
                        Image(systemName:"photo").font(.largeTitle).foregroundStyle(.secondary)
                        Text(asset.previewState == .failed ? "Preview unavailable" : "Preview cache cleared").font(.headline)
                        Text(model.originalAvailable(asset) ? "Rebuild a local preview from the original." : "Reconnect the source drive or restore access to rebuild this preview.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button(asset.previewState == .failed ? "Retry Preview" : "Rebuild Preview") { model.retrySelectedPreview() }
                            .disabled(model.indexing || !model.originalAvailable(asset))
                    }.frame(maxWidth:.infinity,maxHeight:.infinity)
                }
                if let error = asset.error { Text(error).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
                HStack {
                    Text(asset.analysisPath != nil ? "Cached preview · sRGB" : asset.thumbnailPath != nil ? "Cached thumbnail" : "No cached preview").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Reveal Original in Finder") { model.revealPhoto() }
                }
            }
        }.padding(20).frame(width:720,height:540)
    }
}
