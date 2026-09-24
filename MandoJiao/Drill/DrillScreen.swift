import SwiftUI

/// The speech drill: progress, the current card, and the review once it ends.
///
/// Mirrors `LessonView` deliberately, down to the quit confirmation, so the two
/// exercises behave the same at the edges.
struct DrillScreen: View {
    let state: DrillState
    let onAction: (DrillAction) -> Void

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
                    card(lesson)
                }
            } else {
                noWords
            }
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity, alignment: .top)
        .confirmationDialog(
            "Quit this drill?",
            isPresented: Binding(
                get: { state.isConfirmingQuit },
                set: { if !$0 { onAction(.quitCancelled) } }
            ),
            titleVisibility: .visible
        ) {
            Button("Quit", role: .destructive) { onAction(.quitConfirmed) }
            Button("Keep practising", role: .cancel) { onAction(.quitCancelled) }
        } message: {
            Text("Mistakes so far are still added to your mistakes list.")
        }
    }

    // MARK: - Pieces

    private func header(_ lesson: DrillLesson) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Button {
                    onAction(.closeTapped)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close drill")

                LessonProgressBar(progress: lesson.progress, exerciseCount: lesson.plan.cardCount)

                Text("\(lesson.cardNumber)/\(lesson.plan.cardCount)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if !lesson.isFinished, let notice = state.availabilityNotice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func card(_ lesson: DrillLesson) -> some View {
        SpeakCardView(
            card: lesson.card,
            phase: lesson.phase,
            attemptsLeft: lesson.attemptsLeft,
            micState: state.mic,
            partialText: state.partialText,
            isTyping: state.isTyping,
            canListen: state.availability.canListen,
            onStartListening: { onAction(.startListeningTapped) },
            onStopListening: { onAction(.stopListeningTapped) },
            onSubmitTyped: { onAction(.typedAnswerSubmitted($0)) },
            onToggleTyping: { onAction(.typingToggled) },
            onContinue: { onAction(.continueTapped) }
        )
        .id(lesson.cardIndex)
        .padding(.vertical, 8)
    }

    private var noWords: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(Theme.success)
            Text("Nothing to drill")
                .font(.title3.bold())
            Text("There are no words on your mistakes list right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close") { onAction(.closeTapped) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            Spacer()
        }
    }

    private func results(for lesson: DrillLesson) -> LessonCompleteView.Results {
        LessonCompleteView.Results(
            total: lesson.plan.cardCount,
            totalLabel: lesson.plan.cardCount == 1 ? "card" : "cards",
            missCount: lesson.failedAttempts,
            missedPairs: lesson.missedPairs,
            cleanPairs: lesson.clearedPairs
        )
    }
}

private let previewLesson = DrillLesson(
    plan: SpeakPlan(title: "Mistakes", cards: [
        WordPair(english: "water", hanzi: "水", pinyin: "shuǐ"),
        WordPair(english: "mobile phone", hanzi: "手机", pinyin: "shǒujī"),
    ])
)

#Preview("Listening") {
    DrillScreen(
        state: DrillState(
            lesson: previewLesson,
            mic: .listening,
            partialText: "水",
            availability: .ready
        ),
        onAction: { _ in }
    )
}

#Preview("Downloading") {
    DrillScreen(
        state: DrillState(lesson: previewLesson, availability: .downloadingModel(progress: 0.4)),
        onAction: { _ in }
    )
}

#Preview("No words") {
    DrillScreen(state: DrillState(), onAction: { _ in })
}
