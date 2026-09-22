import Foundation
import Testing

@testable import Meguri

@Suite struct TripDefaultSelectionTests {
    private let reference = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeEntry(
        daysFromReference days: Double, place: String? = nil, trip: Trip? = nil
    ) -> Entry {
        let entry = Entry(
            imageFileName: "\(days).jpg", thumbnailData: Data(),
            createdAt: reference.addingTimeInterval(days * 24 * 60 * 60),
            placeName: place)
        entry.trip = trip
        return entry
    }

    @Test func suggestsNewTripWhenNoEntryHasATripYet() {
        let newEntry = makeEntry(daysFromReference: 10, place: "浅草寺")
        let suggestion = TripDefaultSelection.suggest(
            for: newEntry, among: [newEntry], now: reference.addingTimeInterval(10 * 24 * 60 * 60),
            locale: Locale(identifier: "ja_JP"))
        guard case .newTrip(let name) = suggestion else {
            Issue.record("expected .newTrip, got \(suggestion)")
            return
        }
        #expect(name.contains("浅草寺"))
    }

    @Test func suggestsLastUsedTripWhenWithinRecentWindow() {
        let trip = Trip(name: "パリ旅行")
        let assigned = makeEntry(daysFromReference: 0, trip: trip)
        let newEntry = makeEntry(daysFromReference: 1.5)
        let now = reference.addingTimeInterval(1.5 * 24 * 60 * 60)
        let suggestion = TripDefaultSelection.suggest(
            for: newEntry, among: [assigned, newEntry], now: now)
        #expect(suggestion == .existing(id: trip.id, name: "パリ旅行"))
    }

    @Test func suggestsNewTripWhenLastUsedTripIsBeyondRecentWindow() {
        let trip = Trip(name: "パリ旅行")
        let assigned = makeEntry(daysFromReference: 0, trip: trip)
        let newEntry = makeEntry(daysFromReference: 10, place: "東京タワー")
        let now = reference.addingTimeInterval(10 * 24 * 60 * 60)
        let suggestion = TripDefaultSelection.suggest(
            for: newEntry, among: [assigned, newEntry], now: now, locale: Locale(identifier: "ja_JP")
        )
        guard case .newTrip(let name) = suggestion else {
            Issue.record("expected .newTrip, got \(suggestion)")
            return
        }
        #expect(name.contains("東京タワー"))
    }

    @Test func staysWithinWindowAtExactlyTheThreshold() {
        let trip = Trip(name: "パリ旅行")
        let assigned = makeEntry(daysFromReference: 0, trip: trip)
        let newEntry = makeEntry(daysFromReference: Double(TripDefaultSelection.recentWindowDays))
        let now = reference.addingTimeInterval(
            Double(TripDefaultSelection.recentWindowDays) * 24 * 60 * 60)
        let suggestion = TripDefaultSelection.suggest(
            for: newEntry, among: [assigned, newEntry], now: now)
        #expect(suggestion == .existing(id: trip.id, name: "パリ旅行"))
    }

    @Test func ignoresTheNewEntryItselfWhenFindingTheLastUsedTrip() {
        let newEntry = makeEntry(daysFromReference: 0)
        let suggestion = TripDefaultSelection.suggest(
            for: newEntry, among: [newEntry], now: reference)
        guard case .newTrip = suggestion else {
            Issue.record("expected .newTrip, got \(suggestion)")
            return
        }
    }
}
