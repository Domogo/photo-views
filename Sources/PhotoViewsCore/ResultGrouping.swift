import Foundation

public struct PhotoResultGroup: Identifiable {
    public let id: String
    public let title: String
    public let assets: [IndexedAsset]
}

/// Presentation only: every input identity belongs to exactly one bucket, in input rank order.
public enum ResultGrouping {
    public static func groups(_ assets: [IndexedAsset], by grouping: Grouping, sources: [CatalogSource], ranked: Bool, sorting: PhotoSort) -> [PhotoResultGroup] {
        if grouping == .none || grouping == .subject { return [PhotoResultGroup(id:"all",title:"",assets:assets)] }
        let names = Dictionary(uniqueKeysWithValues:sources.map { ($0.id,$0.name) })
        var buckets: [String:[IndexedAsset]] = [:], titles: [String:String] = [:], first: [String:Int] = [:]
        var unknown = Set<String>()
        for (rank,asset) in assets.enumerated() {
            let key: String, title: String
            switch grouping {
            case .folder:
                let folder = (asset.asset.relativePath as NSString).deletingLastPathComponent
                key = "folder:\(asset.asset.sourceID.uuidString):\(folder)"
                title = (names[asset.asset.sourceID] ?? "Unknown source") + (folder.isEmpty ? "" : " / "+folder)
            case .camera:
                let camera = asset.metadata?.camera?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""
                key = camera.isEmpty ? "unknown:camera" : "camera:"+camera
                title = camera.isEmpty ? "Unknown camera" : camera
                if camera.isEmpty { unknown.insert(key) }
            case .month:
                if let month = captureMonth(asset.metadata?.captureDateText) { key = "month:"+month; title = month }
                else { key = "unknown:month"; title = "Unknown date"; unknown.insert(key) }
            default: key = "all"; title = ""
            }
            if first[key] == nil { first[key] = rank; titles[key] = title }
            buckets[key,default:[]].append(asset)
        }
        let keys = buckets.keys.sorted { a,b in
            if ranked { return first[a]! < first[b]! }
            if unknown.contains(a) != unknown.contains(b) { return !unknown.contains(a) }
            if grouping == .month { return sorting == .captureOldest ? a < b : a > b }
            let order = titles[a]!.compare(titles[b]!,options:[.caseInsensitive,.numeric],locale:Locale(identifier:"en_US_POSIX"))
            return order == .orderedSame ? a < b : order == .orderedAscending
        }
        return keys.map { PhotoResultGroup(id:$0,title:titles[$0]!,assets:buckets[$0]!) }
    }
    public static func captureMonth(_ text: String?) -> String? {
        guard let text else { return nil }
        let parts = text.prefix(10).replacingOccurrences(of:":",with:"-").split(separator:"-",omittingEmptySubsequences:false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]), year > 0,
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(secondsFromGMT:0)!
        let components = DateComponents(year:year,month:month,day:day)
        guard let date = calendar.date(from:components), calendar.dateComponents([.year,.month,.day],from:date) == components else { return nil }
        return String(format:"%04d-%02d",year,month)
    }
}
