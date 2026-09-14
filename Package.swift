// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PrintQuote3D", platforms: [.macOS(.v14), .iOS(.v17)], products: [.library(name: "QuoteDomain", targets: ["QuoteDomain"]), .library(name: "QuoteData", targets: ["QuoteData"]), .library(name: "OrcaProfiles", targets: ["OrcaProfiles"]), .executable(name: "PrintQuote3D", targets: ["PrintQuoteApp"]), .executable(name: "OrcaProfileImporter", targets: ["OrcaProfileImporter"])], targets: [
    .target(name: "QuoteDomain"),
    .target(name: "OrcaProfiles", dependencies: ["QuoteDomain"]),
    .executableTarget(name: "OrcaProfileImporter", dependencies: ["OrcaProfiles"], path: "tools/OrcaProfileImporter"),
    .target(name: "QuoteData", dependencies: ["QuoteDomain"], resources: [.process("SeedData")]),
    .executableTarget(name: "PrintQuoteApp", dependencies: ["QuoteDomain", "QuoteData"], exclude: ["BrandAssets.xcassets"], resources: [.process("Resources")]),
    .testTarget(name: "QuoteTests", dependencies: ["QuoteDomain", "QuoteData", "OrcaProfiles"], resources: [.copy("Fixtures")])
])
