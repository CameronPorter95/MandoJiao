import Foundation
import LibraryDomain

/// Runs one command line against a session and returns what to print.
public final class Interpreter {
    public static let help = """
        ls                     the screens open, front last, and the actions the front one takes
        tab <tab>              home, library or dictionary
        open deck <deck>       in the library: a deck by name, built-in key or the start of its id
        open folder <folder>   in the library, the same way
        do <action> [json]     send the open screen an action, its payload as a JSON object
        say <answer>           speak an answer to the open speaking lesson
        state                  the open screen's whole state
        back                   close the lesson, or go back in the open tab
        quit
        """

    private let session: Session

    public init() throws {
        session = try Session()
    }

    public func run(_ command: String) async -> [String] {
        // What the last command set going, and the store's first load, land before this reads.
        await session.settle()
        let (verb, rest) = Self.split(command)
        var output: [String] = []
        do {
            switch verb {
            case "ls":
                output = try await list()
            case "tab":
                try session.select(rest)
            case "open":
                let (kind, query) = Self.split(rest)
                guard !query.isEmpty else { throw CLIError.usage("open deck|folder <name>") }
                try await session.open(kind, query)
            case "do":
                guard let top = session.top else { throw CLIError.usage("nothing is open") }
                let (action, arguments) = Self.split(rest)
                guard !action.isEmpty else { throw CLIError.usage("do <action> [json]") }
                try top.send(action, arguments.isEmpty ? nil : Data(arguments.utf8))
            case "say":
                guard !rest.isEmpty else { throw CLIError.usage("say <answer>") }
                try session.say(rest)
            case "state":
                guard let top = session.top else { throw CLIError.usage("nothing is open") }
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

    /// One line per screen open, the tab first and the front last, then what the front one takes.
    private func list() async throws -> [String] {
        let chain = session.chain
        guard let top = chain.last else { return [] }
        return chain.map { $0.summary() } + ["actions: \(top.actions.joined(separator: ", "))"]
    }

    /// The first word, and the rest of the line.
    private static func split(_ text: String) -> (String, String) {
        let parts = text.split(separator: " ", maxSplits: 1)
        return (parts.first.map(String.init) ?? "", parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : "")
    }
}
