import Foundation
import Testing
@testable import DictionaryDomain

@Suite("Whether a translation says a meaning")
nonisolated struct EnglishMeaningTests {
    @Test("a meaning is said in any form of its words", arguments: [
        ("to hit, to strike", "Why did you hit me?"),
        ("to hit, to strike", "He keeps hitting the wall."),
        ("to see, to look at", "Did they see us?"),
        ("to see, to look at", "I saw her yesterday."),
        ("to see, to look at", "Look, it's my problem."),
        ("friend", "Is this your friend's car?"),
        ("to open (transitive or intransitive)", "The door opened and she came in."),
        ("to drink", "She drank all the milk."),
        ("aeroplane", "This is his plane."),
        ("aeroplane", "The airplane took off ten minutes ago."),
        ("colour", "What color is it?"),
        ("mum", "My mom is a teacher."),
    ])
    func says(meaning: String, english: String) {
        #expect(EnglishMeaning.says(meaning, in: english))
    }

    @Test("a sentence in another sense does not say it", arguments: [
        ("to hit, to strike", "I'll call you up tomorrow."),
        ("to open (transitive or intransitive)", "Could you drive more slowly?"),
        ("to see, to look at", "She loves to read Chinese books."),
    ])
    func doesNotSay(meaning: String, english: String) {
        #expect(!EnglishMeaning.says(meaning, in: english))
    }

    /// 打电话's "to make a phone call" is said as "give me a ring" as often as "call".
    @Test("cost: a paraphrase does not say the meaning")
    func paraphrase() {
        #expect(!EnglishMeaning.says("to make a phone call", in: "Give me a ring tomorrow."))
    }

    @Test("a grammatical meaning has nothing to check")
    func grammar() {
        #expect(!EnglishMeaning.isCheckable("(completed action marker)"))
        #expect(EnglishMeaning.isCheckable("to exist"))
    }

    /// Prepositions frame other meanings ("to look at"), so they are never what is checked.
    @Test("cost: 在's \"at, in\" has nothing to check, so its sentences are held to the learner's fit alone")
    func prepositions() {
        #expect(!EnglishMeaning.isCheckable("at, in"))
    }
}
