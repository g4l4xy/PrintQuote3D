// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PrintQuote3D", platforms: [.macOS(.v14), .iOS(.v17)], products: [.library(name: "QuoteDomain", targets: ["QuoteDomain"]), .library(name: "QuoteData", targets: ["QuoteData"]), .library(name: "OrcaProfiles", targets: ["OrcaProfiles"]), .executable(name: "PrintQuote3D", targets: ["PrintQuoteApp"]), .executable(name: "OrcaProfileImporter", targets: ["OrcaProfileImporter"]), .executable(name: "ThreeMFProbe", targets: ["ThreeMFProbe"])], dependencies: [.package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")], targets: [
    .target(name: "QuoteDomain"),
    .executableTarget(name: "ThreeMFProbe", dependencies: ["QuoteData", "QuoteDomain"], path: "tools/ThreeMFProbe"),
    .target(name: "OrcaProfiles", dependencies: ["QuoteDomain"]),
    .executableTarget(name: "OrcaProfileImporter", dependencies: ["OrcaProfiles"], path: "tools/OrcaProfileImporter"),
    .target(name: "QuoteData", dependencies: ["QuoteDomain", .product(name: "ZIPFoundation", package: "ZIPFoundation")], resources: [.process("SeedData")]),
    .executableTarget(name: "PrintQuoteApp", dependencies: ["QuoteDomain", "QuoteData"], exclude: ["BrandAssets.xcassets"], resources: [.process("Resources")]),
    .testTarget(name: "QuoteTests", dependencies: ["QuoteDomain", "QuoteData", "OrcaProfiles"], resources: [.copy("Fixtures")])
])
