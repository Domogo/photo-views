import SwiftUI
import AppKit

@main struct PhotoViewsApp: App {
    @StateObject private var model = WorkspaceModel()
    var body: some Scene {
        WindowGroup("Photo Views") {
            GeometryReader { geometry in
                WorkspaceView(model:model,availableHeight:geometry.size.height)
            }
            .frame(minWidth:780,minHeight:520)
        }
        .defaultSize(width:1180,height:760)
        .commands {
            CommandGroup(after:.toolbar) {
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
