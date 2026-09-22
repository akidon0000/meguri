import Foundation
import FoundationModels

@Generable
struct Insight: Codable, Sendable, Equatable {
    @Generable
    enum Category: String, Codable, CaseIterable, Sendable {
        case artwork, sculpture, architecture, nature, creature, streetscape, other

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Category(rawValue: raw) ?? .other
        }
    }

    @Guide(
        description:
            "Name of the artwork or place. If unknown, a short descriptive title of what is seen.")
    var title: String

    @Guide(description: "Artist, architect, or origin. Empty string if unknown.")
    var creator: String

    @Guide(description: "Year, period, or era of creation. Empty string if unknown.")
    var era: String

    @Guide(
        description:
            "Two to three sentences explaining what it is and its background. Hedge uncertain claims."
    )
    var summary: String

    @Guide(description: "Interesting facts. At most three.", .maximumCount(3))
    var funFacts: [String]

    @Guide(
        description:
            "One of: artwork, sculpture, architecture, nature, creature, streetscape, other.")
    var category: Category
}
