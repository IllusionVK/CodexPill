import Testing

@testable import CodexPill

struct CodexAppServerClientTests {
    @Test
    func appServerFailurePrefersStderrOverTerminationCode() {
        let error = appServerFailure(
            stderr: "warning on stderr",
            terminationStatus: 128,
            timedOut: false
        )

        #expect(error == .server("warning on stderr"))
    }

    @Test
    func appServerFailureUsesTerminationCodeWhenNoStderrExists() {
        let error = appServerFailure(
            stderr: nil,
            terminationStatus: 128,
            timedOut: false
        )

        #expect(error == .terminated(128))
    }

    @Test
    func appServerFailureUsesStderrForTimeoutWhenPresent() {
        let error = appServerFailure(
            stderr: "network warning",
            terminationStatus: nil,
            timedOut: true
        )

        #expect(error == .server("network warning"))
    }

    @Test
    func appServerFailureFallsBackToTimeoutWithoutStderrOrExitCode() {
        let error = appServerFailure(
            stderr: nil,
            terminationStatus: nil,
            timedOut: true
        )

        #expect(error == .timeout)
    }
}
