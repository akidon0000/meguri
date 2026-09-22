import Foundation

enum TripNaming {
    static func suggestedName(for entries: [Entry], locale: Locale = .current) -> String {
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        guard let first = sorted.first else { return "" }
        let month = monthFormatter(for: locale).string(from: first.createdAt)
        guard let place = representativePlace(in: entries) else {
            return isJapanese(locale) ? "\(month)の旅" : "\(month) Trip"
        }
        return isJapanese(locale) ? "\(month)の\(place)旅行" : "\(place) Trip, \(month)"
    }

    static func representativePlace(in entries: [Entry]) -> String? {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for entry in entries {
            guard let name = entry.placeName, !name.isEmpty else { continue }
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += 1
        }
        guard var best = order.first else { return nil }
        var bestCount = counts[best] ?? 0
        for name in order.dropFirst() {
            let count = counts[name] ?? 0
            if count > bestCount {
                best = name
                bestCount = count
            }
        }
        return best
    }

    static func isJapanese(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "ja"
    }

    static func monthFormatter(for locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter
    }
}
