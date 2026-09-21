import Foundation
import UIKit

struct StoredImage: Sendable, Equatable {
    var fileName: String
    var thumbnailData: Data
}

protocol ImageStoring: Sendable {
    func save(_ image: UIImage) throws -> StoredImage
    func load(fileName: String) -> UIImage?
    func delete(fileName: String)
}

enum ImageStoreError: Error {
    case encodingFailed
}

final class FileImageStore: ImageStoring {
    let directory: URL
    private let thumbnailMaxSide: CGFloat = 256
    private let jpegQuality: CGFloat = 0.85

    static let `default` = FileImageStore(
        directory: URL.applicationSupportDirectory.appendingPathComponent("Images", isDirectory: true))

    init(directory: URL) {
        self.directory = directory
    }

    func save(_ image: UIImage) throws -> StoredImage {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard let jpeg = image.jpegData(compressionQuality: jpegQuality),
            let thumbnail = makeThumbnail(of: image).jpegData(compressionQuality: 0.8)
        else { throw ImageStoreError.encodingFailed }

        let fileName = UUID().uuidString + ".jpg"
        try jpeg.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        return StoredImage(fileName: fileName, thumbnailData: thumbnail)
    }

    func load(fileName: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }

    func delete(fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    // Renders at scale 1 so the longest side is at most thumbnailMaxSide pixels regardless of screen scale.
    private func makeThumbnail(of image: UIImage) -> UIImage {
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixelSize.width, pixelSize.height)
        let ratio = min(1, thumbnailMaxSide / longest)
        let target = CGSize(
            width: max(1, (pixelSize.width * ratio).rounded(.down)),
            height: max(1, (pixelSize.height * ratio).rounded(.down)))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
