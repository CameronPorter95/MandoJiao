import Foundation
import Testing
@testable import DictionaryDomain

@Suite("English word order in written translations")
nonisolated struct EnglishWordOrderTests {
    @Test("the speaker goes last in a list of people", arguments: [
        ("I and my mom went to the supermarket together", "My mom and I went to the supermarket together"),
        ("I and you go to the park together.", "You and I go to the park together."),
        ("I and she went to the park to play", "She and I went to the park to play"),
        ("Yesterday I and my mother had lunch.", "Yesterday my mother and I had lunch."),
    ])
    func speakerLast(written: String, fixed: String) {
        #expect(EnglishWordOrder.speakerLast(written) == fixed)
    }

    @Test("anything else is left as it is", arguments: [
        "My mom and I went to the supermarket.",
        "I like tea and coffee.",
        "Bread and I don't get along.",
    ])
    func untouched(english: String) {
        #expect(EnglishWordOrder.speakerLast(english) == english)
    }
}
