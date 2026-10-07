import Foundation

public nonisolated extension Vocabulary {
    /// The deck or folder most recently practised, which home carries on with. Nil when
    /// nothing has been, or what was has since been deleted.
    var lastPractised: LessonSource? {
        let decks = decks.compactMap { deck in deck.lastPractisedAt.map { (LessonSource.deck(deck.id), $0) } }
        let folders = folders.compactMap { folder in folder.lastPractisedAt.map { (LessonSource.folder(folder.id), $0) } }
        return (decks + folders).max { $0.1 < $1.1 }?.0
    }

    /// When anything was last practised, so a newer practice can be noticed.
    var lastPractisedAt: Date? {
        (decks.compactMap(\.lastPractisedAt) + folders.compactMap(\.lastPractisedAt)).max()
    }

    /// Whether it still exists.
    func contains(_ source: LessonSource) -> Bool {
        switch source {
        case .deck(let id): deck(id: id) != nil
        case .folder(let id): folder(id: id) != nil
        }
    }

    /// Its words, every deck beneath a folder's, once each.
    func words(in source: LessonSource) -> [Word] {
        switch source {
        case .deck(let id): deck(id: id).map { words(in: $0) } ?? []
        case .folder(let id): folder(id: id).map { words(in: $0) } ?? []
        }
    }

    func name(of source: LessonSource) -> String? {
        switch source {
        case .deck(let id): deck(id: id)?.displayName
        case .folder(let id): folder(id: id)?.displayName
        }
    }
}
