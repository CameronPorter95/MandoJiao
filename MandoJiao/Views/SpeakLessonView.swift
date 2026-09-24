import SwiftData
import SwiftUI

/// The speech drill shell: progress, microphone ownership, and writing results back.
///
/// Mirrors `LessonView` deliberately, down to the quit confirmation and the
/// idempotent result recording, so the two exercises behave the same at the edges.
struct SpeakLessonView: View {
    let request: LessonRequest
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var session: SpeakSession?
    @State private var recogniser: any SpeechRecognising
    @State private var isConfirmingQuit = false
    @State private var didRecordResults = false
    @State private var isListening = false
    @State private var isTyping = false
    @State private var listeningTask: Task<Void, Never>?

    @AppStorage(Preferences.Key.speechStrictness) private var strictnessRaw = MatchStrictness.default.rawValue
    @AppStorage(Preferences.Key.drillCardLimit) private var cardLimit = 20

    /// `recogniser` is injectable so the drill can be driven without a microphone.
    init(
        request: LessonRequest,
        recogniser: (any SpeechRecognising)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.request = request
        self.onClose = onClose
        _recogniser = State(initialValue: recogniser ?? DictationRecogniser())
    }

    var body: some View {
        VStack(spacing: 0) {
            if let session {
                header(session)

                if session.isFinished {
                    LessonCompleteView(
                        results: results(for: session),
                        onPractiseAgain: startLesson,
                        onDone: { close() }
                    )
                    .transition(.opacity)
                } else {
                    card(session)
                }
            } else {
                noWords
            }
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity, alignment: .top)
        .task { await prepare() }
        .onDisappear {
            listeningTask?.cancel()
            recogniser.cancel()
            ToneEngine.shared.exitRecordingMode()
        }
        // Losing the foreground mid-answer would otherwise leave the tap installed.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stopListening(submitting: false) }
        }
        .sensoryFeedback(trigger: session?.feedbackToken ?? 0) { _, _ in
            switch session?.phase {
            case .correct: return .success
            case .wrong, .exhausted: return .error
            case .idle, .none: return nil
            }
        }
        .onChange(of: session?.isFinished ?? false) { _, finished in
            if finished { recordResults() }
        }
        .confirmationDialog(
            "Quit this drill?",
            isPresented: $isConfirmingQuit,
            titleVisibility: .visible
        ) {
            Button("Quit", role: .destructive) { close() }
            Button("Keep practising", role: .cancel) {}
        } message: {
            Text("Mistakes so far are still added to your mistakes list.")
        }
    }

    // MARK: - Pieces

    private func header(_ session: SpeakSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Button {
                    if session.isFinished || session.progress == 0 {
                        close()
                    } else {
                        isConfirmingQuit = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close drill")

                LessonProgressBar(progress: session.progress, exerciseCount: session.plan.cardCount)

                Text("\(session.cardNumber)/\(session.plan.cardCount)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if !session.isFinished, let notice = availabilityNotice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func card(_ session: SpeakSession) -> some View {
        SpeakCardView(
            card: session.card,
            phase: session.phase,
            attemptsLeft: session.attemptsLeft,
            isListening: isListening,
            partialText: recogniser.partialText,
            isTyping: isTyping || !recogniser.availability.canListen,
            canListen: recogniser.availability.canListen,
            onStartListening: startListening,
            onStopListening: { stopListening(submitting: true) },
            onSubmitTyped: { session.submit($0) },
            onToggleTyping: { isTyping.toggle() },
            onContinue: { session.advance() }
        )
        .id(session.cardIndex)
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
            Button("Close", action: onClose)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            Spacer()
        }
    }

    private var availabilityNotice: String? {
        switch recogniser.availability {
        case .ready:
            return nil
        case .notPrepared:
            return "Getting the microphone ready…"
        case .needsPermission:
            return "Microphone access is off, so type your answers. Turn it on in Settings to speak them."
        case .downloadingModel(let progress):
            return "Downloading the Mandarin speech model, \(Int(progress * 100))%. You can type in the meantime."
        case .unsupported(let reason):
            return "\(reason) Type your answers instead."
        }
    }

    // MARK: - Microphone

    private func prepare() async {
        if session == nil { startLesson() }
        ToneEngine.shared.enterRecordingMode()
        let availability = await recogniser.prepare()
        // Fall straight into typing rather than showing a mic that cannot work.
        if !availability.canListen { isTyping = true }
    }

    private func startListening() {
        guard !isListening, recogniser.availability.canListen else { return }
        isListening = true

        listeningTask = Task {
            do {
                try await recogniser.start(hints: hints)
            } catch {
                isListening = false
                return
            }
            // Stops as soon as the transcript stops moving, rather than waiting out the
            // limit on every card.
            _ = await Endpointing.waitForEnd { recogniser.partialText }
            guard !Task.isCancelled else { return }
            stopListening(submitting: true)
        }
    }

    private func stopListening(submitting: Bool) {
        guard isListening else { return }
        isListening = false
        listeningTask?.cancel()
        listeningTask = nil

        Task {
            let outcome = await recogniser.stop()
            if submitting { session?.submit(outcome) }
        }
    }

    /// The expected answer, both ways round, biasing recognition toward this card.
    private var hints: [String] {
        guard let card = session?.card else { return [] }
        return [card.hanzi, card.pinyin].filter { !$0.isEmpty }
    }

    // MARK: - Behaviour

    private func startLesson() {
        recordResults()
        didRecordResults = false

        let plan = SpeakLessonBuilder.makeLesson(
            title: request.title,
            from: request.pool,
            maxCards: cardLimit
        )
        guard let plan else {
            session = nil
            return
        }
        session = SpeakSession(
            plan: plan,
            strictness: MatchStrictness(rawValue: strictnessRaw) ?? .default
        )
    }

    private func close() {
        stopListening(submitting: false)
        recordResults()
        onClose()
    }

    private func recordResults() {
        guard let session, !didRecordResults else { return }
        didRecordResults = true
        MistakeLog.apply(
            misses: session.missesByPairID,
            cleanSolves: session.cleanSolvesByPairID,
            in: context
        )
    }

    private func results(for session: SpeakSession) -> LessonCompleteView.Results {
        LessonCompleteView.Results(
            total: session.plan.cardCount,
            totalLabel: session.plan.cardCount == 1 ? "card" : "cards",
            missCount: session.failedAttempts,
            missedPairs: session.missedPairs,
            cleanPairs: session.clearedPairs
        )
    }
}
