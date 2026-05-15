// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MalayalamPanchangamCalendar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Malayalam Panchangam Calendar",
            targets: ["MalayalamPanchangamCalendar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MalayalamPanchangamCalendar",
            linkerSettings: [
                .linkedFramework("CoreLocation"),
                .linkedFramework("EventKit"),
                .linkedFramework("MapKit"),
                .linkedFramework("SwiftData"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .testTarget(
            name: "MalayalamPanchangamCalendarTests",
            dependencies: ["MalayalamPanchangamCalendar"]
        )
    ]
)
