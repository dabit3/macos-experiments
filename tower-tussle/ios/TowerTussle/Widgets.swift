import SwiftUI

// MARK: - Icons

enum IconKind {
    case trophy
    case coin
    case elixir
    case crown(Color, dim: Bool)
    case swords
    case cards
    case clock
    case help
    case sound(on: Bool)
    case pause
    case swap
    case flame
    case shield
}

struct IconView: View {
    let kind: IconKind
    var size: CGFloat = 24

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, s in
            let c = CGPoint(x: s.width / 2, y: s.height / 2)
            let d = min(s.width, s.height) * 0.92
            switch kind {
            case .trophy: Art.trophy(&ctx, center: c, size: d)
            case .coin: Art.coin(&ctx, center: c, size: d)
            case .elixir: Art.elixirDrop(&ctx, center: c, size: d)
            case .crown(let color, let dim): Art.crown(&ctx, center: c, size: d, color: color, dim: dim)
            case .swords:
                Art.sword(&ctx, from: CGPoint(x: c.x - d * 0.4, y: c.y + d * 0.4), to: CGPoint(x: c.x + d * 0.4, y: c.y - d * 0.4), width: d * 0.11)
                Art.sword(&ctx, from: CGPoint(x: c.x + d * 0.4, y: c.y + d * 0.4), to: CGPoint(x: c.x - d * 0.4, y: c.y - d * 0.4), width: d * 0.11)
            case .cards:
                for (i, a) in [-14.0, 0.0, 14.0].enumerated() {
                    var g = ctx
                    g.translateBy(x: c.x + CGFloat(i - 1) * d * 0.14, y: c.y + d * 0.1)
                    g.rotate(by: .degrees(a))
                    let r = CGRect(x: -d * 0.22, y: -d * 0.32, width: d * 0.44, height: d * 0.64)
                    Art.shape(&g, Art.rounded(r, d * 0.06), fill: Art.vertical(i == 1 ? Theme.player : Theme.elixir, i == 1 ? Art.teamDark(.player) : Color(red: 0.4, green: 0.1, blue: 0.55), r), line: max(1, d * 0.05))
                }
            case .clock:
                Art.ball(&ctx, cx: c.x, cy: c.y, r: d * 0.45, color: Color.white, dark: Color(white: 0.75), line: max(1, d * 0.07))
                var hands = Path()
                hands.move(to: c); hands.addLine(to: CGPoint(x: c.x, y: c.y - d * 0.3))
                hands.move(to: c); hands.addLine(to: CGPoint(x: c.x + d * 0.22, y: c.y))
                ctx.stroke(hands, with: .color(Art.outline), style: StrokeStyle(lineWidth: max(1, d * 0.07), lineCap: .round))
            case .help:
                Art.ball(&ctx, cx: c.x, cy: c.y, r: d * 0.45, color: Theme.player, dark: Art.teamDark(.player), line: max(1, d * 0.07))
                var q = Path()
                q.addArc(center: CGPoint(x: c.x, y: c.y - d * 0.12), radius: d * 0.15, startAngle: .degrees(200), endAngle: .degrees(60), clockwise: false)
                q.addLine(to: CGPoint(x: c.x, y: c.y + d * 0.1))
                ctx.stroke(q, with: .color(.white), style: StrokeStyle(lineWidth: max(1.5, d * 0.1), lineCap: .round))
                ctx.fill(Art.circle(c.x, c.y + d * 0.28, d * 0.065), with: .color(.white))
            case .sound(let on):
                var horn = Path()
                horn.move(to: CGPoint(x: c.x - d * 0.42, y: c.y - d * 0.14))
                horn.addLine(to: CGPoint(x: c.x - d * 0.22, y: c.y - d * 0.14))
                horn.addLine(to: CGPoint(x: c.x + d * 0.02, y: c.y - d * 0.36))
                horn.addLine(to: CGPoint(x: c.x + d * 0.02, y: c.y + d * 0.36))
                horn.addLine(to: CGPoint(x: c.x - d * 0.22, y: c.y + d * 0.14))
                horn.addLine(to: CGPoint(x: c.x - d * 0.42, y: c.y + d * 0.14))
                horn.closeSubpath()
                ctx.fill(horn, with: .color(.white))
                ctx.stroke(horn, with: .color(Art.outline), style: StrokeStyle(lineWidth: max(1, d * 0.06), lineJoin: .round))
                if on {
                    for (r, a) in [(0.2, 0.9), (0.34, 0.6)] {
                        var wave = Path()
                        wave.addArc(center: CGPoint(x: c.x + d * 0.06, y: c.y), radius: d * r, startAngle: .degrees(-40), endAngle: .degrees(40), clockwise: false)
                        ctx.stroke(wave, with: .color(.white.opacity(a)), style: StrokeStyle(lineWidth: max(1.5, d * 0.08), lineCap: .round))
                    }
                } else {
                    var x = Path()
                    x.move(to: CGPoint(x: c.x + d * 0.14, y: c.y - d * 0.16)); x.addLine(to: CGPoint(x: c.x + d * 0.42, y: c.y + d * 0.16))
                    x.move(to: CGPoint(x: c.x + d * 0.42, y: c.y - d * 0.16)); x.addLine(to: CGPoint(x: c.x + d * 0.14, y: c.y + d * 0.16))
                    ctx.stroke(x, with: .color(Theme.enemy), style: StrokeStyle(lineWidth: max(1.5, d * 0.1), lineCap: .round))
                }
            case .pause:
                for dx in [-0.18, 0.18] {
                    let r = CGRect(x: c.x + d * dx - d * 0.1, y: c.y - d * 0.32, width: d * 0.2, height: d * 0.64)
                    ctx.fill(Art.rounded(r, d * 0.06), with: .color(.white))
                    ctx.stroke(Art.rounded(r, d * 0.06), with: .color(Art.outline), lineWidth: max(1, d * 0.06))
                }
            case .swap:
                for (dir, dy) in [(1.0, -0.18), (-1.0, 0.18)] {
                    var p = Path()
                    p.move(to: CGPoint(x: c.x - dir * d * 0.36, y: c.y + d * dy))
                    p.addLine(to: CGPoint(x: c.x + dir * d * 0.3, y: c.y + d * dy))
                    p.move(to: CGPoint(x: c.x + dir * d * 0.14, y: c.y + d * dy - d * 0.14))
                    p.addLine(to: CGPoint(x: c.x + dir * d * 0.32, y: c.y + d * dy))
                    p.addLine(to: CGPoint(x: c.x + dir * d * 0.14, y: c.y + d * dy + d * 0.14))
                    ctx.stroke(p, with: .color(Art.outline), style: StrokeStyle(lineWidth: max(2, d * 0.2), lineCap: .round, lineJoin: .round))
                    ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: max(1, d * 0.1), lineCap: .round, lineJoin: .round))
                }
            case .flame:
                var f = Path()
                f.move(to: CGPoint(x: c.x, y: c.y - d * 0.46))
                f.addQuadCurve(to: CGPoint(x: c.x + d * 0.36, y: c.y + d * 0.12), control: CGPoint(x: c.x + d * 0.42, y: c.y - d * 0.3))
                f.addQuadCurve(to: CGPoint(x: c.x, y: c.y + d * 0.46), control: CGPoint(x: c.x + d * 0.36, y: c.y + d * 0.5))
                f.addQuadCurve(to: CGPoint(x: c.x - d * 0.36, y: c.y + d * 0.12), control: CGPoint(x: c.x - d * 0.36, y: c.y + d * 0.5))
                f.addQuadCurve(to: CGPoint(x: c.x - d * 0.06, y: c.y - d * 0.1), control: CGPoint(x: c.x - d * 0.42, y: c.y - d * 0.2))
                f.addQuadCurve(to: CGPoint(x: c.x, y: c.y - d * 0.46), control: CGPoint(x: c.x + d * 0.1, y: c.y - d * 0.25))
                ctx.fill(f, with: .linearGradient(Gradient(colors: [Art.gold, Color(red: 1.0, green: 0.4, blue: 0.1), Theme.enemy]), startPoint: CGPoint(x: c.x, y: c.y - d * 0.4), endPoint: CGPoint(x: c.x, y: c.y + d * 0.4)))
                ctx.stroke(f, with: .color(Art.outline), lineWidth: max(1, d * 0.06))
                ctx.fill(Art.ellipse(c.x, c.y + d * 0.2, d * 0.13, d * 0.2), with: .color(Color(red: 1.0, green: 0.95, blue: 0.6)))
            case .shield:
                var s = Path()
                s.move(to: CGPoint(x: c.x, y: c.y - d * 0.46))
                s.addLine(to: CGPoint(x: c.x + d * 0.4, y: c.y - d * 0.3))
                s.addQuadCurve(to: CGPoint(x: c.x, y: c.y + d * 0.46), control: CGPoint(x: c.x + d * 0.42, y: c.y + d * 0.25))
                s.addQuadCurve(to: CGPoint(x: c.x - d * 0.4, y: c.y - d * 0.3), control: CGPoint(x: c.x - d * 0.42, y: c.y + d * 0.25))
                s.closeSubpath()
                ctx.fill(s, with: .linearGradient(Gradient(colors: [Theme.player, Art.teamDark(.player)]), startPoint: CGPoint(x: c.x, y: c.y - d * 0.4), endPoint: CGPoint(x: c.x, y: c.y + d * 0.4)))
                ctx.stroke(s, with: .color(Art.outline), lineWidth: max(1, d * 0.07))
                ctx.fill(Art.rounded(CGRect(x: c.x - d * 0.05, y: c.y - d * 0.26, width: d * 0.1, height: d * 0.42), d * 0.03), with: .color(Art.gold))
                ctx.fill(Art.rounded(CGRect(x: c.x - d * 0.2, y: c.y - d * 0.14, width: d * 0.4, height: d * 0.1), d * 0.03), with: .color(Art.gold))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Text

/// Heavy display text with a dark outline and drop shadow, like a game logo.
struct DisplayText: View {
    let text: String
    var size: CGFloat = 40
    var fill: LinearGradient = LinearGradient(colors: [Color.white, Color(white: 0.85)], startPoint: .top, endPoint: .bottom)
    var outline: Color = Art.outline
    var outlineWidth: CGFloat? = nil

    var body: some View {
        let w = outlineWidth ?? max(1.5, size * 0.07)
        let font = Font.system(size: size, weight: .black, design: .rounded)
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * .pi * 2
                Text(text).font(font).foregroundStyle(outline)
                    .offset(x: CGFloat(cos(a)) * w, y: CGFloat(sin(a)) * w)
            }
            Text(text).font(font).foregroundStyle(outline).offset(y: w * 1.8)
            Text(text).font(font).foregroundStyle(fill)
        }
        .shadow(color: .black.opacity(0.45), radius: size * 0.08, y: size * 0.1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

extension LinearGradient {
    static let goldText = LinearGradient(colors: [Color(red: 1.0, green: 0.95, blue: 0.6), Art.gold, Color(red: 0.95, green: 0.55, blue: 0.1)], startPoint: .top, endPoint: .bottom)
    static let whiteText = LinearGradient(colors: [Color.white, Color(red: 0.8, green: 0.86, blue: 0.95)], startPoint: .top, endPoint: .bottom)
    static let redText = LinearGradient(colors: [Color(red: 1.0, green: 0.6, blue: 0.55), Theme.enemy, Color(red: 0.6, green: 0.1, blue: 0.12)], startPoint: .top, endPoint: .bottom)
}

// MARK: - Buttons

enum ChunkyStyle {
    case gold, blue, green, red, slate

    var top: Color {
        switch self {
        case .gold: return Color(red: 1.0, green: 0.85, blue: 0.35)
        case .blue: return Color(red: 0.42, green: 0.68, blue: 1.0)
        case .green: return Color(red: 0.55, green: 0.88, blue: 0.4)
        case .red: return Color(red: 1.0, green: 0.5, blue: 0.45)
        case .slate: return Color(red: 0.38, green: 0.45, blue: 0.62)
        }
    }
    var bottom: Color {
        switch self {
        case .gold: return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .blue: return Color(red: 0.16, green: 0.38, blue: 0.85)
        case .green: return Color(red: 0.2, green: 0.6, blue: 0.2)
        case .red: return Color(red: 0.75, green: 0.15, blue: 0.15)
        case .slate: return Color(red: 0.2, green: 0.25, blue: 0.4)
        }
    }
    var edge: Color {
        switch self {
        case .gold: return Color(red: 0.55, green: 0.3, blue: 0.02)
        case .blue: return Color(red: 0.08, green: 0.2, blue: 0.5)
        case .green: return Color(red: 0.1, green: 0.35, blue: 0.1)
        case .red: return Color(red: 0.45, green: 0.06, blue: 0.08)
        case .slate: return Color(red: 0.1, green: 0.12, blue: 0.22)
        }
    }
    var text: Color {
        switch self {
        case .gold: return Color(red: 0.3, green: 0.15, blue: 0.0)
        default: return .white
        }
    }
}

struct ChunkyButton: View {
    let title: String
    var icon: IconKind? = nil
    var style: ChunkyStyle = .gold
    var height: CGFloat = 60
    var fontSize: CGFloat = 24
    let action: () -> Void

    var body: some View {
        Button(action: { ArcadeAudio.play(.tap); action() }) {
            HStack(spacing: 10) {
                if let icon { IconView(kind: icon, size: fontSize * 1.25) }
                Text(title)
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .foregroundStyle(style.text)
                    .shadow(color: style == .gold ? .white.opacity(0.35) : .black.opacity(0.5), radius: 0, y: style == .gold ? 1 : -1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
        }
        .buttonStyle(ChunkyButtonStyle(style: style))
    }
}

/// Small round utility button (help, sound, pause) that shares the chunky bevel language.
struct IconButton: View {
    let icon: IconKind
    let label: String
    var style: ChunkyStyle = .slate
    var size: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button(action: { ArcadeAudio.play(.tap); action() }) {
            IconView(kind: icon, size: size * 0.55)
                .frame(width: size, height: size)
        }
        .buttonStyle(ChunkyButtonStyle(style: style, cornerRadius: size / 2))
        .frame(width: size, height: size)
        .accessibilityLabel(label)
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    let style: ChunkyStyle
    var cornerRadius: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .background {
                ZStack {
                    shape.fill(style.edge).offset(y: pressed ? 2 : 6)
                    shape.fill(LinearGradient(colors: [style.top, style.bottom], startPoint: .top, endPoint: .bottom))
                    shape.inset(by: 3).stroke(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.0)], startPoint: .top, endPoint: .center), lineWidth: 2)
                    RoundedRectangle(cornerRadius: cornerRadius * 0.75, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .padding(.horizontal, 8)
                        .padding(.top, 5)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .frame(height: 22)
                        .frame(maxHeight: .infinity, alignment: .top)
                    shape.stroke(Art.outline.opacity(0.9), lineWidth: 2.5)
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.35), radius: 6, y: 5)
            }
            .offset(y: pressed ? 4 : 0)
            .scaleEffect(pressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

// MARK: - Panels

struct PanelBackground: View {
    var cornerRadius: CGFloat = 18
    var tint: Color = Theme.panel

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [tint.opacity(0.95), Theme.background.opacity(0.98)], startPoint: .top, endPoint: .bottom))
            shape.inset(by: 2).stroke(LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
            shape.stroke(Art.outline.opacity(0.9), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
    }
}

extension View {
    func panel(cornerRadius: CGFloat = 18, tint: Color = Theme.panel) -> some View {
        background(PanelBackground(cornerRadius: cornerRadius, tint: tint))
    }
}

// MARK: - Cards

struct ElixirBadge: View {
    let cost: Int
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            IconView(kind: .elixir, size: size * 1.15)
            Text("\(cost)")
                .font(.system(size: size * 0.6, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.8), radius: 0, x: 1, y: 1)
                .offset(y: size * 0.08)
        }
        .frame(width: size * 1.15, height: size * 1.15)
        .accessibilityLabel("\(cost) elixir")
    }
}

/// Framed card: illustration, gold bevel, cost badge and name plaque.
struct CardFrame: View {
    let card: CardDef
    var selected = false
    var affordable = true
    var showName = true
    var compact = false

    private var frameColors: [Color] {
        card.kind == .spell
            ? [Color(red: 0.85, green: 0.65, blue: 1.0), Color(red: 0.5, green: 0.25, blue: 0.75)]
            : (card.count > 1 || card.cost <= 3
               ? [Color(red: 0.86, green: 0.88, blue: 0.95), Color(red: 0.45, green: 0.5, blue: 0.62)]
               : [Color(red: 1.0, green: 0.9, blue: 0.5), Color(red: 0.75, green: 0.5, blue: 0.1)])
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let radius = w * 0.14
            let border = max(2, w * 0.05)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: frameColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Art.outline, lineWidth: max(1.5, w * 0.03))
                VStack(spacing: 0) {
                    GeometryReader { area in
                        RenderedArt.image("card_\(card.id)").resizable().interpolation(.high).scaledToFill()
                            .frame(width: area.size.width, height: area.size.height)
                            .clipped()
                    }
                        .clipShape(RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous).stroke(Art.outline.opacity(0.8), lineWidth: 1))
                    if showName {
                        Text(card.name.uppercased())
                            .font(.system(size: max(7, w * 0.13), weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.9), radius: 0, x: 1, y: 1)
                            .padding(.horizontal, 3)
                            .frame(maxWidth: .infinity)
                            .frame(height: max(12, w * 0.24))
                            .background(RoundedRectangle(cornerRadius: radius * 0.4).fill(Art.outline.opacity(0.75)))
                            .padding(.top, border * 0.6)
                    }
                }
                .padding(border)
                ElixirBadge(cost: card.cost, size: compact ? w * 0.34 : w * 0.3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: -w * 0.08, y: -w * 0.08)
            }
            .compositingGroup()
            .shadow(color: selected ? Theme.accent.opacity(0.9) : .black.opacity(0.4), radius: selected ? 10 : 3, y: selected ? 0 : 3)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Theme.accent, lineWidth: 3)
                }
            }
            .saturation(affordable ? 1 : 0.15)
            .brightness(affordable ? 0 : -0.25)
        }
        .aspectRatio(0.78, contentMode: .fit)
    }
}

// MARK: - Scenery

/// Painted backdrop for the menu screens: sky, hills, and a castle skyline.
struct LegacySceneryBackdrop: View {
    var dim: Double = 0

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let w = size.width, h = size.height
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.09, green: 0.15, blue: 0.36), Color(red: 0.2, green: 0.4, blue: 0.75), Color(red: 0.55, green: 0.72, blue: 0.9)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.7)))
            // sun glow
            var glow = ctx
            glow.blendMode = .plusLighter
            glow.fill(Art.circle(w * 0.72, h * 0.32, w * 0.55), with: .radialGradient(Gradient(colors: [Art.gold.opacity(0.35), Art.gold.opacity(0)]), center: CGPoint(x: w * 0.72, y: h * 0.32), startRadius: 0, endRadius: w * 0.55))
            // stars
            for i in 0..<40 {
                let x = CGFloat((Double(i) * 0.618).truncatingRemainder(dividingBy: 1)) * w
                let y = CGFloat((Double(i) * 0.2713 + 0.1).truncatingRemainder(dividingBy: 1)) * h * 0.35
                ctx.fill(Art.circle(x, y, CGFloat(0.8 + Double(i % 3) * 0.5)), with: .color(.white.opacity(0.5 + Double(i % 4) * 0.12)))
            }
            // clouds
            for (cx, cy, s) in [(0.2, 0.22, 1.0), (0.75, 0.15, 0.7), (0.5, 0.32, 0.55)] {
                let c = CGPoint(x: w * CGFloat(cx), y: h * CGFloat(cy))
                let r = w * 0.09 * CGFloat(s)
                for (dx, dy, rr) in [(-1.1, 0.2, 0.7), (0.0, 0.0, 1.0), (1.1, 0.25, 0.75), (0.5, -0.4, 0.6)] {
                    ctx.fill(Art.circle(c.x + r * CGFloat(dx), c.y + r * CGFloat(dy), r * CGFloat(rr)), with: .color(.white.opacity(0.18)))
                }
            }
            // distant hills
            func hills(_ baseY: CGFloat, amp: CGFloat, color: Color, seed: CGFloat) {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: 0, y: baseY))
                var x: CGFloat = 0
                while x <= w {
                    let y = baseY - amp * (0.5 + 0.5 * sin(x / w * 5 + seed)) - amp * 0.3 * sin(x / w * 13 + seed * 2)
                    p.addLine(to: CGPoint(x: x, y: y))
                    x += 8
                }
                p.addLine(to: CGPoint(x: w, y: h))
                p.closeSubpath()
                ctx.fill(p, with: .color(color))
            }
            hills(h * 0.62, amp: h * 0.08, color: Color(red: 0.18, green: 0.32, blue: 0.5), seed: 1)
            hills(h * 0.68, amp: h * 0.07, color: Color(red: 0.16, green: 0.36, blue: 0.36), seed: 3)
            // castle skyline silhouette
            var castle = ctx
            castle.opacity = 0.9
            let baseY = h * 0.7
            let silhouette = Color(red: 0.1, green: 0.16, blue: 0.3)
            for (cx, cw, ch) in [(0.12, 0.09, 0.12), (0.3, 0.06, 0.08), (0.5, 0.12, 0.16), (0.7, 0.06, 0.09), (0.88, 0.09, 0.12)] {
                let r = CGRect(x: w * CGFloat(cx) - w * CGFloat(cw) / 2, y: baseY - h * CGFloat(ch), width: w * CGFloat(cw), height: h * CGFloat(ch) + 4)
                castle.fill(Path(r), with: .color(silhouette))
                let n = 3
                for i in 0..<n {
                    let bx = r.minX + r.width * (CGFloat(i) + 0.5) / CGFloat(n)
                    castle.fill(Path(CGRect(x: bx - r.width * 0.12, y: r.minY - h * 0.015, width: r.width * 0.24, height: h * 0.02)), with: .color(silhouette))
                }
                castle.fill(Path(CGRect(x: r.midX - 1, y: r.minY - h * 0.05, width: 2, height: h * 0.05)), with: .color(silhouette))
                castle.fill(Art.polygon([CGPoint(x: r.midX, y: r.minY - h * 0.05), CGPoint(x: r.midX + w * 0.03, y: r.minY - h * 0.04), CGPoint(x: r.midX, y: r.minY - h * 0.03)]), with: .color(cx == 0.5 ? Art.gold : Theme.enemy))
                // window lights
                castle.fill(Art.rounded(CGRect(x: r.midX - r.width * 0.1, y: r.minY + r.height * 0.3, width: r.width * 0.2, height: r.height * 0.18), r.width * 0.1), with: .color(Art.gold.opacity(0.85)))
            }
            castle.fill(Path(CGRect(x: 0, y: baseY - 2, width: w, height: h)), with: .color(silhouette))
            // foreground meadow
            ctx.fill(Path(CGRect(x: 0, y: baseY, width: w, height: h - baseY)), with: .linearGradient(Gradient(colors: [Color(red: 0.2, green: 0.42, blue: 0.24), Color(red: 0.08, green: 0.2, blue: 0.14)]), startPoint: CGPoint(x: 0, y: baseY), endPoint: CGPoint(x: 0, y: h)))
            for i in 0..<60 {
                let x = CGFloat((Double(i) * 0.731).truncatingRemainder(dividingBy: 1)) * w
                let y = baseY + CGFloat((Double(i) * 0.457).truncatingRemainder(dividingBy: 1)) * (h - baseY)
                var tuft = Path()
                let s = 3 + (y - baseY) / (h - baseY) * 5
                tuft.move(to: CGPoint(x: x - s, y: y)); tuft.addLine(to: CGPoint(x: x - s * 0.4, y: y - s * 1.5))
                tuft.move(to: CGPoint(x: x, y: y)); tuft.addLine(to: CGPoint(x: x, y: y - s * 2))
                tuft.move(to: CGPoint(x: x + s, y: y)); tuft.addLine(to: CGPoint(x: x + s * 0.4, y: y - s * 1.5))
                ctx.stroke(tuft, with: .color(Color(red: 0.3, green: 0.6, blue: 0.3).opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
            if dim > 0 {
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.black.opacity(dim)))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct StatPill: View {
    let icon: IconKind
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            IconView(kind: icon, size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.6), radius: 0, y: 1)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .panel(cornerRadius: 22, tint: Color(red: 0.16, green: 0.2, blue: 0.36))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct CrownRow: View {
    let count: Int
    let color: Color
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                IconView(kind: .crown(color, dim: i >= count), size: size)
                    .scaleEffect(i < count ? 1.15 : 1)
                    .animation(.spring(duration: 0.3), value: count)
            }
        }
        .accessibilityLabel("\(count) crowns")
    }
}

struct ElixirBar: View {
    let value: Double
    let max: Double

    var body: some View {
        HStack(spacing: 6) {
            IconView(kind: .elixir, size: 26)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(red: 0.08, green: 0.05, blue: 0.14))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(red: 0.95, green: 0.6, blue: 1.0), Theme.elixir, Color(red: 0.5, green: 0.12, blue: 0.7)], startPoint: .top, endPoint: .bottom))
                        .frame(width: Swift.max(geo.size.height, geo.size.width * CGFloat(value / max)))
                        .overlay(alignment: .top) {
                            Capsule().fill(.white.opacity(0.35)).frame(height: geo.size.height * 0.3).padding(.horizontal, 6).padding(.top, 3)
                                .frame(width: Swift.max(geo.size.height, geo.size.width * CGFloat(value / max)))
                        }
                        .animation(.linear(duration: 0.1), value: value)
                    HStack(spacing: 0) {
                        ForEach(1..<Int(max), id: \.self) { _ in
                            Spacer()
                            Rectangle().fill(Art.outline.opacity(0.7)).frame(width: 1.5)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    Capsule().stroke(Art.outline, lineWidth: 2)
                    Text("\(Int(value))")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black, radius: 0, x: 1, y: 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 22)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Elixir \(Int(value)) of \(Int(max))")
        .accessibilityValue("\(Int(value))")
    }
}

// MARK: - Progression

/// Small uppercase caption used to title sections and groups of controls.
struct SectionLabel: View {
    let text: String
    var color: Color = .white.opacity(0.7)

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(2)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.7), radius: 0, y: 1)
    }
}

struct ProgressTrack: View {
    let progress: Double
    var color: Color = Theme.accent
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.45))
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.65)], startPoint: .top, endPoint: .bottom))
                    .frame(width: max(height, geo.size.width * CGFloat(min(1, max(0, progress)))))
                    .overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.35)).frame(height: height * 0.3).padding(.horizontal, 4).padding(.top, 2)
                    }
                    .animation(.easeOut(duration: 0.6), value: progress)
                Capsule().stroke(Art.outline, lineWidth: 1.5)
            }
        }
        .frame(height: height)
    }
}

/// League name, trophy count and progress to the next tier.
struct LeagueBadge: View {
    let trophies: Int
    var compact = false

    var body: some View {
        let league = League.forTrophies(trophies)
        HStack(spacing: 10) {
            IconView(kind: .trophy, size: compact ? 28 : 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(trophies)")
                        .font(.system(size: compact ? 17 : 20, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(league.name.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(league.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                ProgressTrack(progress: league.progress(trophies: trophies), color: league.color, height: 7)
                if let next = league.next, !compact {
                    Text("\(next.minTrophies - trophies) to \(next.name)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .panel(cornerRadius: 22, tint: Color(red: 0.16, green: 0.2, blue: 0.36))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(trophies) trophies, \(league.name)")
        .accessibilityIdentifier("leagueBadge")
    }
}

/// Miniature battle deck: eight portraits plus the average elixir, tappable to edit.
struct DeckStrip: View {
    let deck: [String]
    let averageElixir: Double
    let action: () -> Void

    var body: some View {
        Button(action: { ArcadeAudio.play(.tap); action() }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SectionLabel(text: "Battle deck")
                    Spacer()
                    HStack(spacing: 4) {
                        IconView(kind: .elixir, size: 14)
                        Text(String(format: "%.1f avg", averageElixir))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text("EDIT ›")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .padding(.leading, 6)
                }
                HStack(spacing: 5) {
                    ForEach(deck, id: \.self) { id in
                        CardFrame(card: Cards.byId(id), showName: false, compact: true)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .panel(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battle deck, average elixir \(String(format: "%.1f", averageElixir)). Edit deck")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("deckStrip")
    }
}

/// Persistent instruction strip that tells the player what to do next.
struct HintBanner: View {
    enum Tone { case neutral, active, warning }
    let step: String?
    let text: String
    var tone: Tone = .neutral
    var onCancel: (() -> Void)? = nil

    private var color: Color {
        switch tone {
        case .neutral: return .white.opacity(0.6)
        case .active: return Theme.accent
        case .warning: return Theme.enemy
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            if let step {
                Text(step)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Art.outline)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(color))
            }
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onCancel {
                Button(action: { ArcadeAudio.play(.tap); onCancel() }) {
                    Text("CANCEL")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.15)))
                        .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                }
                .accessibilityIdentifier("cancelSwapButton")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .panel(cornerRadius: 16, tint: tone == .neutral ? Theme.panel : color.opacity(0.35))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(tone == .neutral ? 0 : 0.8), lineWidth: 2))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(text)
        .accessibilityIdentifier("hintBanner")
    }
}

/// Three-step explainer shown on first launch and from the help button.
struct HowToPlaySheet: View {
    let onDone: () -> Void

    private struct Step: Identifiable {
        let id: Int
        let icon: IconKind
        let title: String
        let body: String
    }

    private let steps = [
        Step(id: 1, icon: .cards, title: "Pick a card", body: "Tap a card in your hand. Each card costs elixir, which refills over time."),
        Step(id: 2, icon: .shield, title: "Drop it on your side", body: "Tap or drag on your half of the arena to deploy. Spells can land anywhere, even on enemy towers."),
        Step(id: 3, icon: .crown(Art.gold, dim: false), title: "Take the towers", body: "Destroy guard towers for crowns. Break the keep for an instant 3-crown win. Three minutes, then sudden-death overtime."),
    ]

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(.white.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 8)
            DisplayText(text: "HOW TO PLAY", size: 30, fill: .goldText)
            VStack(spacing: 12) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle().fill(Theme.panel).frame(width: 52, height: 52)
                                .overlay(Circle().stroke(Art.outline, lineWidth: 2))
                            IconView(kind: step.icon, size: 30)
                            Text("\(step.id)")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(Art.outline)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Theme.accent))
                                .offset(x: 20, y: -20)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title.uppercased())
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text(step.body)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .panel(cornerRadius: 16)
                }
            }
            HStack(spacing: 8) {
                IconView(kind: .elixir, size: 18)
                Text("Elixir doubles in the last minute. Surrender any time from the pause menu.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            ChunkyButton(title: "LET'S TUSSLE", icon: .swords, style: .gold, height: 56, fontSize: 22, action: onDone)
                .accessibilityIdentifier("tutorialDoneButton")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background.ignoresSafeArea())
        .accessibilityIdentifier("howToPlay")
    }
}

/// Battle phase chip: shows OVERTIME / 2x ELIXIR with the remaining time context.
struct PhaseChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .tracking(1)
            .foregroundStyle(Art.outline)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
            .overlay(Capsule().stroke(Art.outline, lineWidth: 1.5))
            .transition(.scale.combined(with: .opacity))
    }
}
