import CoreUI
import VocabularyDomain

extension WordPair {
    /// How every exercise's review lists a word: its Hanzi, pinyin and every meaning.
    var reviewRow: LessonCompleteView.Row {
        LessonCompleteView.Row(id: id, hanzi: hanzi, english: meanings.joined(separator: "; "), pinyin: pinyin)
    }
}
