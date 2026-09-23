import SwiftUI

struct EntryGroupSection: Identifiable {
    let id: String
    let title: String
    let entries: [Entry]
    var tripID: UUID? = nil
}

struct EntryGroupListView: View {
    let sections: [EntryGroupSection]
    var onRenameTrip: ((UUID, String) -> Void)? = nil

    @State private var renamingSection: EntryGroupSection?
    @State private var renameText = ""

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(Color.meguriInk)

                            if section.tripID != nil, onRenameTrip != nil {
                                Button {
                                    renameText = section.title
                                    renamingSection = section
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundStyle(Color.meguriSecondaryText)
                                }
                            }
                        }

                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(section.entries) { entry in
                                NavigationLink(value: entry) {
                                    EntryCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .alert(String(localized: "Rename trip"), isPresented: renamingBinding) {
            TextField(String(localized: "New trip name"), text: $renameText)
            Button(String(localized: "Save")) {
                if let tripID = renamingSection?.tripID {
                    onRenameTrip?(tripID, renameText)
                }
                renamingSection = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) { renamingSection = nil }
        }
    }

    private var renamingBinding: Binding<Bool> {
        Binding(get: { renamingSection != nil }, set: { if !$0 { renamingSection = nil } })
    }
}
