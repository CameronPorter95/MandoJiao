import CoreUI
import Foundation
import LibraryDomain
import ProgressDomain

struct HomeState: Equatable {
    var vocabulary: Vocabulary = .empty
    /// The matching exercise's floor, handed in so this package need not know Matching.
    let minimumMatchingWords: Int
    /// Shown on the quick practice card. Re-read on every appearance, since the settings
    /// screen can change it while home is underneath.
    var quickPracticeRounds: Int
    var isConfirmingClear = false
    /// Read on every appearance, since the settings screen is pushed over home.
    var lessonSettings: LessonSettings = .default
    /// When strengths are read, renewed as home appears and as the vocabulary changes.
    var now: Date = .now

    /// What today's plan would be, nil with nothing new or fading.
    var todayPlan: TodayPlan? {
        TodayPlanner.suggest(
            vocabulary: vocabulary, current: current, settings: lessonSettings,
            boardSize: minimumMatchingWords, now: now
        )
    }
    /// Picked from Practise another deck, and shown until something is next practised.
    var chosen: LessonSource?
    var isChoosingSource = false

    /// A folder offered to carry on with, and its decks, in the library tree's order.
    struct SourceSection: Identifiable, Equatable {
        let folder: FolderSummary
        let title: String
        let wordCount: Int
        let decks: [DeckChoice]
        var id: UUID { folder.id }
    }

    struct DeckChoice: Identifiable, Equatable {
        let deck: DeckSummary
        let wordCount: Int
        var id: UUID { deck.id }
    }

    /// What the Continue section offers: what was picked, else what was last practised.
    var current: LessonSource? {
        if let chosen, vocabulary.contains(chosen) { return chosen }
        return vocabulary.lastPractised
    }

    var currentName: String? { current.flatMap(vocabulary.name(of:)) }

    /// Usable words, which is what an exercise draws.
    var currentWordCount: Int { currentLessonWords.count }

    /// What a lesson from it draws, which leaves out learnt words when the settings say to.
    var currentLessonWords: [Word] {
        (current.map { vocabulary.words(in: $0) } ?? []).forLessons(lessonSettings).filter(\.isUsable)
    }

    /// Where it sits and how big it is: "HSK › HSK 1 · 50 words".
    var currentSubtitle: String {
        guard let current else { return "" }
        let count = currentWordCount == 1 ? "1 word" : "\(currentWordCount) words"
        let parent: UUID? = switch current {
        case .deck(let id): vocabulary.deck(id: id)?.folderID
        case .folder(let id): vocabulary.folder(id: id)?.parentID
        }
        guard let parent else { return count }
        return "\(vocabulary.location(of: parent)) · \(count)"
    }

    func canStart(_ exercise: LessonExercise) -> Bool {
        currentWordCount >= exercise.minimumWords(matching: minimumMatchingWords)
    }

    /// Folders with words beneath them, each with its decks that have any.
    var sourceSections: [SourceSection] {
        let ordered = vocabulary.folders(in: nil).flatMap { [$0] + vocabulary.folders(beneath: $0.id) }
        return ordered.compactMap { folder in
            let wordCount = vocabulary.usableWordCount(in: folder)
            guard wordCount > 0 else { return nil }
            let decks = vocabulary.decks(in: folder.id).compactMap { deck -> DeckChoice? in
                let count = vocabulary.usableWordCount(in: deck)
                return count > 0 ? DeckChoice(deck: deck, wordCount: count) : nil
            }
            return SourceSection(folder: folder, title: vocabulary.location(of: folder.id), wordCount: wordCount, decks: decks)
        }
    }

    /// What quick practice draws.
    var quickPracticeWords: [Word] { vocabulary.usableWords.forLessons(lessonSettings) }
    var usableWordCount: Int { quickPracticeWords.count }
    var canStartQuickPractice: Bool { usableWordCount >= minimumMatchingWords }
    var mistakeWords: [Word] { vocabulary.mistakeWords }

    var mistakesSubtitle: String {
        let count = mistakeWords.count
        let noun = count == 1 ? "word" : "words"
        return "\(count) \(noun) to earn back. Say each one out loud, one at a time."
    }
}

enum HomeAction: Equatable {
    case appeared
    case disappeared
    case quickPracticeTapped
    case todayPlanTapped
    case continueTapped(LessonExercise)
    case chooseSourceTapped
    case sourceChosen(LessonSource)
    case sourceChoiceDismissed
    case practiseMistakesTapped
    case clearMistakesTapped
    case clearMistakesConfirmed
    case clearMistakesCancelled
}

enum HomeEffect: Equatable, Sendable {
    case requestMatching(LessonRequest)
    case requestSpeaking(LessonRequest)
    case requestFlashcards(LessonRequest)
    case requestTodayPlan(TodayPlan)
    case showError(ProgressError)
}
