// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NavigationKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AppComposition", targets: ["AppComposition"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.25.3"),
        .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.7.0"),
    ],
    targets: [
        // Leaf module: the only thing every feature depends on. No feature imports another feature.
        .target(name: "AppRoutes"),

        .target(
            name: "NavigatorDependency",
            dependencies: [
                "AppRoutes",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

        .target(
            name: "ScreenAFeature",
            dependencies: [
                "AppRoutes",
                "NavigatorDependency",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "UIKitNavigation", package: "swift-navigation"),
            ]
        ),
        .target(
            name: "ScreenBFeature",
            dependencies: [
                "AppRoutes",
                "NavigatorDependency",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "UIKitNavigation", package: "swift-navigation"),
            ]
        ),

        .target(name: "ScreenCKit", dependencies: ["AppRoutes"]),
        .target(name: "ScreenDKit", dependencies: ["AppRoutes"]),

        // Composition root: the only target allowed to import every feature. Wires the
        // Navigator, resolves routes to screens, and builds the tab bar.
        .target(
            name: "AppComposition",
            dependencies: [
                "AppRoutes",
                "NavigatorDependency",
                "ScreenAFeature",
                "ScreenBFeature",
                "ScreenCKit",
                "ScreenDKit",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "UIKitNavigation", package: "swift-navigation"),
            ]
        ),
    ]
)
