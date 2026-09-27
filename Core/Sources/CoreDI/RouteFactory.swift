import SwiftUI

// A factory is named for what it takes beyond `Dependencies`, in the order the signature
// takes it. Factories are stateless enums: everything a screen needs arrives as an argument.

/// For a screen with no way out but being closed, and nothing to be told.
@MainActor
public protocol RouteFactory {
    associatedtype Content: View
    static func makeRoute(dependencies: Dependencies) -> Content
}

@MainActor
public protocol NavigationRouteFactory {
    associatedtype Content: View
    associatedtype Navigation
    static func makeRoute(
        dependencies: Dependencies,
        navigation: Navigation
    ) -> Content
}

/// For a screen whose only way out is being closed, which is the presenter's job (N5).
@MainActor
public protocol InputRouteFactory {
    associatedtype Content: View
    associatedtype Input
    static func makeRoute(
        dependencies: Dependencies,
        input: Input
    ) -> Content
}

@MainActor
public protocol NavigationInputRouteFactory {
    associatedtype Content: View
    associatedtype Navigation
    associatedtype Input
    static func makeRoute(
        dependencies: Dependencies,
        navigation: Navigation,
        input: Input
    ) -> Content
}
