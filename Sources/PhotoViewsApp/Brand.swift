import SwiftUI
import AppKit

/// Still's surfaces stay neutral so the photographs supply the color.
enum StillBrand {
    static let canvas = NSColor(name: "StillCanvas") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed:29/255,green:32/255,blue:31/255,alpha:1)
            : NSColor(srgbRed:0.969,green:0.965,blue:0.949,alpha:1)
    }
    static let pane = NSColor(name: "StillPane") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed:36/255,green:40/255,blue:38/255,alpha:1)
            : NSColor(srgbRed:0.941,green:0.937,blue:0.918,alpha:1)
    }
    static let secondary = NSColor(name: "StillSecondary") { appearance in
        appearance.bestMatch(from: [.darkAqua,.aqua]) == .darkAqua
            ? NSColor(srgbRed:183/255,green:189/255,blue:184/255,alpha:1)
            : NSColor(srgbRed:90/255,green:96/255,blue:91/255,alpha:1)
    }
    static let accent = NSColor(name: "StillAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed:158/255,green:185/255,blue:168/255,alpha:1)
            : NSColor(srgbRed:0.20,green:0.37,blue:0.33,alpha:1)
    }
}

/// The selected opposing corners, authored as filled geometry for crisp small-size rendering.
struct StillMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func polygon(_ points: [(CGFloat,CGFloat)]) {
            p.move(to:CGPoint(x:rect.minX+points[0].0*rect.width,y:rect.minY+points[0].1*rect.height))
            for (x,y) in points.dropFirst() { p.addLine(to:CGPoint(x:rect.minX+x*rect.width,y:rect.minY+y*rect.height)) }
            p.closeSubpath()
        }
        polygon([(0,0),(0.67,0),(0.67,0.27),(0.27,0.27),(0.27,0.67),(0,0.67)])
        polygon([(0.73,0.33),(1,0.33),(1,1),(0.33,1),(0.33,0.73),(0.73,0.73)])
        return p
    }
}

/// Custom sharp lettering is a brand asset; all functional UI remains native, selectable text.
struct StillWordmark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let transform = CGAffineTransform(scaleX:rect.width/76,y:rect.height/32).concatenating(CGAffineTransform(translationX:rect.minX,y:rect.minY))
        // Squared s: chamfered corners keep the silhouette legible at toolbar scale.
        p.move(to:CGPoint(x:20,y:10)); p.addLine(to:CGPoint(x:4,y:10)); p.addLine(to:CGPoint(x:0,y:14)); p.addLine(to:CGPoint(x:0,y:20)); p.addLine(to:CGPoint(x:4,y:24)); p.addLine(to:CGPoint(x:14,y:24)); p.addLine(to:CGPoint(x:14,y:27)); p.addLine(to:CGPoint(x:0,y:27)); p.addLine(to:CGPoint(x:0,y:32)); p.addLine(to:CGPoint(x:16,y:32)); p.addLine(to:CGPoint(x:20,y:28)); p.addLine(to:CGPoint(x:20,y:22)); p.addLine(to:CGPoint(x:16,y:18)); p.addLine(to:CGPoint(x:6,y:18)); p.addLine(to:CGPoint(x:6,y:15)); p.addLine(to:CGPoint(x:20,y:15)); p.closeSubpath()
        // t, square i dot and stem, and the paired l rhythm.
        p.addRect(CGRect(x:29,y:3,width:6,height:29)); p.addRect(CGRect(x:24,y:10,width:17,height:5)); p.addRect(CGRect(x:35,y:27,width:6,height:5))
        p.addRect(CGRect(x:46,y:0,width:6,height:6)); p.addRect(CGRect(x:46,y:10,width:6,height:22))
        p.addRect(CGRect(x:58,y:0,width:6,height:32)); p.addRect(CGRect(x:70,y:0,width:6,height:32))
        return p.applying(transform)
    }
}

struct StillSignature: View {
    var body: some View {
        HStack(spacing:9) {
            StillMark().fill().frame(width:22,height:22)
            StillWordmark().fill().frame(width:48,height:20)
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children:.ignore).accessibilityLabel("Still")
    }
}

/// Keep native window controls and dragging while the header occupies the titlebar.
struct StillWindowChrome: NSViewRepresentable {
    final class ChromeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.titleVisibility = .hidden
            window?.titlebarAppearsTransparent = true
            window?.isMovableByWindowBackground = true
        }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
    func makeNSView(context: Context) -> ChromeView { ChromeView() }
    func updateNSView(_ view: ChromeView, context: Context) { }
}
