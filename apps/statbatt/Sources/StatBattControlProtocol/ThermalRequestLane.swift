import Foundation

/// One request at a time per XPC connection. Never retries a failed mutation.
@MainActor public final class ThermalRequestLane {
    private var tail: Task<Void, Never>?
    public init() {}
    public func perform<T: Sendable>(_ operation: @escaping @MainActor () async throws -> T) async throws -> T {
        let previous = tail
        let work = Task {
            if let previous { await previous.value }
            try Task.checkCancellation()
            return try await operation()
        }
        tail = Task { _ = try? await work.value }
        return try await withTaskCancellationHandler {
            try await work.value
        } onCancel: { work.cancel() }
    }
}
