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

        // Piped input is echoed, so a transcript reads like a session typed by hand.
        let echoes = isatty(STDIN_FILENO) == 0
        prompt()
        do {
            // Read without blocking the main actor, which every screen's work runs on.
            for try await line in FileHandle.standardInput.bytes.lines {
                if echoes { print(line) }
                let command = line.trimmingCharacters(in: .whitespaces)
                if command == "quit" || command == "exit" { break }
                if !command.isEmpty { await interpreter.run(command).forEach { print($0) } }
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
}
