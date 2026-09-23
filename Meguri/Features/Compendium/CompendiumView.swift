import SwiftData
import SwiftUI

struct CompendiumView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case trips, places, categories, map
        var id: String { rawValue }

        var label: String {
            switch self {
            case .trips: String(localized: "Trips")
            case .places: String(localized: "Places")
            case .categories: String(localized: "Categories")
            case .map: String(localized: "Map")
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(Entry.newestFirst) private var entries: [Entry]
    @Query(sort: \Trip.name) private var trips: [Trip]
    @State private var mode: Mode = .trips

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                content
            }
            .background(Color.meguriBackground)
            .navigationTitle(String(localized: "Compendium"))
            .navigationDestination(for: Entry.self) { entry in
                EntryDetailView(entry: entry)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "Nothing collected yet"), systemImage: "books.vertical")
            }
        } else {
            switch mode {
            case .trips:
                EntryGroupListView(sections: tripSections, onRenameTrip: renameTrip)
            case .places:
                EntryGroupListView(sections: placeSections)
            case .categories:
                EntryGroupListView(sections: categorySections)
            case .map:
                EntryMapView(entries: entries)
            }
        }
    }

    private var tripSections: [EntryGroupSection] {
        let byTrip = Dictionary(grouping: entries.filter { $0.trip != nil }) { $0.trip!.id }
        let assignedSections = trips.compactMap { trip -> (Date, EntryGroupSection)? in
            guard let members = byTrip[trip.id], !members.isEmpty else { return nil }
            let latest = members.map(\.createdAt).max() ?? .distantPast
            return (
                latest,
                EntryGroupSection(
                    id: trip.id.uuidString, title: trip.name, entries: members, tripID: trip.id)
            )
        }
        .sorted { $0.0 > $1.0 }
        .map(\.1)

        let unassignedSections = UnassignedClustering.makeClusters(from: entries).map {
            EntryGroupSection(id: $0.id.description, title: $0.displayTitle, entries: $0.entries)
        }

        return assignedSections + unassignedSections
    }

    private var placeSections: [EntryGroupSection] {
        PlaceGrouping.makeGroups(from: entries).map {
            EntryGroupSection(id: $0.id, title: $0.name, entries: $0.entries)
        }
    }

    private var categorySections: [EntryGroupSection] {
        CategoryGrouping.makeGroups(from: entries).map {
            EntryGroupSection(id: $0.id, title: $0.displayTitle, entries: $0.entries)
        }
    }

    private func renameTrip(id: UUID, newName: String) {
        guard let trip = trips.first(where: { $0.id == id }), !newName.isEmpty else { return }
        trip.name = newName
        try? modelContext.save()
    }
}

#Preview {
    CompendiumView()
        .modelContainer(for: [Entry.self, Trip.self], inMemory: true)
}
