import CoreDomain
import Foundation
import LibraryDomain

/// JSON under one key. A value that no longer decodes starts the library folded, rather
/// than failing, since it is only a view preference.
public nonisolated struct LibraryLayoutRepositoryImpl: LibraryLayoutRepository {
    /// Documented as thread-safe, though not marked `Sendable`.
    nonisolated(unsafe) let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func layout() -> LibraryLayout {
        guard let data = defaults.data(forKey: Preferences.Key.libraryLayout) else { return LibraryLayout() }
        return (try? JSONDecoder().decode(LibraryLayout.self, from: data)) ?? LibraryLayout()
    }

    public func save(_ layout: LibraryLayout) {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        defaults.set(data, forKey: Preferences.Key.libraryLayout)
    }
}
