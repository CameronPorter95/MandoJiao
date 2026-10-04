import SwiftUI

/// Room below a short list for the navigation bar's large title and search field to collapse
/// over it, and stay collapsed.
///
/// A list scrolls only as far as its content reaches, so over one shorter than the screen the
/// bar sprang back open when the finger lifted: the search field, once pulled down, could not
/// be put away. A deck long enough to scroll did not, which is how it was noticed.
public nonisolated enum BarCollapse {
    /// How far past its top a list can always scroll. The bar collapsed over 112 points on an
    /// iPhone 17 Pro at the default text size; the rest is slack for larger text.
    public static let room: CGFloat = 120

    /// The empty space to add below the content, nothing once it is long enough on its own.
    /// `bottom` is the inset without that space.
    public static func extra(container: CGFloat, content: CGFloat, top: CGFloat, bottom: CGFloat) -> CGFloat {
        max(0, container - content - top - bottom + room)
    }
}

extension View {
    /// For a list under a large title or a search field, as `BarCollapse` explains.
    public func barCollapseRoom() -> some View {
        modifier(BarCollapseRoom())
    }
}

private struct BarCollapseRoom: ViewModifier {
    @State private var extra: CGFloat = 0

    private struct Measure: Equatable {
        let container: CGFloat
        let content: CGFloat
        let top: CGFloat
        let bottom: CGFloat
    }

    func body(content: Content) -> some View {
        content
            // Not contentMargins, which even at zero replaced an inset-grouped list's own
            // bottom margin, and which the geometry counts as content rather than inset.
            .safeAreaPadding(.bottom, extra)
            .onScrollGeometryChange(for: Measure.self) { geometry in
                Measure(
                    container: geometry.containerSize.height,
                    content: geometry.contentSize.height,
                    top: geometry.contentInsets.top,
                    bottom: geometry.contentInsets.bottom
                )
            } action: { _, measure in
                // The bottom inset includes the space already added.
                let needed = BarCollapse.extra(
                    container: measure.container,
                    content: measure.content,
                    top: measure.top,
                    bottom: measure.bottom - extra
                )
                if abs(needed - extra) > 0.5 { extra = needed }
            }
    }
}
