import ProjectDescription

let project = Project(
    name: "CodexPill",
    organizationName: "raphaelgrau",
    targets: [
        .target(
            name: "CodexPill",
            destinations: .macOS,
            product: .app,
            bundleId: "com.raphhgg.codex-switchboard",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(
                with: [
                    "LSUIElement": true,
                    "CFBundleDisplayName": "CodexPill",
                ]
            ),
            sources: ["Sources/**"],
            resources: ["Resources/**"]
        )
    ]
)
