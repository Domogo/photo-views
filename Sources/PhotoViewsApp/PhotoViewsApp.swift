import SwiftUI
import AppKit

@main struct PhotoViewsApp: App {
    @NSApplicationDelegateAdaptor(StillApplicationDelegate.self) private var appDelegate
    @StateObject private var model = WorkspaceModel()
    var body: some Scene {
        WindowGroup("Still") {
            GeometryReader { geometry in
                WorkspaceView(model:model,availableHeight:geometry.size.height,availableWidth:geometry.size.width)
            }
            .frame(minWidth:780,minHeight:520)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width:1180,height:760)
        .commands {
            CommandGroup(after:.toolbar) {
                Button("Search Photos") { model.browsingPeople = false; model.searchFocusRequest += 1 }.keyboardShortcut("f",modifiers:.command)
                Divider()
                Button("Zoom Grid In") { model.zoomGrid(1) }.keyboardShortcut("+",modifiers:.command).disabled(model.gridZoom == 6)
                Button("Zoom Grid Out") { model.zoomGrid(-1) }.keyboardShortcut("-",modifiers:.command).disabled(model.gridZoom == 0)
                Button("Reset Grid Zoom") { model.gridZoom = 2 }.keyboardShortcut("0",modifiers:.command)
            }

            CommandGroup(replacing:.newItem) {
                Button("Add Folder…") { model.chooseFolder() }
                    .keyboardShortcut("o",modifiers:[.command])
                    .disabled(!model.isReady)
            }
        }
    }
}

final class StillApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Developer builds keep the same bundle identity. Refresh the running Dock
        // image from this bundle rather than inheriting Launch Services' old icon.
        guard let name = Bundle.main.object(forInfoDictionaryKey:"CFBundleIconFile") as? String,
              let url = Bundle.main.url(forResource:name,withExtension:"icns"),
              let icon = NSImage(contentsOf:url) else { return }
        NSApplication.shared.applicationIconImage = icon
    }
}
