import Foundation
import SwiftData

/// Starter vocabulary so a fresh install has something to practise with.
/// Everything here is editable and deletable from the library screen.
enum SampleVocabulary {
    struct Entry {
        let english: String
        let hanzi: String
        let pinyin: String
    }

    static let greetings: [Entry] = [
        Entry(english: "hello", hanzi: "你好", pinyin: "nǐ hǎo"),
        Entry(english: "thank you", hanzi: "谢谢", pinyin: "xièxie"),
        Entry(english: "sorry", hanzi: "对不起", pinyin: "duìbùqǐ"),
        Entry(english: "goodbye", hanzi: "再见", pinyin: "zàijiàn"),
        Entry(english: "please", hanzi: "请", pinyin: "qǐng"),
        Entry(english: "name", hanzi: "名字", pinyin: "míngzi"),
        Entry(english: "friend", hanzi: "朋友", pinyin: "péngyou"),
        Entry(english: "teacher", hanzi: "老师", pinyin: "lǎoshī"),
        Entry(english: "student", hanzi: "学生", pinyin: "xuésheng"),
        Entry(english: "happy", hanzi: "高兴", pinyin: "gāoxìng")
    ]

    static let basics: [Entry] = [
        Entry(english: "I, me", hanzi: "我", pinyin: "wǒ"),
        Entry(english: "you", hanzi: "你", pinyin: "nǐ"),
        Entry(english: "he, him", hanzi: "他", pinyin: "tā"),
        Entry(english: "good", hanzi: "好", pinyin: "hǎo"),
        Entry(english: "to be", hanzi: "是", pinyin: "shì"),
        Entry(english: "not", hanzi: "不", pinyin: "bù"),
        Entry(english: "person", hanzi: "人", pinyin: "rén"),
        Entry(english: "big", hanzi: "大", pinyin: "dà"),
        Entry(english: "small", hanzi: "小", pinyin: "xiǎo"),
        Entry(english: "many", hanzi: "多", pinyin: "duō"),
        Entry(english: "few", hanzi: "少", pinyin: "shǎo"),
        Entry(english: "hot", hanzi: "热", pinyin: "rè"),
        Entry(english: "cold", hanzi: "冷", pinyin: "lěng"),
        Entry(english: "book", hanzi: "书", pinyin: "shū"),
        Entry(english: "home", hanzi: "家", pinyin: "jiā")
    ]

    static let foodAndDrink: [Entry] = [
        Entry(english: "water", hanzi: "水", pinyin: "shuǐ"),
        Entry(english: "tea", hanzi: "茶", pinyin: "chá"),
        Entry(english: "rice, meal", hanzi: "饭", pinyin: "fàn"),
        Entry(english: "vegetable, dish", hanzi: "菜", pinyin: "cài"),
        Entry(english: "fruit", hanzi: "水果", pinyin: "shuǐguǒ"),
        Entry(english: "milk", hanzi: "牛奶", pinyin: "niúnǎi"),
        Entry(english: "to eat", hanzi: "吃", pinyin: "chī"),
        Entry(english: "to drink", hanzi: "喝", pinyin: "hē"),
        Entry(english: "delicious", hanzi: "好吃", pinyin: "hǎochī"),
        Entry(english: "restaurant", hanzi: "餐厅", pinyin: "cāntīng")
    ]

    static let timeAndDays: [Entry] = [
        Entry(english: "today", hanzi: "今天", pinyin: "jīntiān"),
        Entry(english: "tomorrow", hanzi: "明天", pinyin: "míngtiān"),
        Entry(english: "yesterday", hanzi: "昨天", pinyin: "zuótiān"),
        Entry(english: "now", hanzi: "现在", pinyin: "xiànzài"),
        Entry(english: "year", hanzi: "年", pinyin: "nián"),
        Entry(english: "month", hanzi: "月", pinyin: "yuè"),
        Entry(english: "week", hanzi: "星期", pinyin: "xīngqī"),
        Entry(english: "morning", hanzi: "早上", pinyin: "zǎoshang"),
        Entry(english: "evening", hanzi: "晚上", pinyin: "wǎnshang"),
        Entry(english: "minute", hanzi: "分钟", pinyin: "fēnzhōng")
    ]

    static let gettingAround: [Entry] = [
        Entry(english: "car", hanzi: "车", pinyin: "chē"),
        Entry(english: "train", hanzi: "火车", pinyin: "huǒchē"),
        Entry(english: "aeroplane", hanzi: "飞机", pinyin: "fēijī"),
        Entry(english: "school", hanzi: "学校", pinyin: "xuéxiào"),
        Entry(english: "shop", hanzi: "商店", pinyin: "shāngdiàn"),
        Entry(english: "money", hanzi: "钱", pinyin: "qián"),
        Entry(english: "to buy", hanzi: "买", pinyin: "mǎi"),
        Entry(english: "to go", hanzi: "去", pinyin: "qù"),
        Entry(english: "to sit", hanzi: "坐", pinyin: "zuò"),
        Entry(english: "mobile phone", hanzi: "手机", pinyin: "shǒujī")
    ]

    static let verbsAndSenses: [Entry] = [
        Entry(english: "to look", hanzi: "看", pinyin: "kàn"),
        Entry(english: "to listen", hanzi: "听", pinyin: "tīng"),
        Entry(english: "to speak", hanzi: "说", pinyin: "shuō"),
        Entry(english: "to read", hanzi: "读", pinyin: "dú"),
        Entry(english: "to write", hanzi: "写", pinyin: "xiě"),
        Entry(english: "to study", hanzi: "学习", pinyin: "xuéxí"),
        Entry(english: "to know", hanzi: "知道", pinyin: "zhīdào"),
        Entry(english: "to want", hanzi: "要", pinyin: "yào"),
        Entry(english: "to like", hanzi: "喜欢", pinyin: "xǐhuan"),
        Entry(english: "to work", hanzi: "工作", pinyin: "gōngzuò")
    ]

    static let deckPlan: [(name: String, entries: [Entry])] = [
        ("Greetings", greetings),
        ("Everyday Basics", basics),
        ("Food and Drink", foodAndDrink),
        ("Time and Days", timeAndDays),
        ("Getting Around", gettingAround),
        ("Verbs and Senses", verbsAndSenses)
    ]

    static var allEntries: [Entry] { deckPlan.flatMap(\.entries) }

    /// Only touches an empty store, so it never fights the user's own edits.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = try? context.fetchCount(FetchDescriptor<VocabWord>())
        guard (existing ?? 0) == 0 else { return }

        for plan in deckPlan {
            let words = plan.entries.map {
                VocabWord(english: $0.english, hanzi: $0.hanzi, pinyin: $0.pinyin)
            }
            words.forEach(context.insert)
            context.insert(Deck(name: plan.name, words: words))
        }

        try? context.save()
    }

    /// In-memory pairs for previews.
    static var previewPairs: [WordPair] {
        allEntries.map { WordPair(english: $0.english, hanzi: $0.hanzi, pinyin: $0.pinyin) }
    }
}
