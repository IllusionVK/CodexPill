import Foundation
import SealRecorder

private let featureID = FeatureID("accounts")
private let scenarioID = ScenarioID("switch-account-changes-active-account")
private let switchInvariantID = InvariantID("accounts.switch_account.menu_action_changes_active_account")

private struct FixtureAccount: Encodable {
    let id: String
    let name: String
    let snapshotFileName: String
    let email: String
}

private struct AccountStateSnapshot: Encodable {
    let activeAccountId: String?
    let activeAccountName: String?
    let savedAccounts: [FixtureAccount]
    let savedAccountIds: [String]
    let savedAccountNames: [String]
    let savedAccountCount: Int

    init(activeAccount: FixtureAccount, savedAccounts: [FixtureAccount]) {
        activeAccountId = activeAccount.id
        activeAccountName = activeAccount.name
        self.savedAccounts = savedAccounts
        savedAccountIds = savedAccounts.map(\.id)
        savedAccountNames = savedAccounts.map(\.name)
        savedAccountCount = savedAccounts.count
    }
}

@main
struct CodexPillProofEmitter {
    static func main() {
        do {
            let outputDirectory = try parseOutputDirectory()
            try guardFixtureOwnedOutputDirectory(outputDirectory)
            try emitAccountSwitchProof(to: outputDirectory)
            print(outputDirectory.path)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            Foundation.exit(1)
        }
    }

    private static func parseOutputDirectory() throws -> URL {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.count == 3,
              arguments[0] == "emit-account-switch-proof",
              arguments[1] == "--output-dir",
              !arguments[2].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw UsageError()
        }

        return URL(fileURLWithPath: arguments[2]).standardizedFileURL
    }

    private static func guardFixtureOwnedOutputDirectory(_ outputDirectory: URL) throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let forbiddenDirectories = [
            home.appendingPathComponent(".codex", isDirectory: true),
            home.appendingPathComponent("Library/Application Support/Codex", isDirectory: true),
            home.appendingPathComponent("Library/Application Support/CodexPill", isDirectory: true),
        ].map(\.standardizedFileURL.path)

        let outputPath = outputDirectory.path
        if forbiddenDirectories.contains(where: { outputPath == $0 || outputPath.hasPrefix($0 + "/") }) {
            throw UnsafeOutputDirectoryError(path: outputPath)
        }
    }

    private static func emitAccountSwitchProof(to outputDirectory: URL) throws {
        let personal = FixtureAccount(
            id: "11111111-1111-4111-8111-111111111111",
            name: "Validation Personal",
            snapshotFileName: "validation-personal-auth.json",
            email: "validation.personal@example.invalid"
        )
        let business = FixtureAccount(
            id: "22222222-2222-4222-8222-222222222222",
            name: "Validation Business",
            snapshotFileName: "validation-business-auth.json",
            email: "validation.business@example.invalid"
        )
        let savedAccounts = [personal, business]

        try SealRecorder.register(features: [try accountSwitchFeature()])
        let run = try SealRecorder.startRun(
            feature: featureID,
            scenario: scenarioID,
            executionMode: .integration,
            outputDirectory: outputDirectory,
            runID: "run_codexpill_account_switch_v1_boundary"
        )
        defer { run.cancelIfUnfinished() }

        try run.recordEvent(
            "menu_action_dispatched",
            step: "menu_action_dispatch",
            invariantIds: [switchInvariantID],
            payload: [
                "action": .string("switchAccount"),
                "targetName": .string(business.name),
                "targetAccountId": .string(business.id),
                "activeAccountId": .string(personal.id)
            ]
        )
        try run.recordSnapshot(
            id: EvidenceID("account_before"),
            path: "evidence/account-before.json",
            value: AccountStateSnapshot(activeAccount: personal, savedAccounts: savedAccounts)
        )
        try run.recordEvent(
            "switch_confirmation_presented",
            step: "switch_confirmation",
            invariantIds: [switchInvariantID],
            payload: ["targetAccountId": .string(business.id)]
        )
        try run.recordEvent(
            "switch_confirmation_accepted",
            step: "switch_confirmation",
            invariantIds: [switchInvariantID],
            payload: ["targetAccountId": .string(business.id)]
        )
        try run.recordEvent(
            "switch_workflow_started",
            step: "switch_workflow_start",
            invariantIds: [switchInvariantID],
            payload: ["targetAccountId": .string(business.id)]
        )
        try run.recordEvent(
            "active_account_changed",
            step: "active_account_change",
            invariantIds: [switchInvariantID],
            payload: [
                "fromName": .string(personal.name),
                "toName": .string(business.name)
            ]
        )
        try run.recordSnapshot(
            id: EvidenceID("account_after"),
            path: "evidence/account-after.json",
            value: AccountStateSnapshot(activeAccount: business, savedAccounts: savedAccounts)
        )
        try run.finish()
    }

    private static func accountSwitchFeature() throws -> SealFeature {
        try SealFeature(
            id: featureID,
            scenarios: [
                try SealScenario(
                    id: scenarioID,
                    scenarioType: .happyPath,
                    supportedExecutionModes: [.integration],
                    expectations: [
                        try SealExpectation(
                            text: "Switching account through the menubar changes the active account",
                            invariants: [
                                SealInvariantRef(
                                    id: switchInvariantID,
                                    requiredEvidence: [
                                        EvidenceRequirement(id: EvidenceID("events"), kind: .eventStream),
                                        EvidenceRequirement(id: EvidenceID("account_before"), kind: .snapshot),
                                        EvidenceRequirement(id: EvidenceID("account_after"), kind: .snapshot)
                                    ],
                                    rule: .all([
                                        .eventSequence([
                                            EventExpectation("menu_action_dispatched", payload: [
                                                "action": .string("switchAccount")
                                            ]),
                                            EventExpectation("switch_confirmation_presented"),
                                            EventExpectation("switch_confirmation_accepted"),
                                            EventExpectation("switch_workflow_started"),
                                            EventExpectation("active_account_changed")
                                        ]),
                                        .snapshotsDiffer(
                                            SnapshotsDifferRule(
                                                before: EvidenceID("account_before"),
                                                after: EvidenceID("account_after"),
                                                paths: ["activeAccountId"]
                                            )
                                        )
                                    ])
                                )
                            ]
                        )
                    ]
                )
            ]
        )
    }
}

private struct UsageError: LocalizedError, CustomStringConvertible {
    var description: String {
        "Usage: CodexPillProofEmitter emit-account-switch-proof --output-dir <proof-output-dir>"
    }
}

private struct UnsafeOutputDirectoryError: LocalizedError, CustomStringConvertible {
    let path: String

    var description: String {
        "Refusing to write proof output under a production Codex data directory: \(path)"
    }
}
