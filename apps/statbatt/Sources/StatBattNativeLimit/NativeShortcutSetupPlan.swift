import Foundation

/// Decides which bundled import to offer. Missing means a successful library lookup
/// found no match; an ambiguous, replaced or unreadable entry must never trigger import.
public struct NativeShortcutSetupPlan: Equatable, Sendable {
    public let nextImport: NativeFixedLimit?
    public let canEnable: Bool
    public let unavailableBundledImports: Set<NativeFixedLimit>

    public init(discovered: Set<NativeFixedLimit>, missing: Set<NativeFixedLimit>,
                bundled: Set<NativeFixedLimit>, deviceQualified: Bool,
                controllerClear: Bool, recoveryRequired: Bool, busy: Bool) {
        unavailableBundledImports = missing.subtracting(discovered).subtracting(bundled)
        let available = deviceQualified && !recoveryRequired && !busy
        nextImport = available ? NativeFixedLimit.allCases.first {
            missing.contains($0) && !discovered.contains($0) && bundled.contains($0)
        } : nil
        canEnable = available && controllerClear &&
            Set(NativeFixedLimit.allCases).isSubset(of: discovered)
    }
}
