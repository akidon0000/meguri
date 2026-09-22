import Foundation
import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class AnalyzeViewModel {
    enum Phase {
        case idle
        case perceiving
        case generating
        case done(Entry)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private var runningTask: Task<Void, Never>?

    private let perception: any ImagePerceiving
    private let generator: any InsightGenerating
    private let location: any LocationProviding
    private let imageStore: any ImageStoring
    private let modelContext: ModelContext
    private let locale: Locale

    init(
        perception: any ImagePerceiving,
        generator: any InsightGenerating,
        location: any LocationProviding,
        imageStore: any ImageStoring,
        modelContext: ModelContext,
        locale: Locale = .current
    ) {
        self.perception = perception
        self.generator = generator
        self.location = location
        self.imageStore = imageStore
        self.modelContext = modelContext
        self.locale = locale
    }

    // SwiftUI cancels and re-runs `.task` while a cover is presented; the work must outlive that.
    func start(_ image: UIImage) {
        guard runningTask == nil else { return }
        runningTask = Task { await analyze(image) }
    }

    func analyze(_ image: UIImage) async {
        guard case .idle = phase else { return }
        phase = .perceiving
        do {
            async let place = location.currentPlace()
            async let perceivedResult = perception.perceive(image)
            // Synchronous JPEG encode runs here, overlapping the awaits above rather than after them.
            let stored = try imageStore.save(image)
            let perceived = try await perceivedResult
            let resolvedPlace = await place

            let entry = Entry(
                imageFileName: stored.fileName,
                thumbnailData: stored.thumbnailData,
                placeName: resolvedPlace?.name,
                latitude: resolvedPlace?.latitude,
                longitude: resolvedPlace?.longitude,
                perceivedLabels: perceived.labels,
                recognizedTexts: perceived.texts)
            modelContext.insert(entry)

            phase = .generating
            await fillInsight(of: entry)
            do {
                try modelContext.save()
            } catch {
                modelContext.delete(entry)
                imageStore.delete(fileName: stored.fileName)
                throw error
            }
            phase = .done(entry)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func regenerate(_ entry: Entry) async {
        phase = .generating
        await fillInsight(of: entry)
        do {
            try modelContext.save()
            phase = .done(entry)
        } catch {
            // Unlike analyze(), there is no new entry/image to roll back here — the entry
            // already existed before this call. Only the save itself failed.
            phase = .failed(error.localizedDescription)
        }
    }

    private func fillInsight(of entry: Entry) async {
        // Clear any previous result up front so a failed retry can never leave a stale
        // insight on screen looking current.
        entry.insight = nil
        if case .unavailable(let reason) = generator.availability {
            entry.unavailableReason = reason
            return
        }
        let prompt = PromptBuilder.prompt(
            labels: entry.perceivedLabels, texts: entry.recognizedTexts, placeName: entry.placeName,
            locale: locale)
        do {
            entry.insight = try await generator.generate(prompt: prompt)
            entry.unavailableReason = nil
        } catch {
            entry.unavailableReason = error.localizedDescription
        }
    }
}
