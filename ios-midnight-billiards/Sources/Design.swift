import SwiftUI

enum Theme {
    static let background = Color(red: 0.027, green: 0.051, blue: 0.066)
    static let surface = Color(red: 0.063, green: 0.094, blue: 0.114)
    static let raised = Color(red: 0.090, green: 0.130, blue: 0.153)
    static let stroke = Color.white.opacity(0.09)
    static let primary = Color(red: 0.965, green: 0.957, blue: 0.937)
    static let secondary = Color(red: 0.615, green: 0.675, blue: 0.705)
    static let tertiary = Color(red: 0.405, green: 0.465, blue: 0.495)
    static let accent = Color(red: 0.992, green: 0.792, blue: 0.435)
    static let accentDeep = Color(red: 0.890, green: 0.620, blue: 0.290)
    static let onAccent = Color(red: 0.110, green: 0.075, blue: 0.035)
    static let felt = Color(red: 0.075, green: 0.345, blue: 0.392)
    static let hot = Color(red: 1.0, green: 0.455, blue: 0.380)
    static let cool = Color(red: 0.420, green: 0.850, blue: 0.800)

    static var accentFill: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .top, endPoint: .bottom)
    }
}

/// Materials used by the table renderer.
enum Brass {
    static let light = Color(red: 0.96, green: 0.85, blue: 0.60)
    static let mid = Color(red: 0.84, green: 0.70, blue: 0.45)
    static let deep = Color(red: 0.58, green: 0.43, blue: 0.22)
    static let walnutDeep = Color(red: 0.14, green: 0.085, blue: 0.06)
    static let leather = Color(red: 0.16, green: 0.09, blue: 0.065)
}

extension Font {
    static func ui(_ size: Double, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(16, .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accentFill))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
            )
            .shadow(color: Theme.accent.opacity(0.25), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(15, .medium))
            .foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.12 : 0.06))
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stroke))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct Panel: ViewModifier {
    var radius = 20.0
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.raised, Theme.surface], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.stroke))
            .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
    }
}

extension View {
    func panel(radius: Double = 20) -> some View { modifier(Panel(radius: radius)) }
}

/// Round glyph button used in the game HUD.
struct HUDButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.ui(15, .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(.white.opacity(0.07)))
                .overlay(Circle().strokeBorder(Theme.stroke))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// Pull-back cue: drag down to load power, release to strike.
struct PowerCue: View {
    @Binding var pull: Double?
    let lastPower: Double
    let enabled: Bool
    let onShoot: (Double) -> Void
    @State private var travel = 0.0

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let track = height - 36
            let value = pull ?? 0
            VStack(spacing: 6) {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke))
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.cool, Theme.accent, Theme.hot], startPoint: .top,
                                endPoint: .bottom)
                        )
                        .frame(height: max(0, (track - 4) * value))
                        .mask(alignment: .top) {
                            RoundedRectangle(cornerRadius: 20, style: .continuous).frame(height: track - 4)
                        }
                        .padding(2)
                        .opacity(0.9)
                    Capsule()
                        .fill(Theme.primary.opacity(0.55))
                        .frame(width: 16, height: 2)
                        .offset(y: 2 + (track - 8) * lastPower)
                        .opacity(pull == nil && lastPower > 0 ? 1 : 0)
                    VStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "chevron.compact.down")
                                .font(.ui(18, .semibold))
                                .opacity(0.25 + Double(index) * 0.2)
                        }
                    }
                    .foregroundStyle(Theme.secondary)
                    .frame(maxHeight: .infinity)
                    .opacity(pull == nil && enabled ? 1 : 0)
                    cueHandle
                        .offset(y: 6 + (track - 52) * value)
                }
                .frame(height: track)
                Text(pull == nil ? (enabled ? "Pull" : "Wait") : "\(Int(value * 100))%")
                    .font(.ui(12, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(pull == nil ? Theme.secondary : Theme.primary)
                    .frame(height: 30)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard enabled else { return }
                        let next = min(1, max(0, gesture.translation.height / (track * 0.82)))
                        if pull == nil || abs((pull ?? 0) - next) > 0.001 { pull = next }
                    }
                    .onEnded { _ in
                        guard enabled, let shot = pull else {
                            pull = nil
                            return
                        }
                        pull = nil
                        if shot > 0.04 { onShoot(shot) }
                    }
            )
            .opacity(enabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.15), value: enabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Shot power")
        .accessibilityValue("\(Int(lastPower * 100)) percent. Drag down and release to shoot.")
        .accessibilityAction(named: "Shoot") { if enabled { onShoot(max(0.1, lastPower)) } }
    }

    private var cueHandle: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(red: 0.32, green: 0.56, blue: 0.80)).frame(width: 10, height: 5)
            Rectangle().fill(Theme.primary).frame(width: 12, height: 5)
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.93, green: 0.80, blue: 0.58),
                            Color(red: 0.78, green: 0.60, blue: 0.38),
                        ], startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 14, height: 36)
        }
        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
        .frame(maxWidth: .infinity)
    }
}

/// Knurled thumb wheel for sub-degree aim.
struct FineAimWheel: View {
    @Binding var angle: Double
    let enabled: Bool
    @State private var anchor: Double?

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            Canvas { context, size in
                let phase = (angle * 180 / .pi * 6).truncatingRemainder(dividingBy: 7)
                var y = -7 + phase
                while y < size.height + 7 {
                    let depth = abs(y - size.height / 2) / (size.height / 2)
                    let rect = CGRect(x: 7, y: y, width: size.width - 14, height: max(0.6, 2.2 * (1 - depth)))
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 1),
                        with: .color(.white.opacity(0.28 * (1 - depth * 0.85))))
                    y += 7
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.6), location: 0),
                                .init(color: Theme.raised, location: 0.5),
                                .init(color: .black.opacity(0.6), location: 1),
                            ], startPoint: .top, endPoint: .bottom))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
            .overlay(
                Capsule().fill(Theme.accent).frame(width: 3, height: 14).offset(
                    x: -geometry.size.width / 2 + 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { gesture in
                        guard enabled else { return }
                        let start = anchor ?? angle
                        anchor = start
                        angle = start - gesture.translation.height / height * (.pi / 60)
                    }
                    .onEnded { _ in anchor = nil }
            )
            .opacity(enabled ? 1 : 0.4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fine aim")
        .accessibilityValue("\(Int((angle * 180 / .pi).rounded())) degrees")
        .accessibilityAdjustableAction { direction in
            angle += (direction == .increment ? 1 : -1) * .pi / 720
        }
    }
}

/// Cue ball face showing where the tip will strike.
struct CueFace: View {
    let spin: Double
    var size = 44.0
    var body: some View {
        ZStack {
            Circle().fill(
                RadialGradient(
                    colors: [
                        .white, Color(red: 0.86, green: 0.86, blue: 0.82),
                        Color(red: 0.55, green: 0.57, blue: 0.56),
                    ],
                    center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.72))
            Circle().stroke(.black.opacity(0.12), lineWidth: 0.5).frame(
                width: size * 0.62, height: size * 0.62)
            Rectangle().fill(.black.opacity(0.1)).frame(width: 0.5, height: size * 0.62)
            Rectangle().fill(.black.opacity(0.1)).frame(width: size * 0.62, height: 0.5)
            Circle().fill(Color(red: 0.86, green: 0.20, blue: 0.20))
                .frame(width: size * 0.2, height: size * 0.2)
                .shadow(color: .black.opacity(0.3), radius: 1)
                .offset(y: -spin * size * 0.3)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.4), radius: size * 0.12, y: size * 0.08)
    }
}

/// Large picker for follow or draw; drag the dot up or down.
struct SpinPicker: View {
    @Binding var spin: Double
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Spin").font(.ui(16, .semibold)).foregroundStyle(Theme.primary)
                Spacer()
                Text(label).font(.ui(13, .medium)).foregroundStyle(Theme.accent).monospacedDigit()
            }
            HStack(spacing: 14) {
                GeometryReader { geometry in
                    let size = geometry.size.width
                    CueFace(spin: spin, size: size)
                        .contentShape(Circle())
                        .gesture(
                            DragGesture(minimumDistance: 0).onChanged { gesture in
                                let offset = (size / 2 - gesture.location.y) / (size * 0.3)
                                let value = min(1, max(-1, offset))
                                spin = abs(value) < 0.12 ? 0 : (value * 20).rounded() / 20
                            })
                }
                .frame(width: 118, height: 118)
                VStack(alignment: .leading, spacing: 8) {
                    choice("Follow", value: 0.75, symbol: "arrow.up")
                    choice("Center", value: 0, symbol: "circle")
                    choice("Draw", value: -0.75, symbol: "arrow.down")
                }
            }
            Button("Done", action: onClose).buttonStyle(SecondaryButtonStyle())
        }
        .padding(16)
        .frame(width: 272)
        .panel(radius: 22)
    }

    private var label: String {
        spin == 0 ? "Center" : spin > 0 ? "Follow \(Int(spin * 100))%" : "Draw \(Int(-spin * 100))%"
    }

    private func choice(_ title: String, value: Double, symbol: String) -> some View {
        let selected = abs(spin - value) < 0.01
        return Button {
            spin = value
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.ui(11, .bold)).frame(width: 14)
                Text(title).font(.ui(14, .medium))
            }
            .foregroundStyle(selected ? Theme.onAccent : Theme.primary)
            .padding(.horizontal, 12)
            .frame(width: 108, height: 34, alignment: .leading)
            .background(
                Capsule().fill(
                    selected ? AnyShapeStyle(Theme.accentFill) : AnyShapeStyle(.white.opacity(0.06))))
        }
        .buttonStyle(PressStyle())
    }
}
