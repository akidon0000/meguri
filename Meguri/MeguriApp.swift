import SwiftData
import SwiftUI

@main
struct MeguriApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                CollectionView()
                    .tabItem { Label(String(localized: "Home"), systemImage: "house.fill") }
                CompendiumView()
                    .tabItem {
                        Label(String(localized: "Compendium"), systemImage: "books.vertical.fill")
                    }
            }
            .tint(Color.meguriSage)
        }
        .modelContainer(for: [Entry.self, Trip.self])
    }
}
