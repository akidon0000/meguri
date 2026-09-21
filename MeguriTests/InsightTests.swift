import Foundation
import Testing

@testable import Meguri

@Suite struct InsightTests {
    @Test func roundTripsThroughJSON() throws {
        let original = Insight(
            title: "睡蓮",
            creator: "クロード・モネ",
            era: "1906年頃",
            summary: "ジヴェルニーの庭の池を描いた連作の一枚。",
            funFacts: ["連作は250点以上ある"],
            category: .artwork
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Insight.self, from: data)
        #expect(decoded == original)
    }
}
