import Foundation
import Testing
@testable import CoreDesignSystem

@Suite("Bar collapse room")
struct BarCollapseTests {
    /// The numbers measured on an iPhone 17 Pro: a screen 874 points tall, the bar 228 with its
    /// large title and search field open, the tab bar 83.
    @Test("a list shorter than the screen gets just enough room to scroll the bar away")
    func shortList() {
        let extra = BarCollapse.extra(container: 874, content: 632, top: 228, bottom: 83)
        #expect(extra == 51)
        #expect(632 + extra + 228 + 83 - 874 == BarCollapse.room)
    }

    @Test("a list long enough to scroll the bar away gets nothing")
    func longList() {
        #expect(BarCollapse.extra(container: 874, content: 842.5, top: 116, bottom: 83) == 0)
    }

    /// As the bar collapses its inset shrinks and the room grows by as much, so the list can
    /// always go the same distance past its top, never further.
    @Test("the room past the top stays the same as the bar collapses")
    func steadyAsTheBarCollapses() {
        for top: CGFloat in [228, 176, 116] {
            let extra = BarCollapse.extra(container: 874, content: 159, top: top, bottom: 83)
            #expect(159 + extra + top + 83 - 874 == BarCollapse.room)
        }
    }
}
