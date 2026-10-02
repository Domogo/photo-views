import Foundation

/// Overall preview pixel coverage, not colored-object detection.
public struct PaletteSearch: Codable, Equatable {
    public static let version = "srgb-hsv-area-v1"
    public static let colors = ["red", "orange", "yellow", "green", "cyan", "blue", "purple", "pink", "brown", "black", "gray", "white"]
    public var color: String
    public var minimumFraction: Double
    public var version: String
    public init(color: String, minimumFraction: Double = 0.25) {
        self.color = color; self.minimumFraction = minimumFraction; self.version = Self.version
    }
    /// Deliberately narrow language: “mostly blue” or “predominantly blue”.
    /// “Blue car” remains a visual description.
    public static func extract(from text: String) -> (intent: String, palette: PaletteSearch?, ambiguous: Bool) {
        let names = colors.joined(separator:"|")
        let regex = try! NSRegularExpression(pattern:"\\b(?:mostly|predominantly) ("+names+")\\b",options:.caseInsensitive)
        let matches = regex.matches(in:text,range:NSRange(text.startIndex...,in:text))
        guard matches.count == 1, let match = matches.first, let color = Range(match.range(at:1),in:text), let range = Range(match.range,in:text) else {
            return (text,nil,matches.count > 1)
        }
        var intent = text; intent.removeSubrange(range)
        intent = intent.split(whereSeparator:{ $0.isWhitespace }).joined(separator:" ")
        return (intent,PaletteSearch(color:String(text[color]).lowercased()),false)
    }
}
