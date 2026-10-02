import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import CryptoKit

public enum ImagePipeline {
    public static let version = "imageio-m2-v1"
    // Extensions route discovery, not compatibility claims. ImageIO validates each actual file.
    public static let extensions: Set<String> = ["jpg","jpeg","png","heic","heif","tif","tiff","webp","avif","nef","nrw","arw","sr2","srf","cr2","cr3","crw","raf","orf","rw2","rwl","dng","pef","ptx","srw","3fr","fff","iiq","mos","kdc","dcr","erf","mef","mrw","raw"]
    public static let rawExtensions = extensions.subtracting(["jpg","jpeg","png","heic","heif","tif","tiff","webp","avif"])
    static func open(_ url: URL) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL,[kCGImageSourceShouldCache:false] as CFDictionary), CGImageSourceGetCount(source) > 0 else {
            throw PipelineError.failed("ImageIO cannot read this file. Check the camera variant or whether the file is damaged.")
        }
        return source
    }
    public static func metadata(_ url: URL) throws -> MetadataRecord {
        let source = try open(url)
        guard let p = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [String:Any] else {
            throw PipelineError.failed("The file has no readable image metadata.")
        }
        let exif = p[kCGImagePropertyExifDictionary as String] as? [String:Any] ?? [:]
        let tiff = p[kCGImagePropertyTIFFDictionary as String] as? [String:Any] ?? [:]
        var record = MetadataRecord()
        record.width = (p[kCGImagePropertyPixelWidth as String] as? NSNumber)?.intValue
        record.height = (p[kCGImagePropertyPixelHeight as String] as? NSNumber)?.intValue
        record.orientation = (p[kCGImagePropertyOrientation as String] as? NSNumber)?.intValue ?? 1
        record.camera = tiff[kCGImagePropertyTIFFModel as String] as? String
        record.lens = exif[kCGImagePropertyExifLensModel as String] as? String
        record.aperture = (exif[kCGImagePropertyExifFNumber as String] as? NSNumber)?.doubleValue
        record.shutterSeconds = (exif[kCGImagePropertyExifExposureTime as String] as? NSNumber)?.doubleValue
        record.iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber])?.first?.doubleValue
        record.captureDateText = (exif[kCGImagePropertyExifDateTimeOriginal as String] as? String) ?? (tiff[kCGImagePropertyTIFFDateTime as String] as? String)
        record.captureTimezone = exif["OffsetTimeOriginal"] as? String
        if let text = record.captureDateText {
            let formatter = DateFormatter(); formatter.locale = Locale(identifier:"en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT:0)
            if let offset = record.captureTimezone {
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
                record.captureDate = formatter.date(from:text+offset)
            } else {
                // Store the camera's unzoned wall time on a neutral axis; retain original text and unknown timezone.
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                record.captureDate = formatter.date(from:text)
            }
        }
        record.format = url.pathExtension.uppercased()
        record.decoder = CGImageSourceGetType(source) as String? ?? "ImageIO"
        return record
    }
    public static func previews(_ url: URL, id: UUID, cache: PreviewCache) throws -> DerivativeRecord {
        let source = try open(url)
        var options: [CFString:Any] = [kCGImageSourceThumbnailMaxPixelSize:1600,kCGImageSourceCreateThumbnailWithTransform:true,
            kCGImageSourceShouldCacheImmediately:true,kCGImageSourceCreateThumbnailFromImageIfAbsent:false]
        var decoded = CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary)
        var origin = "embedded preview"
        if decoded == nil || min(decoded!.width,decoded!.height) < 224 {
            options[kCGImageSourceCreateThumbnailFromImageAlways] = true
            decoded = CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary)
            origin = "ImageIO generated preview"
        }
        guard let decoded else { throw PipelineError.failed("No usable preview. This RAW variant may need a decoder fallback; the original has not been changed.") }
        let analysis = try converted(decoded,maxSize:1600)
        let thumbnail = try converted(analysis,maxSize:512)
        let paths = cache.paths(id)
        try jpeg(analysis).write(to:paths.analysis,options:.atomic)
        try jpeg(thumbnail).write(to:paths.thumbnail,options:.atomic)
        return DerivativeRecord(assetID:id,thumbnailPath:paths.thumbnail.path,analysisPath:paths.analysis.path,
            pipelineVersion:version,previewSource:origin,lastAccess:Date(),byteSize:try cache.size(paths.thumbnail)+cache.size(paths.analysis))
    }
    static func converted(_ image: CGImage, maxSize: Int) throws -> CGImage {
        let scale = min(1,Double(maxSize)/Double(max(image.width,image.height)))
        let width = max(1,Int(Double(image.width)*scale)), height = max(1,Int(Double(image.height)*scale))
        guard let srgb = CGColorSpace(name:CGColorSpace.sRGB), let context = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,space:srgb,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PipelineError.failed("The color-managed preview could not be created.") }
        context.setFillColor(CGColor(gray:1,alpha:1)); context.fill(CGRect(x:0,y:0,width:width,height:height))
        context.interpolationQuality = .high; context.draw(image,in:CGRect(x:0,y:0,width:width,height:height))
        guard let result = context.makeImage() else { throw PipelineError.failed("The preview could not be rendered.") }
        return result
    }
    static func jpeg(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data,UTType.jpeg.identifier as CFString,1,nil) else { throw PipelineError.failed("The preview could not be saved.") }
        CGImageDestinationAddImage(destination,image,[kCGImageDestinationLossyCompressionQuality:0.9,kCGImagePropertyOrientation:1] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PipelineError.failed("The preview could not be saved.") }
        return data as Data
    }
    public static func hash(_ url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom:url); defer { try? file.close() }
        var hash = SHA256()
        while let chunk = try file.read(upToCount:1024*1024), !chunk.isEmpty { hash.update(data:chunk) }
        return hash.finalize().map { String(format:"%02x",$0) }.joined()
    }
}
public enum PipelineError: LocalizedError {
    case failed(String)
    public var errorDescription: String? { if case .failed(let message) = self { return message }; return nil }
}
