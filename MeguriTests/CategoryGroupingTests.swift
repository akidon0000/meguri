import Foundation
import Testing

@testable import Meguri

@Suite struct CategoryGroupingTests {
    private func makeEntry(category: Insight.Category?, order: Int) -> Entry {
        let entry = Entry(imageFileName: "\(order).jpg", thumbnailData: Data())
        if let category {
            entry.insight = Insight(
                title: "t", creator: "", era: "", summary: "s", funFacts: [], category: category)
        }
        return entry
    }

    @Test func emptyInputProducesNoGroups() {
        #expect(CategoryGrouping.makeGroups(from: []).isEmpty)
    }

    @Test func groupsFollowFixedTaxonomyOrderRegardlessOfInputOrder() {
        let entries = [
            makeEntry(category: .other, order: 0),
            makeEntry(category: .artwork, order: 1),
        ]
        let groups = CategoryGrouping.makeGroups(from: entries)
        #expect(groups.map(\.category) == [.artwork, .other])
    }

    @Test func entriesWithoutInsightGoToUnclassifiedGroupAtTheEnd() {
        let entries = [
            makeEntry(category: .artwork, order: 0),
            makeEntry(category: nil, order: 1),
        ]
        let groups = CategoryGrouping.makeGroups(from: entries)
        #expect(groups.count == 2)
        #expect(groups.last?.category == nil)
        #expect(groups.last?.entries.count == 1)
        #expect(groups.last?.displayTitle == String(localized: "Unclassified"))
    }

    @Test func omitsEmptyCategoriesFromTaxonomy() {
        let entries = [makeEntry(category: .nature, order: 0)]
        let groups = CategoryGrouping.makeGroups(from: entries)
        #expect(groups.count == 1)
        #expect(groups[0].category == .nature)
    }
}
