import SwiftUI

struct WordRow: View {
    let word: VocabWord

    var body: some View {
        HStack(spacing: 12) {
            Text(word.hanzi.isEmpty ? "?" : word.hanzi)
                .font(.system(size: 22, weight: .medium))
                .frame(minWidth: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(word.english.isEmpty ? "Untitled" : word.english)
                    .font(.body)
                if !word.pinyin.isEmpty {
                    Text(word.pinyin)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if word.missCount > 0 {
                Text("\(word.missCount)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.miss))
                    .accessibilityLabel("\(word.missCount) outstanding mistakes")
            }
        }
    }
}
