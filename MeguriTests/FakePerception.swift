import Foundation
import UIKit

@testable import Meguri

final class FakePerception: ImagePerceiving, @unchecked Sendable {
    let perception: Perception
    let error: (any Error)?

    init(
        perception: Perception = Perception(labels: ["label"], texts: []), error: (any Error)? = nil
    ) {
        self.perception = perception
        self.error = error
    }

    func perceive(_ image: UIImage) async throws -> Perception {
        if let error { throw error }
        return perception
    }
}
