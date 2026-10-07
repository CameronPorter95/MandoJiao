import DictionaryDomain
import SwiftUI

/// The learner's saved words and the editor that saves one. Both belong to the library, so
/// the app supplies them.
@MainActor
public struct DictionaryVocabulary {
    public let savedReadings: any SavedReadingsRepository
    /// A screen seam: adds a reading, or opens the saved word.
    public let editor: (ReadingEdit) -> AnyView

    public init(savedReadings: any SavedReadingsRepository, editor: @escaping (ReadingEdit) -> AnyView) {
        self.savedReadings = savedReadings
        self.editor = editor
    }
}
