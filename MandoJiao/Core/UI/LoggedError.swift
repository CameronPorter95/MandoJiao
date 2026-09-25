import Foundation

/// A display error that knows what to log about itself.
protocol LoggedError: LocalizedError {
    var loggedModel: DomainErrorModel { get }
    /// Names the operation that failed, for reading the log.
    var logContext: String { get }
}

extension LoggedError {
    func log() {
        ErrorLog.record(loggedModel, context: logContext)
    }
}
