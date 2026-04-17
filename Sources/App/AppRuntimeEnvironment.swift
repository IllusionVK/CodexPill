import Foundation

enum AppRuntimeEnvironment {
    static let suppressEmptyStatePromptEnvironmentKey = "CODEXPILL_SUPPRESS_EMPTY_STATE_PROMPT"
    static let validationAutoRefreshIntervalSecondsEnvironmentKey = "CODEXPILL_VALIDATION_AUTO_REFRESH_INTERVAL_SECONDS"

    static func shouldSuppressEmptyStatePrompt(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if let rawValue = environment[suppressEmptyStatePromptEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           ["1", "true", "yes"].contains(rawValue) {
            return true
        }

        return MenuBarValidationConfiguration.makeSink(environment: environment) != nil
    }

    static func validationAutoRefreshIntervalSeconds(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> TimeInterval? {
        guard let rawValue = environment[validationAutoRefreshIntervalSecondsEnvironmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let seconds = TimeInterval(rawValue),
              seconds > 0 else {
            return nil
        }

        return seconds
    }
}
