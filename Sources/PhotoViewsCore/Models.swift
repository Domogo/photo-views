import Foundation

public enum Grouping: String, CaseIterable, Codable, Identifiable {
    case none, folder, month, camera, subject
    public var id: String { rawValue }
    public var title: String { self == .none ? "None" : self == .subject ? "Primary subject" : rawValue.capitalized }
}
public enum PhotoSort: String, CaseIterable, Codable, Identifiable {
    case captureNewest, captureOldest, filename, relevance
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .captureNewest: return "Newest first"
        case .captureOldest: return "Oldest first"
        case .filename: return "Filename"
        case .relevance: return "Relevance"
        }
    }
}
public struct ExactFilters: Codable, Equatable {
    public var camera: String?
    public var fromDate: Date?
    public var toDate: Date?
    public var folder: String?
    public var confirmedTags: [String] = []
    public var lens: String?
    public var minISO: Double?
    public var maxISO: Double?
    public var minAperture: Double?
    public var maxAperture: Double?
    public var minShutterSeconds: Double?
    public var maxShutterSeconds: Double?
    public var minWidth: Double?
    public var maxWidth: Double?
    public var minHeight: Double?
    public var maxHeight: Double?
    public var format: String?
    public init() {}
}
public struct ViewRecipe: Codable, Equatable {
    public var palette: PaletteSearch?
    public var collapsePairs: Bool?
    public var collectionID: UUID?
    public var favoritesOnly: Bool?
    public var sourceIDs: [UUID] = []
    public var search = ""
    public var searchMode: String?
    public var filters = ExactFilters()
    public var grouping: Grouping = .none
    public var sorting: PhotoSort = .captureNewest
    public var referenceAssetID: UUID?
    public var modelVersion: String?
    public var rankingVersion: String?
    public init() {}
}
public struct CatalogSource: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var bookmark: Data
    public var volumeID: String?
    public var relativePath: String
    public var lastKnownPath: String
    public var createdAt: Date
    public init(id: UUID = UUID(), name: String, bookmark: Data, volumeID: String?, relativePath: String, lastKnownPath: String, createdAt: Date = Date()) {
        self.id = id; self.name = name; self.bookmark = bookmark; self.volumeID = volumeID
        self.relativePath = relativePath; self.lastKnownPath = lastKnownPath; self.createdAt = createdAt
    }
}
public struct SavedView: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var recipe: ViewRecipe
    public var createdAt: Date
    public init(id: UUID = UUID(), name: String, recipe: ViewRecipe, createdAt: Date = Date()) {
        self.id = id; self.name = name; self.recipe = recipe; self.createdAt = createdAt
    }
}
public struct CollectionRecord: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public init(id: UUID = UUID(), name: String) { self.id = id; self.name = name }
}
public struct AssetRecord: Identifiable, Codable {
    public var id: UUID
    public var sourceID: UUID
    public var relativePath: String
    public var fileID: String?
    public var byteSize: Int64
    public var modifiedAt: Date?
}
public struct MetadataRecord: Codable {
    public init() {}
    public var captureDateText: String?
    public var captureTimezone: String?
    public var orientation: Int?
    public var decoder: String?
    public var captureDate: Date?
    public var camera: String?
    public var lens: String?
    public var iso: Double?
    public var aperture: Double?
    public var shutterSeconds: Double?
    public var exposureDescription: String? {
        guard let seconds = shutterSeconds, seconds.isFinite, seconds > 0 else { return nil }
        if seconds < 1 {
            let reciprocal = 1 / seconds
            if reciprocal.isFinite, reciprocal < Double(Int.max) {
                return "1/\(Int(reciprocal.rounded())) s"
            }
        }
        return seconds.formatted(.number.precision(.significantDigits(1...6))) + " s"
    }
    public var width: Int?
    public var height: Int?
    public var format: String?
}
public enum IndexStage: String, Codable { case metadata, preview, embedding }
public enum IndexState: String, Codable { case pending, running, paused, failed, complete }
public enum TagProvenance: String, Codable { case imported, manual, suggested }
public enum TagDecision: String, Codable { case unconfirmed, accepted, rejected }

public struct PhotoRecord: Identifiable, Codable {
    public var id: UUID
    public var primaryAssetID: UUID?
    public var assetIDs: [UUID]
}
public struct EmbeddingRecord: Codable {
    public var assetID: UUID
    public var modelVersion: String
    public var dimensions: Int
    public var vector: Data
}
public struct TagAssignmentRecord: Identifiable, Codable {
    public var id: UUID
    public var assetID: UUID
    public var tag: String
    public var provenance: TagProvenance
    public var decision: TagDecision
    public var modelVersion: String?
    public var score: Double?
    public var threshold: Double?
    public var vocabularyVersion: String?
    public var isConfirmed: Bool { decision != .rejected && (provenance == .manual || decision == .accepted) }
}
public struct IndexJobRecord: Identifiable, Codable {
    public var id: UUID
    public var sourceID: UUID
    public var assetID: UUID?
    public var stage: IndexStage
    public var state: IndexState
    public var error: String?
    public var pipelineVersion: String?
    public var updatedAt: Date
}

public struct IndexedAsset: Identifiable, Codable {
    public var photoID: UUID?
    public var pairedAssetIDs: [UUID]?
    public var favorite: Bool?
    public var primarySubject: String?
    public var primarySubjectSuggested: Bool?
    public var id: UUID { asset.id }
    public var asset: AssetRecord
    public var metadata: MetadataRecord?
    public var thumbnailPath: String?
    public var analysisPath: String?
    public var pipelineVersion: String?
    public var previewSource: String?
    public var available: Bool
    public var previewState: IndexState?
    public var error: String?
    public var filename: String { URL(fileURLWithPath: asset.relativePath).lastPathComponent }
}
public struct SourceProgress: Codable {
    public var sourceID: UUID
    public var state: String
    public var total: Int
    public var metadataReady: Int
    public var completed: Int
    public var failed: Int
    public var error: String?
}
public struct DerivativeRecord {
    public var assetID: UUID
    public var thumbnailPath: String?
    public var analysisPath: String?
    public var pipelineVersion: String
    public var previewSource: String
    public var lastAccess: Date
    public var byteSize: Int64
}
