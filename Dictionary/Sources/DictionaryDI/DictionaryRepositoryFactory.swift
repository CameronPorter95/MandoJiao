import DictionaryData
import DictionaryDomain

/// Builds the dictionary's repositories, for its own screens and for the app to hand to the
/// library, which may not see `DictionaryData`. Nonisolated, since each only hands back a
/// shared instance and a test may ask from anywhere.
public nonisolated enum DictionaryRepositoryFactory {
    public static func makeDictionaryRepository() -> any DictionaryRepository {
        CEDICT.dictionary
    }

    public static func makeLexiconRepository() -> any LexiconRepository {
        Lexicon.repository
    }

    public static func makeHSKRepository() -> any HSKRepository {
        HSKSource.repository
    }

    public static func makeExampleRepository() -> any ExampleRepository {
        Tatoeba.examples
    }

    /// The bundled syllabus, read synchronously, for seeding a fresh store.
    public static func bundledHSKWords() throws -> [HSKWord] {
        try HSKSource.bundledWords()
    }
}
