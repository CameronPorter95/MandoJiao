import CoreUI
import SwiftUI

public struct WordEditorRoute: View {
    @State private var viewModel: WordEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var error: VocabularyError?

    public init(viewModel: WordEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        WordEditorScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .task {
                for await effect in viewModel.effects() {
                    switch effect {
                    case .dismiss: dismiss()
                    case .showError(let error): self.error = error
                    }
                }
            }
            .errorAlert($error)
    }
}
