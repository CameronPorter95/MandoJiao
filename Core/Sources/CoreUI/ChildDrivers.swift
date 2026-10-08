import Foundation

/// The screens a driver shows in front of itself, alive while they stay in its stack.
///
/// Only the front one has appeared, as in a `NavigationStack`, where a screen covered by a push
/// disappears and appears again when uncovered. Its effects are followed while it is in front,
/// as its Route's `.task` follows them while it shows, and what is left over goes to `relay`.
@MainActor
public final class ChildDrivers<Key: Hashable> {
    /// Hand this to the parent's driver, whose effects then carry the front screen's too.
    public let relay = EffectRelay()

    private var alive: [Key: ScreenDriver] = [:]
    private var frontKey: Key?
    private var following: Task<Void, Never>?

    public init() {}

    /// `stack` is every screen that should be alive, bottom first, so the last is in front.
    public func front(of stack: [Key], make: (Key) -> ScreenDriver) -> ScreenDriver? {
        let kept = Set(stack)
        for (key, driver) in alive where !kept.contains(key) {
            if key == frontKey { hide(driver) }
            alive[key] = nil
        }
        if frontKey.map(kept.contains) == false { frontKey = nil }

        guard let key = stack.last else {
            if let previous = frontKey, let driver = alive[previous] { hide(driver) }
            frontKey = nil
            return nil
        }
        if key != frontKey {
            if let previous = frontKey, let driver = alive[previous] { hide(driver) }
            let driver = alive[key] ?? make(key)
            alive[key] = driver
            frontKey = key
            show(driver)
        }
        return alive[key]
    }

    private func show(_ driver: ScreenDriver) {
        try? driver.send("appeared", nil)
        let effects = driver.effects()
        following = Task { [relay] in
            for await effect in effects { relay.sink?(effect) }
        }
    }

    private func hide(_ driver: ScreenDriver) {
        following?.cancel()
        following = nil
        try? driver.send("disappeared", nil)
    }
}
