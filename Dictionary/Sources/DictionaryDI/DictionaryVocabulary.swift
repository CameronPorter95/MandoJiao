import CoreUI
import DictionaryDomain
import SwiftUI

/// The learner's saved words and the editor that saves one. Both belong to the library, so
/// the app supplies them.
@MainActor
public struct DictionaryVocabulary {
    public let savedReadings: any SavedReadingsRepository
    /// A screen seam: adds a reading, or opens the saved word.
    public let editor: (ReadingEdit) -> AnyView
    /// The same editor without its view, for running the dictionary headlessly, given how to close
    /// it. Nil in the app, where the editor's own view offers its driver.
    public let editorDriver: ((ReadingEdit, _ dismissed: @escaping () -> Void) -> ScreenDriver)?

    public init(
        savedReadings: any SavedReadingsRepository,
        editor: @escaping (ReadingEdit) -> AnyView,
        editorDriver: ((ReadingEdit, _ dismissed: @escaping () -> Void) -> ScreenDriver)? = nil
    ) {
        self.savedReadings = savedReadings
        self.editor = editor
        self.editorDriver = editorDriver
    }
}
