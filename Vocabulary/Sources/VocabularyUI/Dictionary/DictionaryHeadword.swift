import Foundation

/// A dictionary page to open: some Hanzi, and the reading a library word has, which the
/// page puts first.
public struct DictionaryHeadword: Hashable, Identifiable, Sendable {
    public let hanzi: String
    public let pinyin: String?

    public var id: Self { self }

    public init(hanzi: String, pinyin: String? = nil) {
        self.hanzi = hanzi
        self.pinyin = pinyin
    }
}
