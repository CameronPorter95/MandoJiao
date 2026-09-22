import SwiftUI

/// What a lesson is drawn from. Kept as detached pairs so the lesson is stable
/// even if the library is edited while it is open.
struct LessonRequest: Identifiable, Hashable {
    let id: UUID
    let title: String
    let pool: [WordPair]

    init(id: UUID = UUID(), title: String, pool: [WordPair]) {
        self.id = id
        self.title = title
        self.pool = pool
    }

    var canStart: Bool { pool.count >= LessonBuilder.pairsPerExercise }
}

struct LessonView: View {
    let request: LessonRequest
    let onClose: () -> Void

    @State private var session: LessonSession?
    @State private var isConfirmingQuit = false

    /// One setting for the whole board, kept across lessons and launches.
    @AppStorage("showsPinyinInLessons") private var showsPinyin = false

    var body: some View {
        VStack(spacing: 0) {
            if let session {
                header(session)

                if session.isFinished {
                    LessonCompleteView(session: session, onPractiseAgain: startLesson, onDone: onClose)
                        .transition(.opacity)
                } else {
                    board(session)
                }
            } else {
                notEnoughWords
            }
        }
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { if session == nil { startLesson() } }
        .sensoryFeedback(trigger: session?.feedbackToken ?? 0) { _, _ in
            feedback(for: session?.lastResult)
        }
        .confirmationDialog(
            "Quit this lesson?",
            isPresented: $isConfirmingQuit,
            titleVisibility: .visible
        ) {
            Button("Quit", role: .destructive, action: onClose)
            Button("Keep practising", role: .cancel) {}
        } message: {
            Text("Progress in this lesson will not be saved.")
        }
    }

    // MARK: - Pieces

    private func header(_ session: LessonSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                Button {
                    if session.isFinished || session.progress == 0 {
                        onClose()
                    } else {
                        isConfirmingQuit = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close lesson")

                LessonProgressBar(progress: session.progress, exerciseCount: session.plan.exerciseCount)

                Text("\(session.exerciseNumber)/\(session.plan.exerciseCount)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if !session.isFinished {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tap the matching pairs")
                            .font(.title2.bold())
                        Text(request.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    pinyinToggle
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    /// Applies to every Hanzi tile on the board at once, rather than revealing
    /// one card at a time.
    private var pinyinToggle: some View {
        Button {
            showsPinyin.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: showsPinyin ? "eye.fill" : "eye.slash")
                Text("pīnyīn")
            }
            .font(.footnote.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(showsPinyin ? Theme.accent : .secondary)
        .accessibilityLabel(showsPinyin ? "Hide pinyin" : "Show pinyin")
    }

    private func board(_ session: LessonSession) -> some View {
        VStack {
            Spacer(minLength: 0)
            MatchBoardView(board: session.board, showsPinyin: showsPinyin) { tile in
                session.tap(tile)
            }
            .id(session.exerciseIndex)
            .transition(.opacity)
            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.2), value: session.exerciseIndex)
    }

    private var notEnoughWords: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "character.book.closed")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Not enough words yet")
                .font(.title3.bold())
            Text("A lesson needs at least \(LessonBuilder.pairsPerExercise) words. Add a few more to the library and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close", action: onClose)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            Spacer()
        }
    }

    // MARK: - Behaviour

    private func startLesson() {
        guard let plan = LessonBuilder.makeLesson(title: request.title, from: request.pool) else {
            session = nil
            return
        }
        session = LessonSession(plan: plan)
    }

    private func feedback(for result: TapResult?) -> SensoryFeedback? {
        switch result {
        case .matched(_, let boardComplete):
            return boardComplete ? .success : .impact(weight: .light)
        case .missed:
            return .error
        case .selected, .switched:
            return .selection
        case .deselected, .ignored, .none:
            return nil
        }
    }
}

#Preview {
    LessonView(
        request: LessonRequest(title: "All words", pool: SampleVocabulary.previewPairs),
        onClose: {}
    )
}
