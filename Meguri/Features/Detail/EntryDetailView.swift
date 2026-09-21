import SwiftData
import SwiftUI

struct EntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: Entry

    @State private var isRegenerating = false
    @State private var confirmsDelete = false

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
    }

    private var photo: some View {
        Group {
            if let image = dependencies.imageStore.load(fileName: entry.imageFileName)
                ?? UIImage(data: entry.thumbnailData)
            {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.secondary.opacity(0.2)
                    .aspectRatio(4 / 3, contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func insightCard(_ insight: Insight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(insight.title)
                .font(.title2.weight(.bold))

            let byline = [insight.creator, insight.era].filter { !$0.isEmpty }.joined(
                separator: " · ")
            if !byline.isEmpty {
                Text(byline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(insight.summary)
                .font(.body)

            if !insight.funFacts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(insight.funFacts, id: \.self) { fact in
                        Label(fact, systemImage: "sparkle")
                            .font(.callout)
                    }
                }
                .padding(.top, 4)
            }

            Text(categoryLabel(insight.category))
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.15), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            .background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .background(
            .background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func categoryLabel(_ category: Insight.Category) -> String {
        switch category {
        case .artwork: String(localized: "Artwork")
        case .landscape: String(localized: "Landscape")
        case .architecture: String(localized: "Architecture")
        case .other: String(localized: "Other")
        }
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
