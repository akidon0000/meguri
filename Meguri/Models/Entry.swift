import Foundation
import SwiftData

@Model
final class Entry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var imageFileName: String
    @Attribute(.externalStorage) var thumbnailData: Data
    var placeName: String?
    var latitude: Double?
    var longitude: Double?
    var insightData: Data?
    var unavailableReason: String?
    var perceivedLabels: [String]
    var recognizedTexts: [String]

    init(
        imageFileName: String,
        thumbnailData: Data,
        createdAt: Date = .now,
        placeName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        perceivedLabels: [String] = [],
        recognizedTexts: [String] = []
    ) {
        self.id = UUID()
        self.createdAt = createdAt
        self.imageFileName = imageFileName
        self.thumbnailData = thumbnailData
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.perceivedLabels = perceivedLabels
        self.recognizedTexts = recognizedTexts
    }

    var insight: Insight? {
        get { insightData.flatMap { try? JSONDecoder().decode(Insight.self, from: $0) } }
        set { insightData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    static var newestFirst: FetchDescriptor<Entry> {
        FetchDescriptor(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    }
}
