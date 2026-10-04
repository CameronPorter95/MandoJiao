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
        modifier(SearchField(text: initial, prompt: prompt, onChange: onChange, onPresentedChange: nil))
    }

    /// As above, also saying when the search opens and closes, so a screen can show results
    /// in place of its own content while it is open, before anything is typed.
    public func searchField(
        initial: String = "",
        prompt: String,
        onChange: @escaping (String) -> Void,
        onPresentedChange: @escaping (Bool) -> Void
    ) -> some View {
        modifier(SearchField(text: initial, prompt: prompt, onChange: onChange, onPresentedChange: onPresentedChange))
    }
}

private struct SearchField: ViewModifier {
    @State var text: String
    @State private var isPresented = false
    let prompt: String
    let onChange: (String) -> Void
    let onPresentedChange: ((Bool) -> Void)?

    func body(content: Content) -> some View {
        content
            .searchable(text: $text, isPresented: $isPresented, prompt: Text(prompt))
            .onChange(of: text) { _, new in onChange(new) }
            .onChange(of: isPresented) { _, new in onPresentedChange?(new) }
    }
}
