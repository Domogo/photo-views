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
    var fill = false
    @State private var image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage:image).resizable().aspectRatio(contentMode:fill ? .fill : .fit) }
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
    var body: some View { NativePhotoGallery(model:model) }
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
