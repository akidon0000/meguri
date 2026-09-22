import Foundation

@testable import Meguri

enum FakeError: Error { case boom }

final class FakeGenerator: InsightGenerating, @unchecked Sendable {
    let availability: GeneratorAvailability
    let result: Result<Insight, any Error>
    let delay: Duration?
    private(set) var receivedPrompts: [String] = []

    init(
        availability: GeneratorAvailability = .available,
        result: Result<Insight, any Error> = .success(
            Insight(title: "t", creator: "", era: "", summary: "s", funFacts: [], category: .other)),
        delay: Duration? = nil
    ) {
        self.availability = availability
        self.result = result
        self.delay = delay
    }

    func generate(prompt: String) async throws -> Insight {
        receivedPrompts.append(prompt)
        if let delay {
            try? await Task.sleep(for: delay)
        }
        return try result.get()
    }
}
