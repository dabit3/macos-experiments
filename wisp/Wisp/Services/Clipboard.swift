import UIKit
import UniformTypeIdentifiers

enum Clipboard {
    /// Copies stay on this device (no Universal Clipboard) and expire after two minutes.
    static func copy(_ text: String) {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: text]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)]
        )
    }
}
