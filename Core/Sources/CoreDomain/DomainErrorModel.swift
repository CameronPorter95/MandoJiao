import Foundation

/// A failure reduced to primitives, so it can cross a layer or a language boundary.
public nonisolated struct DomainErrorModel: Equatable, Sendable {
    public let domain: String
    public let code: Int
    public let description: String

    public init(domain: String, code: Int, description: String) {
        self.domain = domain
        self.code = code
        self.description = description
    }

    public init(_ error: any Error) {
        let nsError = error as NSError
        self.init(domain: nsError.domain, code: nsError.code, description: String(describing: error))
    }
}
