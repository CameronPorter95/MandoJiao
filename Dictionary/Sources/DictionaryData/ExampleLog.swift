import DictionaryDomain
import Foundation
import FoundationModels
import OSLog

/// Prints every sentence the on-device model writes, and whether the checks keep it, since a
/// dropped sentence otherwise leaves only a card with no example. Found needed when 可能 got
/// none in the app on the simulator while the same request passed eight times in eight on the
/// Mac. Debug builds only, as `SpeechLog`.
nonisolated enum ExampleLog {
    #if DEBUG
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MandoJiao", category: "examples")
    #endif

    static func wrote(_ request: ExampleRequest, hanzi: String, english: String, verdict: String) {
        #if DEBUG
        logger.notice("example \(request.hanzi, privacy: .public) \"\(request.meaning, privacy: .public)\": \(hanzi, privacy: .public) | \(english, privacy: .public) → \(verdict, privacy: .public)")
        #endif
    }

    static func failed(_ request: ExampleRequest, _ error: LanguageModelSession.GenerationError) {
        #if DEBUG
        logger.notice("example \(request.hanzi, privacy: .public) \"\(request.meaning, privacy: .public)\": \(String(describing: error), privacy: .public)")
        #endif
    }
}
