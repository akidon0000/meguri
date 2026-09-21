import Foundation
import Testing
import UIKit

@testable import Meguri

@Suite struct FileImageStoreTests {
    private func makeStore() -> FileImageStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return FileImageStore(directory: dir)
    }

    private func makeImage(width: CGFloat = 2000, height: CGFloat = 1500) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func savesJPEGFileAndSmallThumbnail() throws {
        let store = makeStore()
        let stored = try store.save(makeImage())

        #expect(stored.fileName.hasSuffix(".jpg"))
        #expect(
            FileManager.default.fileExists(
                atPath: store.directory.appendingPathComponent(stored.fileName).path))

        let thumb = try #require(UIImage(data: stored.thumbnailData))
        #expect(max(thumb.size.width * thumb.scale, thumb.size.height * thumb.scale) <= 256)
    }

    @Test func loadsAndDeletesSavedImage() throws {
        let store = makeStore()
        let stored = try store.save(makeImage(width: 300, height: 200))

        #expect(store.load(fileName: stored.fileName) != nil)
        store.delete(fileName: stored.fileName)
        #expect(store.load(fileName: stored.fileName) == nil)
    }

    @Test func loadReturnsNilForUnknownFile() {
        #expect(makeStore().load(fileName: "missing.jpg") == nil)
    }
}
