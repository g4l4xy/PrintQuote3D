// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PrintQuote3D", platforms: [.macOS(.v14)], products: [.executable(name: "PrintQuote3D", targets: ["PrintQuoteApp"])], targets: [
    .target(name: "QuoteDomain"),
    .target(name: "QuoteData", dependencies: ["QuoteDomain"], resources: [.process("SeedData")]),
    .executableTarget(name: "PrintQuoteApp", dependencies: ["QuoteDomain", "QuoteData"]),
    .testTarget(name: "QuoteTests", dependencies: ["QuoteDomain", "QuoteData"], resources: [.copy("Fixtures")])
])
