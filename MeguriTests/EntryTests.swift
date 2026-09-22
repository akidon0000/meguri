import Foundation
import SwiftData
import Testing

@testable import Meguri

@Suite struct EntryTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Entry.self, Trip.self, configurations: config)
        return ModelContext(container)
    }

    @Test func persistsInsightAsJSON() throws {
        let context = try makeContext()
        let insight = Insight(
            title: "睡蓮", creator: "モネ", era: "1906", summary: "池。", funFacts: [], category: .artwork
        )
        let entry = Entry(imageFileName: "a.jpg", thumbnailData: Data([1, 2, 3]))
        entry.insight = insight
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Entry>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.insight == insight)
        #expect(fetched.first?.imageFileName == "a.jpg")
    }

    @Test func insightIsNilWhenNotGenerated() throws {
        let entry = Entry(imageFileName: "b.jpg", thumbnailData: Data())
        #expect(entry.insight == nil)
        #expect(entry.unavailableReason == nil)
    }

    @Test func sortsNewestFirst() throws {
        let context = try makeContext()
        let old = Entry(
            imageFileName: "old.jpg", thumbnailData: Data(),
            createdAt: Date(timeIntervalSince1970: 1))
        let new = Entry(
            imageFileName: "new.jpg", thumbnailData: Data(),
            createdAt: Date(timeIntervalSince1970: 2))
        context.insert(old)
        context.insert(new)

        let fetched = try context.fetch(Entry.newestFirst)
        #expect(fetched.map(\.imageFileName) == ["new.jpg", "old.jpg"])
    }

    @Test func persistsTripRelationship() throws {
        let context = try makeContext()
        let trip = Trip(name: "パリ旅行")
        let entry = Entry(imageFileName: "a.jpg", thumbnailData: Data([1, 2, 3]))
        entry.trip = trip
        context.insert(trip)
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Entry>())
        #expect(fetched.first?.trip?.name == "パリ旅行")
    }

    @Test func tripIsNilByDefault() throws {
        let entry = Entry(imageFileName: "b.jpg", thumbnailData: Data())
        #expect(entry.trip == nil)
    }
}
