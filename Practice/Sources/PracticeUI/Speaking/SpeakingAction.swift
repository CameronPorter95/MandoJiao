import Foundation

enum SpeakingAction: Equatable, Decodable {
    case appeared
    case disappeared
    case sceneLeftForeground
    case startListeningTapped
    case stopListeningTapped
    case typedAnswerSubmitted(answer: String)
    case typingToggled
    case continueTapped
    case practiseAgainTapped
    case closeTapped
    case quitConfirmed
    case quitCancelled
}
