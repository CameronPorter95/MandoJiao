import SwiftUI

/// The screens on show in the running app, for driving it remotely. Each offers its driver as it
/// appears and takes it back as it disappears, so the last is the screen in front.
///
/// Only `send`, `summary`, `dump`, `back` and `open` are used from these drivers. The Route keeps
/// following the screen's effects, so the app navigates as if tapped, and the views show the stack.
@MainActor
public final class ScreenRegistry {
    public private(set) var screens: [ScreenDriver] = []
    private var ids: [UUID] = []
    /// The app's own navigation: the open tab and the lesson over it.
    public var app: ScreenDriver?

    public init() {}

    func register(_ driver: ScreenDriver, as id: UUID) {
        remove(id)
        ids.append(id)
        screens.append(driver)
    }

    func remove(_ id: UUID) {
        guard let index = ids.firstIndex(of: id) else { return }
        ids.remove(at: index)
        screens.remove(at: index)
    }
}

public extension EnvironmentValues {
    /// Nil unless the app was launched for remote driving.
    @Entry var screenRegistry: ScreenRegistry? = nil
}

public extension View {
    /// Offers this screen to remote driving while it shows. Does nothing otherwise.
    func drivable(_ makeDriver: @escaping () -> ScreenDriver) -> some View {
        modifier(Drivable(makeDriver: makeDriver))
    }
}

private struct Drivable: ViewModifier {
    let makeDriver: () -> ScreenDriver

    @Environment(\.screenRegistry) private var registry
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { registry?.register(makeDriver(), as: id) }
            .onDisappear { registry?.remove(id) }
    }
}
