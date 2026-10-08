import Foundation
import Testing
@testable import CoreUI

@Suite("Screen driver")
@MainActor
struct ScreenDriverTests {
    private enum Action: Decodable, Equatable {
        case tapped
        case typed(text: String)
    }

    private struct State {
        var text = "hello"
    }

    @Test("a case with no payload needs no arguments")
    func noPayload() throws {
        #expect(try ScreenDriver.decode(Action.self, name: "tapped", arguments: nil) == .tapped)
    }

    @Test("a payload is read by its labels")
    func labelledPayload() throws {
        let arguments = Data(#"{"text":"你好"}"#.utf8)
        #expect(try ScreenDriver.decode(Action.self, name: "typed", arguments: arguments) == .typed(text: "你好"))
    }

    @Test("arguments that are not JSON are refused")
    func notJSON() {
        #expect(throws: ScreenDriverError.badArguments("typed")) {
            try ScreenDriver.decode(Action.self, name: "typed", arguments: Data("text".utf8))
        }
    }

    @Test("an action the screen does not list is refused before decoding")
    func unlisted() {
        var sent: [Action] = []
        let driver = ScreenDriver(
            name: "probe", actions: ["typed"], state: { State() }, summary: { $0.text },
            send: { sent.append($0) }, effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 }
        )
        #expect(throws: ScreenDriverError.unknownAction("tapped")) { try driver.send("tapped", nil) }
        #expect(sent.isEmpty)
    }

    @Test("the dump shows the whole state")
    func dump() {
        let driver = ScreenDriver(
            name: "probe", actions: [], state: { State() }, summary: { $0.text },
            send: { (_: Action) in }, effects: { AsyncStream<Int> { $0.finish() } }, follow: { $0 }
        )
        #expect(driver.dump().contains(#"text: "hello""#))
    }
}
