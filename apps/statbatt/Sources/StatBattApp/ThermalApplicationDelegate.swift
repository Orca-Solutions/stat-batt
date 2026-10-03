import AppKit

@MainActor final class ThermalApplicationDelegate: NSObject, NSApplicationDelegate {
    static weak var model: ThermalUIModel?
    private var terminationPending = false
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model = Self.model else { return .terminateNow }
        guard !terminationPending else { return .terminateCancel }
        terminationPending = true
        Task {
            let restored = await model.stopAndVerify()
            terminationPending = false
            if !restored { NSApplication.shared.activate() }
            sender.reply(toApplicationShouldTerminate: restored)
        }
        return .terminateLater
    }
}
