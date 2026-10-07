import CoreDesignSystem
import CoreUI
import LibraryDomain
import SwiftUI

extension StrengthBand {
    /// Grey to green as a word grows stronger.
    var color: Color { Theme.strength(rawValue) }
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

extension BandBreakdown {
    /// The library's bands, strongest first.
    init(bandCounts: [StrengthBand: Int]) {
        self.init(counts: bandCounts, order: StrengthBand.allCases.reversed(), title: \.title, level: \.rawValue)
    }
}
