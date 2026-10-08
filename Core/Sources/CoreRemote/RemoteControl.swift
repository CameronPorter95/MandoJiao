import CoreUI
import Foundation

/// Answers remote commands from the screens on show, settling after each so its knock-on work,
/// a push or a lesson presented, lands before the reply.
@MainActor
public final class RemoteControl {
    private let registry: ScreenRegistry
    private let transition: Duration

    /// `transition` outlasts a push, pop or dismissal: a screen leaves the registry only as its
    /// disappearance ends, and nothing on show changes in the meantime for the settle to see.
    public init(registry: ScreenRegistry, transition: Duration = .milliseconds(600)) {
        self.registry = registry
        self.transition = transition
    }

    private var top: ScreenDriver? { registry.screens.last ?? registry.app }

    public func handle(_ request: RemoteRequest) async -> RemoteReply {
        await settle()
        do {
            let lines = try await perform(request)
            await settle()
            if request.operation != .ls, request.operation != .state {
                try? await Task.sleep(for: transition)
                await settle()
            }
            return RemoteReply(lines: lines)
        } catch {
            await settle()
            return RemoteReply(error: "\(error)")
        }
    }

    private func perform(_ request: RemoteRequest) async throws -> [String] {
        switch request.operation {
        case .hello:
            return [Self.identity]
        case .ls:
            let screens = ([registry.app] + registry.screens.map(Optional.some)).compactMap { $0?.summary() }
            return screens + (top.map { ["actions: \($0.actions.joined(separator: ", "))"] } ?? [])
        case .state:
            return top?.dump().split(separator: "\n").map(String.init) ?? []
        case .send:
            guard let top, let action = request.action else { throw RemoteError.nothingOpen }
            try top.send(action, request.arguments.map { Data($0.utf8) })
        case .tab:
            guard let app = registry.app, let tab = request.tab else { throw RemoteError.notRemote }
            try app.open("tab", tab)
        case .open:
            guard let app = registry.app, let kind = request.kind, let query = request.query else { throw RemoteError.notRemote }
            try app.open("tab", "vocabulary")
            await settle()
            guard let vocabulary = registry.screens.last(where: { $0.name == "vocabulary" }) else { throw RemoteError.nothingOpen }
            try vocabulary.open(kind, query)
        case .back:
            if registry.app?.back() == true { return [] }
            guard registry.screens.reversed().contains(where: { $0.back() }) else { throw RemoteError.nothingToGoBackFrom }
        }
        return []
    }

    /// "MandoJiao on iPhone 17 Pro (056C9DBA)". Simulators put their name and id in the
    /// environment; a device does not.
    nonisolated static var identity: String {
        identity(
            app: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ProcessInfo.processInfo.processName,
            environment: ProcessInfo.processInfo.environment
        )
    }

    nonisolated static func identity(app: String, environment: [String: String]) -> String {
        guard let device = environment["SIMULATOR_DEVICE_NAME"] else { return "\(app), not on a simulator" }
        let id = environment["SIMULATOR_UDID"].map { " (\($0.prefix(8)))" } ?? ""
        return "\(app) on \(device)\(id)"
    }

    /// Until no screen is busy and what is on show stops changing. Gives up after ten seconds.
    private func settle() async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        var last = snapshot()
        var stableFor = 0
        while stableFor < 3 || registry.screens.contains(where: { $0.isBusy() }), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
            let now = snapshot()
            stableFor = now == last ? stableFor + 1 : 0
            last = now
        }
    }

    private func snapshot() -> String {
        ([registry.app] + registry.screens.map(Optional.some)).compactMap { $0?.dump() }.joined()
    }
}

enum RemoteError: Error, CustomStringConvertible {
    case nothingOpen
    case nothingToGoBackFrom
    case notRemote

    var description: String {
        switch self {
        case .nothingOpen: "nothing is open"
        case .nothingToGoBackFrom: "nothing to go back from"
        case .notRemote: "the app's navigation is not registered"
        }
    }
}
