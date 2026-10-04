import Foundation
import SwiftData
import Testing
import CoreDomain
import CoreTestSupport
import VocabularyTestSupport
@testable import VocabularyDomain
@testable import VocabularyData
@testable import VocabularyUI

/// Each fixture is a real store written by an earlier build. Version 1's is from the build
/// before versioning, with `water` given three mistakes and the first deck renamed. Version
/// 3's is from develop at 6e8614e: a starter folder holding a deck of 水 and 喝, with
/// 水 on two mistakes, and 银行 in no deck. Writing a version 1 store in-process instead
/// does not work: once a version 2 container exists, SwiftData resolves version 1's `Deck`
/// to version 2's entity.
///
/// Off the main actor, because opening and migrating an on-disk store blocks long enough
/// to starve the timing-sensitive suites that share it.
@Suite("Vocabulary schema migration")
nonisolated struct VocabularyMigrationTests {
    @Test("a version 1 store opens as the current version, keeping everything and giving each deck its own id")
    func v1ToV2() throws {
        let fixture = try #require(Bundle.module.url(forResource: "VocabularyV1", withExtension: "store"))
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        try FileManager.default.copyItem(at: fixture, to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let container = try ModelContainer(
            for: Schema(versionedSchema: VocabularySchemaV4.self),
            migrationPlan: VocabularyMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let context = ModelContext(container)
        let words = try context.fetch(FetchDescriptor<VocabWord>())
        let decks = try context.fetch(FetchDescriptor<Deck>())

        #expect(words.count == 65)
        #expect(words.filter { $0.missCount > 0 }.map(\.english) == ["water"])
        #expect(words.first { $0.english == "water" }?.missCount == 3)
        #expect(decks.count == 6)
        #expect(decks.contains { $0.name == "Renamed deck" })
        #expect(Set(decks.map(\.uuid)).count == 6)
        #expect(decks.reduce(0) { $0 + $1.words.count } == 65)
        #expect(decks.allSatisfy { $0.folder == nil && $0.builtInKey == nil })
        #expect(words.allSatisfy { $0.meanings.isEmpty && $0.domainWord.meanings == [$0.english] })
        #expect(try context.fetchCount(FetchDescriptor<Folder>()) == 0)
    }

    @Test("a version 3 store opens as the current version, each word's one English becoming its only meaning")
    func v3ToV4() throws {
        let fixture = try #require(Bundle.module.url(forResource: "VocabularyV3", withExtension: "store"))
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        try FileManager.default.copyItem(at: fixture, to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let container = try ModelContainer(
            for: Schema(versionedSchema: VocabularySchemaV4.self),
            migrationPlan: VocabularyMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
        let context = ModelContext(container)
        let words = try context.fetch(FetchDescriptor<VocabWord>()).map(\.domainWord)

        #expect(Set(words.map(\.meanings)) == [["water"], ["to drink"], ["bank"]])
        #expect(words.first { $0.hanzi == "水" }?.missCount == 2)
        let deck = try #require(context.fetch(FetchDescriptor<Deck>()).first)
        #expect(deck.name == "Drinks")
        #expect(Set(deck.words.map(\.hanzi)) == ["水", "喝"])
        #expect(deck.folder?.builtInKey == "starter")
    }
}
