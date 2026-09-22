import SwiftUI

enum Theme {
    static let accent = Color(red: 0.98, green: 0.52, blue: 0.13)
    static let success = Color(red: 0.34, green: 0.78, blue: 0.33)
    static let miss = Color(red: 0.91, green: 0.33, blue: 0.33)

    static let tileCorner: CGFloat = 16
    static let tileMinHeight: CGFloat = 68
}

/// Sideways wobble for a wrong guess. Driven by a progress value animating
/// 0 to 1 rather than by a repeating animation, so it always settles.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 7
    var wobbles: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = travel * sin(animatableData * .pi * wobbles)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}
