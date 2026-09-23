import MapKit
import SwiftUI

struct EntryMapView: View {
    let entries: [Entry]

    private var located: [Entry] {
        entries.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        if located.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "No located entries"), systemImage: "map")
            } description: {
                Text(String(localized: "Entries with a location will show up here as pins."))
            }
        } else {
            Map {
                ForEach(located) { entry in
                    Annotation(
                        entry.insight?.title ?? "",
                        coordinate: CLLocationCoordinate2D(
                            latitude: entry.latitude!, longitude: entry.longitude!)
                    ) {
                        NavigationLink(value: entry) {
                            Circle()
                                .fill(Color.meguriAccent)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                        }
                    }
                }
            }
        }
    }
}
