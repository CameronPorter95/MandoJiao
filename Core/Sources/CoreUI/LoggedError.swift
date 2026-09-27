import CoreDomain
import Foundation

/// A display error that knows what to log about itself.
public nonisolated protocol LoggedError: LocalizedError, Sendable {
    var loggedModel: DomainErrorModel { get }
    /// Names the operation that failed, for reading the log.
    var logContext: String { get }
}

nonisolated extension LoggedError {
    public func log() {
        ErrorLog.record(loggedModel, context: logContext)
    }
}
