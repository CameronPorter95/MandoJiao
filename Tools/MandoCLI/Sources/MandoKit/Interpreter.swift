import Foundation

/// Runs one command line against a session and returns what to print.
public final class Interpreter {
    public static let help = """
        ls                     the screens open, front last, and the actions the front one takes
        tab <tab>              home, vocabulary or dictionary
        open deck <deck>       in the vocabulary tab: a deck by name, built-in key or the start of its id
        open folder <folder>   in the vocabulary tab, the same way
        do <action> [json]     send the open screen an action, its payload as a JSON object
        say <answer>           speak an answer to the open speaking lesson
        state                  the open screen's whole state
        back                   close the lesson, or go back in the open tab
        quit
        """

    private let session: Backend

    /// Screens built here, over an in-memory store.
    public init() throws {
        session = try Session()
    }

    /// The app on the simulator, launched with -remote.
    public init(remotePort: UInt16) async throws {
        session = try await RemoteBackend(port: remotePort)
    }

    public func run(_ command: String) async -> [String] {
        // What the last command set going, and the store's first load, land before this reads.
        await session.settle()
        let (verb, rest) = Self.split(command)
        var output: [String] = []
        do {
            switch verb {
            case "ls":
                output = try await session.list()
            case "tab":
                try await session.select(rest)
            case "open":
                let (kind, query) = Self.split(rest)
                guard !query.isEmpty else { throw CLIError.usage("open deck|folder <name>") }
                try await session.open(kind, query)
            case "do":
                let (action, arguments) = Self.split(rest)
                guard !action.isEmpty else { throw CLIError.usage("do <action> [json]") }
                try await session.send(action, arguments.isEmpty ? nil : arguments)
            case "say":
                guard !rest.isEmpty else { throw CLIError.usage("say <answer>") }
                try await session.say(rest)
            case "state":
                output = try await session.state()
            case "back":
                try await session.back()
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

    /// The first word, and the rest of the line.
    private static func split(_ text: String) -> (String, String) {
        let parts = text.split(separator: " ", maxSplits: 1)
        return (parts.first.map(String.init) ?? "", parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : "")
    }
}
