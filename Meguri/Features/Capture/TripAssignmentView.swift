import SwiftData
import SwiftUI

struct TripAssignmentView: View {
    let entry: Entry
    let onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(Entry.newestFirst) private var allEntries: [Entry]
    @Query(sort: \Trip.name) private var trips: [Trip]

    @State private var newTripName = ""
    @State private var showsNewTripField = false

    private var suggestion: TripSuggestion {
        TripDefaultSelection.suggest(for: entry, among: allEntries)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        confirm(with: suggestion)
                    } label: {
                        Label(suggestionLabel, systemImage: "checkmark.circle.fill")
                    }
                }

                if !trips.isEmpty {
                    Section(String(localized: "Other trips")) {
                        ForEach(trips) { trip in
                            Button(trip.name) { assign(to: trip) }
                                .foregroundStyle(Color.meguriInk)
                        }
                    }
                }

                Section {
                    if showsNewTripField {
                        TextField(String(localized: "New trip name"), text: $newTripName)
                        Button(String(localized: "Create")) {
                            let trip = Trip(
                                name: newTripName.isEmpty ? suggestedNewTripName : newTripName)
                            modelContext.insert(trip)
                            assign(to: trip)
                        }
                    } else {
                        Button(String(localized: "Create a different trip")) {
                            newTripName = suggestedNewTripName
                            showsNewTripField = true
                        }
                        .foregroundStyle(Color.meguriInk)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        entry.trip = nil
                        try? modelContext.save()
                        onFinish()
                    } label: {
                        Text(String(localized: "Don't add to a trip"))
                    }
                }
            }
            .navigationTitle(String(localized: "Add to a trip"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var suggestedNewTripName: String {
        if case .newTrip(let name) = suggestion { return name }
        return ""
    }

    private var suggestionLabel: String {
        switch suggestion {
        case .existing(_, let name):
            String(format: String(localized: "Add to \"%@\""), name)
        case .newTrip(let name):
            String(format: String(localized: "Start a new trip: \"%@\""), name)
        }
    }

    private func confirm(with suggestion: TripSuggestion) {
        switch suggestion {
        case .existing(let id, _):
            if let trip = trips.first(where: { $0.id == id }) {
                assign(to: trip)
            }
        case .newTrip(let name):
            let trip = Trip(name: name)
            modelContext.insert(trip)
            assign(to: trip)
        }
    }

    private func assign(to trip: Trip) {
        entry.trip = trip
        try? modelContext.save()
        onFinish()
    }
}

#Preview {
    TripAssignmentView(entry: Entry(imageFileName: "x.jpg", thumbnailData: Data())) {}
        .modelContainer(for: [Entry.self, Trip.self], inMemory: true)
}
