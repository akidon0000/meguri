import Foundation
import FoundationModels

enum GeneratorAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)
}

protocol InsightGenerating: Sendable {
    var availability: GeneratorAvailability { get }
    func generate(prompt: String) async throws -> Insight
}

struct FoundationModelsInsightGenerator: InsightGenerating {
    var availability: GeneratorAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(reason: Self.describe(reason))
        }
    }

    func generate(prompt: String) async throws -> Insight {
        let session = LanguageModelSession(instructions: PromptBuilder.instructions)
        let response = try await session.respond(to: prompt, generating: Insight.self)
        return response.content
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return String(localized: "This device does not support Apple Intelligence.")
        case .appleIntelligenceNotEnabled:
            return String(localized: "Apple Intelligence is turned off. Enable it in Settings to get explanations.")
        case .modelNotReady:
            return String(localized: "The on-device model is still downloading. Try again in a while.")
        @unknown default:
            return String(localized: "Apple Intelligence is not available right now.")
        }
    }
}
