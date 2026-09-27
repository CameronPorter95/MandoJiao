import SwiftUI

/// Prompts for creating and deleting, shared so they read alike wherever they appear.
extension View {
    /// A name prompt for creating or renaming. `confirm` is the button's title.
    func namingAlert(
        _ title: String,
        isPresented: Bool,
        name: String,
        message: String,
        confirm: String,
        onNameChanged: @escaping (String) -> Void,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        alert(title, isPresented: Binding(get: { isPresented }, set: { if !$0 { onCancel() } })) {
            TextField("Name", text: Binding(get: { name }, set: onNameChanged))
            Button(confirm, action: onConfirm)
            Button("Cancel", role: .cancel, action: onCancel)
        } message: {
            Text(message)
        }
    }

    func folderDeletionDialog(
        _ warning: String?,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        confirmationDialog(
            "Delete this folder?",
            isPresented: Binding(get: { warning != nil }, set: { if !$0 { onCancel() } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onConfirm)
            Button("Cancel", role: .cancel, action: onCancel)
        } message: {
            Text(warning ?? "")
        }
    }

}
