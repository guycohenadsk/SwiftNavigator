// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyLibrary",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "AppRoutes", targets: ["AppRoutes"]),
        .library(name: "NavigatorDependency", targets: ["NavigatorDependency"]),
        .library(name: "ScreenAFeature", targets: ["ScreenAFeature"]),
        .library(name: "ScreenBFeature", targets: ["ScreenBFeature"]),
        .library(name: "ScreenCKit", targets: ["ScreenCKit"]),
        .library(name: "ScreenDKit", targets: ["ScreenDKit"]),
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
    ]
)
