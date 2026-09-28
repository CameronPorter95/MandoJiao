import SwiftUI

/// iOS-only view modifiers, wrapped so feature views compile on macOS without `#if`.
extension View {
    public func neverAutocapitalize() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    /// A split view's columns default to plain lists; this matches the app's other screens.
    public func insetGroupedList() -> some View {
        #if os(iOS)
        listStyle(.insetGrouped)
        #else
        self
        #endif
    }

    /// Reorder handles shown from the start, without an Edit button. macOS lists have no
    /// edit mode.
    public func alwaysEditing() -> some View {
        #if os(iOS)
        environment(\.editMode, .constant(.active))
        #else
        self
        #endif
    }

    public func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

/// The system Edit button on iOS. macOS lists have no edit mode, so it shows nothing there.
public struct EditModeButton: View {
    public init() {}

    public var body: some View {
        #if os(iOS)
        EditButton()
        #else
        EmptyView()
        #endif
    }
}
