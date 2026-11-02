// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "onetrace_flutter",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "onetrace-flutter", targets: ["onetrace_flutter"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // The native OneTrace SDK for iOS.
        .package(url: "https://github.com/OneTracePro/onetrace-ios.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "onetrace_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "OneTrace", package: "onetrace-ios"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
