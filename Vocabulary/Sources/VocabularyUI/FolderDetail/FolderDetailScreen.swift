import CoreDesignSystem
import SwiftUI
import VocabularyDomain

struct FolderDetailScreen: View {
    let state: FolderDetailState
    let onAction: (FolderDetailAction) -> Void

    var body: some View {
        List {
            Section {
                TextField(
                    "Folder name",
                    text: Binding(get: { state.name ?? "" }, set: { onAction(.nameChanged($0)) })
                )

                Button {
                    onAction(.startLessonTapped)
                } label: {
                    Text("Start lesson")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!state.canStartLesson)
            } footer: {
                if state.canStartLesson {
                    Text("A lesson draws from all \(state.wordCount) words in the decks inside.")
                } else {
                    Text("The decks inside need at least \(state.minimumMatchingWords) words between them.")
                }
            }

            Section {
                Button {
                    onAction(.moveTapped)
                } label: {
                    LabeledContent("Inside", value: state.location)
                }
                .tint(.primary)
                .disabled(state.moveUnavailableReason != nil)
            } footer: {
                if let reason = state.moveUnavailableReason {
                    Text(reason)
                }
            }

            Section {
                if state.isEmpty {
                    Text("Nothing here yet. Add a deck or a folder with the + button.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    FolderContents(
                        folders: state.folders,
                        decks: state.decks,
                        vocabulary: state.vocabulary,
                        minimumMatchingWords: state.minimumMatchingWords,
                        onPractiseFolder: { onAction(.practiseFolderTapped($0)) },
                        onPractiseDeck: { onAction(.practiseDeckTapped($0)) },
                        onDeleteFolder: { onAction(.deleteFolderTapped($0)) },
                        onDeleteDeck: { onAction(.deleteDeckTapped($0)) }
                    )
                }
            } header: {
                Text("Contents")
            }
        }
        .navigationTitle(state.title)
        .inlineNavigationTitle()
        .toolbar {
            NewItemMenu { onAction(.newItemTapped($0)) }
        }
        .newItemAlert(
            state.naming,
            name: state.newItemName,
            onNameChanged: { onAction(.newItemNameChanged($0)) },
            onCreate: { onAction(.createConfirmed) },
            onCancel: { onAction(.createCancelled) }
        )
        .folderDeletionDialog(
            state.deletionWarning,
            onConfirm: { onAction(.deleteFolderConfirmed) },
            onCancel: { onAction(.deleteFolderCancelled) }
        )
        .sheet(
            isPresented: Binding(
                get: { state.isChoosingDestination },
                set: { if !$0 { onAction(.moveCancelled) } }
            )
        ) {
            MoveDestinationPicker(
                title: "Move \(state.title)",
                destinations: state.destinations,
                onChoose: { onAction(.destinationChosen($0)) },
                onCancel: { onAction(.moveCancelled) }
            )
        }
    }
}
