import CoreRemote
import Foundation
import Network

/// What the commands run against: screens built here, or the app on the simulator.
@MainActor
protocol Backend: AnyObject {
    /// One line per screen open, front last, then the front one's actions.
    func list() async throws -> [String]
    func send(_ action: String, _ arguments: String?) async throws
    func select(_ tab: String) async throws
    func open(_ kind: String, _ query: String) async throws
    func say(_ answer: String) async throws
    func back() async throws
    func state() async throws -> [String]
    /// Waits for what the last command set going. The app settles before it replies.
    func settle() async
    /// Effects and attempts since the last call. The app's Routes follow their own.
    func takeNotes() -> [String]
}

/// The app launched with -remote, reached over the loopback interface.
final class RemoteBackend: Backend {
    private let client: RemoteClient

    init(port: UInt16) async throws {
        client = RemoteClient(port: port)
        try await client.connect()
    }

    func list() async throws -> [String] { try await request(RemoteRequest(.ls)) }
    func send(_ action: String, _ arguments: String?) async throws {
        _ = try await request(RemoteRequest(.send, action: action, arguments: arguments))
    }
    func select(_ tab: String) async throws { _ = try await request(RemoteRequest(.tab, tab: tab)) }
    func open(_ kind: String, _ query: String) async throws {
        _ = try await request(RemoteRequest(.open, kind: kind, query: query))
    }
    func back() async throws { _ = try await request(RemoteRequest(.back)) }
    func state() async throws -> [String] { try await request(RemoteRequest(.state)) }
    func say(_ answer: String) async throws {
        throw CLIError.usage(#"the app's microphone is real in remote mode; type it: do typedAnswerSubmitted {"answer":"\#(answer)"}"#)
    }
    func settle() async {}
    func takeNotes() -> [String] { [] }

    private func request(_ request: RemoteRequest) async throws -> [String] {
        let reply = try await client.send(request)
        if let error = reply.error { throw CLIError.usage(error) }
        return reply.lines
    }
}

/// One connection, one request in flight at a time, each reply a JSON line.
private nonisolated final class RemoteClient: @unchecked Sendable {
    private let connection: NWConnection
    private let port: UInt16
    private let queue = DispatchQueue(label: "mando.remote")
    /// Only touched while a request is in flight, and requests are awaited one at a time.
    private var buffer = Data()

    init(port: UInt16) {
        self.port = port
        connection = NWConnection(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
    }

    func connect() async throws {
        let port = port
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = Once()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    once.run { continuation.resume() }
                case .waiting, .failed:
                    once.run { continuation.resume(throwing: CLIError.usage("nothing is listening on \(port); launch the app with -remote")) }
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ request: RemoteRequest) async throws -> RemoteReply {
        var data = try JSONEncoder().encode(request)
        data.append(UInt8(ascii: "\n"))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
        while true {
            if let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = Data(buffer[buffer.startIndex..<newline])
                buffer.removeSubrange(buffer.startIndex...newline)
                return try JSONDecoder().decode(RemoteReply.self, from: line)
            }
            buffer.append(try await receive())
        }
    }

    private func receive() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: CLIError.usage(isComplete ? "the app closed the connection" : "no reply"))
                }
            }
        }
    }
}

/// Resumes a continuation at most once, whichever state comes first.
private nonisolated final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}
