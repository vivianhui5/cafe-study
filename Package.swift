// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "CozyCafeCore", products: [.library(name: "CozyCafeCore", targets: ["CozyCafeCore"])], targets: [.target(name: "CozyCafeCore"), .testTarget(name: "CozyCafeCoreTests", dependencies: ["CozyCafeCore"])])
