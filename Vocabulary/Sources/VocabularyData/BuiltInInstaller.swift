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
        var library = WordMatcher(existing: try context.fetch(FetchDescriptor<VocabWord>()), plan: plan)
        for planned in plan.decks where !present.contains(planned.key) {
            guard let folder = folders[planned.folderKey] else { continue }
            let deckWords = planned.words.map { draft in
                if let existing = library.match(draft) { return existing }
                let word = VocabWord(meanings: draft.meanings, hanzi: draft.hanzi, pinyin: draft.pinyin)
                context.insert(word)
                library.add(word)
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

/// Finds the library word a planned one already is, so installing never duplicates a word and
/// a word the user has keeps its own meanings. A character can be two words, 弹 tán "to play"
/// and 弹 dàn "bullet", so a word is matched by its reading: exactly, spaces and case aside;
/// then by its syllables, tones aside, since Starter has 对不起 duìbùqǐ where HSK has
/// duìbuqǐ; then, for a character's main reading only, any word with that character in none
/// of the plan's other readings, so one saved with its own pinyin, or none, is not added
/// again, and a 弹 saved as dàn is never taken for tán.
nonisolated struct WordMatcher {
    private var byHanzi: [String: [VocabWord]]
    /// Every reading the plan gives each character, the main one first.
    private let readings: [String: [String]]

    init(existing: [VocabWord], plan: BuiltInPlan) {
        byHanzi = Dictionary(grouping: existing, by: \.hanzi)
        var readings: [String: [String]] = [:]
        for draft in plan.decks.flatMap(\.words) where !(readings[draft.hanzi] ?? []).contains(Self.exact(draft.pinyin)) {
            readings[draft.hanzi, default: []].append(Self.exact(draft.pinyin))
        }
        self.readings = readings
    }

    func match(_ draft: WordDraft) -> VocabWord? {
        let words = byHanzi[draft.hanzi] ?? []
        if let word = words.first(where: { Self.exact($0.pinyin) == Self.exact(draft.pinyin) }) { return word }
        if let word = words.first(where: { Self.toneless($0.pinyin) == Self.toneless(draft.pinyin) }) { return word }
        let planned = readings[draft.hanzi] ?? []
        guard planned.first == Self.exact(draft.pinyin) else { return nil }
        let others = Set(planned.dropFirst().flatMap { [$0, Self.toneless($0)] })
        return words.first { !others.contains(Self.exact($0.pinyin)) && !others.contains(Self.toneless($0.pinyin)) }
    }

    mutating func add(_ word: VocabWord) {
        byHanzi[word.hanzi, default: []].append(word)
    }

    private static func exact(_ pinyin: String) -> String {
        pinyin.precomposedStringWithCanonicalMapping.lowercased().filter { !$0.isWhitespace && $0 != "'" }
    }

    private static func toneless(_ pinyin: String) -> String {
        exact(pinyin).folding(options: .diacriticInsensitive, locale: nil)
    }
}
