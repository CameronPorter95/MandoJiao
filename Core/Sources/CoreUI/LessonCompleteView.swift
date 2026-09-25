import CoreDesignSystem
import SwiftUI

/// Shared review screen. Takes plain values rather than a session, so the matching
/// lesson and the speaking lesson both end on the same screen.
public struct LessonCompleteView: View {
    /// One word on the review screen. Its own type so Core never learns what a word is.
    public struct Row: Identifiable, Equatable {
        public let id: UUID
        public let hanzi: String
        public let english: String
        public let pinyin: String

        public init(id: UUID, hanzi: String, english: String, pinyin: String) {
            self.id = id
            self.hanzi = hanzi
            self.english = english
            self.pinyin = pinyin
        }
    }

    public struct Results {
        /// How many questions the lesson asked: matches for the board, cards for a speaking lesson.
        let total: Int
        let totalLabel: String
        /// Failed attempts, not failed words.
        let missCount: Int
        let missedPairs: [(pair: Row, misses: Int)]
        let cleanPairs: [Row]

        public init(total: Int, totalLabel: String, missCount: Int, missedPairs: [(pair: Row, misses: Int)], cleanPairs: [Row]) {
            self.total = total
            self.totalLabel = totalLabel
            self.missCount = missCount
            self.missedPairs = missedPairs
            self.cleanPairs = cleanPairs
        }
    }

    let results: Results
    let onPractiseAgain: () -> Void
    let onDone: () -> Void

    public init(results: Results, onPractiseAgain: @escaping () -> Void, onDone: @escaping () -> Void) {
        self.results = results
        self.onPractiseAgain = onPractiseAgain
        self.onDone = onDone
    }

    private var missedPairs: [(pair: Row, misses: Int)] { results.missedPairs }
    private var cleanPairs: [Row] { results.cleanPairs }

    private var accuracy: Int {
        let attempts = results.total + results.missCount
        guard attempts > 0 else { return 100 }
        return Int((Double(results.total) / Double(attempts) * 100).rounded())
    }

    public var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("做得好")
                    .font(.system(size: 40, weight: .semibold))
                Text("Lesson complete")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            HStack(spacing: 12) {
                stat(value: "\(results.total)", label: results.totalLabel)
                stat(value: "\(results.missCount)", label: results.missCount == 1 ? "miss" : "misses")
                stat(value: "\(accuracy)%", label: "accuracy")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !missedPairs.isEmpty {
                        section(
                            title: "Got wrong",
                            tint: Theme.miss,
                            rows: missedPairs.map { ($0.pair, $0.misses) }
                        )
                    }

                    if !cleanPairs.isEmpty {
                        section(
                            title: missedPairs.isEmpty ? "Words in this lesson" : "Got right",
                            tint: nil,
                            rows: cleanPairs.map { ($0, 0) }
                        )
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 10) {
                Button(action: onPractiseAgain) {
                    Text("Practise again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)

                Button("Done", action: onDone)
                    .font(.headline)
                    .tint(.secondary)
            }
            .padding(.bottom, 8)
        }
    }

    private func section(title: String, tint: Color?, rows: [(Row, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint ?? .secondary)
                Text("\(rows.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 6)

            ForEach(rows, id: \.0.id) { pair, misses in
                HStack(alignment: .firstTextBaseline) {
                    Text(pair.hanzi)
                        .font(.system(size: 20, weight: .medium))
                        .frame(minWidth: 52, alignment: .leading)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(pair.english)
                            .font(.subheadline)
                        if !pair.pinyin.isEmpty {
                            Text(pair.pinyin)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if misses > 1 {
                        Text("\(misses)x")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.miss)
                    }
                }
                .padding(.vertical, 7)
                Divider()
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
