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

    // Each request degrades to an empty result on its own: the simulator, for one, cannot run the classifier.
    func perceive(_ image: UIImage) async throws -> Perception {
        guard let cgImage = image.cgImage else { throw PerceptionError.noCGImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        async let labels = classify(cgImage, orientation: orientation)
        async let texts = recognizeText(cgImage, orientation: orientation)
        return await Perception(labels: labels, texts: texts)
    }

    private func classify(_ cgImage: CGImage, orientation: CGImagePropertyOrientation) async -> [String] {
        guard let observations = try? await ClassifyImageRequest().perform(on: cgImage, orientation: orientation)
        else { return [] }
        return observations
            .filter { $0.confidence >= minLabelConfidence }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxLabels)
            .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
    }

    private func recognizeText(_ cgImage: CGImage, orientation: CGImagePropertyOrientation) async -> [String] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        guard let observations = try? await request.perform(on: cgImage, orientation: orientation) else { return [] }
        return observations
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
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
