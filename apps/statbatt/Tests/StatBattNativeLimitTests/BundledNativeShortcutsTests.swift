import Foundation
import Testing
@testable import StatBattNativeLimit

struct BundledNativeShortcutsTests {
    private var resources: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Resources")
    }

    @Test func shippedExportsMatchInspectedArtifacts() {
        for target in NativeFixedLimit.allCases {
            #expect(BundledNativeShortcuts.url(for: target, resourcesDirectory: resources) != nil)
        }
    }

    @Test func missingOrTamperedExportsAreRejected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let shortcuts = directory.appendingPathComponent("Shortcuts")
        try FileManager.default.createDirectory(at: shortcuts, withIntermediateDirectories: true)
        #expect(BundledNativeShortcuts.url(for: .eighty, resourcesDirectory: directory) == nil)
        let destination = shortcuts.appendingPathComponent(NativeFixedLimit.eighty.expectedShortcutName + ".shortcut")
        let source = try #require(BundledNativeShortcuts.url(for: .eighty, resourcesDirectory: resources))
        var data = try Data(contentsOf: source)
        data[data.count - 1] ^= 1
        try data.write(to: destination)
        #expect(BundledNativeShortcuts.url(for: .eighty, resourcesDirectory: directory) == nil)
    }
}
