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
        // The native OneTrace SDK for iOS. Until it is released, the commit of its `stage-105` branch (see the README);
        // after the release: `from: "1.3.0"`, or a local path `.package(path: "../../../onetrace-ios")`. Only the core:
        // an app with geofences links the `OneTraceLocation` product itself (README), an app without them needs no
        // location purpose strings.
        .package(url: "https://github.com/OneTracePro/onetrace-ios.git", revision: "b975ee14f0823f078d26817ee56673908beee3d8"),
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
