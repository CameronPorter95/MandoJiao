import DictionaryDomain
import Foundation

/// The learner's saved words as a list held in memory, streamed to every observer as it
/// changes, as the library's store would.
public actor FakeSavedReadingsRepository: SavedReadingsRepository {
    private var saved: [SavedReading]
    private var observers: [UUID: AsyncStream<[SavedReading]>.Continuation] = [:]

    public init(_ saved: [SavedReading] = []) {
        self.saved = saved
    }

    public nonisolated func savedReadings() -> AsyncStream<[SavedReading]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [SavedReading].self)
        let id = UUID()
        Task { await self.observe(id, continuation) }
        continuation.onTermination = { _ in Task { await self.stopObserving(id) } }
        return stream
    }

    public func save(hanzi: String, pinyin: String) {
        replace(saved + [SavedReading(id: UUID(), hanzi: hanzi, pinyin: pinyin)])
    }

    public func replace(_ saved: [SavedReading]) {
        self.saved = saved
        observers.values.forEach { $0.yield(saved) }
    }

    private func observe(_ id: UUID, _ continuation: AsyncStream<[SavedReading]>.Continuation) {
        observers[id] = continuation
        continuation.yield(saved)
    }

    private func stopObserving(_ id: UUID) {
        observers[id] = nil
    }
}
