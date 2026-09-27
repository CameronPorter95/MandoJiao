import CoreDesignSystem
import SwiftUI
import VocabularyDomain

struct FolderRow: View {
    let folder: FolderSummary
    let vocabulary: Vocabulary
    let minimumMatchingWords: Int

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.body.weight(.medium))
                Text(vocabulary.subtitle(for: folder, minimumMatchingWords: minimumMatchingWords))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "folder.fill")
                .foregroundStyle(Theme.accent)
        }
    }
}
