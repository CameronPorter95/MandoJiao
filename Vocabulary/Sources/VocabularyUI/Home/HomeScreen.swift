import CoreDesignSystem
import SwiftUI
import VocabularyDomain

struct HomeScreen: View {
    let state: HomeState
    let onAction: (HomeAction) -> Void

    var body: some View {
        List {
            Section {
                quickPracticeCard
            }

            if !state.mistakeWords.isEmpty {
                Section {
                    mistakesCard
                }
            }
        }
        .navigationTitle("MandoJiao")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink(value: HomeDestination.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .confirmationDialog(
            "Clear the mistakes list?",
            isPresented: Binding(
                get: { state.isConfirmingClear },
                set: { if !$0 { onAction(.clearMistakesCancelled) } }
            ),
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) { onAction(.clearMistakesConfirmed) }
            Button("Cancel", role: .cancel) { onAction(.clearMistakesCancelled) }
        } message: {
            Text("\(state.mistakeWords.count) words will be marked as learned.")
        }
    }

    // MARK: - Pieces

    private var quickPracticeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quick practice")
                    .font(.title3.bold())
                Text("\(state.quickPracticeRounds) rounds of \(state.minimumMatchingWords) pairs, drawn at random from all \(state.usableWordCount) words.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                onAction(.quickPracticeTapped)
            } label: {
                Text("Start lesson")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(!state.canStartQuickPractice)

            if !state.canStartQuickPractice {
                Text("Add at least \(state.minimumMatchingWords) words to start a lesson.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var mistakesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mistakes")
                    .font(.title3.bold())
                Text(state.mistakesSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    onAction(.practiseMistakesTapped)
                } label: {
                    Label("Practise mistakes", systemImage: "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.miss)

                Button("Clear") { onAction(.clearMistakesTapped) }
                    .font(.subheadline)
                    .tint(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        HomeScreen(
            state: HomeState(vocabulary: SampleVocabulary.previewVocabulary, minimumMatchingWords: 5, quickPracticeRounds: 10),
            onAction: { _ in }
        )
    }
}
