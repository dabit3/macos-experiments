import AVFoundation
import CoreText
import CourtCore
import Security
import SwiftUI
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

enum Launch {
    static func value(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--\(key)"), args.indices.contains(index + 1) {
            return args[index + 1]
        }
        if let arg = args.first(where: { $0.hasPrefix("--\(key)=") }) {
            return String(arg.dropFirst(key.count + 3))
        }
        return ProcessInfo.processInfo.environment[key]
    }

    static var platform: String {
        #if os(macOS)
            "macos"
        #else
            "ios"
        #endif
    }

    static func identity() throws -> String {
        if let override = value("GC_CLIENT_ID"), !override.isEmpty {
            return override
        }
        let query: [String: NSObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "dev.gambitcourt.native.session" as NSString,
            kSecAttrAccount as String: "client-id" as NSString,
            kSecReturnData as String: NSNumber(value: true),
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) {
            return value
        }
        guard status == errSecItemNotFound else { throw IdentityError(status: status) }
        let value = UUID().uuidString.lowercased()
        var entry = query
        entry.removeValue(forKey: kSecReturnData as String)
        entry[kSecValueData as String] = Data(value.utf8) as NSData
        entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let added = SecItemAdd(entry as CFDictionary, nil)
        guard added == errSecSuccess else { throw IdentityError(status: added) }
        return value
    }

    struct IdentityError: LocalizedError {
        let status: OSStatus
        var errorDescription: String? {
            "Could not save your session identity in Keychain (\(status)). This launch can reconnect, but your seat cannot be resumed after quitting."
        }
    }

    static func registerFonts() {
        guard let directory = Bundle.main.resourceURL?.appendingPathComponent("fonts"),
              let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for url in urls where url.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func copy(_ text: String) {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #else
            UIPasteboard.general.string = text
        #endif
    }
}

@MainActor
final class CourtFeedback {
    private var players: [String: AVAudioPlayer] = [:]
    func play(_ effect: String, sound: Bool, haptics: Bool) {
        if sound, let url = Bundle.main.url(forResource: effect, withExtension: "wav", subdirectory: "sfx") {
            if players[effect] == nil {
                players[effect] = try? AVAudioPlayer(contentsOf: url)
            }
            players[effect]?.currentTime = 0
            players[effect]?.play()
        }
        #if os(iOS)
            if haptics {
                if effect == "end" {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UIImpactFeedbackGenerator(style: effect == "capture" || effect == "check" ? .medium : .light).impactOccurred()
                }
            }
        #endif
    }
}

enum Arcade {
    static let midnight = Color(hex: 0x101B46)
    static let royal = Color(hex: 0x254BCB)
    static let sunshine = Color(hex: 0xFFD34D)
    static let aqua = Color(hex: 0x59E1DD)
    static let porcelain = Color(hex: 0xF6F8FF)
    static func display(_ size: CGFloat) -> Font {
        .custom("Bungee-Regular", size: size, relativeTo: .title)
    }

    static func mono(_ size: CGFloat) -> Font {
        .custom("IBMPlexMono-Regular", size: size, relativeTo: .body)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct CourtButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Manrope-Bold", size: 14, relativeTo: .body))
            .padding(.horizontal, 14).padding(.vertical, 12)
            .foregroundStyle(primary ? Arcade.midnight : Arcade.porcelain)
            .background(primary ? Arcade.sunshine : Arcade.royal.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: primary ? Color(hex: 0x987018) : Arcade.midnight, radius: 0, y: configuration.isPressed ? 0 : 4)
            .offset(y: configuration.isPressed ? 3 : 0)
            .opacity(enabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CourtCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(scheme == .dark ? Color(hex: 0x172653) : Color(hex: 0xF8FAFF), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Arcade.royal.opacity(0.28)))
    }
}

struct Crown: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [CGPoint] = [.init(x: 9, y: 24), .init(x: 30, y: 43), .init(x: 50, y: 13),
                                 .init(x: 70, y: 43), .init(x: 91, y: 24), .init(x: 80, y: 72), .init(x: 20, y: 72)]
        path.addLines(points); path.closeSubpath()
        path.addRoundedRect(in: CGRect(x: 20, y: 80, width: 60, height: 8), cornerSize: CGSize(width: 3, height: 3))
        return path.applying(CGAffineTransform(scaleX: rect.width / 100, y: rect.height / 100))
    }
}
