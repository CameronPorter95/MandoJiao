import Foundation

enum SpeakingAction: Equatable {
    case appeared
    case disappeared
    case sceneLeftForeground
    case startListeningTapped
    case stopListeningTapped
    case typedAnswerSubmitted(String)
    case typingToggled
    case continueTapped
    case practiseAgainTapped
    case closeTapped
    case quitConfirmed
    case quitCancelled
}
