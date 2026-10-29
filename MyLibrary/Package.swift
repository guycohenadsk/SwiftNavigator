// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyLibrary",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "NavigationCore", targets: ["NavigationCore"]),
        .library(name: "NavigatorDependency", targets: ["NavigatorDependency"]),
        .library(name: "RefPicker", targets: ["RefPicker"]),
        .library(name: "IssuesDomain", targets: ["IssuesDomain"]),
        .library(name: "ScreenBFeature", targets: ["ScreenBFeature"]),
        .library(name: "ScreenCKit", targets: ["ScreenCKit"]),
        .library(name: "ScreenDKit", targets: ["ScreenDKit"]),
        .library(name: "IssuesNavigationContract", targets: ["IssuesNavigationContract"]),
        .library(name: "ScreenBNavigationContract", targets: ["ScreenBNavigationContract"]),
        .library(name: "ScreenCNavigationContract", targets: ["ScreenCNavigationContract"]),
        .library(name: "ScreenDNavigationContract", targets: ["ScreenDNavigationContract"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.25.3"),
        .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.7.0"),
    ],
    targets: [
        // Shared navigation vocabulary. The only module features share — no feature imports another.
        .target(name: "NavigationCore"),

        .target(
            name: "NavigatorDependency",
            dependencies: [
                "NavigationCore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

        // Shared UI component: a list of references with "Add Reference". Knows only NavigationCore.
        .target(
            name: "RefPicker",
            dependencies: [
                "NavigationCore",
                "NavigatorDependency",
                "IssuesNavigationContract",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

        // Each feature's routes and the values it sends back. Imported by that feature, and by
        // callers that read those values — never a feature's implementation.
        .target(name: "IssuesNavigationContract", dependencies: ["NavigationCore"]),
        .target(name: "ScreenBNavigationContract", dependencies: ["NavigationCore"]),
        .target(name: "ScreenCNavigationContract", dependencies: ["NavigationCore"]),
        .target(name: "ScreenDNavigationContract", dependencies: ["NavigationCore"]),

        .target(
            name: "IssuesDomain",
            dependencies: [
                "NavigationCore",
                "NavigatorDependency",
                "IssuesNavigationContract",
                "ScreenBNavigationContract",
                "ScreenCNavigationContract",
                "ScreenDNavigationContract",
                "RefPicker",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "UIKitNavigation", package: "swift-navigation"),
            ]
        ),
        .target(
            name: "ScreenBFeature",
            dependencies: [
                "NavigationCore",
                "NavigatorDependency",
                "IssuesNavigationContract",
                "ScreenBNavigationContract",
                "ScreenCNavigationContract",
                "ScreenDNavigationContract",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "UIKitNavigation", package: "swift-navigation"),
            ]
        ),
        .target(name: "ScreenCKit", dependencies: [
            "NavigationCore", "IssuesNavigationContract", "ScreenBNavigationContract", "ScreenCNavigationContract",
        ]),
        .target(name: "ScreenDKit", dependencies: [
            "NavigationCore", "IssuesNavigationContract", "ScreenBNavigationContract", "ScreenDNavigationContract",
        ]),

        .testTarget(name: "NavigationCoreTests", dependencies: ["NavigationCore"]),
        .testTarget(
            name: "RefPickerTests",
            dependencies: [
                "RefPicker",
                "NavigationCore",
                "NavigatorDependency",
                "IssuesNavigationContract",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "FeatureNavigationTests",
            dependencies: [
                "NavigationCore",
                "IssuesNavigationContract",
                "IssuesDomain",
                "NavigatorDependency",
                "ScreenBFeature",
                "ScreenBNavigationContract",
                "ScreenCNavigationContract",
                "ScreenDNavigationContract",
                "ScreenCKit",
                "ScreenDKit",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "IssuesDomainTests",
            dependencies: [
                "IssuesDomain",
                "NavigationCore",
                "IssuesNavigationContract",
                "ScreenBNavigationContract",
                "ScreenCNavigationContract",
                "ScreenDNavigationContract",
                "NavigatorDependency",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ]
)
