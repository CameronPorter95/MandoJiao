import Foundation
import Testing
import MandoKit

/// Card order follows the store's fetch and ids are random, so these read a transcript rather
/// than compare one whole.
@Suite("mando", .serialized)
@MainActor
struct InterpreterTests {
    private let startSpeaking = #"do startLessonTapped {"exercise":"speaking"}"#

    /// What `ls` shows of the screens, without the actions line and the result.
    private func screens(_ mando: Interpreter) async -> [String] {
        await mando.run("ls").filter { !$0.hasPrefix("actions:") && !$0.hasPrefix("✓") }
    }

    @Test("headless, it says it drives no simulator")
    func banner() throws {
        let mando = try Interpreter()
        #expect(mando.banner.hasPrefix("headless: "))
        #expect(mando.prompt == "mando> ")
    }

    @Test("it starts on home, loaded")
    func startsOnHome() async throws {
        let mando = try Interpreter()
        let output = await mando.run("ls")
        #expect(output.first?.hasPrefix("home  quick practice: ") == true)
        #expect(output.first?.contains("quick practice: 0 words") == false)
        #expect(output.last == "✓ ls")
    }

    @Test("open goes through the vocabulary tab: a folder selected, then a deck pushed over it")
    func opening() async throws {
        let mando = try Interpreter()
        #expect(await mando.run("open folder Starter") == ["✓ open"])
        #expect(await mando.run("open deck Greetings") == ["✓ open"])

        let listed = await mando.run("ls")
        #expect(listed[0].hasPrefix("vocabulary  folders: Starter "))
        #expect(listed[0].hasSuffix("selected: Starter"))
        #expect(listed[1] == "deck  Greetings  10 words  lesson words: 10")

        #expect(await mando.run("back") == ["✓ back"])
        #expect(await mando.run("ls")[1].hasPrefix("folder  Starter  "))
        #expect(await mando.run("back") == ["✓ back"])
        #expect(await screens(mando).map { $0.components(separatedBy: "  ")[0] } == ["vocabulary"])
        #expect(await mando.run("back") == ["✗ nothing to go back from"])
    }

    @Test("a whole lesson runs from a deck, answered from what ls shows")
    func wholeLesson() async throws {
        let mando = try Interpreter()
        _ = await mando.run("open deck Greetings")
        #expect(await mando.run(startSpeaking) == ["✓ startLessonTapped"])

        var heard: [String] = []
        for _ in 0..<10 {
            // speaking  card 1/10  学生  xuésheng  mic: idle  idle
            let lesson = await mando.run("ls").first { $0.hasPrefix("speaking") } ?? ""
            let pinyin = lesson.components(separatedBy: "  ").dropFirst(3).first ?? ""
            let toneless = pinyin.folding(options: .diacriticInsensitive, locale: nil).replacingOccurrences(of: " ", with: "")
            heard += await mando.run("say \(toneless)").filter { $0.hasPrefix("· heard") }
        }

        #expect(heard.count == 10)
        #expect(heard.allSatisfy { $0.hasSuffix(": right") })
        #expect(await mando.run("ls").contains("speaking  finished  failed attempts: 0"))
    }

    @Test("closing a lesson comes back to its deck")
    func closing() async throws {
        let mando = try Interpreter()
        _ = await mando.run("open deck Greetings")
        _ = await mando.run(startSpeaking)

        #expect(await mando.run("do closeTapped") == ["✓ closeTapped"])
        #expect(await screens(mando).last == "deck  Greetings  10 words  lesson words: 10")
    }

    @Test("home practises mistakes as a speaking lesson once there are any")
    func mistakesFromHome() async throws {
        let mando = try Interpreter()
        _ = await mando.run("open deck Greetings")
        _ = await mando.run(startSpeaking)
        for _ in 0..<3 { _ = await mando.run("say wrong") }
        #expect(await mando.run("tab home") == ["✗ close the lesson first"])
        // Mid-lesson, closing asks first.
        _ = await mando.run("do closeTapped")
        _ = await mando.run("do quitConfirmed")
        _ = await mando.run("tab home")

        let home = await screens(mando)
        #expect(home.first?.contains("mistakes: 1") == true)
        #expect(await mando.run("do practiseMistakesTapped") == ["✓ practiseMistakesTapped"])
        #expect(await mando.run("ls").contains { $0.hasPrefix("speaking  card 1/1") })
    }

    @Test("the dictionary tab searches and picks a result by its place")
    func dictionary() async throws {
        let mando = try Interpreter()
        _ = await mando.run("tab dictionary")
        _ = await mando.run(#"do queryChanged {"query":"你好"}"#)

        #expect(await mando.run("ls").first == "dictionary  query: 你好  results: 1  0. 你好 nǐhǎo hello, hi")
        _ = await mando.run(#"do vocabularyTapped {"result":0}"#)
        #expect(await mando.run("ls").first?.hasSuffix("editing a reading") == true)
    }

    @Test("every exercise opens from a deck, and back closes it to the deck")
    func everyExercise() async throws {
        let mando = try Interpreter()
        _ = await mando.run("open deck Greetings")
        for (exercise, screen) in [("matching", "matching  board 1/"), ("flashcards", "flashcards  card 1/"), ("speaking", "speaking  card 1/")] {
            #expect(await mando.run(#"do startLessonTapped {"exercise":"\#(exercise)"}"#) == ["✓ startLessonTapped"])
            #expect(await screens(mando).last?.hasPrefix(screen) == true, "\(exercise)")
            #expect(await mando.run("back") == ["✓ back"])
            #expect(await screens(mando).last?.hasPrefix("deck  Greetings") == true, "\(exercise)")
        }
    }

    @Test("today's plan opens from home, with its first step in front")
    func todayPlan() async throws {
        let mando = try Interpreter()
        #expect(await mando.run("do todayPlanTapped") == ["✓ todayPlanTapped"])
        #expect(await screens(mando).contains { $0.hasPrefix("today's plan  step 1/") })
    }

    @Test("home pushes settings, a setting changes and reads back, and back pops it")
    func settings() async throws {
        let mando = try Interpreter()
        #expect(await mando.run(#"do opened {"destination":"settings"}"#) == ["✓ opened"])
        let before = await screens(mando).last ?? ""
        #expect(before.hasPrefix("settings  strictness: "))
        let showsPinyin = before.contains("pinyin: on")

        _ = await mando.run(#"do showsPinyinChanged {"showsPinyin":\#(!showsPinyin)}"#)
        #expect(await screens(mando).last?.contains("pinyin: \(showsPinyin ? "off" : "on")") == true)
        // mando keeps settings in UserDefaults, so put it back for the next run.
        _ = await mando.run(#"do showsPinyinChanged {"showsPinyin":\#(showsPinyin)}"#)

        #expect(await mando.run("back") == ["✓ back"])
        #expect(await screens(mando).last?.hasPrefix("home  ") == true)
    }

    @Test("the dictionary tab pushes a headword's page, and back pops it")
    func headwordPage() async throws {
        let mando = try Interpreter()
        _ = await mando.run("tab dictionary")
        _ = await mando.run(#"do queryChanged {"query":"你好"}"#)
        #expect(await mando.run(#"do opened {"result":0}"#) == ["✓ opened"])
        #expect(await screens(mando).last?.hasPrefix("page  你好") == true)

        #expect(await mando.run("back") == ["✓ back"])
        #expect(await screens(mando).last?.hasPrefix("dictionary  query: 你好") == true)
    }

    @Test("a word's dictionary page opens over the vocabulary's search results, and back closes it")
    func pageFromResults() async throws {
        let mando = try Interpreter()
        _ = await mando.run("tab vocabulary")
        _ = await mando.run(#"do searchPresentedChanged {"_0":true}"#)
        _ = await mando.run(#"do searchChanged {"text":"ni"}"#)
        let word = await screens(mando).last?.components(separatedBy: "0. ").dropFirst().first?.prefix(while: { $0 != " " })

        #expect(await mando.run(#"do dictionaryTapped {"word":0}"#) == ["✓ dictionaryTapped"])
        #expect(await screens(mando).last?.hasPrefix("page  \(word ?? "?")") == true)

        #expect(await mando.run("back") == ["✓ back"])
        #expect(await screens(mando).last?.hasPrefix("results  ") == true)
    }

    @Test("mistakes are refused in a sentence and leave the session usable")
    func refusals() async throws {
        let mando = try Interpreter()
        #expect(await mando.run("back") == ["✗ nothing to go back from"])
        #expect(await mando.run("tab settings") == [#"✗ no tab "settings"; the tabs are home, vocabulary and dictionary"#])
        #expect(await mando.run("open deck nope") == [#"✗ no deck matches "nope""#])
        #expect(await mando.run("say ni") == ["✗ say needs a speaking lesson open"])

        _ = await mando.run("open deck Greetings")
        #expect(await mando.run("do bogus") == [#"✗ no action "bogus" here, see ls"#])
        #expect(await mando.run(#"do startLessonTapped {"exercise":"singing"}"#) == ["✗ the arguments do not fit startLessonTapped"])
        #expect(await screens(mando).last?.hasPrefix("deck  Greetings") == true)
    }
}
