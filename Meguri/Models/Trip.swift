import Foundation
import SwiftData

@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var name: String

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}
