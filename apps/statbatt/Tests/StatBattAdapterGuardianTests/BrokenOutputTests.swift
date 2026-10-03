import Testing
import CAdapterTestSupport

@Test func closedOutputPipeCannotTerminateRecoveryProcess() {
    #expect(sb_test_broken_pipe() == 0)
}
