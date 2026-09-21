import Foundation
import SwiftData
import Testing
import UIKit

@testable import Meguri

@Suite(.serialized) @MainActor struct AnalyzeViewModelTests {
    private let sampleInsight = Insight(
        title: "睡蓮", creator: "モネ", era: "1906", summary: "池。", funFacts: ["連作"], category: .artwork)

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Entry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
    }

    private func makeStore() -> FileImageStore {
        FileImageStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    private func makeViewModel(
        perception: FakePerception = FakePerception(),
        generator: FakeGenerator = FakeGenerator(),
        location: FakeLocation = FakeLocation(),
        context: ModelContext
    ) -> AnalyzeViewModel {
        AnalyzeViewModel(
            perception: perception, generator: generator, location: location,
            imageStore: makeStore(), modelContext: context)
    }

    @Test func savesEntryWithInsightOnSuccess() async throws {
        let context = try makeContext()
        let generator = FakeGenerator(result: .success(sampleInsight))
        let perception = FakePerception(perception: Perception(labels: ["painting"], texts: ["Water Lilies"]))
        let location = FakeLocation(place: Place(name: "国立西洋美術館", latitude: 35.7, longitude: 139.8))
        let viewModel = makeViewModel(
            perception: perception, generator: generator, location: location, context: context)

        await viewModel.analyze(makeImage())

        guard case .done(let entry) = viewModel.phase else {
            Issue.record("expected .done, got \(viewModel.phase)")
            return
        }
        #expect(entry.insight == sampleInsight)
        #expect(entry.placeName == "国立西洋美術館")
        #expect(entry.latitude == 35.7)
        #expect(entry.perceivedLabels == ["painting"])
        #expect(entry.recognizedTexts == ["Water Lilies"])
        #expect(entry.unavailableReason == nil)
        #expect(try context.fetch(FetchDescriptor<Entry>()).count == 1)
        #expect(generator.receivedPrompts.first?.contains("Water Lilies") == true)
        #expect(generator.receivedPrompts.first?.contains("国立西洋美術館") == true)
    }

    @Test func savesEntryWithoutInsightWhenGeneratorUnavailable() async throws {
        let context = try makeContext()
        let generator = FakeGenerator(availability: .unavailable(reason: "Apple Intelligence is off"))
        let viewModel = makeViewModel(generator: generator, context: context)

        await viewModel.analyze(makeImage())

        guard case .done(let entry) = viewModel.phase else {
            Issue.record("expected .done, got \(viewModel.phase)")
            return
        }
        #expect(entry.insight == nil)
        #expect(entry.unavailableReason == "Apple Intelligence is off")
        #expect(generator.receivedPrompts.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Entry>()).count == 1)
    }

    @Test func savesEntryAndRecordsErrorWhenGenerationThrows() async throws {
        let context = try makeContext()
        let generator = FakeGenerator(result: .failure(FakeError.boom))
        let viewModel = makeViewModel(generator: generator, context: context)

        await viewModel.analyze(makeImage())

        guard case .done(let entry) = viewModel.phase else {
            Issue.record("expected .done, got \(viewModel.phase)")
            return
        }
        #expect(entry.insight == nil)
        #expect(entry.unavailableReason?.isEmpty == false)
    }

    @Test func savesEntryWithoutPlaceWhenLocationUnknown() async throws {
        let context = try makeContext()
        let viewModel = makeViewModel(location: FakeLocation(place: nil), context: context)

        await viewModel.analyze(makeImage())

        guard case .done(let entry) = viewModel.phase else {
            Issue.record("expected .done, got \(viewModel.phase)")
            return
        }
        #expect(entry.placeName == nil)
        #expect(entry.latitude == nil)
    }

    @Test func regenerateFillsInsightOnExistingEntry() async throws {
        let context = try makeContext()
        let generator = FakeGenerator(result: .success(sampleInsight))
        let entry = Entry(
            imageFileName: "x.jpg", thumbnailData: Data(), placeName: "Tokyo", perceivedLabels: ["castle"],
            recognizedTexts: [])
        entry.unavailableReason = "earlier failure"
        context.insert(entry)
        let viewModel = makeViewModel(generator: generator, context: context)

        await viewModel.regenerate(entry)

        #expect(entry.insight == sampleInsight)
        #expect(entry.unavailableReason == nil)
        #expect(generator.receivedPrompts.first?.contains("castle") == true)
    }

    @Test func failsWhenPerceptionThrows() async throws {
        let context = try makeContext()
        let viewModel = makeViewModel(perception: FakePerception(error: FakeError.boom), context: context)

        await viewModel.analyze(makeImage())

        guard case .failed = viewModel.phase else {
            Issue.record("expected .failed, got \(viewModel.phase)")
            return
        }
        #expect(try context.fetch(FetchDescriptor<Entry>()).isEmpty)
    }
}

// MARK: - Fakes

enum FakeError: Error { case boom }

final class FakePerception: ImagePerceiving, @unchecked Sendable {
    let perception: Perception
    let error: (any Error)?

    init(perception: Perception = Perception(labels: ["label"], texts: []), error: (any Error)? = nil) {
        self.perception = perception
        self.error = error
    }

    func perceive(_ image: UIImage) async throws -> Perception {
        if let error { throw error }
        return perception
    }
}

final class FakeGenerator: InsightGenerating, @unchecked Sendable {
    let availability: GeneratorAvailability
    let result: Result<Insight, any Error>
    private(set) var receivedPrompts: [String] = []

    init(
        availability: GeneratorAvailability = .available,
        result: Result<Insight, any Error> = .success(
            Insight(title: "t", creator: "", era: "", summary: "s", funFacts: [], category: .other))
    ) {
        self.availability = availability
        self.result = result
    }

    func generate(prompt: String) async throws -> Insight {
        receivedPrompts.append(prompt)
        return try result.get()
    }
}

final class FakeLocation: LocationProviding, @unchecked Sendable {
    let place: Place?
    init(place: Place? = Place(name: "Somewhere", latitude: 1, longitude: 2)) { self.place = place }
    func currentPlace() async -> Place? { place }
}
