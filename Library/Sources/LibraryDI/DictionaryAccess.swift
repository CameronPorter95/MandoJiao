import CoreUI
import DictionaryDomain
import SwiftUI

/// What the library uses of the dictionary. Its data and pages are another package's, so the
/// app supplies them.
@MainActor
public struct DictionaryAccess {
    public let dictionary: any DictionaryRepository
    public let lexicon: any LexiconRepository
    public let hsk: any HSKRepository
    /// A screen seam: a headword's page. `addsToVocabulary` is false in the word editor's
    /// own dictionary, where adding would open an editor over the editor.
    public let page: (_ headword: DictionaryHeadword, _ addsToVocabulary: Bool) -> AnyView
    /// The same page without its view, for running the library headlessly. Nil in the app, where
    /// the page's own view offers its driver.
    public let pageDriver: ((_ headword: DictionaryHeadword, _ addsToVocabulary: Bool) -> ScreenDriver)?

    public init(
        dictionary: any DictionaryRepository,
        lexicon: any LexiconRepository,
        hsk: any HSKRepository,
        page: @escaping (_ headword: DictionaryHeadword, _ addsToVocabulary: Bool) -> AnyView,
        pageDriver: ((_ headword: DictionaryHeadword, _ addsToVocabulary: Bool) -> ScreenDriver)? = nil
    ) {
        self.dictionary = dictionary
        self.lexicon = lexicon
        self.hsk = hsk
        self.page = page
        self.pageDriver = pageDriver
    }
}
