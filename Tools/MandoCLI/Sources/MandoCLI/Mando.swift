import Foundation
import LibraryDomain

@main
struct Mando {
    static let help = """
        ls                     what is open and the actions it takes, or the decks when nothing is
        open deck <deck>       a deck by name, built-in key or the start of its id
        do <action> [json]     send the open screen an action, its payload as a JSON object
        say <answer>           speak an answer to the open speaking lesson
        state                  the open screen's whole state
        back                   close the open screen
        quit
        """

    static func main() async {
        let session: Session
        do {
            session = try Session()
        } catch {
            print("✗ could not open the store: \(error)")
            exit(1)
        }

        // Piped input is echoed, so a transcript reads like a session typed by hand.
        let echoes = isatty(STDIN_FILENO) == 0
        prompt()
        do {
            // Read without blocking the main actor, which every screen's work runs on.
            for try await line in FileHandle.standardInput.bytes.lines {
                if echoes { print(line) }
                let command = line.trimmingCharacters(in: .whitespaces)
                if command == "quit" || command == "exit" { break }
                if !command.isEmpty { await run(command, in: session) }
                prompt()
            }
        } catch {
            print("✗ \(error)")
        }
        if echoes { print() }
    }

    private static func prompt() {
        print("mando> ", terminator: "")
        fflush(stdout)
    }

    private static func run(_ command: String, in session: Session) async {
        let (verb, rest) = split(command)
        do {
            switch verb {
            case "ls":
                try await list(session)
            case "open":
                let (kind, query) = split(rest)
                guard kind == "deck", !query.isEmpty else { throw CLIError.usage("open deck <deck>") }
                try await session.openDeck(query)
            case "do":
                guard let top = session.top else { throw CLIError.nothingOpen }
                let (action, arguments) = split(rest)
                guard !action.isEmpty else { throw CLIError.usage("do <action> [json]") }
                try top.send(action, arguments.isEmpty ? nil : Data(arguments.utf8))
            case "say":
                guard !rest.isEmpty else { throw CLIError.usage("say <answer>") }
                try session.say(rest)
            case "state":
                guard let top = session.top else { throw CLIError.nothingOpen }
                print(top.dump(), terminator: "")
            case "back":
                try session.back()
            case "help":
                print(help)
                return
            default:
                throw CLIError.usage("unknown command \"\(verb)\", try help")
            }
            await session.settle()
            print("✓ \(verb == "do" ? split(rest).0 : verb)")
        } catch {
            await session.settle()
            print("✗ \(error)")
        }
        session.takeNotes().forEach { print($0) }
    }

    private static func list(_ session: Session) async throws {
        if let top = session.top {
            print(top.summary())
            print("actions: \(top.actions.joined(separator: ", "))")
            return
        }
        let vocabulary = await session.vocabulary()
        for deck in vocabulary.decks.sorted(by: { $0.name < $1.name }) {
            let key = deck.builtInKey.map { "  key: \($0)" } ?? ""
            print("\(deck.name)  \(deck.wordIDs.count) words  id: \(deck.id.uuidString.prefix(8))\(key)")
        }
    }

    /// The first word, and the rest of the line.
    private static func split(_ text: String) -> (String, String) {
        let parts = text.split(separator: " ", maxSplits: 1)
        return (parts.first.map(String.init) ?? "", parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : "")
    }
}
