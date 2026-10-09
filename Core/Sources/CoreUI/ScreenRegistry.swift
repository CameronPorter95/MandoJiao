import SwiftUI

/// The screens on show in the running app, for driving it remotely. Each offers its driver as it
/// appears and takes it back as it disappears, so the last is the screen in front.
///
/// Only `send`, `summary`, `dump`, `back` and `open` are used from these drivers. The Route keeps
/// following the screen's effects, so the app navigates as if tapped, and the views show the stack.
@MainActor
public final class ScreenRegistry {
    public private(set) var screens: [ScreenDriver] = []
    /// Each screen's way out as SwiftUI gives it, for one pushed or presented: the way back when
    /// the screen beneath has disappeared and cannot pop it.
    public private(set) var dismissals: [() -> Bool] = []
    private var ids: [UUID] = []
    /// The app's own navigation: the open tab and the lesson over it.
    public var app: ScreenDriver?
    /// Queues an answer for the next listen to hear, when the app hears scripted speech.
    public var speak: ((String) -> Void)?

    public init() {}

    /// `dismiss` returns false when there is nothing to dismiss, the screen being no one's push.
    func register(_ driver: ScreenDriver, as id: UUID, dismiss: @escaping () -> Bool = { false }) {
        remove(id)
        ids.append(id)
        screens.append(driver)
        dismissals.append(dismiss)
    }

    func remove(_ id: UUID) {
        guard let index = ids.firstIndex(of: id) else { return }
        ids.remove(at: index)
        screens.remove(at: index)
        dismissals.remove(at: index)
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
    @Environment(\.isPresented) private var isPresented
    @Environment(\.dismiss) private var dismiss
    @State private var id = UUID()
    @State private var exit = Exit()

    func body(content: Content) -> some View {
        // Kept current on every update and read when back runs, not when the screen appears.
        exit.isPresented = isPresented
        exit.dismiss = dismiss
        return content
            .onAppear { [exit] in registry?.register(makeDriver(), as: id, dismiss: exit.leave) }
            .onDisappear { registry?.remove(id) }
    }
}

/// How a screen leaves as SwiftUI sees it, read when it is needed.
@MainActor
private final class Exit {
    var isPresented = false
    var dismiss: DismissAction?

    func leave() -> Bool {
        guard isPresented, let dismiss else { return false }
        dismiss()
        return true
    }
}
