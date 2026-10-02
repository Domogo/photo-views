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
            let columns = max(1,Int((geometry.size.width-24+8)/208))
            let columnWidth = max(1,(geometry.size.width-24-CGFloat(columns-1)*8)/CGFloat(columns))
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:12) {
                        ForEach(groups) { group in
                            if !group.title.isEmpty {
                                HStack { Text(group.title).font(.headline).lineLimit(1); Text("\(group.assets.count) loaded").font(.caption).foregroundStyle(.secondary) }
                            }
                            let layout = masonry(group.assets,columns:columns,width:columnWidth)
                            HStack(alignment:.top,spacing:8) {
                                ForEach(0..<columns,id:\.self) { column in
                                    LazyVStack(spacing:8) {
                                        ForEach(layout[column]) { asset in
                                            photoCell(asset,height:columnWidth/aspectRatio(asset))
                                        }
                                    }.frame(width:columnWidth)
                                }
                            }
                        }
                        if model.assets.count < model.resultCount {
                            Button("Load More Photos") { model.loadMore() }.onAppear { model.loadMore() }
                        }
                    }.padding(12)
                }
                .coordinateSpace(name:"photoScroll")
                .overlay { if focused { Rectangle().strokeBorder(Color.accentColor.opacity(0.6),lineWidth:1).allowsHitTesting(false) } }
                .onPreferenceChange(VisiblePhotos.self) { positions in
                    visibleAnchor = positions.filter { $0.value > 0 }.min { a,b in a.value == b.value ? a.key.uuidString < b.key.uuidString : a.value < b.value }?.key
                }
                .onChange(of:model.recipe.grouping) { _,_ in
                    if let id = model.selectedGalleryID ?? visibleAnchor, model.assets.contains(where:{ $0.id == id }) { scroll.scrollTo(id,anchor:.center) }
                }
                .focusable().focusEffectDisabled().focused($focused)
                .onKeyPress(.space) { guard model.selectedAsset != nil else { return .ignored }; model.previewPresented = true; return .handled }
                .onKeyPress(.leftArrow) { move(dx:-1,dy:0,columns:columns,width:columnWidth,scroll:scroll); return .handled }
                .onKeyPress(.rightArrow) { move(dx:1,dy:0,columns:columns,width:columnWidth,scroll:scroll); return .handled }
                .onKeyPress(.upArrow) { move(dx:0,dy:-1,columns:columns,width:columnWidth,scroll:scroll); return .handled }
                .onKeyPress(.downArrow) { move(dx:0,dy:1,columns:columns,width:columnWidth,scroll:scroll); return .handled }
            }
        }
    }
    private func aspectRatio(_ asset: IndexedAsset) -> CGFloat {
        guard let w = asset.metadata?.width, let h = asset.metadata?.height, w > 0, h > 0 else { return 1 }
        let rotated = [5,6,7,8].contains(asset.metadata?.orientation ?? 1)
        return rotated ? CGFloat(h)/CGFloat(w) : CGFloat(w)/CGFloat(h)
    }
    private func masonry(_ assets: [IndexedAsset], columns: Int, width: CGFloat) -> [[IndexedAsset]] {
        var result = Array(repeating:[IndexedAsset](),count:columns), heights = Array(repeating:CGFloat(0),count:columns)
        for asset in assets {
            let column = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            result[column].append(asset); heights[column] += width/aspectRatio(asset)+8
        }
        return result
    }
    private func photoCell(_ asset: IndexedAsset, height: CGFloat) -> some View {
        Button { model.selectAsset(asset.id); focused = true } label: {
            CachedPhoto(path:asset.thumbnailPath,revision:String(asset.asset.modifiedAt?.timeIntervalSince1970 ?? 0))
                .frame(maxWidth:.infinity).frame(height:height)
                .background(Color(nsColor:.controlBackgroundColor))
                .overlay { if model.isGallerySelection(asset) { Rectangle().strokeBorder(Color.accentColor,lineWidth:2) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).id(asset.id)
        .background(GeometryReader { frame in Color.clear.preference(key:VisiblePhotos.self,value:[asset.id:frame.frame(in:.named("photoScroll")).maxY]) })
        .accessibilityLabel("\(asset.filename), \(asset.previewState == .failed ? "preview failed" : model.originalAvailable(asset) ? "original available" : "original offline")")
        .contextMenu {
            Button("Preview") { model.selectAsset(asset.id); model.previewPresented = true }
            Button("Find Similar") { model.selectAsset(asset.id); model.findSimilar() }
            Button("Reveal Original in Finder") { model.selectAsset(asset.id); model.revealPhoto() }
        }
        .simultaneousGesture(TapGesture(count:2).onEnded { model.selectAsset(asset.id); model.previewPresented = true })
    }
    private func move(dx: Int, dy: Int, columns: Int, width: CGFloat, scroll: ScrollViewProxy) {
        var positions: [(IndexedAsset,CGFloat,CGFloat)] = [], groupY: CGFloat = 0
        for group in groups {
            let layout = masonry(group.assets,columns:columns,width:width)
            var heights = Array(repeating:CGFloat(0),count:columns)
            for column in 0..<columns {
                for asset in layout[column] {
                    let height = width/aspectRatio(asset)
                    positions.append((asset,CGFloat(column)*(width+8)+width/2,groupY+heights[column]+height/2))
                    heights[column] += height+8
                }
            }
            groupY += (heights.max() ?? 0)+40
        }
        guard !positions.isEmpty else { return }
        guard let current = positions.first(where:{ model.isGallerySelection($0.0) }) else {
            if let first = groups.first?.assets.first { model.selectAsset(first.id); scroll.scrollTo(first.id,anchor:.center) }; return
        }
        let candidates = positions.filter { candidate in
            if dx != 0 { return (candidate.1-current.1)*CGFloat(dx) > 1 }
            return abs(candidate.1-current.1)<1 && (candidate.2-current.2)*CGFloat(dy)>1
        }
        let next = candidates.min { a,b in
            func distance(_ p: (IndexedAsset,CGFloat,CGFloat)) -> CGFloat { abs(p.1-current.1)+abs(p.2-current.2) }
            return distance(a)<distance(b)
        }
        if let next { model.selectAsset(next.0.id); scroll.scrollTo(next.0.id,anchor:.center) }
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
