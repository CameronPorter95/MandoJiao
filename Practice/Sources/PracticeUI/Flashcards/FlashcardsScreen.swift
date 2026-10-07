import CoreDesignSystem
import CoreUI
import PracticeDomain
import SwiftUI
import VocabularyDomain

/// The flash card lesson: progress, the current card, and the review once it ends.
///
/// Mirrors the speaking and matching lessons at the edges, down to the quit confirmation.
struct FlashcardsScreen: View {
    let state: FlashcardsState
    let onAction: (FlashcardsAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let lesson = state.lesson {
                header(lesson)

                if lesson.isFinished {
                    LessonCompleteView(
                        results: results(for: lesson),
                        onPractiseAgain: { onAction(.practiseAgainTapped) },
                        onDone: { onAction(.closeTapped) }
                    )
                    .transition(.opacity)
                } else {
                    FlashcardView(
                        card: lesson.card,
                        phase: lesson.phase,
                        onSubmitTyped: { onAction(.typedAnswerSubmitted($0)) },
                        onPick: { onAction(.optionPicked($0)) },
                        onDontKnow: { onAction(.dontKnowTapped) },
                        onContinue: { onAction(.continueTapped) }
                    )
                    .id(lesson.cardIndex)
                    .padding(.vertical, 8)
                }
            } else {
                noWords
            }
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity, alignment: .top)
        .confirmationDialog(
            "Quit these flash cards?",
            isPresented: Binding(
                get: { state.isConfirmingQuit },
                set: { if !$0 { onAction(.quitCancelled) } }
            ),
            titleVisibility: .visible
        ) {
            Button("Quit", role: .destructive) { onAction(.quitConfirmed) }
            Button("Keep practising", role: .cancel) { onAction(.quitCancelled) }
        } message: {
            Text("Cards answered so far are still saved.")
        }
    }

    private func header(_ lesson: FlashcardLesson) -> some View {
        HStack(spacing: 16) {
            Button {
                onAction(.closeTapped)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close flash cards")

            LessonProgressBar(progress: lesson.progress, exerciseCount: lesson.plan.cardCount)

            Text("\(lesson.cardNumber)/\(lesson.plan.cardCount)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var noWords: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("No words to practise")
                .font(.title3.bold())
            Text("A flash card needs a word with both Hanzi and a meaning.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close") { onAction(.closeTapped) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            Spacer()
        }
    }

    private func results(for lesson: FlashcardLesson) -> LessonCompleteView.Results {
        LessonCompleteView.Results(
            total: lesson.plan.cardCount,
            totalLabel: lesson.plan.cardCount == 1 ? "card" : "cards",
            missCount: lesson.wrongCount,
            missedPairs: lesson.missedPairs.map { (pair: $0.pair.reviewRow, misses: $0.misses) },
            cleanPairs: lesson.clearedPairs.map(\.reviewRow)
        )
    }
}

private let previewWords = [
    WordPair(english: "water", hanzi: "水", pinyin: "shuǐ"),
    WordPair(english: "tea", hanzi: "茶", pinyin: "chá"),
    WordPair(english: "book", hanzi: "书", pinyin: "shū"),
    WordPair(english: "to drink", hanzi: "喝", pinyin: "hē", otherMeanings: ["to shout"]),
]

#Preview("Typed, showing English") {
    FlashcardsScreen(
        state: FlashcardsState(lesson: FlashcardLesson(plan: FlashcardPlan(title: "t", cards: [
            Flashcard(word: previewWords[3], direction: .englishToChinese, format: .typed),
        ]))),
        onAction: { _ in }
    )
}

#Preview("Picked, showing Chinese") {
    FlashcardsScreen(
        state: FlashcardsState(lesson: FlashcardLesson(plan: FlashcardPlan(title: "t", cards: [
            Flashcard(word: previewWords[0], direction: .chineseToEnglish, format: .picked(options: previewWords)),
        ]))),
        onAction: { _ in }
    )
}
