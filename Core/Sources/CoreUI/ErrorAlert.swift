import SwiftUI

extension View {
    /// Shows `error` until dismissed, then clears it.
    public func errorAlert<E: LocalizedError>(_ error: Binding<E?>) -> some View {
        alert(
            "Something went wrong",
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            ),
            presenting: error.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.errorDescription ?? "Please try again.")
        }
    }
}
