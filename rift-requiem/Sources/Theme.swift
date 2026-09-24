import SwiftUI
import UIKit

enum Palette {
    static let cream = Color(uiColor: Ink.cream)
    static let red = Color(uiColor: Ink.red)
    static let darkRed = Color(uiColor: Ink.darkRed)
    static let gold = Color(uiColor: Ink.gold)
    static let black = Color(uiColor: Ink.black)
    static let steel = Color(uiColor: Ink.steel)
    static let light = Color(uiColor: Ink.light)
    static let violet = Color(red: 0.55, green: 0.36, blue: 0.85)
    static let plate = Color(red: 0.09, green: 0.085, blue: 0.11)
    static let muted = Color(uiColor: Ink.cream).opacity(0.55)
}

enum Type {
    static func display(_ size: CGFloat) -> Font { .custom("AvenirNextCondensed-HeavyItalic", size: size) }
    static func heavy(_ size: CGFloat) -> Font { .custom("AvenirNextCondensed-Heavy", size: size) }
    static func demi(_ size: CGFloat) -> Font { .custom("AvenirNextCondensed-DemiBold", size: size) }
    static func label(_ size: CGFloat = 10) -> Font { .system(size: size, weight: .heavy, design: .monospaced) }
    static func mono(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
    static func body(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .medium) }
}

struct BladePanel: Shape {
    var cut: CGFloat = 10
    func path(in rect: CGRect) -> Path {
        Path { path in
            let cut = min(cut, rect.width / 3)
            path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

struct Gear: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            for index in 0..<48 {
                let angle = CGFloat(index) * .pi / 24
                let tooth: CGFloat = index % 4 < 2 ? 1 : 0.85
                let point = CGPoint(x: center.x + cos(angle) * radius * tooth,
                                    y: center.y + sin(angle) * radius * tooth)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
    }
}

struct MetalButton: ButtonStyle {
    enum Kind { case primary, secondary, ghost }
    var kind: Kind = .secondary
    var expand = false

    init(red: Bool = false, expand: Bool = false) {
        kind = red ? .primary : .secondary
        self.expand = expand
    }

    init(kind: Kind, expand: Bool = false) {
        self.kind = kind
        self.expand = expand
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Type.heavy(15))
            .tracking(1.2)
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 18).padding(.vertical, 11)
            .frame(maxWidth: expand ? .infinity : nil)
            .foregroundStyle(kind == .ghost ? Palette.cream.opacity(0.85) : Palette.cream)
            .background(
                BladePanel().fill(kind == .primary ? Palette.red : kind == .secondary ? Palette.plate : .clear)
            )
            .overlay(BladePanel().stroke(kind == .primary ? Palette.gold : Palette.gold.opacity(0.6), lineWidth: 1))
            .shadow(color: kind == .primary ? Palette.red.opacity(0.45) : .clear, radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SectionLabel: View {
    let index: String
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Text(index).font(Type.label(9)).foregroundStyle(Palette.black)
                .padding(.horizontal, 5).padding(.vertical, 2).background(Palette.gold)
            Text(title).font(Type.label(9)).tracking(2).foregroundStyle(Palette.gold)
            Rectangle().fill(Palette.gold.opacity(0.35)).frame(height: 1)
        }
    }
}

struct StatusPill: View {
    enum Tone { case idle, busy, live, bad }
    let tone: Tone
    let text: String
    @State private var pulse = false

    private var color: Color {
        switch tone {
        case .idle: return Palette.muted
        case .busy: return Palette.gold
        case .live: return Color(red: 0.45, green: 0.85, blue: 0.55)
        case .bad: return Palette.red
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 7, height: 7)
                .opacity(tone == .busy && pulse ? 0.3 : 1)
                .animation(tone == .busy ? .easeInOut(duration: 0.6).repeatForever() : .default, value: pulse)
            Text(text).font(Type.mono(10)).foregroundStyle(Palette.cream.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.07)))
        .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
        .onAppear { pulse = true }
        .accessibilityLabel(text)
    }
}

struct Chip: View {
    let text: String
    var fill: Color = Palette.red
    var foreground: Color = Palette.cream
    var body: some View {
        Text(text).font(Type.label(8)).tracking(1)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(fill).foregroundStyle(foreground)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func hit() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func notify(_ kind: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(kind)
    }
}
