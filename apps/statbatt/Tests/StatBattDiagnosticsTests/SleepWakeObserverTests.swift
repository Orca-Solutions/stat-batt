import Testing
@testable import StatBattDiagnostics

@Test func sleepNotificationsAcknowledgeBeforeEvidenceWithoutLeakingToken() {
    let observation = PowerObservation()
    var tokens: [Int] = []
    observation.acknowledge = { _, token in
        #expect(observation.pending.count == tokens.count)
        tokens.append(token)
        return 0
    }
    observation.receive(0xe0000270, argument: .init(bitPattern: 123))
    observation.receive(0xe0000280, argument: .init(bitPattern: 456))
    #expect(tokens == [123, 456])
    #expect(observation.pending.allSatisfy { $0["token"] == nil && $0["acknowledgmentRequired"] as? Bool == true })
}

@Test func wakingNeverAcknowledgesAndUnknownMessagesAreIgnored() {
    let observation = PowerObservation()
    observation.acknowledge = { _, _ in Issue.record("Unexpected acknowledgment"); return 0 }
    observation.receive(0xe0000320, argument: nil)
    #expect(!observation.woke)
    observation.receive(0xe0000300, argument: nil)
    #expect(observation.woke)
    observation.receive(0xe0000290, argument: nil)
    observation.receive(0, argument: nil)
    #expect(observation.events == 3)
}

@Test func fullEventBufferStillAcknowledgesSleep() {
    let observation = PowerObservation()
    var acknowledgments = 0
    observation.acknowledge = { _, _ in acknowledgments += 1; return 0 }
    for _ in 0..<65 { observation.receive(0xe0000280, argument: nil) }
    #expect(acknowledgments == 65)
    #expect(observation.pending.count == 64)
    #expect(observation.droppedEvents == 1)
}
