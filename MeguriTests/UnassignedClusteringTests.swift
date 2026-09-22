import Foundation
import Testing

@testable import Meguri

@Suite struct UnassignedClusteringTests {
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

    @Test func emptyInputProducesNoClusters() {
        #expect(UnassignedClustering.makeClusters(from: []).isEmpty)
    }

    @Test func singleEntryClusterHasNoName() {
        let clusters = UnassignedClustering.makeClusters(from: [makeEntry(daysFromReference: 0)])
        #expect(clusters.count == 1)
        #expect(clusters[0].name == nil)
        #expect(!clusters[0].displayTitle.isEmpty)
    }

    @Test func entriesWithinThresholdMergeIntoOneCluster() {
        let entries = [
            makeEntry(daysFromReference: 0, place: "パリ"),
            makeEntry(daysFromReference: 1, place: "パリ"),
            makeEntry(daysFromReference: 1.5, place: "パリ"),
        ]
        let clusters = UnassignedClustering.makeClusters(
            from: entries, locale: Locale(identifier: "ja_JP"))
        #expect(clusters.count == 1)
        #expect(clusters[0].entries.count == 3)
        #expect(clusters[0].name?.contains("パリ") == true)
    }

    @Test func gapBeyondThresholdSplitsIntoSeparateClusters() {
        let entries = [
            makeEntry(daysFromReference: 0),
            makeEntry(daysFromReference: 1),
            makeEntry(daysFromReference: 5),
            makeEntry(daysFromReference: 5.5),
        ]
        let clusters = UnassignedClustering.makeClusters(from: entries)
        #expect(clusters.count == 2)
    }

    @Test func gapExactlyAtThresholdStaysInSameCluster() {
        let entries = [
            makeEntry(daysFromReference: 0),
            makeEntry(daysFromReference: Double(UnassignedClustering.newClusterGapDays)),
        ]
        let clusters = UnassignedClustering.makeClusters(from: entries)
        #expect(clusters.count == 1)
    }

    @Test func newestClusterIsFirstAndEntriesWithinAClusterAreNewestFirst() {
        let entries = [
            makeEntry(daysFromReference: 0),
            makeEntry(daysFromReference: 0.5),
            makeEntry(daysFromReference: 10),
        ]
        let clusters = UnassignedClustering.makeClusters(from: entries)
        #expect(clusters.count == 2)
        #expect(clusters[0].entries.first?.imageFileName == "10.0.jpg")
        #expect(clusters[1].entries.map(\.imageFileName) == ["0.5.jpg", "0.0.jpg"])
    }

    @Test func representativePlaceBreaksTiesByFirstAppearance() {
        let entries = [
            makeEntry(daysFromReference: 0, place: "浅草寺"),
            makeEntry(daysFromReference: 0.2, place: "オランジュリー美術館"),
        ]
        let clusters = UnassignedClustering.makeClusters(
            from: entries, locale: Locale(identifier: "ja_JP"))
        #expect(clusters[0].name?.contains("浅草寺") == true)
    }

    // NOTE: UnassignedClustering.makeClusters always sorts entries by createdAt before
    // building groups, so a test that only swaps input order at the makeClusters level
    // cannot distinguish "chronological first-appearance" from "array first-appearance" --
    // the group TripNaming.suggestedName receives is already sorted by the time it gets
    // there. This test instead calls TripNaming.suggestedName directly with an
    // out-of-chronological-order array, which is the actual regression surface: a caller
    // (such as the later "suggest a name for a new trip" modal) may not pre-sort its input.
    @Test func suggestedNameBreaksTiesByChronologicalOrderRegardlessOfArrayOrder() {
        let entries = [
            makeEntry(daysFromReference: 0.2, place: "オランジュリー美術館"),
            makeEntry(daysFromReference: 0, place: "浅草寺"),
        ]
        let name = TripNaming.suggestedName(for: entries, locale: Locale(identifier: "ja_JP"))
        #expect(name.contains("浅草寺") == true)
    }

    @Test func generatesEnglishNameForNonJapaneseLocale() {
        let entries = [
            makeEntry(daysFromReference: 0, place: "Louvre"),
            makeEntry(daysFromReference: 0.5, place: "Louvre"),
        ]
        let clusters = UnassignedClustering.makeClusters(
            from: entries, locale: Locale(identifier: "en_US"))
        #expect(clusters[0].name?.contains("Louvre") == true)
        #expect(clusters[0].name?.contains("Trip") == true)
    }

    @Test func entriesAssignedToATripAreExcludedFromClusters() {
        let trip = Trip(name: "既存の旅")
        let entries = [
            makeEntry(daysFromReference: 0, trip: trip),
            makeEntry(daysFromReference: 0.5),
        ]
        let clusters = UnassignedClustering.makeClusters(from: entries)
        #expect(clusters.count == 1)
        #expect(clusters[0].entries.count == 1)
        #expect(clusters[0].entries[0].imageFileName == "0.5.jpg")
    }
}
