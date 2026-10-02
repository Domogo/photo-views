// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PhotoViews",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PhotoViews", targets: ["PhotoViewsApp"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "PhotoViewsCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "PhotoViewsApp", dependencies: ["PhotoViewsCore"]),
        .executableTarget(name: "IndexChecks", dependencies: ["PhotoViewsCore"], path: "Tests/IndexingChecks"),
        .executableTarget(name: "CatalogChecks", dependencies: ["PhotoViewsCore"], path: "Tests/PhotoViewsCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
