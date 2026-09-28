import CoreUI
import SwiftUI

public struct HSKLevelsRoute: View {
    @State private var viewModel: HSKLevelsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var error: VocabularyError?

    public init(viewModel: HSKLevelsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        HSKLevelsScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .onAppear { viewModel.send(.appeared) }
            .onDisappear { viewModel.send(.disappeared) }
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
