import CoreDesignSystem
import CoreUI
import DictionaryDomain
import LibraryDomain
import PracticeDomain
import SwiftUI

/// Today's plan: progress through its steps, the step showing, and the review once it ends.
///
/// Mirrors the single exercises at the edges, down to the quit confirmation.
struct MixedLessonScreen: View {
    let state: MixedLessonState
    let onAction: (MixedLessonAction) -> Void
    /// A matching board, flash card or read-aloud step, built by the exercise that owns it.
    let step: (MixedStep) -> AnyView

    var body: some View {
        VStack(spacing: 0) {
            header

            if state.lesson.isFinished {
                LessonCompleteView(
                    results: results,
                    onPractiseAgain: { onAction(.practiseAgainTapped) },
                    onDone: { onAction(.closeTapped) }
                )
                .transition(.opacity)
            } else if let current = state.lesson.step {
                Group {
                    switch current {
                    case .teach(let word):
                        TeachWordView(word: word, example: state.examples[word.id]) { onAction(.stepCompleted([])) }
                    case .match, .flashcard, .readAloud:
                        step(current)
                    }
                }
                .id(state.lesson.stepIndex)
                .padding(.vertical, 8)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.lesson.stepIndex)
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity, alignment: .top)
        .confirmationDialog(
            "Quit today's plan?",
            isPresented: Binding(
                get: { state.isConfirmingQuit },
                set: { if !$0 { onAction(.quitCancelled) } }
            ),
            titleVisibility: .visible
        ) {
            Button("Quit", role: .destructive) { onAction(.quitConfirmed) }
            Button("Keep practising", role: .cancel) { onAction(.quitCancelled) }
        } message: {
            Text("Everything answered so far is still saved.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Button {
                    onAction(.closeTapped)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close today's plan")

                LessonProgressBar(progress: state.lesson.progress, exerciseCount: state.lesson.steps.count)

                Text("\(state.lesson.stepNumber)/\(state.lesson.steps.count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if state.lesson.stepIndex == 0, !state.lesson.isFinished {
                Text(state.lesson.plan.synopsis)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var results: LessonCompleteView.Results {
        let misses = state.lesson.missesByWordID
        let words = state.lesson.words
        let answered = Set(state.lesson.answers.map(\.wordID))
        return LessonCompleteView.Results(
            total: words.count,
            totalLabel: words.count == 1 ? "word" : "words",
            missCount: misses.values.reduce(0, +),
            missedPairs: words.compactMap { word in misses[word.id].map { (pair: word.reviewRow, misses: $0) } },
            cleanPairs: words.filter { answered.contains($0.id) && misses[$0.id] == nil }.map(\.reviewRow)
        )
    }
}

/// A new word, shown in full before anything asks it, with a sentence using it where there
/// is one.
struct TeachWordView: View {
    let word: WordPair
    let example: ExampleSentence?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            VStack(spacing: 10) {
                Text("New word")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(word.hanzi)
                    .font(.system(size: 72, weight: .medium))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if !word.pinyin.isEmpty {
                    Text(word.pinyin)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Text(word.english)
                    .font(.title3.weight(.semibold))
                    .padding(.top, 8)
                if !word.otherMeanings.isEmpty {
                    Text(word.otherMeanings.joined(separator: "; "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let example {
                    exampleView(example)
                        .padding(.top, 24)
                        .transition(.opacity)
                }
            }
            .multilineTextAlignment(.center)
            .animation(.easeInOut(duration: 0.2), value: example)
            Spacer(minLength: 12)
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func exampleView(_ example: ExampleSentence) -> some View {
        VStack(spacing: 6) {
            Text(highlighted(example.hanzi))
                .font(.title3)
            Text(example.pinyin)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(example.english)
                .font(.subheadline)
            if example.isGenerated {
                Label("AI-generated", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(example.isGenerated ? "AI-generated example" : "Example"): \(example.hanzi). \(example.english)")
    }

    /// The sentence with the word in the accent colour, wherever it appears.
    private func highlighted(_ sentence: String) -> AttributedString {
        var text = AttributedString(sentence)
        var searchStart = text.startIndex
        while let range = text[searchStart...].range(of: word.hanzi) {
            text[range].foregroundColor = Theme.accent
            searchStart = range.upperBound
        }
        return text
    }
}
