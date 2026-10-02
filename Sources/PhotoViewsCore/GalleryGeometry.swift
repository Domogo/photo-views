import Foundation

public enum GalleryGeometry {
    /// Deterministic shortest-column placement; no view measurement or scroll feedback.
    public static func frames(aspects: [Double], width: Double, y: Double = 0) -> (frames: [CGRect], height: Double) {
        let inset = 12.0, gap = 8.0
        let columns = max(1,Int((max(1,width)-2*inset+gap)/208))
        let cellWidth = max(1,(width-2*inset-Double(columns-1)*gap)/Double(columns))
        var heights = Array(repeating:y,count:columns), frames: [CGRect] = []
        for aspect in aspects {
            let column = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            let ratio = aspect.isFinite && aspect > 0 ? aspect : 1
            let height = cellWidth/ratio
            frames.append(CGRect(x:inset+Double(column)*(cellWidth+gap),y:heights[column],width:cellWidth,height:height))
            heights[column] += height+gap
        }
        return (frames,max(y,(heights.max() ?? y)-gap))
    }
}
