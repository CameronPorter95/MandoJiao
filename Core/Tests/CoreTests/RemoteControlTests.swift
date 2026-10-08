import Foundation
import Testing
@testable import CoreRemote
@testable import CoreUI

@Suite("Remote control")
@MainActor
struct RemoteControlTests {
    private enum Action: Decodable {
        case appeared, disappeared, tapped
        case selectTab(tab: String)
    }

    private final class Log {
        var sent: [String] = []
        var opened: [String] = []
        var tab = "home"
        var lesson = false
        var pushed = false
    }

    private func screen(_ name: String, log: Log, back: @escaping () -> Bool = { false }) -> ScreenDriver {
        ScreenDriver(
            name: name, actions: ["appeared", "disappeared", "tapped", "selectTab"],
            state: { name }, summary: { "\($0) shown" },
            send: { (action: Action) in
                if case .selectTab(let tab) = action { log.tab = tab }
                log.sent.append("\(name) \(action)")
            },
            effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 }, back: back,
            open: { kind, query in log.opened.append("\(name) \(kind) \(query)") }
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
        registry.register(screen("library", log: log, back: {
            guard log.pushed else { return false }
            log.pushed = false
            return true
        }), as: UUID())
        registry.register(screen("deck", log: log), as: UUID())
        return (RemoteControl(registry: registry, transition: .zero), registry, log)
    }

    @Test("ls shows the app, then each screen on show, then the front one's actions")
    func listing() async {
        let (control, _, _) = make()
        let reply = await control.handle(RemoteRequest(.ls))
        #expect(reply == RemoteReply(lines: [
            "app shown", "library shown", "deck shown",
            "actions: appeared, disappeared, tapped, selectTab",
        ]))
    }

    @Test("an action goes to the screen in front, and a tab to the app")
    func sending() async {
        let (control, _, log) = make()
        #expect(await control.handle(RemoteRequest(.send, action: "tapped")).error == nil)
        #expect(await control.handle(RemoteRequest(.tab, tab: "library")).error == nil)
        #expect(log.sent == ["deck tapped", #"app selectTab(tab: "library")"#])
        #expect(await control.handle(RemoteRequest(.send, action: "bogus")).error == #"no action "bogus" here, see ls"#)
    }

    @Test("open selects the library tab, then asks the library to find it")
    func opening() async {
        let (control, _, log) = make()
        #expect(await control.handle(RemoteRequest(.open, kind: "deck", query: "Greetings")).error == nil)
        #expect(log.tab == "library")
        #expect(log.opened == ["library deck Greetings"])
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

    @Test("a screen that disappears leaves the registry, so the one behind is in front again")
    func registry() {
        let (_, registry, log) = make()
        let id = UUID()
        registry.register(screen("lesson", log: log), as: id)
        #expect(registry.screens.last?.name == "lesson")
        registry.remove(id)
        #expect(registry.screens.map(\.name) == ["library", "deck"])
    }
}
