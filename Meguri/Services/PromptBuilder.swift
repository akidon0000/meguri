import Foundation

enum PromptBuilder {
    static let instructions = """
        You are a knowledgeable, friendly museum and travel guide. You receive clues extracted from a photo: \
        text visible in the image (captions, plaques, signs), visual labels, and the place it was taken. \
        Identify what the photo most likely shows and explain its background for a curious visitor. \
        Prefer text clues over visual labels. Never invent specific names, dates, or facts you are not \
        confident about; when unsure, describe what is seen and say that the identification is uncertain.
        """

    static func prompt(labels: [String], texts: [String], placeName: String?, locale: Locale) -> String {
        var sections: [String] = []

        if !texts.isEmpty {
            sections.append("Text seen in the photo:\n" + texts.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !labels.isEmpty {
            sections.append("Visual labels: " + labels.joined(separator: ", "))
        }
        if let placeName, !placeName.isEmpty {
            sections.append("Taken at: \(placeName)")
        }
        if texts.isEmpty && labels.isEmpty {
            sections.append(
                "There is little information extracted from the photo. "
                    + "Describe in general terms what a visitor at this place would likely be looking at.")
        }
        sections.append("Answer in \(languageName(for: locale)).")

        return sections.joined(separator: "\n\n")
    }

    static func languageName(for locale: Locale) -> String {
        let code = locale.language.languageCode?.identifier ?? "en"
        return Locale(identifier: "en_US").localizedString(forLanguageCode: code) ?? "English"
    }
}
