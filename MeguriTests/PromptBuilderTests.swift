import Foundation
import Testing

@testable import Meguri

@Suite struct PromptBuilderTests {
    private let japanese = Locale(identifier: "ja_JP")

    @Test func includesRecognizedTextBeforeLabels() throws {
        let prompt = PromptBuilder.prompt(
            labels: ["painting", "water lily"],
            texts: ["Water Lilies, Claude Monet, 1906"],
            placeName: nil,
            locale: japanese
        )
        let textRange = try #require(prompt.range(of: "Water Lilies, Claude Monet, 1906"))
        let labelRange = try #require(prompt.range(of: "painting"))
        #expect(textRange.lowerBound < labelRange.lowerBound)
    }

    @Test func includesPlaceWhenKnown() {
        let prompt = PromptBuilder.prompt(labels: [], texts: [], placeName: "国立西洋美術館", locale: japanese)
        #expect(prompt.contains("国立西洋美術館"))
    }

    @Test func notesSparseInputWhenNothingPerceived() {
        let prompt = PromptBuilder.prompt(labels: [], texts: [], placeName: nil, locale: japanese)
        #expect(prompt.contains("little information"))
    }

    @Test func doesNotNoteSparseInputWhenLabelsExist() {
        let prompt = PromptBuilder.prompt(labels: ["castle"], texts: [], placeName: nil, locale: japanese)
        #expect(!prompt.contains("little information"))
    }

    @Test func requestsAnswerLanguageFromLocale() {
        #expect(PromptBuilder.prompt(labels: ["x"], texts: [], placeName: nil, locale: japanese).contains("Japanese"))
        #expect(
            PromptBuilder.prompt(labels: ["x"], texts: [], placeName: nil, locale: Locale(identifier: "en_US"))
                .contains("English"))
    }
}
