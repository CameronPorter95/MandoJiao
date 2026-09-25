import Foundation

/// One-shot effects from a view model to its Route.
///
/// A Route's `.task` is cancelled whenever the view disappears, including when another
/// screen is pushed over it, and a cancelled consumer ends an `AsyncStream` for good.
/// So each appearance takes a fresh stream, and an effect sent while nobody is
/// listening waits for the next one.
@MainActor
public final class EffectChannel<Effect: Sendable> {
    private var continuation: AsyncStream<Effect>.Continuation?
    private var pending: [Effect] = []

    public init() {}

    /// Replaces any previous stream. There is only ever one consumer.
    public func stream() -> AsyncStream<Effect> {
        continuation?.finish()
        let (stream, continuation) = AsyncStream.makeStream(of: Effect.self)
        self.continuation = continuation
        pending.forEach { continuation.yield($0) }
        pending.removeAll()
        return stream
    }

    public func send(_ effect: Effect) {
        if case .enqueued = continuation?.yield(effect) { return }
        pending.append(effect)
    }
}

/// How a write went, so a view model can revert on failure and do nothing on cancel.
public enum WriteOutcome: Equatable {
    case succeeded
    case failed
    case cancelled
}
