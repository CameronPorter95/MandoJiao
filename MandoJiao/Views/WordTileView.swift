import SwiftUI

struct WordTileView: View {
    let tile: Tile
    let pinyin: String?
    let isSelected: Bool
    let isMatched: Bool
    let isMissed: Bool
    let action: () -> Void

    @State private var shakeProgress: CGFloat = 0

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(tile.text)
                    .font(tile.side == .hanzi ? .system(size: 32, weight: .medium) : .system(size: 19, weight: .medium))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)

                // Pinyin is held back until the pair is solved, so the Hanzi
                // still has to be recognised on its own.
                if isMatched, tile.side == .hanzi, let pinyin, !pinyin.isEmpty {
                    Text(pinyin)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.tileMinHeight)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(background)
            .overlay(border)
            .contentShape(RoundedRectangle(cornerRadius: Theme.tileCorner))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isMatched ? .secondary : .primary)
        .opacity(isMatched ? 0.3 : 1)
        .scaleEffect(isSelected ? 1.03 : 1)
        .modifier(ShakeEffect(animatableData: shakeProgress))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        .animation(.easeOut(duration: 0.2), value: isMatched)
        .disabled(isMatched)
        .onChange(of: isMissed) { _, missed in
            guard missed else { return }
            shakeProgress = 0
            withAnimation(.linear(duration: 0.3)) { shakeProgress = 1 }
        }
        .accessibilityLabel(tile.text)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        if isMatched { return "matched" }
        return isSelected ? "selected" : "not selected"
    }

    private var strokeColor: Color {
        if isMissed { return Theme.miss }
        if isMatched { return Theme.success.opacity(0.5) }
        return isSelected ? Theme.accent : Color.primary.opacity(0.18)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: Theme.tileCorner)
            .fill(isSelected ? Theme.accent.opacity(0.16) : Color.primary.opacity(0.05))
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Theme.tileCorner)
            .strokeBorder(strokeColor, lineWidth: isSelected || isMissed ? 2.5 : 1.5)
    }
}

#Preview {
    let pair = WordPair(english: "to drink", hanzi: "喝", pinyin: "hē")
    return VStack(spacing: 12) {
        WordTileView(
            tile: Tile(pairID: pair.id, side: .english, text: pair.english),
            pinyin: pair.pinyin,
            isSelected: false,
            isMatched: false,
            isMissed: false
        ) {}
        WordTileView(
            tile: Tile(pairID: pair.id, side: .hanzi, text: pair.hanzi),
            pinyin: pair.pinyin,
            isSelected: true,
            isMatched: false,
            isMissed: false
        ) {}
        WordTileView(
            tile: Tile(pairID: pair.id, side: .hanzi, text: pair.hanzi),
            pinyin: pair.pinyin,
            isSelected: false,
            isMatched: true,
            isMissed: false
        ) {}
    }
    .padding()
}
