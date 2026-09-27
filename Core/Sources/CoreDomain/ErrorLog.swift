import Foundation

/// Where logged errors go. Registered once at launch; unset, it drops them.
public nonisolated enum ErrorLog {
    nonisolated(unsafe) public static var sink: @Sendable (_ model: DomainErrorModel, _ context: String) -> Void = { _, _ in }

    public static func record(_ model: DomainErrorModel, context: String) {
        sink(model, context)
    }
}
