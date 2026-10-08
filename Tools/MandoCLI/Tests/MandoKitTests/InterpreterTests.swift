import Foundation
import Testing
import MandoKit

/// Card order follows the store's fetch and deck ids are random, so these read a transcript
/// rather than compare one whole.
@Suite("mando", .serialized)
@MainActor
struct InterpreterTests {
    private let startSpeaking = #"do startLessonTapped {"exercise":"speaking"}"#

    @Test("with nothing open, ls lists the starter decks")
    func listsDecks() async throws {
        let mando = try Interpreter()
        let output = await mando.run("ls")
        #expect(output.contains { $0.hasPrefix("Greetings  10 words  id: ") })
        #expect(output.last == "✓ ls")
    }

    @Test("a whole lesson runs from a deck, answered from what ls shows")
    func wholeLesson() async throws {
        let mando = try Interpreter()
        #expect(await mando.run("open deck Greetings") == ["✓ open"])
        #expect(await mando.run(startSpeaking) == ["✓ startLessonTapped"])

        var heard: [String] = []
        for _ in 0..<10 {
            // speaking  card 1/10  学生  xuésheng  mic: idle  idle
            let pinyin = await mando.run("ls")[0].components(separatedBy: "  ")[3]
            let toneless = pinyin.folding(options: .diacriticInsensitive, locale: nil).replacingOccurrences(of: " ", with: "")
            heard += await mando.run("say \(toneless)").filter { $0.hasPrefix("· heard") }
        }

        #expect(heard.count == 10)
        #expect(heard.allSatisfy { $0.hasSuffix(": right") })
        #expect(await mando.run("ls").first == "speaking  finished  failed attempts: 0")
    }

    @Test("closing a lesson comes back to its deck")
    func closing() async throws {
        let mando = try Interpreter()
        _ = await mando.run("open deck Greetings")
        _ = await mando.run(startSpeaking)

        #expect(await mando.run("do closeTapped") == ["✓ closeTapped"])
        #expect(await mando.run("ls").first == "deck  Greetings  10 words  lesson words: 10")
    }

    @Test("a lesson nothing drives yet says so and stays on the deck")
    func undriven() async throws {
        let mando = try Interpreter()
        _ = await mando.run("open deck Greetings")

        let output = await mando.run(#"do startLessonTapped {"exercise":"matching"}"#)

        #expect(output == ["✓ startLessonTapped", "· matching is not driven yet"])
        #expect(await mando.run("ls").first?.hasPrefix("deck  Greetings") == true)
    }

    @Test("mistakes are refused in a sentence and leave the session usable")
    func refusals() async throws {
        let mando = try Interpreter()
        #expect(await mando.run("back") == ["✗ nothing is open"])
        #expect(await mando.run("open deck nope") == [#"✗ no deck matches "nope""#])
        #expect(await mando.run("say ni") == ["✗ say needs a speaking lesson open"])

        _ = await mando.run("open deck Greetings")
        #expect(await mando.run("do bogus") == [#"✗ no action "bogus" here, see ls"#])
        #expect(await mando.run(#"do startLessonTapped {"exercise":"singing"}"#) == ["✗ the arguments do not fit startLessonTapped"])
        #expect(await mando.run("ls").first?.hasPrefix("deck  Greetings") == true)
    }
}
