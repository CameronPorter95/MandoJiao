import CoreDesignSystem
import LibraryDomain
import SwiftUI

/// A folder something can move into, titled by its path, or the top level.
struct MoveDestination: Identifiable, Equatable {
    /// Nil for the top level.
    let folderID: UUID?
    let title: String
    var id: String { folderID?.uuidString ?? "top" }
}

struct MoveDestinationPicker: View {
    let title: String
    let destinations: [MoveDestination]
    let onChoose: (UUID?) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List(destinations) { destination in
                Button {
                    onChoose(destination.folderID)
                } label: {
                    Label(destination.title, systemImage: destination.folderID == nil ? "house" : "folder.fill")
                }
                .tint(.primary)
            }
            .navigationTitle(title)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
