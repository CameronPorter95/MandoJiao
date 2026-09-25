import Foundation
import SwiftData
import Testing
@testable import MandoJiao

/// The fixture is a real store written by the build before versioning, with `water` given
/// three mistakes and the first deck renamed. Writing a version 1 store in-process instead
/// does not work: once a version 2 container exists, SwiftData resolves version 1's `Deck`
/// to version 2's entity.
///
/// Off the main actor, because opening and migrating an on-disk store blocks long enough
/// to starve the timing-sensitive suites that share it.
@Suite("Vocabulary schema migration")
nonisolated struct VocabularyMigrationTests {
    @Test("a version 1 store opens as version 2, keeping everything and giving each deck its own id")
    func v1ToV2() throws {
        let fixture = try #require(Bundle(for: BundleToken.self).url(forResource: "VocabularyV1", withExtension: "store"))
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).store")
        try FileManager.default.copyItem(at: fixture, to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let container = try ModelContainer(
            for: Schema(versionedSchema: VocabularySchemaV2.self),
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
    }
}

private final class BundleToken {}
