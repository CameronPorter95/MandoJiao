import Foundation

/// A failure reduced to primitives, so it can cross a layer or a language boundary.
nonisolated struct DomainErrorModel: Equatable, Sendable {
    let domain: String
    let code: Int
    let description: String

    init(domain: String, code: Int, description: String) {
        self.domain = domain
        self.code = code
        self.description = description
    }

    init(_ error: any Error) {
        let nsError = error as NSError
        self.init(domain: nsError.domain, code: nsError.code, description: String(describing: error))
    }
}
