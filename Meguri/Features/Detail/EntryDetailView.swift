import SwiftData
import SwiftUI

struct EntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: Entry
    @Query(sort: \Trip.name) private var trips: [Trip]

    @State private var isRegenerating = false
    @State private var confirmsDelete = false
    @State private var loadedImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photo
                if let insight = entry.insight {
                    insightCard(insight)
                } else {
                    unavailableCard
                }
                metadata
            }
            .padding()
        }
        .navigationTitle(entry.insight?.title ?? String(localized: "Untitled"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.meguriBackground)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    confirmsDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete this entry?", isPresented: $confirmsDelete, titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: delete)
        }
        .task(id: entry.imageFileName) {
            loadedImage = dependencies.imageStore.load(fileName: entry.imageFileName)
        }
    }

    private var photo: some View {
        Group {
            if let image = loadedImage ?? UIImage(data: entry.thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.secondary.opacity(0.2)
                    .aspectRatio(4 / 3, contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // The insight card below already conveys the subject in words; the photo is decorative for VoiceOver.
        .accessibilityHidden(true)
    }

    private func insightCard(_ insight: Insight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(insight.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.meguriInk)

            let byline = [insight.creator, insight.era].filter { !$0.isEmpty }.joined(
                separator: " · ")
            if !byline.isEmpty {
                Text(byline)
                    .font(.subheadline)
                    .foregroundStyle(Color.meguriSecondaryText)
            }

            Text(insight.summary)
                .font(.body)
                .foregroundStyle(Color.meguriInk)

            if !insight.funFacts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(insight.funFacts, id: \.self) { fact in
                        Label(fact, systemImage: "sparkle")
                            .font(.callout)
                    }
                }
                .padding(.top, 4)
            }

            CategoryBadge(category: insight.category)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.meguriSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.meguriBorder, lineWidth: 1)
        )
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("No explanation yet", systemImage: "sparkles.slash")
                .font(.headline)
            Text(
                entry.unavailableReason
                    ?? String(localized: "Apple Intelligence is not available right now.")
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            Button {
                Task { await regenerate() }
            } label: {
                if isRegenerating {
                    ProgressView()
                } else {
                    Label("Try again", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRegenerating)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.meguriSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.meguriBorder, lineWidth: 1)
        )
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let placeName = entry.placeName {
                Label(placeName, systemImage: "mappin.and.ellipse")
            }
            Label(entry.createdAt.formatted(date: .long, time: .shortened), systemImage: "calendar")
            if !entry.recognizedTexts.isEmpty {
                Label(
                    entry.recognizedTexts.joined(separator: " / "), systemImage: "text.viewfinder"
                )
                .lineLimit(3)
            }
            tripMenu
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var tripMenu: some View {
        Menu {
            Button(String(localized: "No trip")) { assignTrip(nil) }
            ForEach(trips) { trip in
                Button(trip.name) { assignTrip(trip) }
            }
            Button(String(localized: "Create a new trip")) {
                let trip = Trip(name: TripNaming.suggestedName(for: [entry], locale: .current))
                modelContext.insert(trip)
                assignTrip(trip)
            }
        } label: {
            Label(entry.trip?.name ?? String(localized: "No trip"), systemImage: "case.fill")
        }
    }

    private func assignTrip(_ trip: Trip?) {
        entry.trip = trip
        try? modelContext.save()
    }

    private func regenerate() async {
        isRegenerating = true
        defer { isRegenerating = false }
        let viewModel = dependencies.makeAnalyzeViewModel(modelContext: modelContext)
        await viewModel.regenerate(entry)
    }

    // Dismiss first: deleting a model this view still binds to can fault during the pop.
    private func delete() {
        let fileName = entry.imageFileName
        let context = modelContext
        let entry = entry
        dismiss()
        Task { @MainActor in
            dependencies.imageStore.delete(fileName: fileName)
            context.delete(entry)
            try? context.save()
        }
    }
}
