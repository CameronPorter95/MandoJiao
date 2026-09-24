import Testing
@testable import MandoJiao

@Suite("Grading strictness")
struct StrictnessTests {
    /// The reported case: added by hand, pinyin typed with a space between syllables.
    private let complete = WordPair(english: "to complete", hanzi: "完成", pinyin: "wán chéng")
    private let water = WordPair(english: "water", hanzi: "水", pinyin: "shuǐ")
    private let drink = WordPair(english: "to drink", hanzi: "喝", pinyin: "hē")

    // MARK: - The reported failure

    @Test(
        "a space in the stored pinyin changes nothing",
        arguments: ["完成", "wancheng", "wán chéng", "wánchéng"]
    )
    func spacedPinyinIsFine(answer: String) {
        #expect(AnswerGrader.isCorrect(answer, for: complete, strictness: .strict))
    }

    @Test("a homophone written differently already passed, at every level")
    func homophonePasses() {
        for level in MatchStrictness.allCases {
            #expect(AnswerGrader.isCorrect("完城", for: complete, strictness: level))
        }
    }

    @Test(
        "the word inside a longer phrase is the case that was actually failing",
        arguments: ["完成了", "是完成", "我完成了", "wo wancheng le"]
    )
    func wordInsideAPhrase(answer: String) {
        // This is what a recogniser hands back in practice: a short phrase, not a bare
        // word. Strict still rejects it, which is what makes it strict.
        #expect(!AnswerGrader.isCorrect(answer, for: complete, strictness: .strict))
        #expect(AnswerGrader.isCorrect(answer, for: complete, strictness: .balanced))
    }

    // MARK: - Matching a phrase cannot match rubbish

    @Test("a short word is not matched inside an unrelated longer one")
    func noSpuriousSubstringMatch() {
        // 喝 is "he" and 完成 is "wancheng", which contains the letters h-e. Comparing
        // flat strings would accept it; comparing syllables does not.
        #expect(!AnswerGrader.isCorrect("完成", for: drink, strictness: .balanced))
        #expect(!AnswerGrader.isCorrect("完成", for: drink, strictness: .lenient))
    }

    @Test("a different word is still wrong at every level")
    func genuinelyWrongAnswers() {
        for level in MatchStrictness.allCases {
            // The other failure reported: wanzuo heard for wancheng.
            #expect(!AnswerGrader.isCorrect("wanzuo", for: complete, strictness: level))
            #expect(!AnswerGrader.isCorrect("茶", for: water, strictness: level))
            #expect(!AnswerGrader.isCorrect("", for: complete, strictness: level))
        }
    }

    // MARK: - Near spellings

    @Test("the reported near miss is accepted only when lenient")
    func nearMiss() {
        // wanchang heard for wancheng: one letter out.
        #expect(!AnswerGrader.isCorrect("wanchang", for: complete, strictness: .strict))
        #expect(!AnswerGrader.isCorrect("wanchang", for: complete, strictness: .balanced))
        #expect(AnswerGrader.isCorrect("wanchang", for: complete, strictness: .lenient))
    }

    @Test(
        "lenient folds the initials and finals that get swapped most",
        arguments: ["wanceng", "wancen", "wanzheng"]
    )
    func confusableInitialsAndFinals(answer: String) {
        #expect(AnswerGrader.isCorrect(answer, for: complete, strictness: .lenient))
    }

    @Test("a short word gets no slack even when lenient")
    func shortWordsGetNoSlack() {
        // "he" is two letters. Allowing an edit would accept half the syllables there are.
        #expect(!AnswerGrader.isCorrect("ha", for: drink, strictness: .lenient))
        #expect(!AnswerGrader.isCorrect("shi", for: water, strictness: .lenient))
    }

    @Test("a near miss inside a phrase is caught when lenient")
    func nearMissInsideAPhrase() {
        #expect(AnswerGrader.isCorrect("wo wanchang le", for: complete, strictness: .lenient))
    }

    // MARK: - Empty-rime vowel confusions

    private let know = WordPair(english: "to know", hanzi: "知道", pinyin: "zhīdào")
    private let evening = WordPair(english: "evening", hanzi: "晚上", pinyin: "wǎnshang")

    @Test("zhi heard as zhe is accepted from Balanced up")
    func emptyRimeVowel() {
        // Reported from a real lesson: 知道 came back as 这倒 three attempts running.
        #expect(!AnswerGrader.isCorrect("这倒", for: know, strictness: .strict))
        #expect(AnswerGrader.isCorrect("这倒", for: know, strictness: .balanced))
        #expect(AnswerGrader.isCorrect("这倒", for: know, strictness: .lenient))
    }

    @Test(
        "the fold covers the other empty-rime initials too",
        arguments: [
            ("shi", "she"), ("zhi", "zhe"), ("chi", "che"),
            ("zi", "ze"), ("ci", "ce"), ("si", "se"), ("ri", "re")
        ]
    )
    func emptyRimeInitials(written: String, heard: String) {
        let word = WordPair(english: "x", hanzi: "", pinyin: written)
        #expect(AnswerGrader.isCorrect(heard, for: word, strictness: .balanced))
    }

    @Test("folding the vowel does not loosen anything else at Balanced")
    func balancedStaysTightElsewhere() {
        // Both were alternatives on a real 晚上 card. Lenient takes them, Balanced must
        // not: they differ in the final, which is not what this fold is about.
        #expect(!AnswerGrader.isCorrect("王勺", for: evening, strictness: .balanced))
        #expect(!AnswerGrader.isCorrect("皇上", for: evening, strictness: .balanced))
        // 晚安, a real and different word.
        #expect(!AnswerGrader.isCorrect("晚安", for: evening, strictness: .balanced))
    }

    @Test("a syllable containing ui is untouched by the i-to-e fold")
    func shuiIsNotShi() {
        // "shui" is s-h-u-i, so the fold has no "shi" to find. Worth pinning, since a
        // careless replacement here would make 是 an answer for 水.
        #expect(!AnswerGrader.isCorrect("是", for: water, strictness: .balanced))
        #expect(!AnswerGrader.isCorrect("shi", for: water, strictness: .balanced))
    }

    @Test("the cost of the vowel fold, recorded rather than discovered")
    func emptyRimeFoldCost() {
        // 是 shì and 社 shè are different words that this fold makes identical. That is
        // the price of accepting 这倒 for 知道, and it is deliberate.
        let toBe = WordPair(english: "to be", hanzi: "是", pinyin: "shì")
        #expect(AnswerGrader.isCorrect("社", for: toBe, strictness: .balanced))
        #expect(!AnswerGrader.isCorrect("社", for: toBe, strictness: .strict))
    }

    // MARK: - Alternatives

    @Test("a right answer sitting in the alternatives counts, except when strict")
    func alternativesAreGraded() {
        let outcome = SpeechOutcome(best: "万座", alternatives: ["完成", "晚场"])

        #expect(!AnswerGrader.isCorrect(outcome, for: complete, strictness: .strict))
        #expect(AnswerGrader.isCorrect(outcome, for: complete, strictness: .balanced))
    }

    @Test("alternatives cannot rescue an answer that is wrong throughout")
    func alternativesDoNotRescueRubbish() {
        let outcome = SpeechOutcome(best: "茶", alternatives: ["查", "差"])
        #expect(!AnswerGrader.isCorrect(outcome, for: complete, strictness: .lenient))
    }

    // MARK: - Syllables

    @Test("syllables are kept apart, however the word arrived")
    func syllableSplitting() {
        #expect(AnswerGrader.syllables("完成") == ["wan", "cheng"])
        #expect(AnswerGrader.syllables("wán chéng") == ["wan", "cheng"])
        // Typed as one token there is nothing to split on, which is why both the Hanzi
        // and the stored pinyin are kept as accepted forms.
        #expect(AnswerGrader.syllables("wancheng") == ["wancheng"])
        #expect(AnswerGrader.syllables("") == [])
    }

    @Test("tones are still ignored at the strictest setting")
    func tonesNeverGraded() {
        #expect(AnswerGrader.isCorrect("shuì", for: water, strictness: .strict))
        #expect(AnswerGrader.isCorrect("wan cheng", for: complete, strictness: .strict))
    }
}
