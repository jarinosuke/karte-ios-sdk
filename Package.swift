// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Karte",
    platforms: [
        .iOS(.v9)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "KarteCore",
            targets: ["KarteCore", "KarteUtilities"]
        ),
        .library(
            name: "KarteInAppMessaging",
            targets: ["KarteInAppMessaging", "KarteCore", "KarteUtilities"]
        ),
        .library(
            name: "KarteVariables",
            targets: ["KarteVariables", "KarteCore", "KarteUtilities"]
        ),
        .library(
            name: "KarteVisualTracking",
            targets: ["KarteVisualTracking", "KarteCore", "KarteUtilities"]
        ),
        .library(
            name: "KarteRemoteNotification",
            targets: ["KarteRemoteNotification", "KarteCore", "KarteUtilities"]
        ),
        .library(
            name: "KarteCrashReporting",
            type: .static,
            targets: ["KarteCrashReportingTarget", "KarteCore", "KarteUtilities"]
        ),
        .library(
            name: "KarteNotificationServiceExtension",
            targets: ["KarteNotificationServiceExtension"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "PLCrashReporter", url: "https://github.com/plaidev/PLCrashReporter.git", from: "1.8.2-spm")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .binaryTarget(
            name: "KarteUtilities", url: "https://sdk.karte.io/ios/swiftpm/Utilities-3.6.0/KarteUtilities.xcframework.zip", checksum: "1039895376cb2674fd228e147a1f0fe3ee215dee324ff037cde1d508fa01dfb3"
        ),
        .binaryTarget(
            name: "KarteCore", url: "https://sdk.karte.io/ios/swiftpm/Core-2.21.0/KarteCore.xcframework.zip", checksum: "f0ce6c549397c8ee900f66db7e28457ba32ef087ee216c4fc6e5b8581297f380"
        ),
        .binaryTarget(
            name: "KarteInAppMessaging", url: "https://sdk.karte.io/ios/swiftpm/InAppMessaging-2.12.0/KarteInAppMessaging.xcframework.zip", checksum: "d6ee2ca60687508d5db26cd618bbf43b3a1c870d6858b8017dfc87a1bc0d25a7"
        ),
        .binaryTarget(
            name: "KarteVariables", url: "https://sdk.karte.io/ios/swiftpm/Variables-2.4.1/KarteVariables.xcframework.zip", checksum: "eef7f37b7b20aa79217d9001d6c7c568fc38a71562730e645a108e560dfb87b9"
        ),
        .binaryTarget(
            name: "KarteVisualTracking", url: "https://sdk.karte.io/ios/swiftpm/VisualTracking-2.8.0/KarteVisualTracking.xcframework.zip", checksum: "421785f3b28f44c747815a21cf4c758d64a3279ca8a3f5381c6e73b902f0f79d"
        ),
        .binaryTarget(
            name: "KarteRemoteNotification", url: "https://sdk.karte.io/ios/swiftpm/RemoteNotification-2.8.0/KarteRemoteNotification.xcframework.zip", checksum: "63485389ac28e0e4d17fdd9f10291b631c8b2c5fab9e74b827a5e9fd571afde1"
        ),
        .binaryTarget(
            name: "KarteCrashReporting", url: "https://sdk.karte.io/ios/swiftpm/CrashReporting-2.4.0/KarteCrashReporting.xcframework.zip", checksum: "ab53a6706a67f231be8ceca19859170858f721d3f9cf8bab8b99f2ace6852e76"
        ),
        .target(
            name: "KarteCrashReportingTarget", 
            dependencies: ["PLCrashReporter", "KarteCrashReporting"],
            path: "KarteCrashReporting/SwiftPM"
        ),
        .binaryTarget(
            name: "KarteNotificationServiceExtension", url: "https://sdk.karte.io/ios/swiftpm/NotificationServiceExtension-1.0.0/KarteNotificationServiceExtension.xcframework.zip", checksum: "91310af814444d2a70f5cb390d64f8f73fe1b7e943e759326cd58a8152b988c9"
        ),
    ]
)
