import CoreDesignSystem
import SwiftUI

/// How a set of words' strengths are spread: a bar from strongest to weakest, and the
/// counts. Shown for a deck, a folder and what Home carries on with. Takes any band type
/// with a title and a level, so Core never learns the library's.
public struct BandBreakdown: View {
    private struct Segment: Identifiable {
        let level: Int
        let title: String
        let count: Int
        var id: Int { level }
    }

    private let segments: [Segment]

    /// `order` is strongest first. Bands with no words are left out.
    public init<Band: Hashable>(counts: [Band: Int], order: [Band], title: (Band) -> String, level: (Band) -> Int) {
        segments = order.compactMap { band in
            guard let count = counts[band], count > 0 else { return nil }
            return Segment(level: level(band), title: title(band), count: count)
        }
    }

    private var total: Int { segments.map(\.count).reduce(0, +) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(segments) { segment in
                        Theme.strength(segment.level)
                            .opacity(segment.level == 0 ? 0.35 : 1)
                            .frame(width: max(4, geometry.size.width * CGFloat(segment.count) / CGFloat(max(total, 1))))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)
            Text(segments.map { "\($0.count) \($0.title.lowercased())" }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
