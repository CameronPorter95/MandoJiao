import CoreDesignSystem
import CoreUI
import LibraryDomain
import SwiftUI

struct HomeScreen: View {
    let state: HomeState
    let onAction: (HomeAction) -> Void

    var body: some View {
        List {
            todayPlanSection
            continueSection

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
        .sheet(isPresented: Binding(
            get: { state.isChoosingSource },
            set: { if !$0 { onAction(.sourceChoiceDismissed) } }
        )) {
            SourcePicker(sections: state.sourceSections, current: state.current, onAction: onAction)
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

    /// Today's plan, chosen for how the vocabulary's strengths stand: one call to action,
    /// since there is one thing to do.
    @ViewBuilder
    private var todayPlanSection: some View {
        if let plan = state.todayPlan {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.title3.bold())
                        Text(plan.synopsis)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        onAction(.todayPlanTapped)
                    } label: {
                        Text("Start")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                }
                .padding(.vertical, 6)
            } header: {
                Text("Today's plan")
            }
        }
    }

    /// The deck or folder last practised, with an exercise to carry on with, or a way to
    /// choose one before anything has been practised.
    @ViewBuilder
    private var continueSection: some View {
        if let name = state.currentName {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.title3.bold())
                    Text(state.currentSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let current = state.current {
                        BandBreakdown(
                            counts: state.vocabulary.words(in: current).bandCounts(at: .now),
                            order: StrengthBand.allCases.reversed(),
                            title: \.title,
                            level: \.rawValue
                        )
                            .padding(.top, 6)
                    }
                }
                .padding(.vertical, 4)

                PractiseRows(wordCount: state.currentWordCount, minimumMatchingWords: state.minimumMatchingWords) {
                    onAction(.continueTapped($0))
                }

                Button("Practise another deck…") { onAction(.chooseSourceTapped) }
            } header: {
                Text("Continue")
            }
        } else if !state.sourceSections.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start practising")
                        .font(.title3.bold())
                    Text("Choose a deck or folder. The one you practise last stays here to carry on with.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                Button("Choose a deck…") { onAction(.chooseSourceTapped) }
            }
        }
    }

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

/// Every folder with words beneath it, each with its decks, in the library tree's order.
/// A folder's own row practises everything beneath it.
private struct SourcePicker: View {
    let sections: [HomeState.SourceSection]
    let current: LessonSource?
    let onAction: (HomeAction) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.title) {
                        row(
                            "All of \(section.folder.displayName)", systemImage: "folder",
                            wordCount: section.wordCount, source: .folder(section.folder.id)
                        )
                        ForEach(section.decks) { choice in
                            row(
                                choice.deck.displayName, systemImage: "rectangle.stack",
                                wordCount: choice.wordCount, source: .deck(choice.deck.id)
                            )
                        }
                    }
                }
            }
            .navigationTitle("Practise")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onAction(.sourceChoiceDismissed) }
                }
            }
        }
    }

    private func row(_ title: String, systemImage: String, wordCount: Int, source: LessonSource) -> some View {
        Button { onAction(.sourceChosen(source)) } label: {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(Color.primary)
                Spacer()
                Text("\(wordCount)")
                    .foregroundStyle(.secondary)
                if source == current {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .accessibilityAddTraits(source == current ? .isSelected : [])
    }
}
