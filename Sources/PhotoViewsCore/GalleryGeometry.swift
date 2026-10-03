import Foundation

public enum GalleryGeometry {
    /// Deterministic shortest-column placement; no view measurement or scroll feedback.
    public static func frames(aspects: [Double], width: Double, y: Double = 0, clusters: [String?] = [], targetWidth: Double = 208) -> (frames: [CGRect], height: Double) {
        let inset = 12.0, gap = 8.0
        let columns = max(1,Int((max(1,width)-2*inset+gap)/max(80,targetWidth.isFinite ? targetWidth : 208)))
        let cellWidth = max(1,(width-2*inset-Double(columns-1)*gap)/Double(columns))
        var heights = Array(repeating:y,count:columns), frames: [CGRect] = []
        var index = 0
        while index < aspects.count {
            var end = index+1
            if clusters.count == aspects.count, let cluster = clusters[index] {
                while end < aspects.count && clusters[end] == cluster { end += 1 }
            }
            while index < end {
                let count = min(columns,end-index)
                let start = (0...(columns-count)).min { a,b in heights[a..<(a+count)].max()! < heights[b..<(b+count)].max()! } ?? 0
                let top = heights[start..<(start+count)].max() ?? y
                for column in start..<(start+count) {
                    let aspect = aspects[index]
                    let ratio = aspect.isFinite && aspect > 0 ? aspect : 1
                    let height = cellWidth/ratio
                    frames.append(CGRect(x:inset+Double(column)*(cellWidth+gap),y:top,width:cellWidth,height:height))
                    heights[column] = top+height+gap
                    index += 1
                }
            }
        }
        return (frames,max(y,(heights.max() ?? y)-gap))
    }
}
