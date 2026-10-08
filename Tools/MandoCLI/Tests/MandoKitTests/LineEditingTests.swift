import Foundation
import Testing

/// mando at a terminal, run through `expect` in a pseudo-terminal with a HOME of its own, so the
/// real ~/.mando_history is never touched. Nonisolated: it waits on processes.
@Suite("mando at a terminal", .serialized)
nonisolated struct LineEditingTests {
    private let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test("arrows edit and recall, Chinese is typed whole, Ctrl-D quits, and history lasts between runs",
          .enabled(if: FileManager.default.isExecutableFile(atPath: "/usr/bin/expect")))
    func lineEditing() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let first = try run("first", home: home)
        let second = try run("second", home: home)

        #expect(first == [
            "PASS up arrow recalls the last command", "PASS left arrow edits mid-line",
            "PASS Chinese is typed whole", "PASS Ctrl-D quits",
        ])
        #expect(second == ["PASS history comes back in a new run", "PASS Ctrl-D quits"])
        let history = try String(contentsOf: home.appendingPathComponent(".mando_history"), encoding: .utf8)
        // A command run twice running, as the up arrow just did, is kept once.
        #expect(history.components(separatedBy: "open\\040deck\\040Greetings").count - 1 == 1)
    }

    private func run(_ which: String, home: URL) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/expect")
        process.arguments = [
            package.appendingPathComponent("Tests/line-editing.exp").path,
            package.appendingPathComponent(".build/debug/mando").path,
            which,
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = home.path
        environment["LANG"] = "en_US.UTF-8"
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
