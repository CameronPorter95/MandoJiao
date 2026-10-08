import ProgressDomain
import CoreDomain
import CoreTestSupport
import DictionaryDomain
import Foundation
import Testing
import LibraryTestSupport
@testable import PracticeDomain
@testable import PracticeUI
import LibraryDomain

nonisolated enum LessonWords {
    static let water = WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")
    static let tea = WordPair(english: "tea", hanzi: "茶", pinyin: "chá")
    static let book = WordPair(english: "book", hanzi: "书", pinyin: "shū")
    static let car = WordPair(english: "car", hanzi: "车", pinyin: "chē")
    static let big = WordPair(english: "big", hanzi: "大", pinyin: "dà")
    static let all = [water, tea, book, car, big]
}

nonisolated private let deckID = UUID()

nonisolated private func plan(_ steps: [TodayPlan.Step]) -> TodayPlan {
    TodayPlan(theme: .newWords, title: "New words", synopsis: "Learn.", steps: steps, source: .deck(deckID), otherWords: LessonWords.all)
}

nonisolated private func answer(_ word: WordPair, right: Bool, exercise: Answer.Exercise = .flashcardPicked) -> Answer {
    Answer(wordID: word.id, exercise: exercise, direction: nil, isCorrect: right, wrongAttempts: right ? 0 : 1)
}

@Suite("Mixed lesson")
nonisolated struct MixedLessonDomainTests {
    @Test("a plan's steps become exercises: a word to recognise shows Chinese to pick, one to produce shows English to type")
    func steps() {
        let lesson = MixedLesson(plan: plan([
            .teach(LessonWords.water), .match(LessonWords.all), .recall(LessonWords.water, .recognise), .recall(LessonWords.tea, .produce),
        ]))
        #expect(lesson.steps[0] == .teach(LessonWords.water))
        #expect(lesson.steps[1] == .match(LessonWords.all))
        guard case .flashcard(let recognise) = lesson.steps[2], case .flashcard(let produce) = lesson.steps[3] else {
            Issue.record("expected flash cards")
            return
        }
        #expect(recognise.direction == .chineseToEnglish)
        #expect(recognise.format != .typed)
        #expect(produce.direction == .englishToChinese)
        #expect(produce.format == .typed)
    }

    @Test("each step's answers are kept, and the results carry the plan's deck for the mistakes list and strengths")
    func answers() {
        var lesson = MixedLesson(plan: plan([.teach(LessonWords.water), .recall(LessonWords.water, .recognise), .recall(LessonWords.tea, .recognise)]))
        lesson.complete(with: [])
        #expect(lesson.stepIndex == 1)
        lesson.complete(with: [answer(LessonWords.water, right: true)])
        lesson.complete(with: [answer(LessonWords.tea, right: false)])
        #expect(lesson.isFinished)
        #expect(lesson.progress == 1)
        let results = lesson.results
        #expect(results.cleanSolves == [LessonWords.water.id: 1])
        #expect(results.misses == [LessonWords.tea.id: 1])
        #expect(results.answers.count == 2)
        #expect(results.source == .deck(deckID))
        // Taught words, though nothing was answered for them, are words of the lesson.
        #expect(lesson.words == [LessonWords.water, LessonWords.tea])
        lesson.complete(with: [answer(LessonWords.book, right: true)])
        #expect(lesson.answers.count == 2)
    }

    @Test("a word to read aloud is a step that listens, and the only kind that does")
    func readAloud() {
        let lesson = MixedLesson(plan: plan([.teach(LessonWords.water), .recall(LessonWords.water, .recognise), .readAloud(LessonWords.tea)]))
        #expect(lesson.steps[2] == .readAloud(LessonWords.tea))
        #expect(lesson.steps.map(\.listens) == [false, false, true])
        #expect(lesson.words == [LessonWords.water, LessonWords.tea])
    }

    @Test("a read aloud listens on arrival only straight after a read that carried on")
    func listensOnArrival() {
        var lesson = MixedLesson(plan: plan([
            .readAloud(LessonWords.water), .readAloud(LessonWords.tea), .readAloud(LessonWords.book),
            .recall(LessonWords.water, .recognise), .readAloud(LessonWords.car),
        ]))
        #expect(!lesson.listensOnArrival)
        lesson.complete(with: [answer(LessonWords.water, right: true, exercise: .speaking)], carriesOn: true)
        #expect(lesson.listensOnArrival)
        lesson.complete(with: [answer(LessonWords.tea, right: false, exercise: .speaking)], carriesOn: false)
        #expect(!lesson.listensOnArrival)
        // Carrying on into a flash card means nothing, and the read after it waits for a tap.
        lesson.complete(with: [answer(LessonWords.book, right: true, exercise: .speaking)], carriesOn: true)
        #expect(!lesson.listensOnArrival)
        lesson.complete(with: [answer(LessonWords.water, right: true)])
        #expect(!lesson.listensOnArrival)
    }
}

@Suite("Mixed lesson view model")
@MainActor
struct MixedLessonViewModelTests {
    private let repository = FakeVocabularyRepository()
    private let sounds = FakeSounds()
    private static let drinking = ExampleSentence(hanzi: "我喝水。", pinyin: "Wǒ hē shuǐ.", english: "I drink water.")

    private func makeViewModel(
        _ steps: [TodayPlan.Step] = [.teach(LessonWords.water), .recall(LessonWords.water, .recognise)],
        examples: FakeExamples = FakeExamples(["水": [drinking]]),
        generator: FakeGenerator = FakeGenerator(nil)
    ) -> (MixedLessonViewModel, EffectLog<MixedLessonEffect>) {
        let viewModel = MixedLessonViewModel(
            lesson: MixedLesson(plan: plan(steps)),
            recordResults: RecordLessonResultsUseCase(repository: repository),
            findExamples: FindExamplesUseCase(repository: examples),
            generateExample: GenerateExampleUseCase(generator: generator),
            sounds: sounds,
            audioSession: sounds
        )
        return (viewModel, EffectLog(viewModel.effects()))
    }

    private static let salt = ExampleSentence(hanzi: "请把盐递给我，水也要。", pinyin: "", english: "Pass the salt, please.")
    private static let written = ExampleSentence(hanzi: "我想喝水。", pinyin: "Wǒ xiǎng hē shuǐ.", english: "I want to drink water.")

    @Test("a word none of whose sentences say its meaning has one written on the device, keeping to the learner's words")
    func examplesWritten() async {
        let generator = FakeGenerator(Self.written)
        let (viewModel, _) = makeViewModel(examples: FakeExamples(["水": [Self.salt]]), generator: generator)
        viewModel.send(.appeared)
        #expect(await waitUntil { viewModel.state.examples[LessonWords.water.id] == Self.written })
        #expect(await generator.requests == [ExampleRequest(hanzi: "水", pinyin: "shuǐ", meaning: "water", known: [])])
    }

    @Test("a word with a sentence in its sense is never written")
    func examplesNotWritten() async {
        let generator = FakeGenerator(Self.written)
        let (viewModel, _) = makeViewModel(generator: generator)
        viewModel.send(.appeared)
        #expect(await waitUntil { viewModel.state.examples[LessonWords.water.id] == Self.drinking })
        await settle()
        #expect(await generator.requests.isEmpty)
    }

    @Test("a sentence the device cannot write leaves the card without one, and no alert")
    func examplesWritingFails() async {
        let (viewModel, log) = makeViewModel(examples: FakeExamples(["水": [Self.salt]]), generator: FakeGenerator(nil, fails: true))
        viewModel.send(.appeared)
        await settle()
        #expect(viewModel.state.examples.isEmpty)
        #expect(log.effects.isEmpty)
    }

    @Test("each taught word's example arrives on appearing, and a word with none has none")
    func examples() async {
        let examples = FakeExamples(["水": [Self.drinking]])
        let (viewModel, _) = makeViewModel([.teach(LessonWords.water), .teach(LessonWords.tea), .recall(LessonWords.water, .recognise)], examples: examples)
        viewModel.send(.appeared)
        #expect(await waitUntil { viewModel.state.examples[LessonWords.water.id] == Self.drinking })
        #expect(viewModel.state.examples[LessonWords.tea.id] == nil)
        // Only the taught words are looked up, once, with their own reading.
        viewModel.send(.appeared)
        await settle()
        #expect(await examples.lookups == ["水 shuǐ", "茶 chá"])
    }

    @Test("a taught word's example is the sentence with the fewest words the learner has not started")
    func examplesFitTheLearner() async {
        let unfamiliar = ExampleSentence(hanzi: "妹妹喝水。", pinyin: "", english: "My sister drinks water.", words: ["妹妹", "喝", "水"])
        let familiar = ExampleSentence(hanzi: "我们喝水。", pinyin: "", english: "We drink water.", words: ["我们", "喝", "水"])
        let viewModel = MixedLessonViewModel(
            lesson: MixedLesson(plan: TodayPlan(
                theme: .newWords, title: "New words", synopsis: "", steps: [.teach(LessonWords.water)],
                source: nil, otherWords: [], known: ["我们", "喝"]
            )),
            recordResults: RecordLessonResultsUseCase(repository: repository),
            findExamples: FindExamplesUseCase(repository: FakeExamples(["水": [unfamiliar, familiar]])),
            generateExample: GenerateExampleUseCase(generator: FakeGenerator(nil)),
            sounds: sounds,
            audioSession: sounds
        )
        viewModel.send(.appeared)
        #expect(await waitUntil { viewModel.state.examples[LessonWords.water.id] == familiar })
    }

    @Test("examples that cannot be read are left off without an alert")
    func examplesFailing() async {
        let (viewModel, log) = makeViewModel(examples: FakeExamples([:], fails: true))
        viewModel.send(.appeared)
        await settle()
        #expect(viewModel.state.examples.isEmpty)
        #expect(log.effects.isEmpty)
    }

    @Test("the last step plays the finishing tune and records the lesson once, with its deck")
    func finishing() async {
        let (viewModel, _) = makeViewModel()
        viewModel.send(.stepCompleted([]))
        #expect(sounds.played.isEmpty)
        viewModel.send(.stepCompleted([answer(LessonWords.water, right: true)]))
        viewModel.send(.stepCompleted([answer(LessonWords.water, right: true)]))
        #expect(await waitUntil { sounds.played.contains("complete") })
        #expect(await waitUntil { await repository.recordedResults.count == 1 })
        #expect(await repository.recordedResults.first?.source == .deck(deckID))
        viewModel.send(.closeTapped)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await repository.recordedResults.count == 1)
    }

    @Test("closing part way asks first, then records what was answered")
    func quitting() async {
        let (viewModel, log) = makeViewModel()
        viewModel.send(.stepCompleted([]))
        viewModel.send(.closeTapped)
        #expect(viewModel.state.isConfirmingQuit)
        viewModel.send(.quitConfirmed)
        #expect(await log.contains(.close))
        // Nothing answered yet, so nothing to record.
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await repository.recordedResults.isEmpty)
    }

    @Test("the microphone's session is kept through a run of read-aloud steps, handed back before anything else, and before the fanfare")
    func audioSession() async {
        let (viewModel, _) = makeViewModel([
            .readAloud(LessonWords.water), .readAloud(LessonWords.tea), .recall(LessonWords.water, .recognise), .readAloud(LessonWords.book),
        ])
        viewModel.send(.stepCompleted([answer(LessonWords.water, right: true, exercise: .speaking)]))
        await settle()
        #expect(sounds.played.isEmpty)

        viewModel.send(.stepCompleted([answer(LessonWords.tea, right: true, exercise: .speaking)]))
        #expect(await waitUntil { sounds.played == ["exit"] })

        viewModel.send(.stepCompleted([answer(LessonWords.water, right: true)]))
        viewModel.send(.stepCompleted([answer(LessonWords.book, right: true, exercise: .speaking)]))
        #expect(await waitUntil { sounds.played == ["exit", "exit", "complete"] })
    }

    @Test("closing, or the lesson going away, hands the microphone's session back")
    func audioSessionOnLeaving() async {
        let (viewModel, log) = makeViewModel([.readAloud(LessonWords.water), .readAloud(LessonWords.tea)])
        viewModel.send(.closeTapped)
        #expect(await log.contains(.close))
        #expect(await waitUntil { sounds.played == ["exit"] })
        viewModel.send(.disappeared)
        #expect(await waitUntil { sounds.played == ["exit", "exit"] })
    }

    @Test("a failed save says why")
    func failedSave() async {
        await repository.failWrites()
        let (viewModel, log) = makeViewModel()
        viewModel.send(.stepCompleted([]))
        viewModel.send(.stepCompleted([answer(LessonWords.water, right: false)]))
        #expect(await log.contains(.showError(.recordResultsFailed(FakeVocabularyRepository.failure))))
    }
}

/// Sentences by Hanzi, recording each lookup; can be told to fail.
private actor FakeExamples: ExampleRepository {
    private let sentences: [String: [ExampleSentence]]
    private let fails: Bool
    private(set) var lookups: [String] = []

    init(_ sentences: [String: [ExampleSentence]], fails: Bool = false) {
        self.sentences = sentences
        self.fails = fails
    }

    func examples(forHanzi hanzi: String, pinyin: String) throws -> [ExampleSentence] {
        lookups.append("\(hanzi) \(pinyin)")
        if fails { throw DictionaryDomainError.unexpected(model: DomainErrorModel(domain: "test", code: 5, description: "no examples")) }
        return sentences[hanzi] ?? []
    }
}

/// Writes the one sentence it is given, recording each request; can be told to fail.
private actor FakeGenerator: ExampleGenerating {
    private let sentence: ExampleSentence?
    private let fails: Bool
    private(set) var requests: [ExampleRequest] = []

    init(_ sentence: ExampleSentence?, fails: Bool = false) {
        self.sentence = sentence
        self.fails = fails
    }

    func example(for request: ExampleRequest) throws -> ExampleSentence? {
        requests.append(request)
        if fails { throw DictionaryDomainError.unexpected(model: DomainErrorModel(domain: "test", code: 6, description: "no model")) }
        return sentence
    }
}

/// Sounds and the audio session in one log, so their order shows.
@MainActor
private final class FakeSounds: MatchSoundPlaying, AudioSessionSwitching {
    private(set) var played: [String] = []
    func enterRecordingMode() { played.append("enter") }
    func exitRecordingMode() async { played.append("exit") }
    func prepare() {}
    func playMatch(step: Int, of total: Int) { played.append("match") }
    func playMiss() { played.append("miss") }
    func playLessonComplete() { played.append("complete") }
}
