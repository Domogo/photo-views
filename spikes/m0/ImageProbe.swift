import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

// One input, one derivative. Original properties are recorded before decoding.
let args = CommandLine.arguments
func finish(_ value: [String: Any]) -> Never {
    let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    print(String(data: data, encoding: .utf8)!)
    exit(0)
}
guard args.count == 3 else { fputs("usage: ImageProbe input output.jpg\n", stderr); exit(2) }
let start = Date()
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
var report: [String: Any] = ["pipelineVersion": "imageio-m0-v2", "decoder": "ImageIO"]
guard let source = CGImageSourceCreateWithURL(input as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
    report["status"] = "unsupported-or-corrupt"
    report["error"] = "ImageIO could not open this file; validate camera variant or file integrity."
    finish(report)
}
report["sourceType"] = CGImageSourceGetType(source) as String? ?? "unknown"
report["imageCount"] = CGImageSourceGetCount(source)
let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
// Property lists include dates/data on some cameras; normalize through descriptions.
func normalize(_ item: Any) -> Any {
    if let dict = item as? [String: Any] { return dict.mapValues { normalize($0) } }
    if let array = item as? [Any] { return array.map { normalize($0) } }
    if item is String || item is NSNumber || item is NSNull { return item }
    return String(describing: item)
}
report["metadata"] = normalize(properties)
report["originalOrientation"] = properties[kCGImagePropertyOrientation as String] ?? 1
let base: [CFString: Any] = [kCGImageSourceThumbnailMaxPixelSize: 1600,
                           kCGImageSourceCreateThumbnailWithTransform: true,
                           kCGImageSourceShouldCacheImmediately: true]
// First ask for an existing thumbnail; only synthesize when none is usable.
var options = base
options[kCGImageSourceCreateThumbnailFromImageIfAbsent] = false
var image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
var previewSource = "imageio-existing-thumbnail"
if image == nil || min(image!.width, image!.height) < 224 {
    options[kCGImageSourceCreateThumbnailFromImageAlways] = true
    image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    previewSource = "imageio-generated-thumbnail"
}
guard let decodedPreview = image else {
    report["status"] = "preview-failed"
    report["error"] = "No usable preview; evaluate a RAW fallback against the required camera fixture."
    finish(report)
}
guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: decodedPreview.width, height: decodedPreview.height,
                              bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    report["status"] = "color-conversion-failed"; finish(report)
}
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: decodedPreview.width, height: decodedPreview.height))
context.draw(decodedPreview, in: CGRect(x: 0, y: 0, width: decodedPreview.width, height: decodedPreview.height))
guard let preview = context.makeImage() else {
    report["status"] = "color-conversion-failed"; finish(report)
}
report["decodedColorSpace"] = decodedPreview.colorSpace?.name as String? ?? "unknown"
report["outputColorPolicy"] = "8-bit-sRGB-white-alpha-composite"
report["previewSource"] = previewSource
report["previewWidth"] = preview.width
report["previewHeight"] = preview.height
report["previewColorSpace"] = preview.colorSpace?.name as String? ?? "unknown"
report["analysisSizeAdequate"] = min(preview.width, preview.height) >= 224
// ImageIO applies the orientation transform; output has normal orientation.
guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
    report["status"] = "output-failed"; report["error"] = "Cannot create derivative destination."
    finish(report)
}
CGImageDestinationAddImage(destination, preview, [kCGImageDestinationLossyCompressionQuality: 0.9,
                                               kCGImagePropertyOrientation: 1] as CFDictionary)
report["status"] = CGImageDestinationFinalize(destination) ? "preview-ready" : "output-failed"
report["elapsedSeconds"] = Date().timeIntervalSince(start)
finish(report)
