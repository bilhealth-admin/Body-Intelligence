// swift-tools-version: 5.9
import PackageDescription

// CI copies the two exact checked-out production source files into Sources.
// This target tests the real Foundation/SwiftUI renderer without a cloud app,
// Flutter engine, signing credential or network dependency.
let package = Package(
  name: "BILCoachPresentation",
  platforms: [.iOS(.v15), .macOS(.v12)],
  products: [.library(name: "BILCoachPresentation", targets: ["BILCoachPresentation"])],
  targets: [
    .target(name: "BILCoachPresentation"),
    .testTarget(name: "BILCoachPresentationTests", dependencies: ["BILCoachPresentation"]),
  ]
)
