import CoreUI
import SwiftUI

public struct SettingsRoute: View {
    @State private var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        SettingsScreen(state: viewModel.state, onAction: { viewModel.send($0) })
            .drivable { viewModel.driver() }
            .onAppear { viewModel.send(.appeared) }
    }
}
