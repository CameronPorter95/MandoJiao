import Foundation

/// Polls until `condition` holds, or gives up after `timeout`.
@MainActor
public func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while await !condition() {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return true
}

/// Long enough for any queued work to land, for asserting that something did not happen.
public func settle() async {
    try? await Task.sleep(for: .milliseconds(100))
}

/// Collects a view model's effects as they arrive.
@MainActor
public final class EffectLog<Effect: Equatable> {
    public private(set) var effects: [Effect] = []
    private var task: Task<Void, Never>?

    public init(_ stream: AsyncStream<Effect>) {
        task = Task { [weak self] in
            for await effect in stream { self?.effects.append(effect) }
        }
    }

    deinit { task?.cancel() }

    public func contains(_ effect: Effect) async -> Bool {
        await waitUntil { self.effects.contains(effect) }
    }

    public func equals(_ expected: [Effect]) async -> Bool {
        await waitUntil { self.effects == expected }
    }
}
