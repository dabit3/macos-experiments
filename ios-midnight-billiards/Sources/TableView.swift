import SwiftUI

enum Club {
    static let ink = Color(red: 0.035, green: 0.075, blue: 0.10)
    static let panel = Color(red: 0.065, green: 0.12, blue: 0.145)
    static let gold = Color(red: 0.84, green: 0.70, blue: 0.45)
    static let ivory = Color(red: 0.96, green: 0.94, blue: 0.86)
    static let muted = Color(red: 0.56, green: 0.67, blue: 0.69)
    static let teal = Color(red: 0.31, green: 0.78, blue: 0.74)
    static func ballColor(_ id: Int) -> Color {
        switch id > 8 ? id - 8 : id {
        case 1: return Color(red: 0.98, green: 0.73, blue: 0.18)
        case 2: return Color(red: 0.14, green: 0.43, blue: 0.82)
        case 3: return Color(red: 0.82, green: 0.19, blue: 0.21)
        case 4: return Color(red: 0.52, green: 0.28, blue: 0.72)
        case 5: return Color(red: 1.0, green: 0.42, blue: 0.14)
        case 6: return Color(red: 0.10, green: 0.55, blue: 0.42)
        case 7: return Color(red: 0.49, green: 0.16, blue: 0.23)
        case 8: return Color(red: 0.07, green: 0.09, blue: 0.13)
        default: return Club.ivory
        }
    }
}

struct TableView: View {
    let table: Table
    var angle = 0.0
    var power = 0.5
    var aiming = false
    var ballInHand = false
    var kitchen = false
    var calledPocket: Int?
    var requireCall = false
    var onTouch: ((Vector, Vector) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 660, geometry.size.height / 360)
            let offset = CGPoint(
                x: (geometry.size.width - 660 * scale) / 2,
                y: (geometry.size.height - 360 * scale) / 2)
            Canvas { context, _ in
                context.translateBy(x: offset.x, y: offset.y)
                context.scaleBy(x: scale, y: scale)
                drawTable(&context)
                context.translateBy(x: 30, y: 30)
                if kitchen && ballInHand {
                    context.fill(
                        Path(CGRect(x: 10, y: 10, width: 140, height: 280)),
                        with: .color(Theme.accent.opacity(0.08)))
                }
                if aiming && !table.cue.pocketed { drawAim(&context) }
                for ball in table.balls where !ball.pocketed {
                    drawBall(&context, ball: ball)
                }
                if ballInHand {
                    let center = point(table.cue.position)
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - 20, y: center.y - 20, width: 40, height: 40)),
                        with: .color(Theme.accent.opacity(0.14)))
                    context.stroke(
                        Path(ellipseIn: CGRect(x: center.x - 20, y: center.y - 20, width: 40, height: 40)),
                        with: .color(Theme.accent), lineWidth: 1.4)
                    for (dx, dy) in [(0.0, -1.0), (1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)] {
                        var chevron = Path()
                        let tip = CGPoint(x: center.x + dx * 28, y: center.y + dy * 28)
                        chevron.move(to: CGPoint(x: tip.x - dy * 3 - dx * 3, y: tip.y - dx * 3 - dy * 3))
                        chevron.addLine(to: tip)
                        chevron.addLine(to: CGPoint(x: tip.x + dy * 3 - dx * 3, y: tip.y + dx * 3 - dy * 3))
                        context.stroke(
                            chevron, with: .color(Theme.accent),
                            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        func local(_ point: CGPoint) -> Vector {
                            Vector(x: (point.x - offset.x) / scale - 30, y: (point.y - offset.y) / scale - 30)
                        }
                        onTouch?(local(value.location), local(value.startLocation))
                    }
            )
            .accessibilityLabel("Billiards table")
            .accessibilityValue(
                "\(table.balls.filter { !$0.pocketed && $0.id != 0 }.count) object balls. \(ballInHand ? "Ball in hand. Drag the cue ball to place it." : "Drag to aim.")"
            )
            .accessibilityIdentifier("billiardsTable")
        }
        .aspectRatio(660 / 360, contentMode: .fit)
    }

    private func point(_ vector: Vector) -> CGPoint { CGPoint(x: vector.x, y: vector.y) }

    private func drawTable(_ context: inout GraphicsContext) {
        let outer = Path(roundedRect: CGRect(x: 1, y: 1, width: 658, height: 358), cornerRadius: 30)
        var railContext = context
        railContext.addFilter(.shadow(color: .black.opacity(0.6), radius: 14, x: 0, y: 10))
        railContext.fill(
            outer,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.40, green: 0.25, blue: 0.16), location: 0),
                    .init(color: Color(red: 0.28, green: 0.165, blue: 0.11), location: 0.45),
                    .init(color: Color(red: 0.14, green: 0.085, blue: 0.065), location: 1),
                ]),
                startPoint: .zero, endPoint: CGPoint(x: 160, y: 360)))
        // Walnut grain: long low-contrast strokes following the rails.
        var longRails = context
        longRails.clip(to: outer)
        var longMask = Path()
        longMask.addRect(CGRect(x: 0, y: 0, width: 660, height: 24))
        longMask.addRect(CGRect(x: 0, y: 336, width: 660, height: 24))
        longRails.clip(to: longMask)
        for index in 0..<8 {
            for base in [0.0, 336.0] {
                let y = base + Double(index) * 3.1 + Double((index * 37) % 3) * 0.4
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addCurve(
                    to: CGPoint(x: 660, y: y + 1.5), control1: CGPoint(x: 220, y: y - 1.5),
                    control2: CGPoint(x: 440, y: y + 2.5))
                longRails.stroke(
                    line, with: .color(.black.opacity(index % 3 == 0 ? 0.16 : 0.07)), lineWidth: 0.6)
            }
        }
        var shortRails = context
        shortRails.clip(to: outer)
        var shortMask = Path()
        shortMask.addRect(CGRect(x: 0, y: 24, width: 24, height: 312))
        shortMask.addRect(CGRect(x: 636, y: 24, width: 24, height: 312))
        shortRails.clip(to: shortMask)
        for index in 0..<8 {
            for base in [0.0, 636.0] {
                let x = base + Double(index) * 3.1 + Double((index * 37) % 3) * 0.4
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addCurve(
                    to: CGPoint(x: x + 1.5, y: 360), control1: CGPoint(x: x - 1.5, y: 120),
                    control2: CGPoint(x: x + 2.5, y: 240))
                shortRails.stroke(
                    line, with: .color(.black.opacity(index % 3 == 0 ? 0.16 : 0.07)), lineWidth: 0.6)
            }
        }
        // Mitred corner joints where the rails meet.
        for (x, y, dx, dy) in [
            (0.0, 0.0, 1.0, 1.0), (660.0, 0.0, -1.0, 1.0), (0.0, 360.0, 1.0, -1.0),
            (660.0, 360.0, -1.0, -1.0),
        ] {
            var joint = Path()
            joint.move(to: CGPoint(x: x + dx * 6, y: y + dy * 6))
            joint.addLine(to: CGPoint(x: x + dx * 22, y: y + dy * 22))
            context.stroke(joint, with: .color(.black.opacity(0.35)), lineWidth: 0.8)
        }
        // Edge highlights where wood meets the cushion.
        context.stroke(outer, with: .color(.white.opacity(0.12)), lineWidth: 1)
        context.stroke(
            Path(roundedRect: CGRect(x: 4, y: 4, width: 652, height: 352), cornerRadius: 27),
            with: .color(Color.black.opacity(0.4)), lineWidth: 0.8)
        let cushionOuter = Path(roundedRect: CGRect(x: 21, y: 21, width: 618, height: 318), cornerRadius: 11)
        context.stroke(cushionOuter, with: .color(.black.opacity(0.45)), lineWidth: 1.2)
        context.stroke(
            Path(roundedRect: CGRect(x: 19.5, y: 19.5, width: 621, height: 321), cornerRadius: 12),
            with: .color(.black.opacity(0.35)), lineWidth: 1)
        // Cushions: a raised felt lip with a lit top edge and a shadowed nose.
        context.fill(cushionOuter, with: .color(Color(red: 0.07, green: 0.30, blue: 0.34)))
        context.fill(
            Path(roundedRect: CGRect(x: 23, y: 23, width: 614, height: 314), cornerRadius: 9),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.10, green: 0.38, blue: 0.42), Color(red: 0.05, green: 0.24, blue: 0.28),
                ]), startPoint: CGPoint(x: 0, y: 23), endPoint: CGPoint(x: 0, y: 337)))
        // Bevel: lit crown along the cushion top, shadow under the nose.
        context.stroke(
            Path(roundedRect: CGRect(x: 24.5, y: 24.5, width: 611, height: 311), cornerRadius: 8),
            with: .color(.white.opacity(0.10)), lineWidth: 1.2)
        context.stroke(
            Path(roundedRect: CGRect(x: 27.5, y: 27.5, width: 605, height: 305), cornerRadius: 4),
            with: .color(.black.opacity(0.22)), lineWidth: 1.5)
        context.stroke(
            Path(roundedRect: CGRect(x: 29.5, y: 29.5, width: 601, height: 301), cornerRadius: 2),
            with: .color(.black.opacity(0.5)), lineWidth: 1.6)
        // Felt under a single lamp: bright pool at centre, deep petrol at the corners.
        context.fill(
            Path(CGRect(x: 30, y: 30, width: 600, height: 300)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.10, green: 0.40, blue: 0.44), location: 0),
                    .init(color: Color(red: 0.065, green: 0.30, blue: 0.345), location: 0.5),
                    .init(color: Color(red: 0.03, green: 0.175, blue: 0.225), location: 1),
                ]),
                center: CGPoint(x: 330, y: 150), startRadius: 20, endRadius: 400))
        context.fill(
            Path(CGRect(x: 30, y: 30, width: 600, height: 300)),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.05), .clear, .black.opacity(0.10)]),
                startPoint: CGPoint(x: 0, y: 30), endPoint: CGPoint(x: 0, y: 330)))
        for index in 0..<220 {
            let x = Double((index * 127) % 596) + 32
            let y = Double((index * 71) % 294) + 33
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 0.8, height: 0.8)),
                with: .color(index % 2 == 0 ? .white.opacity(0.07) : .black.opacity(0.12)))
        }
        // Inner shadow cast by the cushions onto the felt.
        var inner = context
        inner.clip(to: Path(CGRect(x: 30, y: 30, width: 600, height: 300)))
        inner.stroke(
            Path(CGRect(x: 30, y: 30, width: 600, height: 300)), with: .color(.black.opacity(0.28)),
            lineWidth: 12)
        inner.stroke(
            Path(CGRect(x: 30, y: 30, width: 600, height: 300)), with: .color(.black.opacity(0.18)),
            lineWidth: 4)
        var headstring = Path()
        headstring.move(to: CGPoint(x: 180, y: 46))
        headstring.addLine(to: CGPoint(x: 180, y: 314))
        context.stroke(
            headstring, with: .color(.white.opacity(0.12)), style: StrokeStyle(lineWidth: 0.7, dash: [4, 5]))
        context.fill(
            Path(ellipseIn: CGRect(x: 178, y: 178, width: 4, height: 4)), with: .color(.white.opacity(0.3)))
        context.fill(
            Path(ellipseIn: CGRect(x: 455, y: 178, width: 4, height: 4)), with: .color(.white.opacity(0.25)))
        for x in [105.0, 180, 255, 405, 480, 555] {
            for y in [15.0, 345] { diamond(&context, at: CGPoint(x: x, y: y)) }
        }
        for y in [105.0, 180, 255] {
            for x in [15.0, 645] { diamond(&context, at: CGPoint(x: x, y: y)) }
        }
        for (index, pocket) in Table.pockets.enumerated() {
            let center = CGPoint(x: pocket.x + 30, y: pocket.y + 30)
            let rect = CGRect(x: center.x - 19, y: center.y - 19, width: 38, height: 38)
            // Leather collar with a brass rim, then the dark well.
            context.fill(
                Path(ellipseIn: rect.insetBy(dx: -6, dy: -6)),
                with: .radialGradient(
                    Gradient(colors: [Brass.leather, Color(red: 0.09, green: 0.05, blue: 0.04)]),
                    center: CGPoint(x: center.x - 4, y: center.y - 5), startRadius: 4, endRadius: 26))
            context.stroke(
                Path(ellipseIn: rect.insetBy(dx: -6, dy: -6)), with: .color(.black.opacity(0.5)), lineWidth: 1
            )
            context.stroke(
                Path(ellipseIn: rect.insetBy(dx: -1, dy: -1)), with: .color(.white.opacity(0.10)),
                lineWidth: 1)
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .black, location: 0), .init(color: .black, location: 0.55),
                        .init(color: Color(red: 0.05, green: 0.08, blue: 0.09), location: 1),
                    ]),
                    center: CGPoint(x: center.x + 2, y: center.y + 3), startRadius: 2, endRadius: 19))
            context.stroke(
                Path(ellipseIn: rect.insetBy(dx: 1.5, dy: 1.5)), with: .color(.white.opacity(0.06)),
                lineWidth: 1)
            if calledPocket == index {
                context.stroke(
                    Path(ellipseIn: rect.insetBy(dx: -10, dy: -10)), with: .color(Theme.accent),
                    lineWidth: 2.5
                )
                context.fill(
                    Path(ellipseIn: rect), with: .color(Theme.accent.opacity(0.22)))
            } else if requireCall {
                context.stroke(
                    Path(ellipseIn: rect.insetBy(dx: -10, dy: -10)), with: .color(Theme.accent.opacity(0.75)),
                    style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            }
        }
    }

    private func diamond(_ context: inout GraphicsContext, at center: CGPoint) {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - 3))
        path.addLine(to: CGPoint(x: center.x + 2, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + 3))
        path.addLine(to: CGPoint(x: center.x - 2, y: center.y))
        path.closeSubpath()
        context.fill(path, with: .color(.black.opacity(0.5)))
        var inlay = Path()
        inlay.move(to: CGPoint(x: center.x, y: center.y - 3.4))
        inlay.addLine(to: CGPoint(x: center.x + 2.2, y: center.y - 0.4))
        inlay.addLine(to: CGPoint(x: center.x, y: center.y + 2.6))
        inlay.addLine(to: CGPoint(x: center.x - 2.2, y: center.y - 0.4))
        inlay.closeSubpath()
        context.fill(
            inlay,
            with: .linearGradient(
                Gradient(colors: [Brass.light, Brass.deep]),
                startPoint: CGPoint(x: center.x - 2, y: center.y - 3),
                endPoint: CGPoint(x: center.x + 2, y: center.y + 3)))
    }

    private func drawBall(_ context: inout GraphicsContext, ball: Ball) {
        let x = ball.position.x
        let y = ball.position.y
        let radius = Table.radius
        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        // Soft contact shadow thrown away from the lamp, plus a tight dark contact spot.
        let lampOffset = CGPoint(x: (x - 330) / 330 * 2.2 + 1.2, y: (y - 150) / 150 * 1.6 + 3.4)
        context.fill(
            Path(ellipseIn: rect.insetBy(dx: -2.5, dy: -1.5).offsetBy(dx: lampOffset.x, dy: lampOffset.y)),
            with: .radialGradient(
                Gradient(colors: [.black.opacity(0.42), .black.opacity(0)]),
                center: CGPoint(x: x + lampOffset.x, y: y + lampOffset.y), startRadius: 3,
                endRadius: radius + 3))
        context.fill(
            Path(ellipseIn: rect.insetBy(dx: 2, dy: 3).offsetBy(dx: lampOffset.x * 0.4, dy: 3.2)),
            with: .color(.black.opacity(0.3)))
        let base = ball.id > 8 ? Club.ivory : Club.ballColor(ball.id)
        context.fill(Path(ellipseIn: rect), with: .color(base))
        if ball.id > 8 {
            var stripe = context
            stripe.clip(to: Path(ellipseIn: rect))
            stripe.fill(
                Path(CGRect(x: x - radius, y: y - 4.8, width: radius * 2, height: 9.6)),
                with: .color(Club.ballColor(ball.id)))
            stripe.stroke(
                Path(CGRect(x: x - radius - 1, y: y - 4.8, width: radius * 2 + 2, height: 9.6)),
                with: .color(.black.opacity(0.12)), lineWidth: 0.5)
        }
        // Lamp shading: specular near the top-left, deep terminator, faint felt bounce at the bottom.
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.42), location: 0),
                    .init(color: .white.opacity(0.05), location: 0.38),
                    .init(color: .black.opacity(0.18), location: 0.78),
                    .init(color: .black.opacity(0.58), location: 1),
                ]), center: CGPoint(x: x - 3.2, y: y - 4.2), startRadius: 0, endRadius: 17.5))
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [Color(red: 0.2, green: 0.55, blue: 0.6).opacity(0.22), .clear]),
                center: CGPoint(x: x + 2, y: y + radius), startRadius: 0, endRadius: radius * 0.9))
        if ball.id != 0 {
            context.fill(
                Path(ellipseIn: CGRect(x: x - 4.5, y: y - 4.5, width: 9, height: 9)),
                with: .color(.black.opacity(0.12)))
            context.fill(
                Path(ellipseIn: CGRect(x: x - 4.2, y: y - 4.3, width: 8.4, height: 8.4)),
                with: .color(Club.ivory))
            context.draw(
                Text("\(ball.id)").font(.system(size: ball.id > 9 ? 5.4 : 6.4, weight: .bold))
                    .foregroundColor(Club.ink),
                at: CGPoint(x: x, y: y + 0.2))
        }
        // Specular pinpoint from the lamp.
        context.fill(
            Path(ellipseIn: CGRect(x: x - 5.2, y: y - 6.4, width: 3.4, height: 2.2)),
            with: .color(.white.opacity(ball.id == 8 ? 0.8 : 0.72)))
    }

    private func drawAim(_ context: inout GraphicsContext) {
        let trace = table.trace(angle: angle)
        let direction = Vector.direction(angle)
        let cue = table.cue.position
        var guide = Path()
        guide.move(to: point(cue + direction * 12))
        guide.addLine(to: point(trace.end))
        context.stroke(
            guide, with: .color(Club.ivory.opacity(0.18)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        context.stroke(
            guide, with: .color(Club.ivory.opacity(0.7)),
            style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [1.2, 5]))
        // Ghost cue ball at the contact point.
        let ghost = CGRect(x: trace.end.x - 8.5, y: trace.end.y - 8.5, width: 17, height: 17)
        context.fill(Path(ellipseIn: ghost), with: .color(Club.ivory.opacity(0.10)))
        context.stroke(Path(ellipseIn: ghost), with: .color(Club.ivory.opacity(0.75)), lineWidth: 1)
        if let id = trace.ball, let ball = table.balls.first(where: { $0.id == id }),
            let outgoing = trace.outgoing
        {
            var path = Path()
            path.move(to: point(ball.position))
            path.addLine(to: point(ball.position + outgoing * 58))
            context.stroke(
                path, with: .color(Brass.mid.opacity(0.3)),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            context.stroke(
                path, with: .color(Brass.light.opacity(0.9)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            let arrow = point(ball.position + outgoing * 58)
            context.fill(
                Path(ellipseIn: CGRect(x: arrow.x - 2, y: arrow.y - 2, width: 4, height: 4)),
                with: .color(Brass.light))
        } else if let bank = trace.bank {
            var path = Path()
            path.move(to: point(trace.end))
            path.addLine(to: point(trace.end + bank * 60))
            context.stroke(
                path, with: .color(Brass.light.opacity(0.6)),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [3, 4]))
        }
        drawCue(&context, cue: cue, direction: direction)
    }

    private func drawCue(_ context: inout GraphicsContext, cue: Vector, direction: Vector) {
        let start = cue - direction * (20 + power * 15)
        var cueContext = context
        cueContext.addFilter(.shadow(color: .black.opacity(0.5), radius: 3, x: 1.5, y: 3))
        func segment(_ from: Double, _ to: Double, width: Double, color: Color, cap: CGLineCap = .butt) {
            var path = Path()
            path.move(to: point(start - direction * from))
            path.addLine(to: point(start - direction * to))
            cueContext.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: cap))
        }
        // Butt: dark walnut wrap with brass joint; shaft: pale maple tapering to the ferrule; tip: blue chalk.
        segment(50, 82, width: 5.2, color: Brass.walnutDeep, cap: .round)
        segment(52, 66, width: 5.2, color: Color(red: 0.2, green: 0.11, blue: 0.08))
        segment(48.5, 50.5, width: 5.4, color: Brass.mid)
        segment(28, 49, width: 4.6, color: Color(red: 0.78, green: 0.60, blue: 0.38))
        segment(4, 29, width: 3.8, color: Color(red: 0.88, green: 0.74, blue: 0.52))
        segment(1.5, 4.5, width: 3.6, color: Club.ivory)
        segment(0, 1.8, width: 3.4, color: Color(red: 0.30, green: 0.55, blue: 0.78), cap: .round)
        // Highlight along the lit side of the shaft.
        var sheen = Path()
        let side = Vector(x: -direction.y, y: direction.x) * 1.1
        sheen.move(to: point(start - direction * 6 - side))
        sheen.addLine(to: point(start - direction * 48 - side))
        context.stroke(sheen, with: .color(.white.opacity(0.35)), lineWidth: 0.8)
    }
}

struct BallBadge: View {
    let number: Int
    var size = 21.0
    var plain = false
    var body: some View {
        ZStack {
            Circle().fill(number > 8 ? Club.ivory : Club.ballColor(number))
            if number > 8 {
                Rectangle().fill(Club.ballColor(number))
                    .frame(width: size, height: size * 0.57)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            }
            Circle().fill(
                RadialGradient(
                    stops: [
                        .init(color: .white.opacity(0.45), location: 0),
                        .init(color: .white.opacity(0.04), location: 0.4),
                        .init(color: .black.opacity(0.2), location: 0.78),
                        .init(color: .black.opacity(0.6), location: 1),
                    ], center: UnitPoint(x: 0.36, y: 0.3), startRadius: 0, endRadius: size * 0.78))
            if number != 0 && !plain {
                Circle().fill(Club.ivory).frame(width: size * 0.5, height: size * 0.5)
                Text("\(number)").font(.system(size: size * 0.31, weight: .bold)).foregroundStyle(Club.ink)
            }
            Ellipse().fill(.white.opacity(0.75)).frame(width: size * 0.2, height: size * 0.12)
                .offset(x: -size * 0.2, y: -size * 0.3)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.45), radius: size * 0.16, y: size * 0.14)
        .accessibilityLabel(number == 0 ? "Cue ball" : "Ball \(number)")
    }
}
