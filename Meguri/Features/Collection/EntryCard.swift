import SwiftUI

struct EntryCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(Color.meguriSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.meguriBorder, lineWidth: 1)
                )
                .overlay(alignment: .bottomTrailing) {
                    if let category = entry.insight?.category {
                        CategoryBadge(category: category, compact: true)
                            .padding(6)
                    }
                }

            Text(entry.insight?.title ?? String(localized: "Untitled"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.meguriInk)
                .lineLimit(2)

            Text(entry.placeName ?? entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(Color.meguriSecondaryText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = UIImage(data: entry.thumbnailData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else {
            Color.secondary.opacity(0.2)
        }
    }
}

#Preview {
    EntryCard(entry: Entry(imageFileName: "x.jpg", thumbnailData: Data()))
        .padding()
        .background(Color.meguriBackground)
}
