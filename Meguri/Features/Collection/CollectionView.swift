import PhotosUI
import SwiftData
import SwiftUI

struct CollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @Query(Entry.newestFirst) private var entries: [Entry]

    @State private var pickedItem: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var showsLibrary = false
    @State private var imageToAnalyze: PickedImage?
    @State private var showsLoadError = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .navigationTitle("Meguri")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addMenu
                }
            }
            .navigationDestination(for: Entry.self) { entry in
                EntryDetailView(entry: entry)
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { image in
                showsCamera = false
                imageToAnalyze = PickedImage(image: image)
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showsLibrary, selection: $pickedItem, matching: .images)
        .fullScreenCover(item: $imageToAnalyze) { picked in
            AnalyzingView(
                image: picked.image,
                viewModel: dependencies.makeAnalyzeViewModel(modelContext: modelContext)
            ) {
                imageToAnalyze = nil
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data)
                {
                    imageToAnalyze = PickedImage(image: image)
                } else {
                    showsLoadError = true
                }
                pickedItem = nil
            }
        }
        .alert("Couldn't load this photo", isPresented: $showsLoadError) {
            Button("OK", role: .cancel) {}
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(entries) { entry in
                    NavigationLink(value: entry) {
                        EntryCard(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Take your first photo", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text(
                "Point at a painting, a building, or a view. Meguri explains what it is and keeps it here."
            )
        } actions: {
            addMenu
                .buttonStyle(.borderedProminent)
        }
    }

    private var addMenu: some View {
        Menu {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showsCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }
            Button {
                showsLibrary = true
            } label: {
                Label("Choose from Library", systemImage: "photo")
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
    }
}

#Preview {
    CollectionView()
        .modelContainer(for: Entry.self, inMemory: true)
}
