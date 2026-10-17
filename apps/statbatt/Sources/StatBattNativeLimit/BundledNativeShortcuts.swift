import Foundation
import CryptoKit

/// Pins the inspected Apple-signed exports shipped with StatBatt. This verifies the
/// bundled artifact, not the editable library shortcut after the user imports it.
public enum BundledNativeShortcuts {
    public static func url(for target: NativeFixedLimit, bundle: Bundle = .main) -> URL? {
        guard let directory = bundle.resourceURL else { return nil }
        return url(for: target, resourcesDirectory: directory)
    }

    public static func url(for target: NativeFixedLimit, resourcesDirectory: URL) -> URL? {
        let url = resourcesDirectory.appendingPathComponent("Shortcuts", isDirectory: true)
            .appendingPathComponent(target.expectedShortcutName + ".shortcut")
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size < 1_000_000,
              let data = try? Data(contentsOf: url),
              data.prefix(4) == Data("AEA1".utf8),
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == digest(for: target)
        else { return nil }
        return url
    }

    private static func digest(for target: NativeFixedLimit) -> String {
        switch target {
        case .eighty: "5db7064b8e86d9df2e0c3c61759e57f23b7231956cbc141293f8f18463651665"
        case .hundred: "81eb7e6acc7ff1225fc8822eba6bbe5f87447555363b580ba6086d11498b2225"
        }
    }
}
