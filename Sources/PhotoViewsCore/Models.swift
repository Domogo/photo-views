import Foundation

public enum Grouping: String, CaseIterable, Codable, Identifiable {
    case none, folder, month, camera, subject
    public var id: String { rawValue }
    public var title: String { self == .none ? "None" : rawValue.capitalized }
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
    public var format: String?
    public init() {}
}
public struct ViewRecipe: Codable, Equatable {
    public var sourceIDs: [UUID] = []
    public var search = ""
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
    public var captureDate: Date?
    public var camera: String?
    public var lens: String?
    public var iso: Double?
    public var aperture: Double?
    public var shutterSeconds: Double?
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
