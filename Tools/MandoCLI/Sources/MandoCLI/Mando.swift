import Foundation
import MandoKit

@main
struct Mando {
    static func main() async {
        let interpreter: Interpreter
        do {
            // mando --remote [port] drives the app on the simulator, launched with -remote.
            let arguments = CommandLine.arguments.dropFirst()
            if let flag = arguments.firstIndex(of: "--remote") {
                let port = arguments.dropFirst(flag - arguments.startIndex + 1).first.flatMap(UInt16.init) ?? 9393
                interpreter = try await Interpreter(remotePort: port)
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

    private static func prompt(_ prompt: String) {
        print(prompt, terminator: "")
        fflush(stdout)
    }
}
