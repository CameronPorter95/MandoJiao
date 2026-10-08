import Foundation
import Network

/// Listens on the loopback interface for one JSON request per line and answers each on a line
/// of its own. For debug builds launched to be driven; never start it otherwise.
///
/// Network calls back on its own queue, so every callback here is nonisolated and hops to the
/// main actor before touching the control, or Swift 6 traps at runtime.
public nonisolated final class RemoteServer: Sendable {
    public static let defaultPort: UInt16 = 9393

    private let listener: NWListener
    private let control: RemoteControl
    private let queue = DispatchQueue(label: "MandoJiao.RemoteServer")

    public init(control: RemoteControl, port: UInt16 = defaultPort) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        parameters.allowLocalEndpointReuse = true
        listener = try NWListener(using: parameters)
        self.control = control
    }

    public func start() {
        let control = control
        let queue = queue
        listener.newConnectionHandler = { connection in
            RemoteConnection(connection: connection, control: control, queue: queue).start()
        }
        listener.start(queue: queue)
    }
}

/// Reads a connection's requests in turn, replying to each before reading the next.
private nonisolated final class RemoteConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let control: RemoteControl
    private let queue: DispatchQueue
    /// Only touched on `queue`.
    private var buffer = Data()

    init(connection: NWConnection, control: RemoteControl, queue: DispatchQueue) {
        self.connection = connection
        self.control = control
        self.queue = queue
    }

    func start() {
        connection.start(queue: queue)
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [self] data, _, isComplete, error in
            if let data { buffer.append(data) }
            if let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[buffer.startIndex..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                answer(Data(line))
            } else if isComplete || error != nil {
                connection.cancel()
            } else {
                receive()
            }
        }
    }

    private func answer(_ line: Data) {
        let control = control
        Task { [self] in
            let reply: RemoteReply
            if let request = try? JSONDecoder().decode(RemoteRequest.self, from: line) {
                reply = await control.handle(request)
            } else {
                reply = RemoteReply(error: "not a request")
            }
            var data = (try? JSONEncoder().encode(reply)) ?? Data()
            data.append(UInt8(ascii: "\n"))
            connection.send(content: data, completion: .contentProcessed { [self] _ in
                queue.async { self.receive() }
            })
        }
    }
}
