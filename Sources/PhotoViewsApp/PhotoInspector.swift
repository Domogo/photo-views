import SwiftUI
import PhotoViewsCore

struct PhotoInspector: View {
    @ObservedObject var model: WorkspaceModel
    let asset: IndexedAsset
    @State private var metadataExpanded = false
    @State private var pairExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text(asset.filename).font(.subheadline.weight(.medium)).lineLimit(2).textSelection(.enabled)
            HStack(spacing:8) {
                Button { model.toggleFavorite() } label: { Label(model.selectedFavorite ? "Favorited" : "Favorite",systemImage:model.selectedFavorite ? "heart.fill" : "heart") }
                    .accessibilityValue(model.selectedFavorite ? "Favorited" : "Not favorited")
                Button { model.previewPresented = true } label: { Label("Preview",systemImage:"arrow.up.left.and.arrow.down.right") }
                    .help("Open photo preview (Space)")
            }
            if !model.installedEditors.isEmpty {
                VStack(alignment:.leading,spacing:6) {
                    ForEach(model.installedEditors) { editor in
                        Button { model.openOriginal(in:editor.url) } label: { Label("Open in " + editor.name,systemImage:"arrow.up.forward.app") }
                            .disabled(!model.originalAvailable(asset))
                            .help(model.originalAvailable(asset) ? "Open this original in " + editor.name : "Reconnect the source drive to open this original")
                    }
                }
            }
            CachedPhoto(path:asset.thumbnailPath,revision:String(asset.asset.modifiedAt?.timeIntervalSince1970 ?? 0)).frame(maxWidth:.infinity).frame(height:128)
            if !model.originalAvailable(asset) {
                Label(model.availability[asset.asset.sourceID] == "Connected" ? "Original unavailable" : "Original on disconnected drive",systemImage:"externaldrive.badge.exclamationmark")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Find Similar") { model.findSimilar() }.disabled(model.visualCoverage.embedded == 0)
                Menu {
                    if model.collections.isEmpty { Text("Create a collection in the folder pane") }
                    ForEach(model.collections) { collection in
                        Button { model.toggleCollection(collection) } label: {
                            if model.selectedCollections.contains(collection.id) { Label(collection.name,systemImage:"checkmark") }
                            else { Text(collection.name) }
                        }
                    }
                } label: {
                    HStack(spacing:6) {
                        Text("Collections")
                        Image(systemName:"chevron.down").font(.system(size:8,weight:.semibold))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal,8).padding(.vertical,4)
                    .background(Color.primary.opacity(0.06),in:RoundedRectangle(cornerRadius:5))
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().accessibilityLabel("Collections")
            }
            if model.selectedPairMembers.count == 2 {
                DisclosureGroup("RAW + JPEG",isExpanded:$pairExpanded) {
                    VStack(alignment:.leading,spacing:8) {
                        ForEach(model.selectedPairMembers) { member in
                            Button { model.selectAsset(member.id) } label: {
                                HStack { Text(member.filename).lineLimit(1); Spacer(); if member.id == asset.id { Image(systemName:"checkmark") } }
                            }.help("Inspect and open this file; favorites and tags belong to the selected file")
                        }
                        Text("Actions and tags apply to the selected file.").font(.caption).foregroundStyle(.secondary)
                        Button("Separate Pair") { model.separateSelectedPair() }
                    }.padding(.top,8)
                }.font(.subheadline)
            }
            Divider()
            PhotoTags(model:model)
            Divider()
            DisclosureGroup("Metadata",isExpanded:$metadataExpanded) {
                VStack(alignment:.leading,spacing:8) {
                    LabeledContent("Original",value:model.originalAvailable(asset) ? "Available" : "Unavailable")
                    if let metadata = asset.metadata {
                        LabeledContent("Camera",value:metadata.camera ?? "Unknown")
                        LabeledContent("Captured",value:metadata.captureDateText ?? "Unknown")
                        if metadata.captureDateText != nil && metadata.captureTimezone == nil { Text("Camera timezone not recorded").foregroundStyle(.secondary) }
                        LabeledContent("Lens",value:metadata.lens ?? "Unknown")
                        LabeledContent("ISO",value:metadata.iso.map { String(Int($0)) } ?? "Unknown")
                        LabeledContent("Aperture",value:metadata.aperture.flatMap { $0 > 0 ? "f/\($0.formatted())" : nil } ?? "Unknown")
                        LabeledContent("Exposure",value:metadata.exposureDescription ?? "Unknown")
                        LabeledContent("Size",value:metadata.width.flatMap { width in metadata.height.map { "\(width) × \($0)" } } ?? "Unknown")
                        LabeledContent("Format",value:metadata.format ?? "Unknown")
                    }
                    if let source = asset.previewSource { Text("\(source) · sRGB").foregroundStyle(.secondary) }
                    Text(asset.asset.relativePath).foregroundStyle(.secondary).textSelection(.enabled)
                    Button("Reveal Original in Finder") { model.revealPhoto() }.disabled(!model.originalAvailable(asset))
                }.font(.caption).padding(.top,8)
            }.font(.subheadline)
            if let error = asset.error {
                Label("Preview failed",systemImage:"exclamationmark.triangle").font(.subheadline.weight(.semibold))
                Text(error).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Button("Retry Preview") { model.retrySelectedPreview() }.disabled(model.indexing || !model.originalAvailable(asset))
            } else if asset.thumbnailPath == nil && asset.previewState == .complete {
                Text("The cached preview was cleared. The original is preserved.").font(.caption).foregroundStyle(.secondary)
                Button("Rebuild Preview") { model.retrySelectedPreview() }.disabled(model.indexing || !model.originalAvailable(asset))
            }
        }.controlSize(.small)
            .animation(reduceMotion ? nil : .easeOut(duration:0.18),value:metadataExpanded)
            .animation(reduceMotion ? nil : .easeOut(duration:0.18),value:pairExpanded)
    }
}
