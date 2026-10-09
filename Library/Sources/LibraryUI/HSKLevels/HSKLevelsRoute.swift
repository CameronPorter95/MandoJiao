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
            .drivable { viewModel.driver(dismiss: { dismiss() }) }
            .onAppear { viewModel.send(.appeared) }
            .onDisappear { viewModel.send(.disappeared) }
            .task {
                for await effect in viewModel.effects() {
                    if case .showError(let error) = effect.followed(dismiss: { dismiss() }) { self.error = error }
                }
            }
            .errorAlert($error)
    }
}
