import Foundation
import SwiftData
import VocabularyDomain

/// Creates what a plan has and the store lacks. Seeding a fresh store and installing from
/// the app both come here, so they cannot build different trees.
nonisolated enum BuiltInInstaller {
    /// Everything made in one install shares a time, so decks sorted by date fall back to their
    /// names and list 1, 2, 3 rather than in the microseconds between them.
    static func install(_ plan: BuiltInPlan, in context: ModelContext, at time: Date = .now) throws {
        var folders = Dictionary(
            try context.fetch(FetchDescriptor<Folder>()).compactMap { folder in folder.builtInKey.map { ($0, folder) } },
            uniquingKeysWith: { first, _ in first }
        )
        for planned in plan.folders where folders[planned.key] == nil {
            let parent = planned.parentKey.flatMap { folders[$0] }
            if planned.parentKey != nil, parent == nil { continue }
            let folder = Folder(name: planned.name, parent: parent, position: planned.position)
            folder.builtInKey = planned.key
            folder.createdAt = time
            context.insert(folder)
            folders[planned.key] = folder
        }

        let present = Set(try context.fetch(FetchDescriptor<Deck>()).compactMap(\.builtInKey))
        var words = Dictionary(
            try context.fetch(FetchDescriptor<VocabWord>()).map { ($0.hanzi, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for planned in plan.decks where !present.contains(planned.key) {
            guard let folder = folders[planned.folderKey] else { continue }
            let deckWords = planned.words.map { draft in
                if let existing = words[draft.hanzi] { return existing }
                let word = VocabWord(meanings: draft.meanings, hanzi: draft.hanzi, pinyin: draft.pinyin)
                context.insert(word)
                words[draft.hanzi] = word
                return word
            }
            let deck = Deck(name: planned.name, words: deckWords, folder: folder, position: planned.position)
            deck.builtInKey = planned.key
            deck.createdAt = time
            deck.editedAt = time
            context.insert(deck)
        }
        try context.save()
    }
}
