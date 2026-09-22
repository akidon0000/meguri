import Foundation

struct UnassignedCluster: Identifiable {
    var id: Date { dateRange.lowerBound }
    var name: String?
    var dateRange: ClosedRange<Date>
    var entries: [Entry]

    var displayTitle: String {
        if let name { return name }
        return UnassignedCluster.singleDateFormatter.string(from: dateRange.lowerBound)
    }

    private static let singleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

enum UnassignedClustering {
    static let newClusterGapDays = 2

    static func makeClusters(from entries: [Entry], locale: Locale = .current) -> [UnassignedCluster]
    {
        let unassigned = entries.filter { $0.trip == nil }
        guard !unassigned.isEmpty else { return [] }
        let sorted = unassigned.sorted { $0.createdAt < $1.createdAt }
        let thresholdSeconds = TimeInterval(newClusterGapDays * 24 * 60 * 60)

        var groups: [[Entry]] = []
        var current: [Entry] = [sorted[0]]
        for entry in sorted.dropFirst() {
            if let last = current.last,
                entry.createdAt.timeIntervalSince(last.createdAt) > thresholdSeconds
            {
                groups.append(current)
                current = [entry]
            } else {
                current.append(entry)
            }
        }
        groups.append(current)

        return groups.reversed().map { group in
            UnassignedCluster(
                name: group.count > 1 ? TripNaming.suggestedName(for: group, locale: locale) : nil,
                dateRange: group.first!.createdAt...group.last!.createdAt,
                entries: group.reversed()
            )
        }
    }
}
