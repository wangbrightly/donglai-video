// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Donglai", platforms: [.macOS(.v13)], targets: [.executableTarget(name: "Donglai", exclude: ["Resources"])])
