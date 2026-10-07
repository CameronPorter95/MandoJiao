import CoreDesignSystem
import LibraryDomain
import SwiftUI

struct HSKLevelsScreen: View {
    let state: HSKLevelsState
    let onAction: (HSKLevelsAction) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if state.words == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(state.levels) { level in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.name)
                                    .font(.body.weight(.medium))
                                Text("\(level.wordCount) words in \(level.deckCount) decks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            trailing(for: level)
                        }
                    }
                } footer: {
                    Text("A level's decks go in the HSK folder, 50 or fewer words each, most common first. Words you already have are shared, not copied. Restore brings back deleted decks and leaves the ones you kept as they are. HSK 3.0, 2025 revision.")
                }
            }
            .navigationTitle("HSK levels")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onAction(.doneTapped) }
                }
            }
        }
    }

    @ViewBuilder
    private func trailing(for level: HSKLevelsState.Level) -> some View {
        if state.installing.contains(level.level) {
            ProgressView()
        } else {
            switch level.status {
            case .added:
                Label("Added", systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .missing(let count):
                Button(count == 1 ? "Restore 1 deck" : "Restore \(count) decks") { onAction(.installTapped(level.level)) }
                    .buttonStyle(.bordered)
            case .notAdded:
                Button("Add") { onAction(.installTapped(level.level)) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
