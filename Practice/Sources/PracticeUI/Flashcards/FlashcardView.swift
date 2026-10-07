import CoreDesignSystem
import PracticeDomain
import SwiftUI
import VocabularyDomain

/// One flash card: the prompt, the answer control, and once answered, the word in full.
///
/// Presentational. `FlashcardsViewModel` owns the lesson.
struct FlashcardView: View {
    let card: Flashcard
    let phase: FlashcardLesson.Phase
    let onSubmitTyped: (String) -> Void
    let onPick: (UUID) -> Void
    let onDontKnow: () -> Void
    let onContinue: () -> Void

    @State private var typed = ""
    @FocusState private var isFieldFocused: Bool

    private var isAnswered: Bool { phase != .answering }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            prompt
                .padding(.bottom, 24)
            if isAnswered {
                verdict
                    .transition(.opacity)
            }
            Spacer(minLength: 12)
            control
        }
        .animation(.easeInOut(duration: 0.2), value: phase)
        .onAppear {
            if card.format == .typed { isFieldFocused = true }
        }
    }

    // MARK: - Prompt

    /// A card showing English lists every meaning, since the headline alone can fit
    /// several Chinese words.
    private var prompt: some View {
        VStack(spacing: 8) {
            Text(card.showsChinese ? "What does this mean?" : "Write this in Chinese")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if card.showsChinese {
                Text(card.word.hanzi)
                    .font(.system(size: 64, weight: .medium))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
            } else {
                Text(card.word.english)
                    .font(.system(size: 34, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                if !card.word.otherMeanings.isEmpty {
                    Text(card.word.otherMeanings.joined(separator: "; "))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Verdict

    @ViewBuilder
    private var verdict: some View {
        if case .answered(let isCorrect, let given) = phase {
            VStack(spacing: 10) {
                if !isCorrect, given.isEmpty {
                    Text("The answer is")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    Label(isCorrect ? "Correct" : "Not quite", systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(isCorrect ? Theme.success : Theme.miss)
                }
                if !isCorrect, !given.isEmpty, card.format == .typed {
                    Text("You wrote \(given)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                answer
            }
        }
    }

    /// The word in full, whichever way it was asked.
    private var answer: some View {
        VStack(spacing: 4) {
            Text(card.word.hanzi)
                .font(.system(size: 34, weight: .medium))
            if !card.word.pinyin.isEmpty {
                Text(card.word.pinyin)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Text(card.word.meanings.joined(separator: "; "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
    }

    // MARK: - Control

    @ViewBuilder
    private var control: some View {
        if isAnswered {
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .keyboardShortcut(.defaultAction)
        } else {
            VStack(spacing: 12) {
                switch card.format {
                case .typed: typingControl
                case .picked(let options): optionsControl(options)
                }
                // Counts as a mistake, and shows the answer.
                Button("Don't know") {
                    isFieldFocused = false
                    onDontKnow()
                }
                .font(.subheadline)
                .tint(.secondary)
            }
        }
    }

    private var typingControl: some View {
        VStack(spacing: 12) {
            TextField(card.showsChinese ? "English" : "汉字", text: $typed)
                .neverAutocapitalize()
                .autocorrectionDisabled()
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.tileCorner)
                        .fill(Color.primary.opacity(0.05))
                )
                .focused($isFieldFocused)
                .submitLabel(.done)
                .onSubmit(submitTyped)

            if !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !FlashcardGrader.canCheck(typed, for: card) {
                Text(card.showsChinese ? "Type the meaning in English." : "Type the characters, not pinyin or English.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(action: submitTyped) {
                Text("Check")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(!FlashcardGrader.canCheck(typed, for: card))
        }
    }

    /// Each option reads as the answer would: English for a card showing Chinese, Hanzi
    /// for one showing English.
    private func optionsControl(_ options: [WordPair]) -> some View {
        VStack(spacing: 10) {
            ForEach(options) { option in
                Button {
                    onPick(option.id)
                } label: {
                    Text(card.showsChinese ? option.english : option.hanzi)
                        .font(card.showsChinese ? .title3 : .system(size: 28, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
            }
        }
    }

    private func submitTyped() {
        guard FlashcardGrader.canCheck(typed, for: card) else { return }
        isFieldFocused = false
        onSubmitTyped(typed)
    }
}
