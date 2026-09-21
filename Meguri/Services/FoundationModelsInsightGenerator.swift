import Foundation
import FoundationModels

enum GeneratorAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)
}

struct InsightGenerationError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
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
        do {
            return try await session.respond(to: prompt, generating: Insight.self).content
        } catch let error as LanguageModelSession.GenerationError {
            throw InsightGenerationError(message: Self.describe(error))
        } catch {
            throw InsightGenerationError(
                message: String(localized: "The model couldn't produce an explanation this time.")
                    + " (\(error.localizedDescription))")
        }
    }

    private static func describe(_ error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .guardrailViolation, .refusal:
            return String(localized: "The model declined to describe this photo.")
        case .rateLimited, .concurrentRequests:
            return String(localized: "Too many requests right now. Try again in a moment.")
        case .assetsUnavailable:
            return String(
                localized: "The on-device model is still downloading. Try again in a while.")
        case .unsupportedLanguageOrLocale:
            return String(localized: "Your language isn't supported by the on-device model yet.")
        default:
            return String(localized: "The model couldn't produce an explanation this time.")
        }
    }

    private static func describe(
        _ reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
        switch reason {
        case .deviceNotEligible:
            return String(localized: "This device does not support Apple Intelligence.")
        case .appleIntelligenceNotEnabled:
            return String(
                localized:
                    "Apple Intelligence is turned off. Enable it in Settings to get explanations.")
        case .modelNotReady:
            return String(
                localized: "The on-device model is still downloading. Try again in a while.")
        @unknown default:
            return String(localized: "Apple Intelligence is not available right now.")
        }
    }
}
