import SwiftUI

struct EntryCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(entry.insight?.title ?? String(localized: "Untitled"))
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(entry.placeName ?? entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = UIImage(data: entry.thumbnailData) {
            Color.clear.overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
        } else {
            Color.secondary.opacity(0.2)
        }
    }
}
