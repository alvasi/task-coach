// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TaskCoach",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TaskCoach",
            path: "Sources/TaskCoach"
        )
    ]
)
