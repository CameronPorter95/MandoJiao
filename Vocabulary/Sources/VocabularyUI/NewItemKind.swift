import Foundation

/// What a naming alert is about to create.
enum NewItemKind: Equatable {
    case deck
    case folder

    var title: String {
        switch self {
        case .deck: "New deck"
        case .folder: "New folder"
        }
    }

    var message: String {
        switch self {
        case .deck: "Give the deck a name, then pick its words."
        case .folder: "Give the folder a name, then add decks or folders to it."
        }
    }
}
