import Testing

@testable import Meguri

@Suite struct CategoryDisplayTests {
    @Test func everyCategoryHasNonEmptyDisplayName() {
        for category in Insight.Category.allCases {
            #expect(!category.displayName.isEmpty)
        }
    }

    @Test func everyCategoryHasNonEmptySystemImageName() {
        for category in Insight.Category.allCases {
            #expect(!category.systemImageName.isEmpty)
        }
    }

    @Test func categoriesHaveDistinctSystemImages() {
        let names = Insight.Category.allCases.map(\.systemImageName)
        #expect(Set(names).count == names.count)
    }
}
