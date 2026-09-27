import SwiftUI

/// The prompts home and the folder screen share, so creating and deleting read alike.
extension View {
    func newItemAlert(
        _ kind: NewItemKind?,
        name: String,
        onNameChanged: @escaping (String) -> Void,
        onCreate: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        alert(
            kind?.title ?? "",
            isPresented: Binding(get: { kind != nil }, set: { if !$0 { onCancel() } })
        ) {
            TextField("Name", text: Binding(get: { name }, set: onNameChanged))
            Button("Create", action: onCreate)
            Button("Cancel", role: .cancel, action: onCancel)
        } message: {
            Text(kind?.message ?? "")
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

/// The + menu on home and the folder screen.
struct NewItemMenu: ToolbarContent {
    let onChoose: (NewItemKind) -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { onChoose(.deck) } label: { Label("New deck", systemImage: "rectangle.stack") }
                Button { onChoose(.folder) } label: { Label("New folder", systemImage: "folder") }
            } label: {
                Label("New", systemImage: "plus")
            }
        }
    }
}
