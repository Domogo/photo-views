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
struct PhotoGrid: View {
    @ObservedObject var model: WorkspaceModel
    @FocusState private var focused: Bool
    private struct PhotoGroup: Identifiable { var id: String; var assets: [IndexedAsset] }
    private var groups: [PhotoGroup] {
        if model.recipe.grouping == .none || model.recipe.grouping == .subject { return [PhotoGroup(id:"",assets:model.assets)] }
        let grouped = Dictionary(grouping:model.assets) { asset -> String in
            switch model.recipe.grouping {
            case .folder:
                let source = model.sources.first { $0.id == asset.asset.sourceID }?.name ?? "Source"
                let folder = (asset.asset.relativePath as NSString).deletingLastPathComponent
                return folder.isEmpty ? source : source+" / "+folder
            case .camera: return asset.metadata?.camera ?? "Unknown camera"
            case .month:
                guard let date = asset.metadata?.captureDateText else { return "Unknown date" }
                return String(date.prefix(7)).replacingOccurrences(of:":",with:"-")
            default: return ""
            }
        }
        let keys = grouped.keys.sorted { a,b in
            if a.hasPrefix("Unknown") { return false }; if b.hasPrefix("Unknown") { return true }
            return model.recipe.grouping == .month && model.recipe.sorting != .captureOldest ? a > b : a.localizedStandardCompare(b) == .orderedAscending
        }
        return keys.map { PhotoGroup(id:$0,assets:grouped[$0]!) }
    }
    var body: some View {
        GeometryReader { geometry in
            let columns = max(1,Int((geometry.size.width-40+16)/176))
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:24) {
                        Text("\(model.assets.count) of \(model.browseableAssets) browseable photos loaded")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(groups) { group in
                            if !group.id.isEmpty {
                                HStack { Text(group.id).font(.headline).lineLimit(1); Text("\(group.assets.count) loaded").font(.caption).foregroundStyle(.secondary) }
                            }
                            LazyVGrid(columns:[GridItem(.adaptive(minimum:160),spacing:16)],spacing:20) {
                                ForEach(group.assets) { asset in
                                    Button {
                                        model.selectAsset(asset.id); focused = true
                                    } label: {
                                        VStack(alignment:.leading,spacing:6) {
                                            CachedPhoto(path:asset.thumbnailPath,revision:String(asset.asset.modifiedAt?.timeIntervalSince1970 ?? 0))
                                                .frame(maxWidth:.infinity).frame(height:128)
                                                .background(Color(nsColor:.controlBackgroundColor))
                                                .overlay { if model.selectedAssetID == asset.id { Rectangle().strokeBorder(Color.accentColor,lineWidth:2) } }
                                            Text(asset.filename).font(.caption).lineLimit(1).foregroundStyle(.primary)
                                            HStack(spacing:4) {
                                                Text(asset.metadata?.format ?? URL(fileURLWithPath:asset.asset.relativePath).pathExtension.uppercased())
                                                if !model.originalAvailable(asset) { Label(asset.available ? "Offline" : "Missing",systemImage:"externaldrive.badge.xmark") }
                                                else if asset.previewState == .failed { Label("Preview failed",systemImage:"exclamationmark.triangle") }
                                                else if asset.previewState != .complete { Text("Preparing…") }
                                                else if asset.thumbnailPath == nil { Text("Cache cleared") }
                                            }.font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                        }.contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .id(asset.id)
                                    .accessibilityLabel("\(asset.filename), \(asset.previewState == .failed ? "preview failed" : model.originalAvailable(asset) ? "original available" : "original offline")")
                                    .contextMenu {
                                        Button("Preview") { model.selectAsset(asset.id); model.previewPresented = true }
                                        Button("Reveal Original in Finder") { model.selectAsset(asset.id); model.revealPhoto() }
                                    }
                                    .simultaneousGesture(TapGesture(count:2).onEnded { model.selectAsset(asset.id); model.previewPresented = true })
                                }
                            }
                        }
                        if model.assets.count < model.browseableAssets {
                            Button("Load More Photos") { model.loadMore() }.onAppear { model.loadMore() }
                        }
                    }.padding(20)
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
