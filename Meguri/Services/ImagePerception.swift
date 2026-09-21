import Foundation
import UIKit
import Vision

struct Perception: Sendable, Equatable {
    var labels: [String]
    var texts: [String]
}

protocol ImagePerceiving: Sendable {
    func perceive(_ image: UIImage) async throws -> Perception
}

enum PerceptionError: Error {
    case noCGImage
}

struct VisionImagePerception: ImagePerceiving {
    var maxLabels = 8
    var minLabelConfidence: Float = 0.3

    func perceive(_ image: UIImage) async throws -> Perception {
        guard let cgImage = image.cgImage else { throw PerceptionError.noCGImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        async let classifications = ClassifyImageRequest().perform(on: cgImage, orientation: orientation)
        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        async let texts = textRequest.perform(on: cgImage, orientation: orientation)

        let labels = try await classifications
            .filter { $0.confidence >= minLabelConfidence }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxLabels)
            .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }

        let lines = try await texts
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }

        return Perception(labels: Array(labels), texts: lines)
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
