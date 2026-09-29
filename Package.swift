// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "swift-test-benchmark",
    platforms: [.macOS(.v27), .iOS(.v27), .tvOS(.v27), .watchOS(.v27), .visionOS(.v27)],
    products: [.library(name: "Test Benchmark", targets: ["Test Benchmark"])],
    dependencies: [
        .package(
            url: "https://github.com/swift-molecules/swift-test.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-benchmark.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-source.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-cardinal.git",
            branch: "main"
        ),
    ],
    targets: [
        .target(name: "Test Benchmark", dependencies: [
            .product(name: "Test", package: "swift-test"),
            .product(name: "Benchmark", package: "swift-benchmark"),
            .product(name: "Source", package: "swift-source"),
            .product(name: "Cardinal", package: "swift-cardinal"),
        ]),
        .testTarget(name: "Test Benchmark Tests", dependencies: [
            .target(name: "Test Benchmark"),
            .product(name: "Test", package: "swift-test"),
            .product(name: "Benchmark", package: "swift-benchmark"),
            .product(name: "Source", package: "swift-source"),
            .product(name: "Cardinal", package: "swift-cardinal"),
        ]),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .strictMemorySafety(), .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"), .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"), .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"), .enableUpcomingFeature("LifetimeDependence"),
    ]
}
