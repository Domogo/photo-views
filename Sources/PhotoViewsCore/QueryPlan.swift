import Foundation

/// Bounded, deterministic query grammar. No model text becomes SQL or file operations.
public struct QueryPlan: Codable, Equatable {
    public var version = "explicit-v1"
    public var input: String
    public var visualIntent: String
    public var filters: ExactFilters
    public var grouping: Grouping?
    public var ambiguities: [String] = []
    public var unsupported: [String] = []
    public var referenceDay: String
    public var timezone: String
    public var canApply: Bool { ambiguities.isEmpty && unsupported.isEmpty }
}
public enum QueryInterpreter {
    public static func interpret(_ input: String, filters: ExactFilters = ExactFilters(), cameras: [String], lenses: [String], formats: [String], now: Date = Date(), timezone: TimeZone = .current) -> QueryPlan {
        var calendar = Calendar(identifier:.gregorian); calendar.timeZone = timezone
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = timezone; formatter.locale = Locale(identifier:"en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
        var plan = QueryPlan(input:input,visualIntent:input,filters:filters,referenceDay:formatter.string(from:now),timezone:timezone.identifier)
        var remainder = input
        var seen = Set<String>()
        func unique(_ key: String) { if !seen.insert(key).inserted { plan.ambiguities.append("Repeated \(key) directive. Keep one value or use Filters.") } }
        func consume(_ pattern: String, _ action: ([String]) -> Void) {
            guard let regex = try? NSRegularExpression(pattern:pattern,options:[.caseInsensitive]) else { return }
            let matches = regex.matches(in:remainder,range:NSRange(remainder.startIndex...,in:remainder))
            for match in matches.reversed() {
                let values = (1..<match.numberOfRanges).map { i in Range(match.range(at:i),in:remainder).map { String(remainder[$0]) } ?? "" }
                action(values)
                if let range = Range(match.range,in:remainder) { remainder.replaceSubrange(range,with:" ") }
            }
        }
        func resolve(_ text: String, choices: [String], field: String) -> String? {
            let exact = choices.filter { $0.caseInsensitiveCompare(text) == .orderedSame }
            if exact.count == 1 { return exact[0] }
            let candidates = choices.filter { $0.localizedCaseInsensitiveContains(text) }
            if candidates.count == 1 { return candidates[0] }
            plan.ambiguities.append(candidates.isEmpty ? "Unknown \(field): \(text). Choose a catalog value in Filters." : "\(field.capitalized) ‘\(text)’ matches \(candidates.joined(separator:", ")). Use its full quoted name.")
            return nil
        }
        // Quoted catalog values keep multiword camera/lens/folder names intact.
        consume(#"\b(camera|lens|folder|format|tag):(?:"([^"]+)"|([^\s]+))"#) { v in
            if v[0].lowercased() != "tag" { unique(v[0].lowercased()) }
            let value = v[1].isEmpty ? v[2] : v[1]
            switch v[0].lowercased() {
            case "camera": plan.filters.camera = resolve(value,choices:cameras,field:"camera")
            case "lens": plan.filters.lens = resolve(value,choices:lenses,field:"lens")
            case "format": plan.filters.format = resolve(value,choices:formats,field:"format")
            case "folder": plan.filters.folder = value
            default: let tag = value.trimmingCharacters(in:.whitespacesAndNewlines).lowercased(); if !plan.filters.confirmedTags.contains(tag) { plan.filters.confirmedTags.append(tag) }
            }
        }
        consume(#"\bshot with "([^"]+)""#) { v in unique("camera"); plan.filters.camera = resolve(v[0],choices:cameras,field:"camera") }
        consume(#"\bin folder "([^"]+)""#) { v in unique("folder"); plan.filters.folder = v[0] }
        consume(#"\b(?:group(?:ed)? by|group:)[ ]*(none|folder|month|camera|subject)\b"#) { v in unique("grouping"); plan.grouping = Grouping(rawValue:v[0].lowercased()) }
        consume(#"\b(from|through|on):?(?: +|(?=\d))(\d{4}-\d{2}-\d{2})\b"#) { v in
            if (v[0].lowercased() == "on" && !seen.isDisjoint(with:["from","through"])) || (v[0].lowercased() != "on" && seen.contains("on")) { plan.ambiguities.append("Use either on or a from/through range.") }
            unique(v[0].lowercased())
            guard let date = formatter.date(from:v[1]), formatter.string(from:date) == v[1] else { plan.ambiguities.append("Invalid date: \(v[1]). Use YYYY-MM-DD."); return }
            if v[0].lowercased() != "through" { plan.filters.fromDate = date }
            if v[0].lowercased() != "from" { plan.filters.toDate = date }
        }
        consume(#"\b(today|yesterday)\b"#) { v in
            if !seen.isDisjoint(with:["from","through","on"]) { plan.ambiguities.append("Use one date expression.") }
            unique("relative date")
            let day = calendar.startOfDay(for:now); let date = v[0].lowercased() == "today" ? day : calendar.date(byAdding:.day,value:-1,to:day)!
            plan.filters.fromDate = date; plan.filters.toDate = date
        }
        consume(#"\b(iso|aperture|shutter|width|height) *(>=|<=|=|>|<) *([0-9]+(?:\.[0-9]+)?(?:/[0-9]+(?:\.[0-9]+)?)?)\b"#) { v in
            let parts = v[2].split(separator:"/"); let value = parts.count == 2 ? (Double(parts[0]) ?? 0)/(Double(parts[1]) ?? 0) : Double(v[2]) ?? 0
            guard value.isFinite && value > 0 else { plan.ambiguities.append("\(v[0]): enter a positive finite limit."); return }
            guard v[1] != ">" && v[1] != "<" else { plan.unsupported.append("Strict \(v[1]) for \(v[0]); use >= or <=."); return }
            let min = v[1] != "<=", max = v[1] != ">="
            switch v[0].lowercased() {
            case "iso": if min { plan.filters.minISO = value }; if max { plan.filters.maxISO = value }
            case "aperture": if min { plan.filters.minAperture = value }; if max { plan.filters.maxAperture = value }
            case "shutter": if min { plan.filters.minShutterSeconds = value }; if max { plan.filters.maxShutterSeconds = value }
            case "width": if min { plan.filters.minWidth = value }; if max { plan.filters.maxWidth = value }
            default: if min { plan.filters.minHeight = value }; if max { plan.filters.maxHeight = value }
            }
        }
        // Visible unsupported directives block application; unconstrained prose remains visual intent.
        if let regex = try? NSRegularExpression(pattern:#"\b(?:iso|aperture|shutter|width|height) *[<>=][^\s]*|\b[a-z]+:[^\s]+|\b(?:last|this|next) +(?:week|month|year)|\bgroup(?:ed)? by +[^,;]+"#,options:[.caseInsensitive]) {
            for match in regex.matches(in:remainder,range:NSRange(remainder.startIndex...,in:remainder)) {
                if let range = Range(match.range,in:remainder) { plan.unsupported.append(String(remainder[range])) }
            }
        }
        plan.visualIntent = remainder.split(whereSeparator: { $0.isWhitespace }).joined(separator:" ").trimmingCharacters(in:CharacterSet(charactersIn:",; "))
        validate(&plan)
        return plan
    }
    public static func validate(_ plan: inout QueryPlan) {
        let f = plan.filters
        for (name,min,max) in [("ISO",f.minISO,f.maxISO),("aperture",f.minAperture,f.maxAperture),("shutter",f.minShutterSeconds,f.maxShutterSeconds),("width",f.minWidth,f.maxWidth),("height",f.minHeight,f.maxHeight)] {
            if let min, (!min.isFinite || min <= 0) { plan.ambiguities.append("\(name) minimum must be positive.") }
            if let max, (!max.isFinite || max <= 0) { plan.ambiguities.append("\(name) maximum must be positive.") }
            if let min, let max, min > max { plan.ambiguities.append("\(name) minimum exceeds maximum.") }
        }
        if let from = f.fromDate, let to = f.toDate, from > to { plan.ambiguities.append("From date is after Through date.") }
    }
}
