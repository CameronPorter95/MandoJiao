import Foundation
import LibraryDomain

/// Runs one command line against a session and returns what to print.
public final class Interpreter {
    public static let help = """
        ls                     what is open and the actions it takes, or the decks when nothing is
        open deck <deck>       a deck by name, built-in key or the start of its id
        do <action> [json]     send the open screen an action, its payload as a JSON object
        say <answer>           speak an answer to the open speaking lesson
        state                  the open screen's whole state
        back                   close the open screen
        quit
        """

    private let session: Session

    public init() throws {
        session = try Session()
    }

    public func run(_ command: String) async -> [String] {
        let (verb, rest) = Self.split(command)
        var output: [String] = []
        do {
            switch verb {
            case "ls":
                output = try await list()
            case "open":
                let (kind, query) = Self.split(rest)
                guard kind == "deck", !query.isEmpty else { throw CLIError.usage("open deck <deck>") }
                try await session.openDeck(query)
            case "do":
                guard let top = session.top else { throw CLIError.nothingOpen }
                let (action, arguments) = Self.split(rest)
                guard !action.isEmpty else { throw CLIError.usage("do <action> [json]") }
                try top.send(action, arguments.isEmpty ? nil : Data(arguments.utf8))
            case "say":
                guard !rest.isEmpty else { throw CLIError.usage("say <answer>") }
                try session.say(rest)
            case "state":
                guard let top = session.top else { throw CLIError.nothingOpen }
                output = top.dump().split(separator: "\n").map(String.init)
            case "back":
                try session.back()
            case "help":
                return Self.help.split(separator: "\n").map(String.init)
            default:
                throw CLIError.usage("unknown command \"\(verb)\", try help")
            }
            await session.settle()
            output.append("✓ \(verb == "do" ? Self.split(rest).0 : verb)")
        } catch {
            await session.settle()
            output.append("✗ \(error)")
        }
        return output + session.takeNotes()
    }

    private func list() async throws -> [String] {
        if let top = session.top {
            return [top.summary(), "actions: \(top.actions.joined(separator: ", "))"]
        }
        let vocabulary = await session.vocabulary()
        return vocabulary.decks.sorted { $0.name < $1.name }.map { deck in
            let key = deck.builtInKey.map { "  key: \($0)" } ?? ""
            return "\(deck.name)  \(deck.wordIDs.count) words  id: \(deck.id.uuidString.prefix(8))\(key)"
        }
    }

    /// The first word, and the rest of the line.
    private static func split(_ text: String) -> (String, String) {
        let parts = text.split(separator: " ", maxSplits: 1)
        return (parts.first.map(String.init) ?? "", parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : "")
    }
}
