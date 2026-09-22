import Foundation

struct PlaceGroup: Identifiable {
    var id: String { name }
    var name: String
    var entries: [Entry]
}

enum PlaceGrouping {
    static let unknownPlaceName = String(localized: "Unknown place")

    static func makeGroups(from entries: [Entry]) -> [PlaceGroup] {
        var order: [String] = []
        var buckets: [String: [Entry]] = [:]
        for entry in entries {
            let key = (entry.placeName?.isEmpty == false) ? entry.placeName! : unknownPlaceName
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(entry)
        }
        return order.map { PlaceGroup(name: $0, entries: buckets[$0] ?? []) }
    }
}
