import SwiftUI

enum Theme {
    static let pink = Color(UIColor.orbitPink)
    static let cyan = Color(UIColor.orbitCyan)
    static let gold = Color(UIColor.orbitGold)
    static let ink = Color(UIColor.orbitInk)
    static let mint = Color(red: 0.45, green: 1, blue: 0.75)
    static let surface = Color.white.opacity(0.055)
    static let surfaceRaised = Color.white.opacity(0.09)
    static let stroke = Color.white.opacity(0.10)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.42)

    static let backdrop = LinearGradient(
        colors: [Color(red: 0.13, green: 0.05, blue: 0.30), ink, Color(red: 0.02, green: 0.12, blue: 0.24)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat = 15, weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight) }
    static func mono(_ size: CGFloat, weight: Font.Weight = .black) -> Font { .system(size: size, weight: weight, design: .monospaced) }

    static func grade(_ text: String) -> Color {
        switch text {
        case "PERFECT": return gold
        case "GREAT": return cyan
        case "GOOD": return mint
        default: return pink
        }
    }

    static func rank(for accuracy: Double) -> String {
        accuracy >= 100 ? "SSS" : accuracy >= 98 ? "SS" : accuracy >= 90 ? "S" : accuracy >= 80 ? "A" : accuracy >= 65 ? "B" : "C"
    }

    static func score(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.textTertiary

    init(_ text: String, color: Color = Theme.textTertiary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .black)).tracking(2).foregroundStyle(color)
    }
}

struct Card<Content: View>: View {
    var tint: Color = .clear
    var selected = false
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? tint.opacity(0.14) : Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(selected ? tint : (tint == .clear ? Theme.stroke : tint.opacity(0.28)), lineWidth: selected ? 1.5 : 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.cyan
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(isEnabled ? Theme.ink : Theme.textTertiary)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(
                LinearGradient(colors: isEnabled ? [color, color.opacity(0.72)] : [Theme.surfaceRaised, Theme.surfaceRaised],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: isEnabled ? color.opacity(configuration.isPressed ? 0.15 : 0.45) : .clear, radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = Theme.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.textPrimary.opacity(0.85))
            .frame(width: 42, height: 42)
            .background(Theme.surfaceRaised, in: Circle())
            .overlay(Circle().stroke(Theme.stroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
    }
}

struct Chip: View {
    let text: String
    var color: Color = Theme.cyan
    var icon: String?

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .black)) }
            Text(text.uppercased()).font(.system(size: 9, weight: .black)).tracking(0.8).lineLimit(1).fixedSize()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct StatusDot: View {
    let color: Color
    var pulsing = false
    @State private var on = false

    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.8), radius: pulsing && on ? 6 : 2)
            .scaleEffect(pulsing && on ? 1.25 : 1)
            .onAppear {
                guard pulsing else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

struct Avatar: View {
    let name: String?
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(name == nil ? Theme.surfaceRaised : color.opacity(0.22))
            if let name, let first = name.first {
                Text(String(first).uppercased()).font(Theme.display(size * 0.44)).foregroundStyle(color)
            } else {
                Image(systemName: "person.fill.questionmark").font(.system(size: size * 0.4)).foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(name == nil ? Theme.stroke : color.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: name == nil ? [4, 4] : [])))
    }
}

struct Field: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let id: String
    var icon: String = "person"
    var monospaced = false
    var uppercase = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Eyebrow(label)
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textTertiary).frame(width: 18)
                TextField(placeholder, text: $text)
                    .font(monospaced ? Theme.mono(18) : .system(size: 16, weight: .semibold, design: .rounded))
                    .textInputAutocapitalization(uppercase ? .characters : .never).autocorrectionDisabled()
                    .onChange(of: text) { _, value in
                        if uppercase {
                            let cleaned = String(value.uppercased().filter(\.isHexDigit).prefix(6))
                            if cleaned != value { text = cleaned }
                        }
                    }
                    .accessibilityIdentifier(id)
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textTertiary)
                    }.accessibilityLabel("Clear \(label)")
                }
            }
            .padding(.horizontal, 14).frame(height: 52)
            .background(Theme.ink.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        }
    }
}

struct Toast: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.gold)
            Text(message).font(Theme.body(13, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Dismiss", action: dismiss).font(Theme.body(13, weight: .bold)).foregroundStyle(Theme.cyan)
        }
        .padding(16)
        .background(Color(red: 0.36, green: 0.06, blue: 0.20), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.pink.opacity(0.5), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
}
