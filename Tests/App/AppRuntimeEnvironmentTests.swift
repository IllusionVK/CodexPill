import Foundation
import Testing

@testable import CodexPill

struct AppRuntimeEnvironmentTests {
    @Test
    func validationAutoRefreshIntervalSecondsParsesPositiveValues() {
        let environment = [
            AppRuntimeEnvironment.validationAutoRefreshIntervalSecondsEnvironmentKey: "2.5"
        ]

        #expect(AppRuntimeEnvironment.validationAutoRefreshIntervalSeconds(environment: environment) == 2.5)
    }

    @Test
    func validationAutoRefreshIntervalSecondsRejectsInvalidValues() {
        #expect(AppRuntimeEnvironment.validationAutoRefreshIntervalSeconds(environment: [:]) == nil)
        #expect(
            AppRuntimeEnvironment.validationAutoRefreshIntervalSeconds(
                environment: [AppRuntimeEnvironment.validationAutoRefreshIntervalSecondsEnvironmentKey: "0"]
            ) == nil
        )
        #expect(
            AppRuntimeEnvironment.validationAutoRefreshIntervalSeconds(
                environment: [AppRuntimeEnvironment.validationAutoRefreshIntervalSecondsEnvironmentKey: "abc"]
            ) == nil
        )
    }
}
