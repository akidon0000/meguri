import SwiftUI

extension Insight.Category {
    var displayName: String {
        switch self {
        case .artwork: String(localized: "Artwork")
        case .sculpture: String(localized: "Sculpture")
        case .architecture: String(localized: "Architecture")
        case .nature: String(localized: "Nature")
        case .creature: String(localized: "Creature")
        case .streetscape: String(localized: "Streetscape")
        case .other: String(localized: "Other")
        }
    }

    var systemImageName: String {
        switch self {
        case .artwork: "paintpalette.fill"
        case .sculpture: "cube.fill"
        case .architecture: "building.columns.fill"
        case .nature: "leaf.fill"
        case .creature: "pawprint.fill"
        case .streetscape: "signpost.right.fill"
        case .other: "questionmark.circle.fill"
        }
    }
}

struct CategoryBadge: View {
    let category: Insight.Category
    var compact: Bool = false

    var body: some View {
        Group {
            if compact {
                Image(systemName: category.systemImageName)
                    .font(.caption2.weight(.semibold))
                    .padding(6)
                    .background(Color.meguriSurface, in: Circle())
                    .overlay(Circle().stroke(Color.meguriBorder, lineWidth: 1))
            } else {
                Label(category.displayName, systemImage: category.systemImageName)
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.meguriSurface, in: Capsule())
                    .overlay(Capsule().stroke(Color.meguriBorder, lineWidth: 1))
            }
        }
        .foregroundStyle(Color.meguriInk)
        .accessibilityLabel(category.displayName)
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(Insight.Category.allCases, id: \.self) { category in
            CategoryBadge(category: category)
        }
    }
    .padding()
    .background(Color.meguriBackground)
}
