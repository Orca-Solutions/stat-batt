import Foundation
import Testing
import StatBattDomain
@testable import StatBattControlProtocol

private func credentials(uid: UInt32 = 501, id: UUID = UUID(), audit: UInt32 = 7) -> ConnectionCredentials {
    ConnectionCredentials(connectionID: id, effectiveUID: uid, auditSessionID: audit)
}
private func policyCommand(_ context: CommandContext, upper: Double = 80) -> OwnerCommand {
    .setPolicy(SetPolicyRequest(context: context, policy: RangePolicy(holdAtPercent: upper)))
}

@Test func replayPrecedesCASAndChangedPayloadConflicts() async throws {
    let version = StateVersion()
    let peer = credentials()
    let ledger = CommandAdmissionLedger(version: version, ownerUID: 501)
    let session = try await ledger.openOwnerSession(for: peer)
    let context = CommandContext(expected: version, controlSessionID: session)
    let first = try await ledger.admit(policyCommand(context), credentials: peer, nowUTC: Date())
    #expect(first.receipt.version.revision == 1)
    let replay = try await ledger.admit(policyCommand(context), credentials: peer, nowUTC: Date())
    #expect(replay.isReplay)
    #expect(replay.receipt == first.receipt)
    do {
        _ = try await ledger.admit(policyCommand(context, upper: 90), credentials: peer, nowUTC: Date())
        Issue.record("Changed intent accepted")
    } catch { #expect(error as? WireFailure == WireFailure(.idempotencyConflict)) }
    let changedExpected = CommandContext(commandID: context.commandID, expected: first.receipt.version, controlSessionID: session)
    do {
        _ = try await ledger.admit(policyCommand(changedExpected), credentials: peer, nowUTC: Date())
        Issue.record("Replay expectation changed")
    } catch { #expect(error as? WireFailure == WireFailure(.idempotencyConflict)) }
    let changed = CommandContext(expected: version, controlSessionID: session)
    do {
        _ = try await ledger.admit(policyCommand(changed), credentials: peer, nowUTC: Date())
        Issue.record("Stale CAS accepted")
    } catch { #expect(error as? WireFailure == WireFailure(.revisionConflict)) }
    #expect(await ledger.checkpoint().version.revision == 1)
}

@Test func reconnectNewSessionReplaysSameIntentAndRejectsChangedIntent() async throws {
    let version = StateVersion()
    let ledger = CommandAdmissionLedger(version: version, ownerUID: 501)
    let firstPeer = credentials()
    let firstSession = try await ledger.openOwnerSession(for: firstPeer)
    let commandID = UUID()
    let firstContext = CommandContext(commandID: commandID, expected: version, controlSessionID: firstSession)
    let first = try await ledger.admit(policyCommand(firstContext), credentials: firstPeer, nowUTC: Date())
    let completed = try await ledger.recordOutcome(operationID: first.receipt.operationID, outcome: .noChange)
    await ledger.disconnect(firstPeer.connectionID)
    let reconnectedPeer = credentials(audit: 9)
    let newSession = try await ledger.openOwnerSession(for: reconnectedPeer)
    #expect(newSession != firstSession)
    let replayContext = CommandContext(commandID: commandID, expected: version, controlSessionID: newSession)
    let replay = try await ledger.admit(policyCommand(replayContext), credentials: reconnectedPeer, nowUTC: Date())
    #expect(replay.isReplay)
    #expect(replay.receipt == completed)
    #expect(await ledger.checkpoint().version.revision == 1)
    do {
        _ = try await ledger.admit(policyCommand(replayContext, upper: 90), credentials: reconnectedPeer, nowUTC: Date())
        Issue.record("Changed intent after reconnect accepted")
    } catch { #expect(error as? WireFailure == WireFailure(.idempotencyConflict)) }
    do {
        _ = try await ledger.admit(policyCommand(firstContext), credentials: reconnectedPeer, nowUTC: Date())
        Issue.record("Expired session replay accepted")
    } catch { #expect(error as? WireFailure == WireFailure(.controlSessionExpired)) }
}

@Test func authenticatedOwnerStopAllowsStaleRevisionButOtherUserCannotStop() async throws {
    let version = StateVersion(revision: 9)
    let ledger = CommandAdmissionLedger(version: version, ownerUID: 501)
    let peer = credentials()
    let session = try await ledger.openOwnerSession(for: peer)
    let context = CommandContext(expected: StateVersion(), controlSessionID: session)
    let stop = OwnerCommand.stopAndRestore(context: context, reason: .userRequested)
    let result = try await ledger.admit(stop, credentials: peer, nowUTC: Date())
    #expect(result.receipt.version.revision == 10)
    do {
        _ = try await ledger.admit(stop, credentials: credentials(uid: 502), nowUTC: Date())
        Issue.record("Other user stopped owner policy")
    } catch { #expect(error as? WireFailure == WireFailure(.ownerConflict)) }
    do {
        _ = try await ledger.admit(.stopAndRestore(context: context, reason: .recovery), credentials: peer, nowUTC: Date())
        Issue.record("Stop reason changed on replay")
    } catch { #expect(error as? WireFailure == WireFailure(.idempotencyConflict)) }
}

@Test func tokensAreBoundToConnectionAndAuditSessionAndExpireOnDisconnect() async throws {
    let version = StateVersion()
    let ledger = CommandAdmissionLedger(version: version, ownerUID: 501)
    let peer = credentials()
    let session = try await ledger.openOwnerSession(for: peer)
    let context = CommandContext(expected: version, controlSessionID: session)
    for invalidPeer in [credentials(), credentials(id: peer.connectionID, audit: 8)] {
        do {
            _ = try await ledger.admit(policyCommand(context), credentials: invalidPeer, nowUTC: Date())
            Issue.record("Token reused outside authenticated connection")
        } catch { #expect(error as? WireFailure == WireFailure(.controlSessionExpired)) }
    }
    await ledger.disconnect(peer.connectionID)
    do {
        _ = try await ledger.admit(policyCommand(context), credentials: peer, nowUTC: Date())
        Issue.record("Disconnected token accepted")
    } catch { #expect(error as? WireFailure == WireFailure(.controlSessionExpired)) }
}

@Test func restoreUnknownIntentDoesNotScheduleEffectAgain() async throws {
    let version = StateVersion()
    let ledger = CommandAdmissionLedger(version: version, ownerUID: 501)
    let peer = credentials()
    let session = try await ledger.openOwnerSession(for: peer)
    let context = CommandContext(expected: version, controlSessionID: session)
    let accepted = try await ledger.admit(policyCommand(context), credentials: peer, nowUTC: Date())
    let checkpoint = await ledger.checkpoint()
    let decoded = try JSONDecoder().decode(AdmissionCheckpoint.self, from: JSONEncoder().encode(checkpoint))
    let restored = CommandAdmissionLedger(restoring: decoded)
    let state = await restored.checkpoint()
    #expect(state.version == accepted.receipt.version)
    #expect(state.records[0].receipt.outcome == .outcomeUnknown)
    #expect(state.records[0].normalizedPayload == checkpoint.records[0].normalizedPayload)
    let reconnectedPeer = credentials()
    let newSession = try await restored.openOwnerSession(for: reconnectedPeer)
    let replayContext = CommandContext(commandID: context.commandID, expected: context.expected, controlSessionID: newSession)
    let replay = try await restored.admit(policyCommand(replayContext), credentials: reconnectedPeer, nowUTC: Date())
    #expect(replay.isReplay)
    #expect(replay.receipt.outcome == .outcomeUnknown)
    #expect(replay.receipt.operationID == accepted.receipt.operationID)
}

@Test func expiredDeduplicationDoesNotReplayIntoFreshState() async throws {
    let version = StateVersion()
    let ledger = CommandAdmissionLedger(version: version, ownerUID: 501)
    let peer = credentials()
    let session = try await ledger.openOwnerSession(for: peer)
    let context = CommandContext(expected: version, controlSessionID: session)
    let start = Date(timeIntervalSince1970: 1_000)
    _ = try await ledger.admit(policyCommand(context), credentials: peer, nowUTC: start)
    do {
        _ = try await ledger.admit(policyCommand(context), credentials: peer, nowUTC: start.addingTimeInterval(CommandAdmissionLedger.retentionSeconds))
        Issue.record("Expired command silently replayed")
    } catch { #expect(error as? WireFailure == WireFailure(.revisionConflict)) }
}

@Test func outstandingLimitReleasedByCompletion() async throws {
    let ledger = CommandAdmissionLedger(version: StateVersion(), ownerUID: 501)
    let peer = credentials()
    let session = try await ledger.openOwnerSession(for: peer)
    var first: AdmissionReceipt?
    for _ in 0..<32 {
        let current = await ledger.checkpoint().version
        let accepted = try await ledger.admit(policyCommand(CommandContext(expected: current, controlSessionID: session)), credentials: peer, nowUTC: Date())
        if first == nil { first = accepted.receipt }
    }
    let current = await ledger.checkpoint().version
    do {
        _ = try await ledger.admit(policyCommand(CommandContext(expected: current, controlSessionID: session)), credentials: peer, nowUTC: Date())
        Issue.record("Exceeded per-connection limit")
    } catch { #expect(error as? WireFailure == WireFailure(.rateLimited)) }
    _ = try await ledger.recordOutcome(operationID: try #require(first).operationID, outcome: .noChange)
    _ = try await ledger.admit(policyCommand(CommandContext(expected: current, controlSessionID: session)), credentials: peer, nowUTC: Date())
    #expect(await ledger.checkpoint().version.revision == 33)
    let stop = try await ledger.admit(.stopAndRestore(context: CommandContext(expected: StateVersion(), controlSessionID: session), reason: .userRequested), credentials: peer, nowUTC: Date())
    #expect(stop.receipt.version.revision == 34)
}
