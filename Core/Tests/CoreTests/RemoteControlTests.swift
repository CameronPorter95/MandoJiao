import Foundation
import Testing
@testable import CoreRemote
@testable import CoreUI

@Suite("Remote control")
@MainActor
struct RemoteControlTests {
    private enum Action: Decodable {
        case appeared, disappeared, tapped, startListeningTapped
        case selectTab(tab: String)
    }

    private final class Log {
        var sent: [String] = []
        var opened: [String] = []
        var tab = "home"
        var lesson = false
        var pushed = false
    }

    private func screen(
        _ name: String, log: Log, back: @escaping () -> Bool = { false }, covers: @escaping () -> Bool = { false }
    ) -> ScreenDriver {
        ScreenDriver(
            name: name, actions: ["appeared", "disappeared", "tapped", "selectTab", "startListeningTapped"],
            state: { name }, summary: { "\($0) shown" },
            send: { (action: Action) in
                if case .selectTab(let tab) = action { log.tab = tab }
                log.sent.append("\(name) \(action)")
            },
            effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 }, back: back,
            covers: { _ in covers() },
            open: { kind, query in
                if kind == "tab" { log.tab = query }
                log.opened.append("\(name) \(kind) \(query)")
            }
        )
    }

    private func make() -> (RemoteControl, ScreenRegistry, Log) {
        let log = Log()
        let registry = ScreenRegistry()
        registry.app = screen("app", log: log, back: {
            guard log.lesson else { return false }
            log.lesson = false
            return true
        })
        registry.register(screen("vocabulary", log: log, back: {
            guard log.pushed else { return false }
            log.pushed = false
            return true
        }), as: UUID())
        registry.register(screen("deck", log: log), as: UUID())
        return (RemoteControl(registry: registry, transition: .zero), registry, log)
    }

    @Test("hello names the app and, on a simulator, which one")
    func hello() async {
        let (control, _, _) = make()
        #expect(await control.handle(RemoteRequest(.hello)).lines == [RemoteControl.identity])

        let simulator = ["SIMULATOR_DEVICE_NAME": "iPhone 17 Pro", "SIMULATOR_UDID": "056C9DBA-BD6F-47F7-B8AE-F3E0F33A0F00"]
        #expect(RemoteControl.identity(app: "MandoJiao", environment: simulator) == "MandoJiao on iPhone 17 Pro (056C9DBA)")
        #expect(RemoteControl.identity(app: "MandoJiao", environment: [:]) == "MandoJiao, not on a simulator")
    }

    @Test("ls shows the app, then each screen on show, then the front one's actions")
    func listing() async {
        let (control, _, _) = make()
        let reply = await control.handle(RemoteRequest(.ls))
        #expect(reply == RemoteReply(lines: [
            "app shown", "vocabulary shown", "deck shown",
            "actions: appeared, disappeared, tapped, selectTab, startListeningTapped",
        ]))
    }

    @Test("an action goes to the screen in front, and a tab to the app")
    func sending() async {
        let (control, _, log) = make()
        #expect(await control.handle(RemoteRequest(.send, action: "tapped")).error == nil)
        #expect(await control.handle(RemoteRequest(.tab, tab: "vocabulary")).error == nil)
        #expect(log.sent == ["deck tapped"])
        #expect(log.tab == "vocabulary")
        #expect(await control.handle(RemoteRequest(.send, action: "bogus")).error == #"no action "bogus" here, see ls"#)
    }

    @Test("a screen showing a dialog takes the commands, and the screens it covers are left off ls")
    func covering() async {
        let log = Log()
        let registry = ScreenRegistry()
        var asking = true
        var closed = false
        registry.register(screen("plan", log: log, back: { closed = true; return true }, covers: { asking }), as: UUID())
        registry.register(screen("step", log: log), as: UUID())
        let control = RemoteControl(registry: registry, transition: .zero)

        #expect(await control.handle(RemoteRequest(.ls)).lines.prefix(2) == ["plan shown", "actions: appeared, disappeared, tapped, selectTab, startListeningTapped"])
        #expect(await control.handle(RemoteRequest(.send, action: "tapped")).error == nil)
        #expect(await control.handle(RemoteRequest(.back)).error == nil)
        #expect(log.sent == ["plan tapped"])
        #expect(closed)

        asking = false
        #expect(await control.handle(RemoteRequest(.send, action: "tapped")).error == nil)
        #expect(log.sent == ["plan tapped", "step tapped"])
    }

    @Test("answer goes to the screen in front, right unless asked for wrong")
    func answering() async {
        let registry = ScreenRegistry()
        registry.register(ScreenDriver(
            name: "lesson", actions: [], state: { 0 }, summary: { _ in "" },
            send: { (_: Action) in }, effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 },
            answer: { right in right ? "right" : "wrong" }
        ), as: UUID())
        let control = RemoteControl(registry: registry, transition: .zero)

        #expect(await control.handle(RemoteRequest(.answer)).lines == ["right"])
        #expect(await control.handle(RemoteRequest(.answer, wrong: true)).lines == ["wrong"])

        let (plain, _, _) = make()
        #expect(await plain.handle(RemoteRequest(.answer)).error == "nothing to answer here")
    }

    @Test("open selects the vocabulary tab, then asks it to find the deck or folder")
    func opening() async {
        let (control, _, log) = make()
        #expect(await control.handle(RemoteRequest(.open, kind: "deck", query: "Greetings")).error == nil)
        #expect(log.tab == "vocabulary")
        #expect(log.opened == ["app tab vocabulary", "vocabulary deck Greetings"])
    }

    @Test("back closes a lesson first, then pops the deepest stack that can pop")
    func back() async {
        let (control, _, log) = make()
        log.lesson = true
        log.pushed = true

        #expect(await control.handle(RemoteRequest(.back)).error == nil)
        #expect(!log.lesson && log.pushed)
        #expect(await control.handle(RemoteRequest(.back)).error == nil)
        #expect(!log.pushed)
        #expect(await control.handle(RemoteRequest(.back)).error == "nothing to go back from")
    }

    @Test("say queues the answer, then taps the microphone, only with scripted speech and a lesson open")
    func saying() async {
        let (control, registry, log) = make()
        #expect(await control.handle(RemoteRequest(.say, answer: "ni")).error?.hasPrefix("say needs the app launched with -scripted-speech") == true)

        var spoken: [String] = []
        registry.speak = { spoken.append($0) }
        #expect(await control.handle(RemoteRequest(.say, answer: "ni")).error == "say needs a speaking lesson open")

        registry.register(screen("speaking", log: log), as: UUID())
        #expect(await control.handle(RemoteRequest(.say, answer: "nihao")).error == nil)
        #expect(spoken == ["nihao"])
        #expect(log.sent.last == "speaking startListeningTapped")
    }

    @Test("with nothing on show able to pop, back dismisses the frontmost pushed screen")
    func backDismisses() async {
        let log = Log()
        let registry = ScreenRegistry()
        registry.app = screen("app", log: log)
        var dismissed: [String] = []
        // Settings pushed over home, which has disappeared and left the registry.
        registry.register(screen("settings", log: log), as: UUID(), dismiss: { dismissed.append("settings"); return true })
        let control = RemoteControl(registry: registry, transition: .zero)

        #expect(await control.handle(RemoteRequest(.back)).error == nil)
        #expect(dismissed == ["settings"])
    }

    @Test("a screen's own back is tried before any dismissal")
    func ownBackFirst() async {
        let (control, registry, log) = make()
        log.pushed = true
        var dismissed = 0
        registry.register(screen("deck", log: log), as: UUID(), dismiss: { dismissed += 1; return true })

        #expect(await control.handle(RemoteRequest(.back)).error == nil)
        #expect(!log.pushed)
        #expect(dismissed == 0)
    }

    @Test("a reply waits while a screen animates out, and no longer than the transition")
    func waitsWhileLeaving() async {
        let log = Log()
        let registry = ScreenRegistry()
        registry.app = screen("app", log: log)
        var checks = 0
        registry.register(screen("deck", log: log), as: UUID(), leaving: {
            checks += 1
            return checks < 5
        })
        let control = RemoteControl(registry: registry, transition: .seconds(5))
        #expect(await control.handle(RemoteRequest(.send, action: "tapped")).error == nil)
        #expect(checks >= 5)

        // One that never finishes leaving, as SwiftUI can leave a screen, holds a reply only so long.
        registry.register(screen("ghost", log: log), as: UUID(), leaving: { true })
        let capped = RemoteControl(registry: registry, transition: .milliseconds(20))
        #expect(await capped.handle(RemoteRequest(.send, action: "tapped")).error == nil)
        #expect(log.sent == ["deck tapped", "ghost tapped"])
    }

    @Test("a screen that disappears leaves the registry, so the one behind is in front again")
    func registry() {
        let (_, registry, log) = make()
        let id = UUID()
        registry.register(screen("lesson", log: log), as: id)
        #expect(registry.screens.last?.name == "lesson")
        registry.remove(id)
        #expect(registry.screens.map(\.name) == ["vocabulary", "deck"])
    }

    @Test("a screen coming back into view keeps its place, whatever order the screens reappear in")
    func reappearing() {
        let log = Log()
        let registry = ScreenRegistry()
        let (list, deck) = (UUID(), UUID())
        registry.register(screen("vocabulary", log: log), as: list)
        registry.register(screen("deck", log: log), as: deck)
        // Away to another tab and back: SwiftUI shows the pushed deck before the list.
        registry.remove(list)
        registry.remove(deck)
        registry.register(screen("deck", log: log), as: deck)
        registry.register(screen("vocabulary", log: log), as: list)
        #expect(registry.screens.map(\.name) == ["vocabulary", "deck"])
        // A screen new to the registry goes in front of them both.
        registry.register(screen("speaking", log: log), as: UUID())
        #expect(registry.screens.last?.name == "speaking")
    }

    @Test("a reply waits for the app to stop animating, as one transition follows another")
    func waitsForTransitions() async {
        let log = Log()
        var checks = 0
        let registry = ScreenRegistry(transitioning: {
            checks += 1
            return checks < 5
        })
        registry.app = screen("app", log: log)
        let control = RemoteControl(registry: registry, transition: .seconds(5))
        #expect(await control.handle(RemoteRequest(.tab, tab: "home")).error == nil)
        #expect(checks >= 5)
        // Reading waits for nothing.
        let before = checks
        _ = await control.handle(RemoteRequest(.ls))
        #expect(checks == before)
    }
}
