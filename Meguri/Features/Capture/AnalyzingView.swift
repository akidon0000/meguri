import SwiftUI

struct AnalyzingView: View {
    let image: UIImage
    @State var viewModel: AnalyzeViewModel
    let onFinish: () -> Void

    @State private var pendingTripEntry: Entry?

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.meguriBackground)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onFinish)
                    }
                }
        }
        .task {
            viewModel.start(image)
        }
        .onChange(of: isDone) { _, isDone in
            guard isDone, case .done(let entry) = viewModel.phase else { return }
            pendingTripEntry = entry
        }
        .sheet(item: $pendingTripEntry) { entry in
            TripAssignmentView(entry: entry) {
                pendingTripEntry = nil
            }
        }
    }

    private var isDone: Bool {
        if case .done = viewModel.phase { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .perceiving:
            progress(String(localized: "Looking at the photo…"))
        case .generating:
            progress(String(localized: "Finding out what it is…"))
        case .done(let entry):
            EntryDetailView(entry: entry)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't read this photo", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Close", action: onFinish)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func progress(_ title: String) -> some View {
        VStack(spacing: 24) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                .accessibilityHidden(true)
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
