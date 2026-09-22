import Foundation
import SwiftData
import Testing
import UIKit

@testable import Meguri

@Suite(.serialized) @MainActor struct AnalyzeViewModelTests {
    private let sampleInsight = Insight(
        title: "睡蓮", creator: "モネ", era: "1906", summary: "池。", funFacts: ["連作"], category: .artwork
    )

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
        FileImageStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(
                UUID().uuidString))
    }

    private func makeViewModel(
        context: ModelContext,
        perception: FakePerception = FakePerception(),
        generator: FakeGenerator = FakeGenerator(),
        location: FakeLocation = FakeLocation()
    ) -> AnalyzeViewModel {
        AnalyzeViewModel(
            perception: perception, generator: generator, location: location,
            imageStore: makeStore(), modelContext: context)
    }

    @Test func savesEntryWithInsightOnSuccess() async throws {
        let context = try makeContext()
        let generator = FakeGenerator(result: .success(sampleInsight))
        let perception = FakePerception(
            perception: Perception(labels: ["painting"], texts: ["Water Lilies"]))
        let location = FakeLocation(place: Place(name: "国立西洋美術館", latitude: 35.7, longitude: 139.8))
        let viewModel = makeViewModel(
            context: context, perception: perception, generator: generator, location: location)

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
        let generator = FakeGenerator(
            availability: .unavailable(reason: "Apple Intelligence is off"))
        let viewModel = makeViewModel(context: context, generator: generator)

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
        let viewModel = makeViewModel(context: context, generator: generator)

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
        let viewModel = makeViewModel(context: context, location: FakeLocation(place: nil))

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
            imageFileName: "x.jpg", thumbnailData: Data(), placeName: "Tokyo",
            perceivedLabels: ["castle"],
            recognizedTexts: [])
        entry.unavailableReason = "earlier failure"
        context.insert(entry)
        let viewModel = makeViewModel(context: context, generator: generator)

        await viewModel.regenerate(entry)

        #expect(entry.insight == sampleInsight)
        #expect(entry.unavailableReason == nil)
        #expect(generator.receivedPrompts.first?.contains("castle") == true)
    }

    @Test func regenerateClearsStaleInsightWhenGenerationFails() async throws {
        let context = try makeContext()
        let generator = FakeGenerator(result: .failure(FakeError.boom))
        let entry = Entry(imageFileName: "x.jpg", thumbnailData: Data())
        entry.insight = sampleInsight
        context.insert(entry)
        let viewModel = makeViewModel(context: context, generator: generator)

        await viewModel.regenerate(entry)

        #expect(entry.insight == nil)
        #expect(entry.unavailableReason?.isEmpty == false)
    }

    @Test func regenerateIgnoresConcurrentCall() async throws {
        let context = try makeContext()
        let generator = FakeGenerator(result: .success(sampleInsight), delay: .milliseconds(50))
        let entry = Entry(imageFileName: "x.jpg", thumbnailData: Data())
        context.insert(entry)
        let viewModel = makeViewModel(context: context, generator: generator)

        let first = Task { await viewModel.regenerate(entry) }
        try await Task.sleep(for: .milliseconds(10))
        await viewModel.regenerate(entry)
        await first.value

        #expect(generator.receivedPrompts.count == 1)
    }

    @Test func analyzeDoesNotInsertEntryUntilInsightIsResolved() async throws {
        let context = try makeContext()
        let generator = FakeGenerator(result: .success(sampleInsight), delay: .milliseconds(50))
        let viewModel = makeViewModel(context: context, generator: generator)

        let task = Task { await viewModel.analyze(makeImage()) }
        try await Task.sleep(for: .milliseconds(10))
        if case .generating = viewModel.phase {
            #expect(try context.fetch(FetchDescriptor<Entry>()).isEmpty)
        }
        await task.value

        #expect(try context.fetch(FetchDescriptor<Entry>()).count == 1)
    }

    @Test func ignoresSecondAnalyzeCall() async throws {
        let context = try makeContext()
        let viewModel = makeViewModel(context: context)

        await viewModel.analyze(makeImage())
        await viewModel.analyze(makeImage())

        #expect(try context.fetch(FetchDescriptor<Entry>()).count == 1)
    }

    @Test func startSurvivesCancellationOfCaller() async throws {
        let context = try makeContext()
        let viewModel = makeViewModel(context: context)

        let caller = Task { viewModel.start(makeImage()) }
        caller.cancel()
        await caller.value
        viewModel.start(makeImage())

        for _ in 0..<50 {
            if case .done = viewModel.phase { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        guard case .done = viewModel.phase else {
            Issue.record("expected .done, got \(viewModel.phase)")
            return
        }
        #expect(try context.fetch(FetchDescriptor<Entry>()).count == 1)
    }

    @Test func failsWhenPerceptionThrows() async throws {
        let context = try makeContext()
        let viewModel = makeViewModel(
            context: context, perception: FakePerception(error: FakeError.boom))

        await viewModel.analyze(makeImage())

        guard case .failed = viewModel.phase else {
            Issue.record("expected .failed, got \(viewModel.phase)")
            return
        }
        #expect(try context.fetch(FetchDescriptor<Entry>()).isEmpty)
    }
}
