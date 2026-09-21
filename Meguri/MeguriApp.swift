import SwiftData
import SwiftUI

@main
struct MeguriApp: App {
    var body: some Scene {
        WindowGroup {
            CollectionView()
        }
        .modelContainer(for: Entry.self)
    }
}
