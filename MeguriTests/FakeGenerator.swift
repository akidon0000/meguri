import Foundation

@testable import Meguri

enum FakeError: Error { case boom }

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
