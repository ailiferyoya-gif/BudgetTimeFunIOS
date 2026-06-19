// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BudgetTimeFun",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(name: "BudgetTimeFun", targets: ["BudgetTimeFun"])
    ],
    targets: [
        .executableTarget(
            name: "BudgetTimeFun",
            path: "Sources/BudgetTimeFun"
        )
    ]
)
