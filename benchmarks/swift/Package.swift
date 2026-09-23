// swift-tools-version:5.10
// Core ML latency harness shared by the macOS CLI (`coreml-bench`) and the iOS app
// (CoreMLBench.xcodeproj). See benchmarks/README.md, experiment 002.
import PackageDescription

let package = Package(
    name: "CoreMLBench",
    platforms: [.macOS("14.4"), .iOS("17.4")],
    products: [
        .library(name: "BenchCore", targets: ["BenchCore"]),
        .executable(name: "coreml-bench", targets: ["coreml-bench"]),
    ],
    targets: [
        .target(name: "BenchCore", path: "Sources/BenchCore"),
        .executableTarget(name: "coreml-bench", dependencies: ["BenchCore"], path: "Sources/coreml-bench"),
    ]
)
