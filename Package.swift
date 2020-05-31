// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "gsoc-swift-tracing",
    products: [
        .library(
            name: "ContextPropagation",
            targets: [
                "ContextPropagation"
            ]
        ),
        .library(
            name: "ContextPropagationDreamland",
            targets: [
                "ContextPropagationDreamland"
            ]
        ),
    ],

    dependencies: [
        // ~~~ ONLY FOR DREAMLAND ~~~
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.12.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],

    targets: [
        // ==== Targets ------------------------------------------------------------------------------------------------
        .target(
            name: "ContextPropagation"
        ),
        .target(
            name: "ContextPropagationDreamland",
            dependencies: [
                "ContextPropagation",
                // .product(name: "NIO", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .target(
            name: "ContextPropagationDreamlandExamples",
            dependencies: [
                "ContextPropagationDreamland",
            ]
        ),
        // ==== Test targets -------------------------------------------------------------------------------------------
        .testTarget(
            name: "ContextPropagationTests",
            dependencies: [
                "ContextPropagation"
            ]
        ),
        .testTarget(
            name: "ContextPropagationDreamlandTests",
            dependencies: [
                "ContextPropagationDreamland",
            ]
        )
    ]
)
