import CEditLine
import Foundation

/// Reads lines with libedit at a terminal: left and right move the cursor, up and down walk the
/// history, kept between runs in ~/.mando_history.
///
/// libedit blocks while it waits for a line, and every screen's work runs on the main actor, so
/// it reads on a thread of its own. It waits for `ready()` before reading the next line, so the
/// prompt comes after the last command's reply rather than in the middle of it.
nonisolated final class LineEditor: Sendable {
    private let prompt: String
    private let historyPath: String
    private let next = DispatchSemaphore(value: 0)

    init(prompt: String) {
        self.prompt = prompt
        // HOME first, so a test can keep its history out of the real one.
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        historyPath = URL(fileURLWithPath: home).appendingPathComponent(".mando_history").path
    }

    func lines() -> AsyncStream<String> {
        let (lines, continuation) = AsyncStream.makeStream(of: String.self)
        let thread = Thread { [self] in
            // Without the user's locale, libedit takes Chinese a byte at a time.
            setlocale(LC_ALL, "")
            stifle_history(500)
            read_history(historyPath)
            // The last command kept, the last run's to begin with.
            var last = mando_last_history().map { String(cString: $0) } ?? ""
            while let typed = readline(prompt) {
                let line = String(cString: typed)
                free(typed)
                // A command run twice running is kept once, as shells do.
                if !line.trimmingCharacters(in: .whitespaces).isEmpty, line != last {
                    add_history(line)
                    write_history(historyPath)
                    last = line
                }
                continuation.yield(line)
                next.wait()
            }
            continuation.finish()
        }
        thread.start()
        return lines
    }

    /// The last line's reply is printed, so the next prompt can go up.
    func ready() {
        next.signal()
    }
}
