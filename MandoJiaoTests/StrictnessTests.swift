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
        "the word inside a longer phrase counts at every level, including Strict",
        arguments: ["完成了", "是完成", "我完成了", "wo wancheng le"]
    )
    func wordInsideAPhrase(answer: String) {
        // A recogniser pads one word into something sentence-shaped. The speaker did not
        // say 了, so failing them for it would be judging the recogniser's phrasing
        // rather than their pronunciation.
        for level in MatchStrictness.allCases {
            #expect(AnswerGrader.isCorrect(answer, for: complete, strictness: level))
        }
    }

    @Test("what Strict still refuses")
    func strictStillMeansSomething() {
        // No vowel folding, and the best guess only: the answer being in the alternatives
        // does not count.
        #expect(!AnswerGrader.isCorrect("这倒", for: know, strictness: .strict))
        #expect(!AnswerGrader.isCorrect("wanchang", for: complete, strictness: .strict))

        let outcome = SpeechOutcome(best: "万座", alternatives: ["完成"])
        #expect(!AnswerGrader.isCorrect(outcome, for: complete, strictness: .strict))
    }

    @Test("the cost of never requiring the word alone, recorded rather than discovered")
    func phraseMatchingCost() {
        // A single-syllable answer can be found inside a longer word that contains it as
        // a whole syllable: 老师 is lao + shi, so it carries 是. Saying a different word
        // that happens to contain the target syllable passes. The alternative was failing
        // people whenever the recogniser added a particle, which happens constantly.
        let toBe = WordPair(english: "to be", hanzi: "是", pinyin: "shì")
        #expect(AnswerGrader.isCorrect("老师", for: toBe, strictness: .strict))

        // Multi-syllable answers are far safer: a chance run of two syllables is rare.
        #expect(!AnswerGrader.isCorrect("老师", for: complete, strictness: .strict))
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

    // MARK: - Nasal finals

    @Test("the default level is Relaxed")
    func defaultLevel() {
        #expect(MatchStrictness.default == .relaxed)
    }

    @Test("levels are ordered tightest to loosest")
    func ordering() {
        #expect(MatchStrictness.allCases == [.strict, .balanced, .relaxed, .lenient])
    }

    @Test(
        "one -ng ending is accepted for another from Relaxed up",
        arguments: ["晚昌", "晚冲", "晚充"]
    )
    func nasalFinalsFold(answer: String) {
        // Reported from a lesson: 完成 came back as 晚昌 and 晚冲 repeatedly. The initial
        // and the nasal are right, only the vowel in front of the -ng differs.
        #expect(!AnswerGrader.isCorrect(answer, for: complete, strictness: .balanced))
        #expect(AnswerGrader.isCorrect(answer, for: complete, strictness: .relaxed))
        #expect(AnswerGrader.isCorrect(answer, for: complete, strictness: .lenient))
    }

    @Test(
        "Relaxed lets none of the neighbouring real words through",
        arguments: ["晚餐", "晚春", "晚窗", "晚安", "完全", "晚上"]
    )
    func relaxedKeepsRealWordsApart(answer: String) {
        // The point of a separate level rather than reaching for Generous: every one of
        // these is a different word, and Generous takes most of them.
        #expect(!AnswerGrader.isCorrect(answer, for: complete, strictness: .relaxed))
    }

    @Test("a first syllable that differs is not rescued by the nasal fold")
    func nasalFoldOnlyForgivesTheVowel() {
        // 往昌 is wang + chang. The fold makes chang and cheng one ending, but wang and
        // wan are still different syllables, so the word as a whole does not match.
        #expect(!AnswerGrader.isCorrect("往昌", for: complete, strictness: .relaxed))
        #expect(AnswerGrader.isCorrect("往昌", for: complete, strictness: .lenient))
    }

    @Test("-ing is left out of the fold, so ming and mang stay apart")
    func ingIsNotFolded() {
        let tomorrow = WordPair(english: "tomorrow", hanzi: "明天", pinyin: "míngtiān")
        #expect(!AnswerGrader.isCorrect("忙天", for: tomorrow, strictness: .relaxed))
    }

    @Test("a compound final keeps its medial, so chuang is not cheng")
    func compoundFinalsStayDistinct() {
        #expect(!AnswerGrader.isCorrect("晚窗", for: complete, strictness: .relaxed))
    }

    @Test("the cost of the nasal fold, recorded rather than discovered")
    func nasalFoldCost() {
        // 想 xiǎng and 兄 xiōng differ only in the vowel before the -ng, so this fold
        // makes them identical. That is the price of accepting 晚昌 for 完成.
        let want = WordPair(english: "to want", hanzi: "想", pinyin: "xiǎng")
        #expect(AnswerGrader.isCorrect("兄", for: want, strictness: .relaxed))
        #expect(!AnswerGrader.isCorrect("兄", for: want, strictness: .balanced))
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
