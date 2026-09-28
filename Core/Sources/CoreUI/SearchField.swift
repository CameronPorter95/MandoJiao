import SwiftUI

extension View {
    /// `.searchable` over text the view owns, with each change handed on.
    ///
    /// Not a `Binding(get:set:)` into a view model: SwiftUI never saw the screen read it,
    /// so its copy went stale, and tapping clear on a field not being edited emptied it and
    /// then put the old query back as the field began editing.
    public func searchField(
        initial: String = "",
        prompt: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        modifier(SearchField(text: initial, prompt: prompt, onChange: onChange))
    }
}

private struct SearchField: ViewModifier {
    @State var text: String
    let prompt: String
    let onChange: (String) -> Void

    func body(content: Content) -> some View {
        content
            .searchable(text: $text, prompt: Text(prompt))
            .onChange(of: text) { _, new in onChange(new) }
    }
}
