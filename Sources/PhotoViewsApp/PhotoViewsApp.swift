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
            CommandGroup(replacing:.newItem) {
                Button("Add Folder…") { model.chooseFolder() }
                    .keyboardShortcut("o",modifiers:[.command])
                    .disabled(!model.isReady)
            }
        }
    }
}
