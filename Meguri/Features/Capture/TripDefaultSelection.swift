import Foundation

enum TripSuggestion: Equatable {
    case existing(id: UUID, name: String)
    case newTrip(suggestedName: String)
}

enum TripDefaultSelection {
    static let recentWindowDays = 2

    static func suggest(
        for newEntry: Entry, among entries: [Entry], now: Date = .now, locale: Locale = .current
    ) -> TripSuggestion {
        let threshold = TimeInterval(recentWindowDays * 24 * 60 * 60)
        let lastAssigned = entries
            .filter { $0.trip != nil && $0.id != newEntry.id }
            .max { $0.createdAt < $1.createdAt }

        if let lastAssigned, let trip = lastAssigned.trip,
            now.timeIntervalSince(lastAssigned.createdAt) <= threshold
        {
            return .existing(id: trip.id, name: trip.name)
        }
        return .newTrip(suggestedName: TripNaming.suggestedName(for: [newEntry], locale: locale))
    }
}
