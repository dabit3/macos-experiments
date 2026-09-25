import SwiftUI

enum Typeface {
    static func display(_ size: Double) -> Font {
        .custom("Baskerville", size: size)
    }

    static func displayBold(_ size: Double) -> Font {
        .custom("Baskerville-SemiBold", size: size)
    }

    static func italic(_ size: Double) -> Font {
        .custom("Baskerville-Italic", size: size)
    }

    static func label(_ size: Double = 10.5) -> Font {
        .custom("Baskerville-SemiBold", size: size)
    }
}

struct SkyBackdrop: View {
    let palette: PostcardPalette
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: palette.skyTop, location: 0),
                    .init(color: palette.skyHorizon, location: 0.52),
                    .init(color: PostcardPalette.paper, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            GeometryReader { geometry in
                let size = geometry.size
                let sun = CGPoint(x: size.width * 0.78, y: size.height * 0.15)
                Circle()
                    .fill(RadialGradient(
                        colors: [palette.glow.opacity(0.75), palette.glow.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 170
                    ))
                    .frame(width: 340, height: 340)
                    .position(sun)
                Circle()
                    .fill(PostcardPalette.ivory.opacity(0.92))
                    .frame(width: 46, height: 46)
                    .position(sun)
                Hills(palette: palette)
                    .frame(height: size.height * 0.34)
                    .position(x: size.width / 2, y: size.height * 0.62)
                TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    Clouds(time: time)
                }
            }
            RadialGradient(
                colors: [.clear, palette.deep.opacity(0.14)],
                center: .center, startRadius: 180, endRadius: 620
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct Hills: View {
    let palette: PostcardPalette

    var body: some View {
        Canvas { context, size in
            let layers: [(Double, Double, Double, Double)] = [
                (0.35, 0.16, 0.9, 0.16), (0.55, 0.12, 1.7, 0.24), (0.74, 0.09, 2.6, 0.34),
            ]
            for (baseline, amplitude, frequency, opacity) in layers {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                let steps = 48
                for step in 0 ... steps {
                    let t = Double(step) / Double(steps)
                    let y = size.height * baseline
                        - sin(t * .pi * frequency + baseline * 5) * size.height * amplitude
                        - sin(t * .pi * frequency * 2.3 + 1.7) * size.height * amplitude * 0.35
                    path.addLine(to: CGPoint(x: size.width * t, y: y))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .linearGradient(
                    Gradient(colors: [palette.mist.opacity(opacity), palette.mist.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: size.height * baseline * 0.6),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
            }
        }
    }
}

private struct Clouds: View {
    let time: Double

    var body: some View {
        Canvas { context, size in
            let clouds: [(Double, Double, Double, Double)] = [
                (0.12, 0.09, 74, 0.017), (0.58, 0.22, 56, 0.012), (0.86, 0.32, 44, 0.02), (0.3, 0.4, 38, 0.009),
            ]
            for (x, y, width, speed) in clouds {
                let drift = ((x + time * speed).truncatingRemainder(dividingBy: 1.3)) - 0.15
                let origin = CGPoint(x: size.width * drift, y: size.height * y)
                var cloud = Path()
                cloud.addEllipse(in: CGRect(x: origin.x, y: origin.y, width: width, height: width * 0.3))
                cloud.addEllipse(in: CGRect(
                    x: origin.x + width * 0.25,
                    y: origin.y - width * 0.13,
                    width: width * 0.5,
                    height: width * 0.36
                ))
                cloud.addEllipse(in: CGRect(
                    x: origin.x + width * 0.5,
                    y: origin.y - width * 0.04,
                    width: width * 0.42,
                    height: width * 0.3
                ))
                context.fill(cloud, with: .color(PostcardPalette.ivory.opacity(0.62)))
            }
        }
    }
}

struct Stamp: View {
    let numeral: String
    let palette: PostcardPalette
    var collected = false
    var width: Double = 46

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(
                    colors: [palette.mist, palette.skyTop.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(
                    PostcardPalette.paper,
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round, dash: [0.01, 5.2])
                )
            RoundedRectangle(cornerRadius: 1)
                .stroke(palette.deep.opacity(0.55), lineWidth: 0.8)
                .padding(5.5)
            VStack(spacing: 2) {
                Image(systemName: collected ? "sun.max.fill" : "sun.max")
                    .font(.system(size: width * 0.2, weight: .light))
                    .foregroundStyle(collected ? PostcardPalette.goldDeep : palette.deep)
                Text(numeral)
                    .font(Typeface.displayBold(width * 0.36))
                    .foregroundStyle(palette.deep)
            }
        }
        .frame(width: width, height: width * 1.2)
        .shadow(color: palette.deep.opacity(0.18), radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}

struct Postmark: View {
    let value: String
    let caption: String
    let palette: PostcardPalette
    var diameter: Double = 60

    var body: some View {
        ZStack {
            Circle().stroke(palette.deep.opacity(0.75), lineWidth: 1.4)
            Circle().stroke(palette.deep.opacity(0.5), lineWidth: 0.8).padding(4)
            VStack(spacing: -1) {
                Text(value)
                    .font(Typeface.display(diameter * 0.4))
                    .contentTransition(.numericText())
                Text(caption)
                    .font(Typeface.label(diameter * 0.12))
                    .tracking(1.4)
            }
            .foregroundStyle(palette.deep)
        }
        .frame(width: diameter, height: diameter)
    }
}

struct CancelLines: View {
    let palette: PostcardPalette

    var body: some View {
        Canvas { context, size in
            for row in 0 ..< 3 {
                let y = size.height * (0.28 + 0.22 * Double(row))
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: y))
                for step in 1 ... 24 {
                    let x = size.width * Double(step) / 24
                    wave.addLine(to: CGPoint(x: x, y: y + sin(Double(step) * 0.9) * 1.8))
                }
                context.stroke(wave, with: .color(palette.deep.opacity(0.42)), lineWidth: 1)
            }
        }
        .frame(height: 30)
        .accessibilityHidden(true)
    }
}

struct Ornament: View {
    let color: Color
    var width: Double = 120

    var body: some View {
        HStack(spacing: 8) {
            line
            Rectangle().fill(color).frame(width: 5, height: 5).rotationEffect(.degrees(45))
            line
        }
        .frame(width: width)
        .accessibilityHidden(true)
    }

    private var line: some View {
        Rectangle().fill(color.opacity(0.55)).frame(height: 0.8)
    }
}

struct PostcardCard<Content: View>: View {
    let palette: PostcardPalette
    var tilt: Double = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(
                    colors: [PostcardPalette.ivory, PostcardPalette.paper],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: palette.deep.opacity(0.24), radius: 22, y: 14)
                .shadow(color: palette.deep.opacity(0.1), radius: 3, y: 1)
            RoundedRectangle(cornerRadius: 2)
                .stroke(palette.deep.opacity(0.28), lineWidth: 0.8)
                .padding(9)
            content()
        }
        .rotationEffect(.degrees(tilt))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let palette: PostcardPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.display(18))
            .foregroundStyle(PostcardPalette.ivory)
            .padding(.horizontal, 26)
            .frame(minHeight: 58)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(LinearGradient(
                    colors: [PostcardPalette.ink.opacity(0.86), PostcardPalette.ink],
                    startPoint: .top, endPoint: .bottom
                ))
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            .shadow(color: palette.deep.opacity(configuration.isPressed ? 0.12 : 0.32), radius: 14, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    let palette: PostcardPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.display(15))
            .foregroundStyle(PostcardPalette.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(Capsule().fill(PostcardPalette.paper.opacity(configuration.isPressed ? 0.9 : 0.5)))
            .overlay(Capsule().strokeBorder(palette.deep.opacity(0.3), lineWidth: 0.8))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct TextLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typeface.italic(15))
            .foregroundStyle(PostcardPalette.ink.opacity(configuration.isPressed ? 0.5 : 0.8))
            .frame(minHeight: 44)
    }
}

struct GlassButton: View {
    let symbol: String
    let label: String
    let palette: PostcardPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(PostcardPalette.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(PostcardPalette.paper.opacity(0.7)))
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1))
                .shadow(color: palette.deep.opacity(0.16), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = PostcardPalette.ink.opacity(0.72)

    var body: some View {
        Text(text)
            .font(Typeface.label(10.5))
            .tracking(2.2)
            .foregroundStyle(color)
    }
}

struct SealRow: View {
    let lit: Int
    let total: Int
    let palette: PostcardPalette

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 7) {
                ForEach(0 ..< total, id: \.self) { bit in
                    let on = lit & (1 << bit) != 0
                    Image(systemName: on ? "sun.max.fill" : "sun.max")
                        .font(.system(size: 15, weight: on ? .regular : .light))
                        .foregroundStyle(on ? PostcardPalette.goldDeep : palette.deep.opacity(0.45))
                        .shadow(color: on ? PostcardPalette.gold.opacity(0.7) : .clear, radius: 5)
                        .animation(.easeOut(duration: 0.4), value: on)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Capsule().fill(PostcardPalette.paper.opacity(0.55)))
            .overlay(Capsule().strokeBorder(palette.deep.opacity(0.25), lineWidth: 0.8))
            Eyebrow(text: total == 1 ? "SUN SEAL" : "SUN SEALS", color: palette.deep)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(lit.nonzeroBitCount) of \(total) sun seals lit")
    }
}

struct TurnDial: View {
    let mechanism: Mechanism
    let orientation: Int
    let numeral: String?
    let enabled: Bool
    let occupied: Bool
    let busy: Bool
    let palette: PostcardPalette
    let reduceMotion: Bool
    let action: () -> Void
    @State private var wraps = 0

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [PostcardPalette.ivory, PostcardPalette.paper.opacity(0.85)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .shadow(color: palette.deep.opacity(0.2), radius: 8, y: 4)
                    Circle().strokeBorder(
                        occupied ? palette.accent : palette.deep.opacity(0.35),
                        lineWidth: occupied ? 2 : 1
                    )
                    Circle().stroke(palette.deep.opacity(0.22), lineWidth: 0.7).padding(6)
                    ForEach(0 ..< 4, id: \.self) { dock in
                        Circle()
                            .fill(palette.deep.opacity(0.35))
                            .frame(width: 3.5, height: 3.5)
                            .offset(y: -25)
                            .rotationEffect(.degrees(Double(dock) * 90))
                    }
                    ZStack {
                        arm.rotationEffect(.degrees(0))
                        arm.rotationEffect(.degrees(mechanism.elbow ? 90 : 180))
                        Circle().fill(palette.accent).frame(width: 12, height: 12)
                        Circle().stroke(PostcardPalette.ivory, lineWidth: 1.2).frame(width: 12, height: 12)
                    }
                    .rotationEffect(.degrees(Double(orientation + wraps) * 90))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.48), value: orientation + wraps)
                    .opacity(enabled ? 1 : 0.35)
                    if !enabled {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.deep)
                            .padding(6)
                            .background(Circle().fill(PostcardPalette.paper))
                            .offset(x: 22, y: -22)
                    }
                    if let numeral {
                        Text(numeral)
                            .font(Typeface.displayBold(11))
                            .foregroundStyle(PostcardPalette.ivory)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(occupied ? palette.accent : palette.deep))
                            .offset(x: -22, y: -22)
                    }
                }
                .frame(width: 68, height: 68)
                VStack(spacing: 1) {
                    Text(mechanism.name)
                        .font(Typeface.display(14))
                        .foregroundStyle(PostcardPalette.ink)
                    Text(enabled ? "quarter turn" : "sealed")
                        .font(Typeface.italic(11.5))
                        .foregroundStyle(PostcardPalette.ink.opacity(0.6))
                }
            }
            .frame(minWidth: 118)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .opacity(busy ? 0.65 : 1)
        .onChange(of: orientation) { old, new in
            if new < old {
                wraps += 4
            }
        }
        .accessibilityLabel("Turn \(mechanism.name)")
        .accessibilityValue(
            enabled ? (occupied ? "Traveler aboard. Quarter turn clockwise" : "Quarter turn clockwise") :
                "Requires first sun seal"
        )
    }

    private var arm: some View {
        Capsule()
            .fill(palette.accent)
            .frame(width: 7, height: 26)
            .offset(y: -13)
    }
}
