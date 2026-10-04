import SwiftUI

/// A section title that folds its section, the same size for every section.
struct FoldingHeader: View {
    let title: String
    var systemImage: String?
    let isFolded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            withAnimation { onToggle() }
        } label: {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                }
                // Color.primary, not .primary, which a header resolves to its own grey.
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isFolded ? -90 : 0))
            }
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .accessibilityLabel("\(title), \(isFolded ? "folded" : "unfolded")")
        .accessibilityHint(isFolded ? "Unfolds the section" : "Folds the section")
    }
}
