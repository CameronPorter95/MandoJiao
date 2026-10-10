import SwiftUI

/// The screens on show in the running app, for driving it remotely. Each offers its driver as it
/// appears and takes it back as it disappears, so the last is the screen in front.
///
/// Only `send`, `summary`, `dump`, `back` and `open` are used from these drivers. The Route keeps
/// following the screen's effects, so the app navigates as if tapped, and the views show the stack.
@MainActor
public final class ScreenRegistry {
    private struct Entry {
        let id: UUID
        let order: Int
        let driver: ScreenDriver
        let dismiss: () -> Bool
        let leaving: () -> Bool
    }

    private var entries: [Entry] = []
    /// When each screen first appeared, which is its place for as long as it lives.
    private var orders: [UUID: Int] = [:]
    private let transitioning: () -> Bool

    public var screens: [ScreenDriver] { entries.map(\.driver) }
    /// Each screen's way out as SwiftUI gives it, for one pushed or presented: the way back when
    /// the screen beneath has disappeared and cannot pop it.
    public var dismissals: [() -> Bool] { entries.map(\.dismiss) }
    /// The app's own navigation: the open tab and the lesson over it.
    public var app: ScreenDriver?
    /// Queues an answer for the next listen to hear, when the app hears scripted speech.
    public var speak: ((String) -> Void)?

    /// `transitioning` says whether the app is mid-animation, for one that runs in UIKit:
    /// `UIKitTransitions.inProgress`.
    public init(transitioning: @escaping () -> Bool = { false }) {
        self.transitioning = transitioning
    }

    /// Whether a screen has begun to go and is still animating out. It stays registered until
    /// its disappearance ends, so until then the registry is stale.
    public var isLeaving: Bool { entries.contains { $0.leaving() } }

    /// Whether a push, pop, presentation or dismissal is under way anywhere in the app.
    public var isTransitioning: Bool { transitioning() }

    /// `dismiss` returns false when there is nothing to dismiss, the screen being no one's push.
    /// A screen coming back into view keeps the place it first had: as a tab is reselected, a
    /// pushed screen can appear before the one it was pushed over.
    func register(
        _ driver: ScreenDriver, as id: UUID,
        dismiss: @escaping () -> Bool = { false }, leaving: @escaping () -> Bool = { false }
    ) {
        remove(id)
        let order = orders[id] ?? orders.count
        orders[id] = order
        let entry = Entry(id: id, order: order, driver: driver, dismiss: dismiss, leaving: leaving)
        entries.insert(entry, at: entries.firstIndex { $0.order > order } ?? entries.endIndex)
    }

    func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
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
            .background { if registry != nil { DisappearanceProbe(exit: exit) } }
            .onAppear { [exit] in
                registry?.register(makeDriver(), as: id, dismiss: exit.leave, leaving: { exit.isLeaving })
            }
            .onDisappear { registry?.remove(id) }
    }
}

/// How a screen leaves as SwiftUI sees it, read when it is needed.
@MainActor
private final class Exit {
    var isPresented = false
    var dismiss: DismissAction?
    /// While UIKit animates the screen out: a pop, a dismissal or a tab switch. SwiftUI says
    /// nothing until the end.
    var isLeaving = false

    func leave() -> Bool {
        guard isPresented, let dismiss else { return false }
        dismiss()
        return true
    }
}

#if canImport(UIKit)
import UIKit

/// Marks a screen leaving as its disappearance begins. A view controller set in a SwiftUI view
/// is a child of the screen's hosting controller, so UIKit tells it when the screen goes.
private struct DisappearanceProbe: UIViewControllerRepresentable {
    let exit: Exit

    func makeUIViewController(context: Context) -> Probe { Probe(exit: exit) }
    func updateUIViewController(_ controller: Probe, context: Context) {}

    final class Probe: UIViewController {
        private let exit: Exit

        init(exit: Exit) {
            self.exit = exit
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) { fatalError("not from a storyboard") }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            exit.isLeaving = false
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            exit.isLeaving = true
        }

        // SwiftUI does not always say a screen has gone, so the end is UIKit's word too.
        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            exit.isLeaving = false
        }
    }
}
/// UIKit's view of whether the app is mid-animation, for `ScreenRegistry(transitioning:)`.
public enum UIKitTransitions {
    public static func inProgress() -> Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .compactMap(\.rootViewController)
            .contains(where: isTransitioning)
    }

    private static func isTransitioning(_ controller: UIViewController) -> Bool {
        controller.transitionCoordinator != nil || controller.isBeingPresented || controller.isBeingDismissed
            || controller.children.contains(where: isTransitioning)
            || controller.presentedViewController.map(isTransitioning) == true
    }
}
#else
private struct DisappearanceProbe: View {
    let exit: Exit
    var body: some View { EmptyView() }
}
#endif
