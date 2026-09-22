import Foundation
import Testing

@testable import Meguri

@Suite struct PlaceGroupingTests {
    private func makeEntry(place: String?, order: Int) -> Entry {
        Entry(imageFileName: "\(order).jpg", thumbnailData: Data(), placeName: place)
    }

    @Test func emptyInputProducesNoGroups() {
        #expect(PlaceGrouping.makeGroups(from: []).isEmpty)
    }

    @Test func groupsEntriesBySamePlaceName() {
        let entries = [makeEntry(place: "浅草寺", order: 0), makeEntry(place: "浅草寺", order: 1)]
        let groups = PlaceGrouping.makeGroups(from: entries)
        #expect(groups.count == 1)
        #expect(groups[0].entries.count == 2)
    }

    @Test func entriesWithoutPlaceNameFallIntoUnknownGroup() {
        let entries = [makeEntry(place: nil, order: 0)]
        let groups = PlaceGrouping.makeGroups(from: entries)
        #expect(groups.count == 1)
        #expect(groups[0].name == PlaceGrouping.unknownPlaceName)
    }

    @Test func emptyPlaceNameAlsoFallsIntoUnknownGroup() {
        let entries = [makeEntry(place: "", order: 0)]
        let groups = PlaceGrouping.makeGroups(from: entries)
        #expect(groups.count == 1)
        #expect(groups[0].name == PlaceGrouping.unknownPlaceName)
    }

    @Test func preservesFirstAppearanceOrderAcrossDistinctPlaces() {
        let entries = [
            makeEntry(place: "浅草寺", order: 0),
            makeEntry(place: "オランジュリー美術館", order: 1),
            makeEntry(place: "浅草寺", order: 2),
        ]
        let groups = PlaceGrouping.makeGroups(from: entries)
        #expect(groups.map { $0.name } == ["浅草寺", "オランジュリー美術館"])
    }
}
