import SwiftUI

struct AnalyzingView: View {
    let image: UIImage
    @State var viewModel: AnalyzeViewModel
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
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
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
