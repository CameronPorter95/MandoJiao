import Foundation
import MandoKit

@main
struct Mando {
    static func main() async {
        let interpreter: Interpreter
        do {
            // mando --remote [port] drives the app on the simulator, launched with -remote.
            // mando --store <path> runs headlessly over a copy of a store, such as a simulator's.
            let arguments = Array(CommandLine.arguments.dropFirst())
            let store = arguments.firstIndex(of: "--store").map { flag in
                arguments.indices.contains(flag + 1) ? arguments[flag + 1] : ""
            }
            if let flag = arguments.firstIndex(of: "--remote") {
                // The app has a store of its own; there is nothing to hand it.
                if store != nil { refuse("--store is for running headlessly; the app uses its own store") }
                let port = arguments.indices.contains(flag + 1) ? UInt16(arguments[flag + 1]) ?? 9393 : 9393
                interpreter = try await Interpreter(remotePort: port)
            } else if let store {
                if store.isEmpty { refuse("--store <path to a store, or an app's data container>") }
                interpreter = try Interpreter(store: URL(fileURLWithPath: (store as NSString).expandingTildeInPath))
            } else {
                interpreter = try Interpreter()
            }
        } catch {
            print("✗ \(error)")
            exit(1)
        }
        print(interpreter.banner)

        if isatty(STDIN_FILENO) == 1 {
            await edit(with: interpreter)
        } else {
            await readPiped(into: interpreter)
        }
    }

    /// At a terminal: arrow keys and history.
    private static func edit(with interpreter: Interpreter) async {
        let editor = LineEditor(prompt: interpreter.prompt)
        for await line in editor.lines() {
            let command = line.trimmingCharacters(in: .whitespaces)
            if command == "quit" || command == "exit" { return }
            if !command.isEmpty { await interpreter.run(command).forEach { print($0) } }
            editor.ready()
        }
        // Ctrl-D leaves the cursor after the prompt.
        print()
    }

    /// Piped in, as by a script or an agent: each line is echoed after the prompt, so the
    /// transcript reads like a session typed by hand.
    private static func readPiped(into interpreter: Interpreter) async {
        prompt(interpreter.prompt)
        do {
            // Read without blocking the main actor, which every screen's work runs on.
            for try await line in FileHandle.standardInput.bytes.lines {
                print(line)
                let command = line.trimmingCharacters(in: .whitespaces)
                if command == "quit" || command == "exit" { break }
                if !command.isEmpty { await interpreter.run(command).forEach { print($0) } }
                prompt(interpreter.prompt)
            }
        } catch {
            print("✗ \(error)")
        }
        print()
    }

    private static func refuse(_ reason: String) -> Never {
        print("✗ \(reason)")
        exit(1)
    }

    private static func prompt(_ prompt: String) {
        print(prompt, terminator: "")
        fflush(stdout)
    }
}
