import Foundation

/// One command to the running app, one JSON object per line.
public nonisolated struct RemoteRequest: Codable, Sendable, Equatable {
    public enum Operation: String, Codable, Sendable {
        case ls, send, tab, open, back, state
    }

    public var operation: Operation
    /// `send`: the action, and its payload as JSON text.
    public var action: String?
    public var arguments: String?
    /// `tab`.
    public var tab: String?
    /// `open`.
    public var kind: String?
    public var query: String?

    public init(
        _ operation: Operation,
        action: String? = nil, arguments: String? = nil,
        tab: String? = nil, kind: String? = nil, query: String? = nil
    ) {
        self.operation = operation
        self.action = action
        self.arguments = arguments
        self.tab = tab
        self.kind = kind
        self.query = query
    }
}

/// What a command printed, or why it failed.
public nonisolated struct RemoteReply: Codable, Sendable, Equatable {
    public var lines: [String]
    public var error: String?

    public init(lines: [String] = [], error: String? = nil) {
        self.lines = lines
        self.error = error
    }
}
