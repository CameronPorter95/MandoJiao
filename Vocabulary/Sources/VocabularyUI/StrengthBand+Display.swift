import CoreDesignSystem
import SwiftUI
import VocabularyDomain

extension StrengthBand {
    /// Grey to green as a word grows stronger.
    var color: Color {
        switch self {
        case .new: .secondary
        case .learning: Theme.accent
        case .familiar: .blue
        case .known: Theme.success
        }
    }
}

/// A word's band, small, beside the word.
struct StrengthBadge: View {
    let band: StrengthBand

    var body: some View {
        Text(band.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(band.color)
            .accessibilityLabel("Strength: \(band.title)")
    }
}

/// How a set of words' strengths are spread: a bar from strongest to weakest, and the
/// counts. Shown for a deck, a folder and what Home carries on with.
struct BandBreakdown: View {
    let counts: [StrengthBand: Int]

    private var total: Int { counts.values.reduce(0, +) }
    private var bands: [StrengthBand] { StrengthBand.allCases.reversed() }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(bands.filter { (counts[$0] ?? 0) > 0 }, id: \.self) { band in
                        band.color
                            .opacity(band == .new ? 0.35 : 1)
                            .frame(width: max(4, geometry.size.width * CGFloat(counts[band] ?? 0) / CGFloat(max(total, 1))))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)
            Text(bands.compactMap { band in
                (counts[band] ?? 0) > 0 ? "\(counts[band] ?? 0) \(band.title.lowercased())" : nil
            }.joined(separator: " · "))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
