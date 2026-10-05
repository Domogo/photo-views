import AppKit
import SwiftUI
import ImageIO
import PhotoViewsCore

private let galleryItemID = NSUserInterfaceItemIdentifier("Photo")

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
        view.effectiveAppearance.performAsCurrentDrawingAppearance { view.layer?.borderColor = StillBrand.accent.cgColor }
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
private final class MasonryCollectionLayout: NSCollectionViewLayout {
    var groups: [PhotoResultGroup] = []
    var targetWidth: Double = 208
    private(set) var items: [IndexPath:NSCollectionViewLayoutAttributes] = [:]
    private var size = NSSize.zero
    override var collectionViewContentSize: NSSize { size }
    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool { abs(newBounds.width-size.width)>0.5 }
    override func prepare() {
        guard let collectionView else { return }
        let width = collectionView.enclosingScrollView?.contentView.bounds.width ?? collectionView.bounds.width
        items.removeAll(keepingCapacity:true)
        let assets = groups.flatMap(\.assets)
        let aspects = assets.map { asset -> Double in
            guard let w = asset.metadata?.width, let h = asset.metadata?.height, w > 0, h > 0 else { return 1 }
            return [5,6,7,8].contains(asset.metadata?.orientation ?? 1) ? Double(h)/Double(w) : Double(w)/Double(h)
        }
        let result = GalleryGeometry.frames(aspects:aspects,width:width,y:12,clusters:assets.map(\.nearDuplicateGroup),targetWidth:targetWidth)
        var offset = 0
        for (section,group) in groups.enumerated() {
            for item in group.assets.indices {
                let path = IndexPath(item:item,section:section), attr = NSCollectionViewLayoutAttributes(forItemWith:path)
                attr.frame = result.frames[offset]; items[path] = attr; offset += 1
            }
        }
        size = NSSize(width:width,height:max(result.height+12,collectionView.enclosingScrollView?.contentView.bounds.height ?? 1))
    }
    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        Array(items.values.filter { $0.frame.intersects(rect) })
    }
    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? { items[indexPath] }
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
        if selectionIndexPaths != [path] { selectionIndexPaths = [path]; delegate?.collectionView?(self,didSelectItemsAt:[path]) }; scrollToItems(at:[path],scrollPosition:.nearestVerticalEdge)
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
        collection.backgroundColors = [StillBrand.canvas]; collection.collectionViewLayout = context.coordinator.layout
        collection.register(GalleryCell.self,forItemWithIdentifier:galleryItemID)
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
        private var previousQuery: ViewRecipe?
        private var resetScrollPending = false
        private var loadingCount = -1
        private var viewportWidth: CGFloat = 0
        init(model: WorkspaceModel) { self.model = model }
        fileprivate func update(_ model: WorkspaceModel) {
            self.model = model
            var query = model.recipe
            query.grouping = .none; query.sorting = .captureNewest
            if let previousQuery, previousQuery != query { resetScrollPending = true }
            previousQuery = query
            if layout.targetWidth != model.gridTargetWidth {
                let visible = collection?.visibleItems().compactMap { collection?.indexPath(for:$0) }.min { (layout.items[$0]?.frame.minY ?? 0) < (layout.items[$1]?.frame.minY ?? 0) }
                layout.targetWidth = model.gridTargetWidth
                layout.invalidateLayout(); collection?.layoutSubtreeIfNeeded()
                if let visible { collection?.scrollToItems(at:[visible],scrollPosition:.top) }
            }
            let groups = ResultGrouping.groups(model.assets,by:model.usesVisualVectors && model.recipe.grouping == .folder ? .none : model.recipe.grouping,sources:model.sources,ranked:model.isRankedSearch,sorting:model.recipe.sorting)
            let next = groups.map { $0.id+":"+$0.assets.map { $0.id.uuidString+String($0.asset.modifiedAt?.timeIntervalSince1970 ?? 0)+($0.thumbnailPath ?? "")+($0.nearDuplicateGroup ?? "") }.joined(separator:"|") }.joined(separator:";")
            if signature != next {
                let oldSelected = model.selectedAssetID
                let oldVisible = collection?.visibleItems().compactMap { collection?.indexPath(for:$0) }.sorted { a,b in (layout.items[a]?.frame.minY ?? 0)<(layout.items[b]?.frame.minY ?? 0) }.first
                let anchor = oldVisible.flatMap { path in layout.groups.indices.contains(path.section) && layout.groups[path.section].assets.indices.contains(path.item) ? layout.groups[path.section].assets[path.item].id : nil }
                let changedGrouping = layout.groups.map(\.id) != groups.map(\.id)
                layout.groups = groups; signature = next; loadingCount = -1
                collection?.reloadData(); layout.invalidateLayout(); collection?.layoutSubtreeIfNeeded()
                if changedGrouping && !resetScrollPending, let id = oldSelected ?? anchor, let path = path(for:id) { collection?.scrollToItems(at:[path],scrollPosition:.top) }
            }
            if resetScrollPending && !model.searching, let scroll = collection?.enclosingScrollView {
                scroll.contentView.scroll(to:.zero)
                scroll.reflectScrolledClipView(scroll.contentView)
                resetScrollPending = false
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
        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt paths: Set<IndexPath>) {
            if let path = paths.first { model.selectAsset(layout.groups[path.section].assets[path.item].id) }
        }
        fileprivate func menu(_ path: IndexPath) -> NSMenu {
            let menu = NSMenu(); menu.autoenablesItems = false
            for (title,action) in [("Preview",#selector(openPreview)),("Find Similar",#selector(findSimilar)),("Reveal Original in Finder",#selector(reveal))] {
                let item = NSMenuItem(title:title,action:action,keyEquivalent:""); item.target = self; menu.addItem(item)
            }
            if model.recipe.personID != nil {
                let item = NSMenuItem(title:"Not This Person",action:#selector(removePersonMatch),keyEquivalent:"")
                item.target = self; menu.addItem(item)
            }
            let editors = installedPhotoEditors()
            if !editors.isEmpty { menu.addItem(.separator()) }
            for (name,url) in editors {
                let item = NSMenuItem(title:"Open in " + name,action:#selector(openEditor(_:)),keyEquivalent:"")
                item.target = self; item.representedObject = url
                item.isEnabled = model.selectedAsset.map { model.originalAvailable($0) } ?? false
                menu.addItem(item)
            }
            return menu
        }
        private func installedPhotoEditors() -> [(String,URL)] {
            var found: [String:URL] = [:]
            let roots = [URL(fileURLWithPath:"/Applications"),FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
            for root in roots {
                guard let entries = FileManager.default.enumerator(at:root,includingPropertiesForKeys:nil,options:[.skipsHiddenFiles,.skipsPackageDescendants]) else { continue }
                for case let url as URL in entries {
                    if entries.level > 3 { entries.skipDescendants(); continue }
                    guard url.pathExtension == "app", let bundle = Bundle(url:url) else { continue }
                    let name = (bundle.object(forInfoDictionaryKey:"CFBundleDisplayName") as? String ?? bundle.object(forInfoDictionaryKey:"CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent).lowercased()
                    if name == "photomator" { found["Photomator"] = url }
                    if name.contains("lightroom") {
                        let label = name.contains("classic") ? "Lightroom Classic" : "Lightroom"
                        found[label] = url
                    }
                }
            }
            return found.sorted { $0.key < $1.key }.map { ($0.key,$0.value) }
        }
        @objc private func removePersonMatch() { if let asset = model.selectedAsset { model.removeFromPerson(asset) } }
        @objc private func openEditor(_ sender: NSMenuItem) {
            guard let application = sender.representedObject as? URL else { return }
            model.openOriginal(in:application)
        }
        @objc private func openPreview() { model.previewPresented = true }
        @objc private func findSimilar() { model.findSimilar() }
        @objc private func reveal() { model.revealPhoto() }
    }
}
