import Foundation

struct CategoryGroup: Identifiable {
    var id: String { category?.rawValue ?? "unclassified" }
    var category: Insight.Category?
    var entries: [Entry]

    var displayTitle: String {
        category?.displayName ?? String(localized: "Unclassified")
    }
}

enum CategoryGrouping {
    static func makeGroups(from entries: [Entry]) -> [CategoryGroup] {
        var buckets: [Insight.Category: [Entry]] = [:]
        var unclassified: [Entry] = []
        for entry in entries {
            if let category = entry.insight?.category {
                buckets[category, default: []].append(entry)
            } else {
                unclassified.append(entry)
            }
        }
        var groups = Insight.Category.allCases.compactMap { category -> CategoryGroup? in
            guard let bucket = buckets[category], !bucket.isEmpty else { return nil }
            return CategoryGroup(category: category, entries: bucket)
        }
        if !unclassified.isEmpty {
            groups.append(CategoryGroup(category: nil, entries: unclassified))
        }
        return groups
    }
}
