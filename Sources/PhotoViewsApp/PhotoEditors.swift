import AppKit

struct PhotoEditor: Identifiable, Equatable {
    let name: String
    let url: URL
    var id: String { url.path }

    /// Launch Services also finds apps outside the usual Applications folders.
    static func installed() -> [PhotoEditor] {
        var found: [String:PhotoEditor] = [:]
        func include(_ url: URL) {
            guard url.pathExtension == "app", let bundle = Bundle(url:url) else { return }
            let names = [url.deletingPathExtension().lastPathComponent,
                         bundle.object(forInfoDictionaryKey:"CFBundleDisplayName") as? String ?? "",
                         bundle.object(forInfoDictionaryKey:"CFBundleName") as? String ?? ""].joined(separator:" ").lowercased()
            let identifier = bundle.bundleIdentifier?.lowercased() ?? ""
            let name: String
            if names.contains("photomator") || identifier == "com.pixelmatorteam.pixelmator.touch.x.photo" { name = "Photomator" }
            else if names.contains("lightroom") || identifier.contains("lightroom") { name = names.contains("classic") || identifier == "com.adobe.lightroomclassiccc7" ? "Lightroom Classic" : "Lightroom" }
            else { return }
            found[name] = PhotoEditor(name:name,url:url)
        }
        for id in ["com.pixelmatorteam.pixelmator.touch.x.photo","com.adobe.LightroomCC","com.adobe.LightroomClassicCC7","com.adobe.Lightroom6"] {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier:id) { include(url) }
        }
        for root in [URL(fileURLWithPath:"/Applications"),FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")] {
            guard let entries = FileManager.default.enumerator(at:root,includingPropertiesForKeys:nil,options:[.skipsHiddenFiles,.skipsPackageDescendants]) else { continue }
            for case let url as URL in entries {
                if entries.level > 3 { entries.skipDescendants(); continue }
                if url.pathExtension == "app" { include(url) }
            }
        }
        return found.values.sorted { $0.name < $1.name }
    }
}
