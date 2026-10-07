import CoreDesignSystem
import LibraryDomain
import SwiftUI

struct DeckRow: View {
    let deck: DeckSummary
    let vocabulary: Vocabulary
    let minimumMatchingWords: Int

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(deck.displayName)
                    .font(.body.weight(.medium))
                Text(vocabulary.subtitle(for: deck, minimumMatchingWords: minimumMatchingWords))
                    .font(.caption)
                    .foregroundStyle(
                        vocabulary.canStartLesson(with: deck, minimumMatchingWords: minimumMatchingWords)
                            ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.miss)
                    )
            }
        } icon: {
            Image(systemName: "rectangle.stack")
                .foregroundStyle(.secondary)
        }
    }
}
