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
private final class GalleryCard: NSView {
    var hoverChanged: ((Bool) -> Void)?
    private var tracking: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let next = NSTrackingArea(rect:.zero,options:[.mouseEnteredAndExited,.activeInKeyWindow,.inVisibleRect],owner:self,userInfo:nil)
        addTrackingArea(next); tracking = next
    }
    override func mouseEntered(with event: NSEvent) { hoverChanged?(true) }
    override func mouseExited(with event: NSEvent) { hoverChanged?(false) }
    override func resetCursorRects() { addCursorRect(bounds,cursor:.pointingHand) }
}
private final class GalleryCell: NSCollectionViewItem {
    private var operation: Operation?
    private var imageKey = ""
    private var hovered = false
    private var actionsVisible = false
    private var actions = NSStackView()
    private var favoriteButton: NSButton?
    private var actionKey = ""
    private var favoriteAction: (() -> Void)?
    private var editorActions: [() -> Void] = []
    override func loadView() {
        let card = GalleryCard(); card.wantsLayer = true; view = card
        card.hoverChanged = { [weak self] hovered in self?.hovered = hovered; self?.updateSelection() }
        let image = NSImageView(); image.imageScaling = .scaleProportionallyUpOrDown; image.imageAlignment = .alignCenter
        image.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(image); imageView = image
        NSLayoutConstraint.activate([image.leadingAnchor.constraint(equalTo:view.leadingAnchor),image.trailingAnchor.constraint(equalTo:view.trailingAnchor),image.topAnchor.constraint(equalTo:view.topAnchor),image.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
        actions.orientation = .horizontal; actions.spacing = 4; actions.edgeInsets = NSEdgeInsets(top:4,left:4,bottom:4,right:4)
        actions.translatesAutoresizingMaskIntoConstraints = false; actions.wantsLayer = true; actions.layer?.cornerRadius = 5
        view.addSubview(actions)
        NSLayoutConstraint.activate([actions.topAnchor.constraint(equalTo:view.topAnchor,constant:8),actions.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-8)])
        view.setAccessibilityElement(true); view.setAccessibilityRole(.button); image.setAccessibilityElement(false)
        actions.isHidden = true
    }
    override var isSelected: Bool { didSet { updateSelection() } }
    private func updateSelection() {
        view.layer?.borderWidth = isSelected ? 2 : hovered ? 1 : 0
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            view.layer?.borderColor = (isSelected ? StillBrand.accent : StillBrand.secondary).cgColor
            actions.layer?.backgroundColor = NSColor(srgbRed:0.08,green:0.09,blue:0.085,alpha:0.94).cgColor
        }
        let visible = hovered || isSelected
        guard visible != actionsVisible else { return }
        actionsVisible = visible; actions.isHidden = !visible
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.12
            actions.animator().alphaValue = visible ? 1 : 0
        }
    }
    private func button(_ symbol: String, label: String, action: Selector) -> NSButton {
        let button = NSButton(image:NSImage(systemSymbolName:symbol,accessibilityDescription:label)!,target:self,action:action)
        button.bezelStyle = .inline; button.isBordered = false; button.imagePosition = .imageOnly
        button.contentTintColor = NSColor(white:0.96,alpha:1); button.toolTip = label; button.setAccessibilityLabel(label)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([button.widthAnchor.constraint(equalToConstant:26),button.heightAnchor.constraint(equalToConstant:26)])
        return button
    }
    @objc private func favoriteClicked() { favoriteAction?() }
    private var editors: [PhotoEditor] = []
    @objc private func editorClicked(_ sender: NSButton) {
        guard !editorActions.isEmpty else { return }
        if editorActions.count == 1 { editorActions[0](); return }
        let menu = NSMenu(); menu.autoenablesItems = false
        for (index,editor) in editors.enumerated() {
            let item = NSMenuItem(title:"Open in " + editor.name,action:#selector(editorMenuClicked(_:)),keyEquivalent:"")
            item.tag = index; item.target = self; menu.addItem(item)
        }
        menu.popUp(positioning:nil,at:NSPoint(x:0,y:sender.bounds.maxY),in:sender)
    }
    @objc private func editorMenuClicked(_ sender: NSMenuItem) { if editorActions.indices.contains(sender.tag) { editorActions[sender.tag]() } }
    override func prepareForReuse() {
        super.prepareForReuse(); operation?.cancel(); operation = nil; imageKey = ""; imageView?.image = nil
        hovered = false; favoriteAction = nil; editorActions = []; actionKey = ""; actionsVisible = false; actions.isHidden = true; actions.alphaValue = 0
    }
    func configure(_ asset: IndexedAsset, available: Bool, editors: [PhotoEditor], favorite: @escaping () -> Void, openEditor: @escaping (PhotoEditor) -> Void) {
        view.setAccessibilityLabel(asset.filename+", "+(available ? "original available" : "original offline"))
        self.editors = editors
        favoriteAction = favorite; editorActions = editors.map { editor in { openEditor(editor) } }
        let nextActions = editors.map(\.id).joined(separator:"|")
        if actionKey != nextActions || actions.arrangedSubviews.isEmpty {
            for child in actions.arrangedSubviews { actions.removeArrangedSubview(child); child.removeFromSuperview() }
            let favorite = button("heart",label:"Favorite",action:#selector(favoriteClicked)); favoriteButton = favorite; actions.addArrangedSubview(favorite)
            if !editors.isEmpty {
                let label = editors.count == 1 ? "Open in " + editors[0].name : "Open in photo editor"
                let editor = button("arrow.up.forward.app",label:label,action:#selector(editorClicked(_:)))
                editor.tag = 0; actions.addArrangedSubview(editor)
            }
            actionKey = nextActions
        }
        let isFavorite = asset.favorite == true
        favoriteButton?.image = NSImage(systemSymbolName:isFavorite ? "heart.fill" : "heart",accessibilityDescription:isFavorite ? "Remove favorite" : "Favorite")
        favoriteButton?.toolTip = isFavorite ? "Remove favorite" : "Favorite"
        favoriteButton?.setAccessibilityLabel(isFavorite ? "Remove favorite" : "Favorite")
        for button in actions.arrangedSubviews.dropFirst(1).compactMap({ $0 as? NSButton }) { button.isEnabled = available }
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
        private var favorites: [UUID:Bool] = [:]
        private var previousQuery: ViewRecipe?
        private var resetScrollPending = false
        private var loadingCount = -1
        private var viewportWidth: CGFloat = 0
        init(model: WorkspaceModel) { self.model = model }
        fileprivate func update(_ model: WorkspaceModel) {
            self.model = model
            favorites = Dictionary(uniqueKeysWithValues:model.assets.map { ($0.id,$0.favorite == true) })
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
            if resetScrollPending && (!model.searching || model.cachedResultsVisible), let scroll = collection?.enclosingScrollView {
                scroll.contentView.scroll(to:.zero)
                scroll.reflectScrolledClipView(scroll.contentView)
                resetScrollPending = false
            }
            if let selected = model.selectedGalleryID, let path = path(for:selected) { collection?.selectionIndexPaths = [path] }
            else { collection?.selectionIndexPaths = [] }
            for item in collection?.visibleItems() ?? [] {
                if let path = collection?.indexPath(for:item), let cell = item as? GalleryCell { configure(cell,at:path) }
            }
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
            configure(cell,at:path); return cell
        }
        private func configure(_ cell: GalleryCell, at path: IndexPath) {
            guard layout.groups.indices.contains(path.section), layout.groups[path.section].assets.indices.contains(path.item) else { return }
            var asset = layout.groups[path.section].assets[path.item]
            asset.favorite = favorites[asset.id]
            cell.configure(asset,available:asset.available && model.availability[asset.asset.sourceID] == "Connected",editors:model.installedEditors,
                favorite:{ [weak model] in model?.toggleFavorite(asset.id) },
                openEditor:{ [weak model] editor in model?.openOriginal(asset,in:editor.url) })
        }
        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt paths: Set<IndexPath>) {
            if let path = paths.first { model.selectAsset(layout.groups[path.section].assets[path.item].id) }
        }
        fileprivate func menu(_ path: IndexPath) -> NSMenu {
            let menu = NSMenu(); menu.autoenablesItems = false
            for (title,action) in [("Preview",#selector(openPreview)),(model.selectedFavorite ? "Remove Favorite" : "Favorite",#selector(toggleFavorite)),("Find Similar",#selector(findSimilar)),("Reveal Original in Finder",#selector(reveal))] {
                let item = NSMenuItem(title:title,action:action,keyEquivalent:""); item.target = self; menu.addItem(item)
            }
            if model.recipe.personID != nil {
                let item = NSMenuItem(title:"Not This Person",action:#selector(removePersonMatch),keyEquivalent:"")
                item.target = self; menu.addItem(item)
            }
            let editors = model.installedEditors
            if !editors.isEmpty { menu.addItem(.separator()) }
            for editor in editors {
                let item = NSMenuItem(title:"Open in " + editor.name,action:#selector(openEditor(_:)),keyEquivalent:"")
                item.target = self; item.representedObject = editor.url
                item.isEnabled = model.selectedAsset.map { model.originalAvailable($0) } ?? false
                menu.addItem(item)
            }
            return menu
        }
        @objc private func toggleFavorite() { model.toggleFavorite() }
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
