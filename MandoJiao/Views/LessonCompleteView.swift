import SwiftUI

struct LessonCompleteView: View {
    let session: LessonSession
    let onPractiseAgain: () -> Void
    let onDone: () -> Void

    private var totalMatches: Int {
        session.plan.exercises.reduce(0) { $0 + $1.count }
    }

    private var accuracy: Int {
        let attempts = totalMatches + session.missCount
        guard attempts > 0 else { return 100 }
        return Int((Double(totalMatches) / Double(attempts) * 100).rounded())
    }

    var body: some View {
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
                stat(value: "\(totalMatches)", label: "matches")
                stat(value: "\(session.missCount)", label: session.missCount == 1 ? "miss" : "misses")
                stat(value: "\(accuracy)%", label: "accuracy")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Words in this lesson")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(session.plan.distinctPairs.sorted { $0.english < $1.english }) { pair in
                            HStack(alignment: .firstTextBaseline) {
                                Text(pair.hanzi)
                                    .font(.system(size: 20, weight: .medium))
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
                            }
                            .padding(.vertical, 7)
                            Divider()
                        }
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
