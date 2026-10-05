// Regenerate Still's icon with native vector drawing; no external assets or runtime dependencies.
import AppKit
import Foundation
let root = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
let iconset = root.appendingPathComponent(".build/Still.iconset",isDirectory:true)
try FileManager.default.createDirectory(at:iconset,withIntermediateDirectories:true)
for base in [16,32,128,256,512] {
    for scale in [1,2] {
        let size = base*scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
        let n = CGFloat(size)
        NSColor(srgbRed:29/255,green:32/255,blue:31/255,alpha:1).setFill()
        NSBezierPath(roundedRect:NSRect(x:n*0.04,y:n*0.04,width:n*0.92,height:n*0.92),xRadius:n*0.20,yRadius:n*0.20).fill()
        NSColor(srgbRed:0.969,green:0.965,blue:0.949,alpha:1).setStroke()
        NSColor(srgbRed:0.969,green:0.965,blue:0.949,alpha:1).setFill()
        let path = NSBezierPath()
        func point(_ x:CGFloat,_ y:CGFloat)->NSPoint { NSPoint(x:n*(0.22+x*0.56),y:n*(0.22+(1-y)*0.56)) }
        for points: [(CGFloat,CGFloat)] in [[(0,0),(0.67,0),(0.67,0.27),(0.27,0.27),(0.27,0.67),(0,0.67)],[(0.73,0.33),(1,0.33),(1,1),(0.33,1),(0.33,0.73),(0.73,0.73)]] {
            path.move(to:point(points[0].0,points[0].1))
            for (x,y) in points.dropFirst() { path.line(to:point(x,y)) }
            path.close()
        }
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using:.png,properties:[:])!.write(to:iconset.appendingPathComponent(name))
    }
}
let task=Process(); task.executableURL=URL(fileURLWithPath:"/usr/bin/iconutil"); task.arguments=["-c","icns",iconset.path,"-o",root.appendingPathComponent("Resources/Brand/Still.icns").path]; try task.run(); task.waitUntilExit(); exit(task.terminationStatus)
