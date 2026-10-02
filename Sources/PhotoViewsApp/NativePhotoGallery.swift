import AppKit
import SwiftUI
import ImageIO
import PhotoViewsCore

private let galleryItemID = NSUserInterfaceItemIdentifier("Photo")
private let galleryHeaderID = NSUserInterfaceItemIdentifier("Group")
private let headerKind = "PhotoGroupHeader"

private enum GalleryThumbnails {
    static let cache: NSCache<NSString,NSImage> = {
        let value = NSCache<NSString,NSImage>(); value.totalCostLimit = 64*1024*1024; value.countLimit = 256; return value
    }()
    static let queue: OperationQueue = {
        let value = OperationQueue(); value.name = "PhotoViews.thumbnails"; value.qualityOfService = .utility; value.maxConcurrentOperationCount = 4; return value
    }()
    static func decode(_ path: String) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:512,kCGImageSourceShouldCacheImmediately:true] as CFDictionary) else { return nil }
        return NSImage(cgImage:image,size:NSSize(width:image.width,height:image.height))
    }
}
private final class GalleryCell: NSCollectionViewItem {
    private var operation: Operation?
    private var imageKey = ""
    override func loadView() {
        view = NSView(); view.wantsLayer = true
        let image = NSImageView(); image.imageScaling = .scaleProportionallyUpOrDown; image.imageAlignment = .alignCenter
        image.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(image); imageView = image
        NSLayoutConstraint.activate([image.leadingAnchor.constraint(equalTo:view.leadingAnchor),image.trailingAnchor.constraint(equalTo:view.trailingAnchor),image.topAnchor.constraint(equalTo:view.topAnchor),image.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
        view.setAccessibilityElement(true); view.setAccessibilityRole(.button); image.setAccessibilityElement(false)
    }
    override var isSelected: Bool { didSet { updateSelection() } }
    private func updateSelection() {
        view.layer?.borderWidth = isSelected ? 2 : 0
        view.layer?.borderColor = NSColor.controlAccentColor.cgColor
    }
    override func prepareForReuse() { super.prepareForReuse(); operation?.cancel(); operation = nil; imageKey = ""; imageView?.image = nil }
    func configure(_ asset: IndexedAsset, available: Bool) {
        view.setAccessibilityLabel(asset.filename+", "+(available ? "original available" : "original offline"))
        updateSelection()
        let key = (asset.thumbnailPath ?? "")+String(asset.asset.modifiedAt?.timeIntervalSince1970 ?? 0)
        guard key != imageKey else { return }
        operation?.cancel(); imageKey = key; imageView?.image = NSImage(systemSymbolName:"photo",accessibilityDescription:"Preview unavailable")
        guard let path = asset.thumbnailPath else { return }
        if let image = GalleryThumbnails.cache.object(forKey:key as NSString) { imageView?.image = image; return }
        let work = BlockOperation()
        work.addExecutionBlock { [weak self, weak work] in
            guard work?.isCancelled == false, let image = GalleryThumbnails.decode(path), work?.isCancelled == false else { return }
            GalleryThumbnails.cache.setObject(image,forKey:key as NSString,cost:Int(image.size.width*image.size.height)*4)
            DispatchQueue.main.async { [weak self] in guard let self, self.imageKey == key else { return }; self.imageView?.image = image }
        }
        operation = work; GalleryThumbnails.queue.addOperation(work)
    }
}
private final class GalleryHeader: NSView {
    let label = NSTextField(labelWithString:"")
    override init(frame: NSRect) {
        super.init(frame:frame); label.font = .systemFont(ofSize:NSFont.systemFontSize,weight:.semibold)
        label.lineBreakMode = .byTruncatingMiddle; label.translatesAutoresizingMaskIntoConstraints = false; addSubview(label)
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo:leadingAnchor),label.trailingAnchor.constraint(equalTo:trailingAnchor),label.centerYAnchor.constraint(equalTo:centerYAnchor)])
    }
    required init?(coder: NSCoder) { fatalError() }
}
private final class MasonryCollectionLayout: NSCollectionViewLayout {
    var groups: [PhotoResultGroup] = []
    private(set) var items: [IndexPath:NSCollectionViewLayoutAttributes] = [:]
    private var headers: [IndexPath:NSCollectionViewLayoutAttributes] = [:]
    private var size = NSSize.zero
    override var collectionViewContentSize: NSSize { size }
    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool { abs(newBounds.width-size.width)>0.5 }
    override func prepare() {
        guard let collectionView else { return }
        let width = collectionView.enclosingScrollView?.contentView.bounds.width ?? collectionView.bounds.width
        items.removeAll(keepingCapacity:true); headers.removeAll(keepingCapacity:true)
        var y = 12.0
        for (section,group) in groups.enumerated() {
            if !group.title.isEmpty {
                let path = IndexPath(item:0,section:section)
                let attr = NSCollectionViewLayoutAttributes(forSupplementaryViewOfKind:headerKind,with:path)
                attr.frame = CGRect(x:12,y:y,width:max(1,width-24),height:24); headers[path] = attr; y += 32
            }
            let aspects = group.assets.map { asset -> Double in
                guard let w = asset.metadata?.width, let h = asset.metadata?.height, w > 0, h > 0 else { return 1 }
                return [5,6,7,8].contains(asset.metadata?.orientation ?? 1) ? Double(h)/Double(w) : Double(w)/Double(h)
            }
            let result = GalleryGeometry.frames(aspects:aspects,width:width,y:y)
            for (item,frame) in result.frames.enumerated() {
                let path = IndexPath(item:item,section:section), attr = NSCollectionViewLayoutAttributes(forItemWith:path)
                attr.frame = frame; items[path] = attr
            }
            y = result.height+20
        }
        size = NSSize(width:width,height:max(y,collectionView.enclosingScrollView?.contentView.bounds.height ?? 1))
    }
    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        Array(items.values.filter { $0.frame.intersects(rect) })+Array(headers.values.filter { $0.frame.intersects(rect) })
    }
    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? { items[indexPath] }
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? { headers[indexPath] }
}
private final class GalleryCollection: NSCollectionView {
    var preview: (() -> Void)?
    var actionMenu: ((IndexPath) -> NSMenu)?
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { preview?(); return }
        guard let layout = collectionViewLayout as? MasonryCollectionLayout, [123,124,125,126].contains(event.keyCode) else { super.keyDown(with:event); return }
        guard let current = selectionIndexPaths.first, let frame = layout.items[current]?.frame else {
            if let first = layout.items.keys.sorted(by:{ $0.section == $1.section ? $0.item<$1.item : $0.section<$1.section }).first { choose(first) }; return
        }
        let horizontal = event.keyCode == 123 || event.keyCode == 124, sign: CGFloat = event.keyCode == 123 || event.keyCode == 126 ? -1 : 1
        let candidates = layout.items.filter { _,attr in
            horizontal ? (attr.frame.midX-frame.midX)*sign > 1 : abs(attr.frame.midX-frame.midX)<1 && (attr.frame.midY-frame.midY)*sign > 1
        }
        if let next = candidates.min(by:{ a,b in
            abs(a.value.frame.midX-frame.midX)+abs(a.value.frame.midY-frame.midY) < abs(b.value.frame.midX-frame.midX)+abs(b.value.frame.midY-frame.midY)
        })?.key { choose(next) }
    }
    private func choose(_ path: IndexPath) {
        selectionIndexPaths = [path]; delegate?.collectionView?(self,didSelectItemsAt:[path]); scrollToItems(at:[path],scrollPosition:.nearestVerticalEdge)
    }
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with:event)
        if event.clickCount == 2 { preview?() }
    }
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let path = indexPathForItem(at:convert(event.locationInWindow,from:nil)) else { return nil }
        choose(path); return actionMenu?(path)
    }
}

struct NativePhotoGallery: NSViewRepresentable {
    @ObservedObject var model: WorkspaceModel
    func makeCoordinator() -> Coordinator { Coordinator(model:model) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
        let collection = GalleryCollection(); collection.isSelectable = true; collection.allowsMultipleSelection = false
        collection.backgroundColors = [.textBackgroundColor]; collection.collectionViewLayout = context.coordinator.layout
        collection.register(GalleryCell.self,forItemWithIdentifier:galleryItemID)
        collection.register(GalleryHeader.self,forSupplementaryViewOfKind:headerKind,withIdentifier:galleryHeaderID)
        collection.dataSource = context.coordinator; collection.delegate = context.coordinator
        collection.preview = { [weak model] in if model?.selectedAsset != nil { model?.previewPresented = true } }
        collection.actionMenu = { [weak coordinator = context.coordinator] path in coordinator?.menu(path) ?? NSMenu() }
        scroll.documentView = collection; context.coordinator.collection = collection
        scroll.contentView.postsBoundsChangedNotifications = true
        context.coordinator.observer = NotificationCenter.default.addObserver(forName:NSView.boundsDidChangeNotification,object:scroll.contentView,queue:.main) { [weak coordinator = context.coordinator] _ in MainActor.assumeIsolated { coordinator?.didScroll() } }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) { context.coordinator.update(model) }
    static func dismantleNSView(_ view: NSScrollView, coordinator: Coordinator) { if let observer = coordinator.observer { NotificationCenter.default.removeObserver(observer) } }
    @MainActor final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
        var model: WorkspaceModel
        fileprivate let layout = MasonryCollectionLayout()
        fileprivate weak var collection: GalleryCollection?
        var observer: NSObjectProtocol?
        private var signature = ""
        private var loadingCount = -1
        private var viewportWidth: CGFloat = 0
        init(model: WorkspaceModel) { self.model = model }
        fileprivate func update(_ model: WorkspaceModel) {
            self.model = model
            let groups = ResultGrouping.groups(model.assets,by:model.recipe.grouping,sources:model.sources,ranked:model.isRankedSearch,sorting:model.recipe.sorting)
            let next = groups.map { $0.id+":"+$0.assets.map { $0.id.uuidString+String($0.asset.modifiedAt?.timeIntervalSince1970 ?? 0)+($0.thumbnailPath ?? "") }.joined(separator:"|") }.joined(separator:";")
            if signature != next {
                let oldSelected = model.selectedAssetID
                let oldVisible = collection?.visibleItems().compactMap { collection?.indexPath(for:$0) }.sorted { a,b in (layout.items[a]?.frame.minY ?? 0)<(layout.items[b]?.frame.minY ?? 0) }.first
                let anchor = oldVisible.flatMap { path in layout.groups.indices.contains(path.section) && layout.groups[path.section].assets.indices.contains(path.item) ? layout.groups[path.section].assets[path.item].id : nil }
                let changedGrouping = layout.groups.map(\.id) != groups.map(\.id)
                layout.groups = groups; signature = next; loadingCount = -1
                collection?.reloadData(); layout.invalidateLayout(); collection?.layoutSubtreeIfNeeded()
                if changedGrouping, let id = oldSelected ?? anchor, let path = path(for:id) { collection?.scrollToItems(at:[path],scrollPosition:.top) }
            }
            if let selected = model.selectedGalleryID, let path = path(for:selected) { collection?.selectionIndexPaths = [path] }
            else { collection?.selectionIndexPaths = [] }
        }
        fileprivate func didScroll() {
            guard let scroll = collection?.enclosingScrollView else { return }
            let width = scroll.contentView.bounds.width
            if viewportWidth > 0 && abs(width-viewportWidth)>0.5 {
                DispatchQueue.main.async { [weak self] in
                    guard let self, let id = self.model.selectedGalleryID, let path = self.path(for:id) else { return }
                    self.collection?.scrollToItems(at:[path],scrollPosition:.nearestVerticalEdge)
                }
            }
            viewportWidth = width
            if scroll.contentView.bounds.maxY >= layout.collectionViewContentSize.height-600, model.assets.count < model.resultCount, loadingCount != model.assets.count, !model.searching {
                loadingCount = model.assets.count; model.loadMore()
            }
        }
        private func path(for id: UUID) -> IndexPath? {
            for (section,group) in layout.groups.enumerated() { if let item = group.assets.firstIndex(where:{ $0.id == id || (model.recipe.collapsePairs != false && $0.pairedAssetIDs?.contains(id) == true) }) { return IndexPath(item:item,section:section) } }; return nil
        }
        func numberOfSections(in collectionView: NSCollectionView) -> Int { layout.groups.count }
        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { layout.groups[section].assets.count }
        func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt path: IndexPath) -> NSCollectionViewItem {
            let cell = collectionView.makeItem(withIdentifier:galleryItemID,for:path) as! GalleryCell
            let asset = layout.groups[path.section].assets[path.item]
            cell.configure(asset,available:asset.available && model.availability[asset.asset.sourceID] == "Connected"); return cell
        }
        func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at path: IndexPath) -> NSView {
            let header = collectionView.makeSupplementaryView(ofKind:kind,withIdentifier:galleryHeaderID,for:path) as! GalleryHeader
            header.label.stringValue = layout.groups[path.section].title; return header
        }
        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt paths: Set<IndexPath>) {
            if let path = paths.first { model.selectAsset(layout.groups[path.section].assets[path.item].id) }
        }
        fileprivate func menu(_ path: IndexPath) -> NSMenu {
            let menu = NSMenu()
            for (title,action) in [("Preview",#selector(openPreview)),("Find Similar",#selector(findSimilar)),("Reveal Original in Finder",#selector(reveal))] {
                let item = NSMenuItem(title:title,action:action,keyEquivalent:""); item.target = self; menu.addItem(item)
            }; return menu
        }
        @objc private func openPreview() { model.previewPresented = true }
        @objc private func findSimilar() { model.findSimilar() }
        @objc private func reveal() { model.revealPhoto() }
    }
}
