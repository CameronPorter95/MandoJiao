import Testing
@testable import MandoJiao

@Suite("Answer grading")
struct AnswerGraderTests {
    private let water = WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")
    private let phone = WordPair(english: "mobile phone", hanzi: "手机", pinyin: "shǒujī")
    private let green = WordPair(english: "green", hanzi: "绿", pinyin: "lǜ")
    private let student = WordPair(english: "student", hanzi: "学生", pinyin: "xuésheng")

    @Test(
        "everything reduces to bare pinyin letters",
        arguments: [
            ("水", "shui"),
            ("shuǐ", "shui"),
            ("SHUI", "shui"),
            ("  shui  ", "shui"),
            ("shui3", "shui"),
            ("手机", "shouji"),
            ("shǒu jī", "shouji"),
            ("lv", "lu"),
            ("lǜ", "lu"),
            ("", ""),
            ("   ", "")
        ]
    )
    func normalisation(input: String, expected: String) {
        #expect(AnswerGrader.normalised(input) == expected)
    }

    @Test(
        "an answer for 水 is accepted however it is written",
        arguments: ["水", "shuǐ", "shui", "shui3", "SHUI", " shui "]
    )
    func acceptsWater(answer: String) {
        #expect(AnswerGrader.isCorrect(answer, for: water))
    }

    @Test(
        "a wrong or empty answer for 水 is rejected",
        arguments: ["cha", "茶", "", "   ", "water", "shuiii"]
    )
    func rejectsWrongAnswers(answer: String) {
        #expect(!AnswerGrader.isCorrect(answer, for: water))
    }

    @Test("tones are not graded, so the wrong tone still passes")
    func tonesAreNotGraded() {
        // Deliberate. A recogniser's tone output reflects its own guess as much as the
        // speaker's, so failing on tone would reject people for reasons they cannot see.
        #expect(AnswerGrader.isCorrect("shuì", for: water))
    }

    @Test("multi-syllable words pass with or without the syllable break")
    func multiSyllable() {
        #expect(AnswerGrader.isCorrect("手机", for: phone))
        #expect(AnswerGrader.isCorrect("shouji", for: phone))
        #expect(AnswerGrader.isCorrect("shǒu jī", for: phone))
    }

    @Test("ü is accepted as typed v")
    func uWithUmlaut() {
        #expect(AnswerGrader.isCorrect("绿", for: green))
        #expect(AnswerGrader.isCorrect("lv", for: green))
        #expect(AnswerGrader.isCorrect("lǜ", for: green))
    }

    @Test("a word is accepted from its hanzi even when the stored pinyin differs")
    func hanziAndStoredPinyinBothCount() {
        // 学生 is stored as xuésheng but the transform produces xuéshēng. Dropping tones
        // happens to reconcile these two, but the derived form is kept as an accepted
        // spelling regardless, for words where the stored reading differs for real.
        #expect(AnswerGrader.isCorrect("学生", for: student))
        #expect(AnswerGrader.isCorrect("xuesheng", for: student))
    }

    @Test("a homophone passes, which is a known limit of grading audio")
    func homophonesPass() {
        // 是 and 事 are both shì. Nothing in an audio answer can separate them, so this
        // is pinned rather than left to be discovered as a bug report.
        let toBe = WordPair(english: "to be", hanzi: "是", pinyin: "shì")
        #expect(AnswerGrader.isCorrect("事", for: toBe))
    }

    @Test("the reveal keeps tone marks")
    func revealKeepsTones() {
        #expect(AnswerGrader.pinyinWithTones("水") == "shuǐ")
    }

    @Test("latin input is left alone by the hanzi transform")
    func latinPassesThrough() {
        #expect(!AnswerGrader.containsHan("shui"))
        #expect(AnswerGrader.containsHan("水"))
        #expect(AnswerGrader.containsHan("say 水 now"))
    }
}
