import Foundation

/// A screen driven by action name, without its view, for tools that run the app headlessly.
@MainActor
public struct ScreenDriver {
    public let name: String
    /// Every action name `send` accepts.
    public let actions: [String]
    /// Takes an action's name and its payload as a JSON object, or nil for none.
    public let send: (_ action: String, _ arguments: Data?) throws -> Void
    /// One line, for reading at a glance.
    public let summary: () -> String
    /// The whole state, as `dump` prints it.
    public let dump: () -> String
    /// The state, cheaply: what a settle compares while it waits, many times a second.
    public let fingerprint: () -> String
    /// The effects left over once navigation has been followed, described.
    public let effects: () -> AsyncStream<String>
    /// The screen this one shows in front of itself, such as a page pushed onto its stack.
    public let front: () -> ScreenDriver?
    /// Pops its own stack by one, as the back button does. False when it has nothing to pop.
    public let back: () -> Bool
    /// Working on something that will change what it shows, such as a search under way.
    public let isBusy: () -> Bool
    /// Showing a dialog over everything in front of it, such as asking whether to quit, so
    /// commands reach it and not the screens it covers.
    public let covers: () -> Bool
    /// Opens something this screen lists by its name, as tapping its row would.
    public let open: (_ kind: String, _ query: String) throws -> Void
    /// Answers the card showing, right or wrong, as a learner would, then goes on to the next
    /// where the card is done. Says what it gave and how it was graded.
    public let answer: (_ right: Bool) throws -> String

    /// `follow` carries out an effect that navigates and returns the rest, as the screen's Route does.
    public init<State, Action: Decodable, Effect: Sendable>(
        name: String,
        actions: [String],
        state: @escaping () -> State,
        summary: @escaping (State) -> String,
        send: @escaping (Action) -> Void,
        effects: @escaping () -> AsyncStream<Effect>,
        follow: @escaping (Effect) -> Effect?,
        front: @escaping () -> ScreenDriver? = { nil },
        back: @escaping () -> Bool = { false },
        relay: EffectRelay? = nil,
        isBusy: @escaping (State) -> Bool = { _ in false },
        covers: @escaping (State) -> Bool = { _ in false },
        open: @escaping (_ kind: String, _ query: String) throws -> Void = { kind, _ in throw ScreenDriverError.cannotOpen(kind) },
        answer: @escaping (_ right: Bool) throws -> String = { _ in throw ScreenDriverError.cannotAnswer("nothing to answer here") }
    ) {
        self.open = open
        self.answer = answer
        self.front = front
        self.back = back
        self.isBusy = { isBusy(state()) }
        self.covers = { covers(state()) }
        self.name = name
        self.actions = actions
        self.send = { action, arguments in
            guard actions.contains(action) else { throw ScreenDriverError.unknownAction(action) }
            send(try Self.decode(Action.self, name: action, arguments: arguments))
        }
        self.summary = { summary(state()) }
        self.dump = {
            var text = ""
            Swift.dump(state(), to: &text)
            return text
        }
        self.fingerprint = { String(describing: state()) }
        self.effects = {
            let source = effects()
            let (described, continuation) = AsyncStream.makeStream(of: String.self)
            relay?.sink = { continuation.yield($0) }
            let task = Task {
                for await effect in source {
                    if let left = follow(effect) { continuation.yield(Self.describe(left)) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
            return described
        }
    }

    /// An effect as Swift prints it, without the modules its types are qualified with:
    /// `haptic(SpeakingHaptic.success)` rather than `haptic(PracticeUI.SpeakingHaptic.success)`.
    nonisolated static func describe(_ effect: some Sendable) -> String {
        // One of the app's packages' modules, followed by the dot that qualifies a type.
        let module = /\b(?:Core|Library|Dictionary|Practice|Progress|Settings)(?:Domain|Data|UI|DI|Sound|Persistence|DesignSystem|Remote|TestSupport)\./
        return String(describing: effect).replacing(module, with: "")
    }

    /// Wraps the payload as `{"name": arguments}`, the shape synthesised `Codable` gives an enum case.
    static func decode<Action: Decodable>(_ type: Action.Type, name: String, arguments: Data?) throws -> Action {
        do {
            let payload = try arguments.map { try JSONSerialization.jsonObject(with: $0) } ?? [String: Any]()
            let wrapped = try JSONSerialization.data(withJSONObject: [name: payload])
            return try JSONDecoder().decode(type, from: wrapped)
        } catch {
            throw ScreenDriverError.badArguments(name)
        }
    }
}

/// Carries what a screen in front leaves over into the effects of the screen behind it, as an
/// alert shown by a pushed screen still shows in the app.
@MainActor
public final class EffectRelay {
    var sink: ((String) -> Void)?

    public init() {}
}

public nonisolated enum ScreenDriverError: Error, Equatable, CustomStringConvertible {
    case unknownAction(String)
    case badArguments(String)
    case cannotOpen(String)
    /// Why the screen cannot answer as asked.
    case cannotAnswer(String)
    case notFound(String, String)
    /// The kind, what was asked for, and the names there are.
    case notOneOf(String, String, [String])

    public var description: String {
        switch self {
        case .unknownAction(let action): "no action \"\(action)\" here, see ls"
        case .badArguments(let action): "the arguments do not fit \(action)"
        case .cannotOpen(let kind): "nothing here opens a \(kind)"
        case .cannotAnswer(let reason): reason
        case .notFound(let kind, let query): "no \(kind) matches \"\(query)\""
        case .notOneOf(let kind, let query, let names):
            "no \(kind) \"\(query)\"; the \(kind)s are \(names.dropLast().joined(separator: ", ")) and \(names.last ?? "")"
        }
    }
}
