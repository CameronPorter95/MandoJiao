import SwiftUI

/// What the microphone is doing.
///
/// `arming` exists because opening the microphone is not instant, and a button that says
/// it is listening before capture has started invites people to speak into nothing. The
/// first syllable then goes missing and comes back as a grunt.
enum MicState: Equatable {
    case idle
    case arming
    case listening
}

/// One speech card: the English prompt, the answer control, and the verdict.
///
/// Presentational. The lesson view owns the microphone and the session.
struct SpeakCardView: View {
    let card: WordPair
    let phase: SpeakSession.Phase
    let attemptsLeft: Int
    let micState: MicState
    let partialText: String
    let isTyping: Bool
    let canListen: Bool

    let onStartListening: () -> Void
    let onStopListening: () -> Void
    let onSubmitTyped: (String) -> Void
    let onToggleTyping: () -> Void
    let onContinue: () -> Void

    @State private var typed = ""
    @State private var shakeProgress: CGFloat = 0
    @FocusState private var isFieldFocused: Bool

    private var revealedPinyin: String {
        card.pinyin.isEmpty ? AnswerGrader.pinyinWithTones(card.hanzi) : card.pinyin
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            prompt
                .padding(.bottom, 28)

            // Reserved so the prompt does not jump when a verdict appears, and so an
            // unanswered card is not mostly empty space.
            verdict
                .frame(minHeight: 150)

            Spacer(minLength: 12)

            control
        }
        .animation(.easeInOut(duration: 0.2), value: phase)
        .animation(.easeInOut(duration: 0.2), value: isTyping)
        .onChange(of: phase) { _, new in
            if case .wrong = new {
                shakeProgress = 0
                withAnimation(.linear(duration: 0.3)) { shakeProgress = 1 }
            }
            if new == .idle { typed = "" }
        }
    }

    // MARK: - Prompt

    private var prompt: some View {
        VStack(spacing: 6) {
            Text("Say this in Chinese")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(card.english)
                .font(.system(size: 38, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
        }
    }

    // MARK: - Verdict

    @ViewBuilder
    private var verdict: some View {
        switch phase {
        case .idle:
            if micState == .listening, !partialText.isEmpty {
                heardText(partialText, tint: .secondary)
            } else {
                Color.clear.frame(height: 1)
            }

        case .wrong(let heard, let left):
            VStack(spacing: 10) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.miss)
                // Showing what was heard is what makes a wrong verdict believable
                // rather than the app just being difficult.
                if heard.isEmpty {
                    Text("Didn't catch that")
                        .font(.headline)
                } else {
                    heardText(heard, tint: Theme.miss)
                }
                Text(left == 1 ? "1 try left" : "\(left) tries left")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .modifier(ShakeEffect(animatableData: shakeProgress))

        case .correct:
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.success)
                answer
            }

        case .exhausted(let heard):
            VStack(spacing: 10) {
                Text("The answer was")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                answer
                if !heard.isEmpty {
                    heardText(heard, tint: Theme.miss)
                }
            }
        }
    }

    private var answer: some View {
        VStack(spacing: 4) {
            Text(card.hanzi)
                .font(.system(size: 48, weight: .medium))
            if !revealedPinyin.isEmpty {
                Text(revealedPinyin)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func heardText(_ text: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("heard")
                .font(.caption2)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.title3)
                .foregroundStyle(tint)
        }
    }

    // MARK: - Control

    @ViewBuilder
    private var control: some View {
        switch phase {
        case .correct:
            Color.clear.frame(height: 88)

        case .exhausted:
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)

        case .idle, .wrong:
            if isTyping {
                typingControl
            } else {
                micControl
            }
        }
    }

    private var micControl: some View {
        VStack(spacing: 14) {
            Button {
                micState == .listening ? onStopListening() : onStartListening()
            } label: {
                ZStack {
                    Circle()
                        .fill(micState == .idle ? Theme.accent : Theme.miss)
                        .frame(width: 88, height: 88)

                    switch micState {
                    case .idle:
                        Image(systemName: "mic.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.white)
                    case .arming:
                        ProgressView()
                            .tint(.white)
                    case .listening:
                        Image(systemName: "stop.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .overlay {
                    if micState == .listening {
                        Circle()
                            .stroke(Theme.miss.opacity(0.35), lineWidth: 3)
                            .frame(width: 112, height: 112)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(micState == .arming)
            .accessibilityLabel(micState == .listening ? "Stop listening" : "Start speaking")

            Text(micPrompt)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Type it instead", action: onToggleTyping)
                .font(.footnote)
                .tint(.secondary)
        }
    }

    private var typingControl: some View {
        VStack(spacing: 12) {
            TextField("pinyin or 汉字", text: $typed)
                .textInputAutocapitalization(.never)
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

            Button(action: submitTyped) {
                Text("Check")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if canListen {
                Button("Speak it instead", action: onToggleTyping)
                    .font(.footnote)
                    .tint(.secondary)
            }
        }
    }

    /// Waiting is stated rather than hidden: being told to hold on for a moment is better
    /// than being told to speak into a microphone that is not open yet.
    private var micPrompt: String {
        switch micState {
        case .idle: "Tap and say it out loud"
        case .arming: "Opening the microphone…"
        case .listening: "Listening, tap to stop"
        }
    }

    private func submitTyped() {
        let answer = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
        onSubmitTyped(answer)
        typed = ""
    }
}

#Preview("Idle") {
    SpeakCardView(
        card: WordPair(english: "water", hanzi: "水", pinyin: "shuǐ"),
        phase: .idle,
        attemptsLeft: 3,
        micState: .idle,
        partialText: "",
        isTyping: false,
        canListen: true,
        onStartListening: {},
        onStopListening: {},
        onSubmitTyped: { _ in },
        onToggleTyping: {},
        onContinue: {}
    )
    .padding(20)
}

#Preview("Wrong") {
    SpeakCardView(
        card: WordPair(english: "water", hanzi: "水", pinyin: "shuǐ"),
        phase: .wrong(heard: "茶", attemptsLeft: 2),
        attemptsLeft: 2,
        micState: .idle,
        partialText: "",
        isTyping: false,
        canListen: true,
        onStartListening: {},
        onStopListening: {},
        onSubmitTyped: { _ in },
        onToggleTyping: {},
        onContinue: {}
    )
    .padding(20)
}
