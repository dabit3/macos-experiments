import SwiftUI

enum GardenPalette {
    static let ink = Color(red: 0.055, green: 0.18, blue: 0.14)
    static let night = Color(red: 0.035, green: 0.12, blue: 0.095)
    static let cream = Color(red: 0.95, green: 0.94, blue: 0.83)
    static let gold = Color(red: 0.86, green: 0.72, blue: 0.39)
    static let muted = Color(red: 0.62, green: 0.74, blue: 0.59)
}

struct GardenCanvas: View {
    let simulation: GolfSimulation
    var aim = Vector.zero
    var bloom = 0.0
    var reducedMotion = false
    var decorative = false
    var onDrag: ((Vector) -> Void)?
    var onRelease: ((Vector) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 400, geometry.size.height / 590)
            let offsetX = (geometry.size.width - 400 * scale) / 2 + 20 * scale
            let offsetY = (geometry.size.height - 590 * scale) / 2 + 30 * scale
            Canvas { context, _ in
                context.translateBy(x: offsetX, y: offsetY)
                context.scaleBy(x: scale, y: scale)
                drawGarden(&context)
            }
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        let pull = Vector(
                            x: -value.translation.width / scale,
                            y: -value.translation.height / scale)
                        onDrag?(pull)
                    }
                    .onEnded { value in
                        onRelease?(
                            Vector(
                                x: -value.translation.width / scale,
                                y: -value.translation.height / scale))
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                decorative
                    ? "A miniature moss garden with a lily pond and golden flag"
                    : "\(simulation.hole.name) course. Ball at \(Int(simulation.position.x)), \(Int(simulation.position.y)). Cup at \(Int(simulation.hole.cup.x)), \(Int(simulation.hole.cup.y))."
            )
            .accessibilityHint("Drag back anywhere on the garden and release to putt. Practice offers button controls.")
            .accessibilityIdentifier("garden.playfield")
        }
    }

    private func drawGarden(_ context: inout GraphicsContext) {
        let hole = simulation.hole
        let time = reducedMotion ? 0 : simulation.time
        ellipse(&context, x: 13, y: 91, w: 337, h: 427, color: .black.opacity(0.25))
        for index in 0..<33 {
            let side = index % 4
            let seed = Double(index)
            let x =
                side == 0
                ? 12 + noise(seed) * 26
                : side == 1 ? 320 + noise(seed) * 35 : 22 + noise(seed) * 313
            let y =
                side == 2
                ? 36 + noise(seed + 2) * 36
                : side == 3 ? 476 + noise(seed + 2) * 37 : 67 + noise(seed + 2) * 428
            fern(&context, x: x, y: y, angle: seed * 2.3, size: 28 + noise(seed + 8) * 30)
        }
        rounded(&context, x: 30, y: 83, w: 300, h: 417, radius: 32, color: Color(hex: 0x333F2C))
        rounded(&context, x: 29, y: 70, w: 302, h: 416, radius: 30, color: Color(hex: 0x817E5D))
        rounded(&context, x: 29, y: 63, w: 302, h: 416, radius: 30, color: Color(hex: 0xD6D4B8))
        rounded(&context, x: 34, y: 67, w: 292, h: 407, radius: 26, color: Color(hex: 0xE6E3CC))
        for index in 0..<12 {
            let y = 91 + Double(index) * 31
            line(
                &context, from: CGPoint(x: 30, y: y), to: CGPoint(x: 44, y: y + 2), color: Color(hex: 0xA6A987),
                width: 1)
            line(
                &context, from: CGPoint(x: 316, y: y + 12), to: CGPoint(x: 329, y: y + 9), color: Color(hex: 0xA6A987),
                width: 1)
        }
        for index in 0..<8 {
            let x = 57 + Double(index) * 31
            line(
                &context, from: CGPoint(x: x, y: 64), to: CGPoint(x: x + 2, y: 82), color: Color(hex: 0xA6A987),
                width: 1)
            line(
                &context, from: CGPoint(x: x, y: 475), to: CGPoint(x: x + 2, y: 486), color: Color(hex: 0xA6A987),
                width: 1)
        }
        let lawn = Path(roundedRect: CGRect(x: 44, y: 81, width: 272, height: 395), cornerRadius: 20)
        context.fill(
            lawn,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x6D9554), Color(hex: 0x426C3B), Color(hex: 0x254F35)]),
                startPoint: CGPoint(x: 50, y: 83), endPoint: CGPoint(x: 296, y: 475)))
        context.stroke(lawn, with: .color(Color(hex: 0x233E2C).opacity(0.6)), lineWidth: 3)
        var grass = context
        grass.clip(to: lawn)
        for index in 0..<500 {
            let seed = Double(index)
            let x = 44 + noise(seed * 2) * 272
            let y = 81 + noise(seed * 2 + 1) * 394
            let length = 1 + noise(seed + 42) * 3
            line(
                &grass, from: CGPoint(x: x, y: y), to: CGPoint(x: x + 0.7, y: y - length), color: .white.opacity(0.085),
                width: 0.7)
        }
        for index in 0..<6 {
            ellipse(
                &grass, x: 24 + Double(index) * 47, y: 90 + Double(index % 3) * 96,
                w: 122, h: 63, color: Color(hex: 0xD9ED94).opacity(0.045))
        }
        for water in hole.water { pond(&context, water: water, time: time) }
        if hole.lily { lily(&context, center: hole.lilyCenter(at: simulation.time), time: time) }
        for wall in hole.walls { stone(&context, wall: wall, moving: false) }
        if hole.gate {
            let gate = hole.gateStone(at: simulation.time)
            line(
                &context, from: CGPoint(x: 55, y: gate.y + 7), to: CGPoint(x: 305, y: gate.y + 7),
                color: GardenPalette.gold.opacity(0.45), width: 1)
            stone(&context, wall: gate, moving: true)
        }
        for mushroom in hole.mushrooms { drawMushroom(&context, mushroom: mushroom) }
        for index in 0..<14 {
            let seed = Double(index + hole.number * 13)
            let x = index.isMultiple(of: 2) ? 39 + noise(seed) * 8 : 311 + noise(seed) * 10
            let y = 100 + noise(seed + 30) * 350
            ellipse(&context, x: x - 6, y: y - 3, w: 15, h: 9, color: Color(hex: 0x70854C))
            ellipse(&context, x: x - 3, y: y - 5, w: 9, h: 7, color: Color(hex: 0xA5B378))
        }
        let tee = simulation.hole.tee
        ellipse(&context, x: tee.x - 13, y: tee.y - 5, w: 26, h: 10, color: .white.opacity(0.09))
        line(
            &context, from: CGPoint(x: tee.x - 11, y: tee.y + 11), to: CGPoint(x: tee.x + 11, y: tee.y + 11),
            color: GardenPalette.cream.opacity(0.28), width: 1)
        flag(&context, at: hole.cup, time: time)
        if aim.length >= 5 && !simulation.moving && !simulation.sunk {
            trajectory(&context)
        }
        if !simulation.sunk { ball(&context, at: simulation.position) }
        if bloom > 0 {
            for index in 0..<22 {
                let angle = Double(index) * 2.4
                let distance = (20 + noise(Double(index)) * 47) * min(1, bloom * 2)
                let x = hole.cup.x + cos(angle) * distance
                let y = hole.cup.y + sin(angle) * distance * 0.72
                flower(&context, x: x, y: y, size: 3 + noise(Double(index + 4)) * 3, pale: index.isMultiple(of: 2))
            }
        }
        for index in 0..<9 {
            let x = 21 + noise(Double(index + 81)) * 318
            let y = 55 + noise(Double(index + 106)) * 429
            let drift = sin(time * 0.4 + Double(index)) * 4
            ellipse(&context, x: x + drift, y: y, w: 2, h: 2, color: GardenPalette.gold.opacity(0.45))
        }
    }

    private func trajectory(_ context: inout GraphicsContext) {
        let prediction = simulation.prediction(pull: aim)
        let points = prediction.points
        for (index, point) in points.enumerated() {
            let alpha = 0.9 - Double(index) / Double(max(points.count, 1)) * 0.55
            ellipse(
                &context, x: point.x - 1.7, y: point.y - 1.7, w: 3.4, h: 3.4, color: GardenPalette.cream.opacity(alpha))
        }
        if let end = points.last {
            let color =
                prediction.waterHazard
                ? Color(hex: 0xFFD28A) : prediction.sinks ? GardenPalette.gold : GardenPalette.cream
            context.stroke(
                Path(ellipseIn: CGRect(x: end.x - 8, y: end.y - 8, width: 16, height: 16)),
                with: .color(color), lineWidth: prediction.sinks ? 2 : 1)
            if prediction.waterHazard {
                line(
                    &context, from: CGPoint(x: end.x - 4, y: end.y - 4), to: CGPoint(x: end.x + 4, y: end.y + 4),
                    color: color, width: 1.5)
                line(
                    &context, from: CGPoint(x: end.x + 4, y: end.y - 4), to: CGPoint(x: end.x - 4, y: end.y + 4),
                    color: color, width: 1.5)
            }
        }
        let position = simulation.position
        let tail = position - aim.unit * min(aim.length, 58)
        line(
            &context, from: CGPoint(x: position.x, y: position.y), to: CGPoint(x: tail.x, y: tail.y),
            color: GardenPalette.gold, width: 2.5)
        ellipse(&context, x: tail.x - 3, y: tail.y - 3, w: 6, h: 6, color: GardenPalette.gold)
    }

    private func ball(_ context: inout GraphicsContext, at point: Vector) {
        ellipse(&context, x: point.x - 6, y: point.y + 3, w: 16, h: 8, color: .black.opacity(0.25))
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)),
            with: .radialGradient(
                Gradient(colors: [.white, GardenPalette.cream, Color(hex: 0xBCBB91)]),
                center: CGPoint(x: point.x - 2, y: point.y - 3), startRadius: 0, endRadius: 11))
        ellipse(&context, x: point.x - 3, y: point.y - 4, w: 3, h: 2, color: .white)
    }

    private func flag(_ context: inout GraphicsContext, at point: Vector, time: Double) {
        ellipse(&context, x: point.x - 14, y: point.y - 7, w: 28, h: 14, color: Color(hex: 0x93AE67).opacity(0.65))
        ellipse(&context, x: point.x - 8, y: point.y - 5, w: 16, h: 10, color: Color(hex: 0x142F23))
        ellipse(&context, x: point.x - 5, y: point.y - 3, w: 10, h: 5, color: Color(hex: 0x091A16))
        line(
            &context, from: CGPoint(x: point.x, y: point.y), to: CGPoint(x: point.x + 29, y: point.y + 11),
            color: .black.opacity(0.17), width: 2)
        line(
            &context, from: CGPoint(x: point.x, y: point.y), to: CGPoint(x: point.x, y: point.y - 49),
            color: Color(hex: 0xF4E7AE), width: 1.5)
        var flag = Path()
        flag.move(to: CGPoint(x: point.x + 1, y: point.y - 49))
        flag.addQuadCurve(
            to: CGPoint(x: point.x + 27, y: point.y - 44 + sin(time * 1.5) * 2),
            control: CGPoint(x: point.x + 15, y: point.y - 50))
        flag.addLine(to: CGPoint(x: point.x + 1, y: point.y - 33))
        flag.closeSubpath()
        context.fill(flag, with: .color(GardenPalette.gold))
        context.draw(
            Text("\(simulation.hole.number)").font(.system(size: 8, weight: .bold, design: .serif)).foregroundStyle(
                GardenPalette.ink),
            at: CGPoint(x: point.x + 9, y: point.y - 42))
        ellipse(&context, x: point.x - 2, y: point.y - 53, w: 4, h: 4, color: GardenPalette.cream)
    }

    private func pond(_ context: inout GraphicsContext, water: Stone, time: Double) {
        rounded(
            &context, x: water.x - 3, y: water.y - 3, w: water.width + 6, h: water.height + 6, radius: 13,
            color: Color(hex: 0x355B46))
        let pond = Path(
            roundedRect: CGRect(x: water.x, y: water.y, width: water.width, height: water.height), cornerRadius: 11)
        context.fill(
            pond,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0x8FB3A4), Color(hex: 0xCCDDD0), Color(hex: 0x7EA595)]),
                startPoint: CGPoint(x: water.x, y: water.y),
                endPoint: CGPoint(x: water.x + water.width, y: water.y + water.height)))
        var clipped = context
        clipped.clip(to: pond)
        for index in 0..<8 {
            let x = water.x + noise(Double(index + 8)) * water.width
            let y = water.y + noise(Double(index + 31)) * water.height
            let drift = sin(time + Double(index)) * 3
            line(
                &clipped, from: CGPoint(x: x + drift, y: y), to: CGPoint(x: x + 24 + drift, y: y),
                color: .white.opacity(0.23), width: 1.5)
        }
        ellipse(&clipped, x: water.x + 10, y: water.y + 8, w: water.width * 0.62, h: 7, color: .white.opacity(0.15))
    }

    private func lily(_ context: inout GraphicsContext, center: Vector, time: Double) {
        ellipse(&context, x: center.x - 53, y: center.y - 41, w: 106, h: 86, color: .white.opacity(0.22))
        ellipse(&context, x: center.x - 48, y: center.y - 43, w: 96, h: 94, color: Color(hex: 0x416D4B).opacity(0.25))
        var leaf = Path()
        leaf.addArc(
            center: CGPoint(x: center.x, y: center.y), radius: 48, startAngle: .degrees(-18), endAngle: .degrees(320),
            clockwise: false)
        leaf.addLine(to: CGPoint(x: center.x + 5, y: center.y))
        leaf.closeSubpath()
        context.fill(
            leaf,
            with: .linearGradient(
                Gradient(colors: [Color(hex: 0xADBB70), Color(hex: 0x638A50)]),
                startPoint: CGPoint(x: center.x - 30, y: center.y - 40),
                endPoint: CGPoint(x: center.x + 30, y: center.y + 40)))
        for index in 0..<7 {
            let angle = Double(index) * 0.85 + 0.3
            line(
                &context, from: CGPoint(x: center.x, y: center.y),
                to: CGPoint(x: center.x + cos(angle) * 43, y: center.y + sin(angle) * 43),
                color: Color(hex: 0xDADEA0).opacity(0.32), width: 0.7)
        }
        flower(&context, x: center.x - 29, y: center.y - 16, size: 7, pale: true)
    }

    private func stone(_ context: inout GraphicsContext, wall: Stone, moving: Bool) {
        rounded(
            &context, x: wall.x + 3, y: wall.y + 8, w: wall.width, h: wall.height, radius: 4,
            color: .black.opacity(0.23))
        rounded(
            &context, x: wall.x, y: wall.y, w: wall.width, h: wall.height + 4, radius: 4, color: Color(hex: 0x777F5D))
        rounded(
            &context, x: wall.x, y: wall.y - 5, w: wall.width, h: wall.height, radius: 4, color: Color(hex: 0xD9D6B6))
        line(
            &context, from: CGPoint(x: wall.x + 5, y: wall.y - 2),
            to: CGPoint(x: wall.x + wall.width - 5, y: wall.y - 2), color: .white.opacity(0.35), width: 1)
        if moving {
            for index in 0..<5 {
                let x = wall.x + 13 + Double(index) * 22
                ellipse(&context, x: x, y: wall.y - 1, w: 3, h: 3, color: GardenPalette.gold)
            }
        } else {
            fern(&context, x: wall.x + 7, y: wall.y + wall.height - 5, angle: -0.6, size: 17)
        }
    }

    private func drawMushroom(_ context: inout GraphicsContext, mushroom: Mushroom) {
        let center = mushroom.center
        let radius = mushroom.radius
        ellipse(
            &context, x: center.x - radius + 8, y: center.y - radius + 16, w: radius * 2, h: radius * 1.7,
            color: .black.opacity(0.22))
        rounded(
            &context, x: center.x - 7, y: center.y - 2, w: 14, h: radius * 0.6, radius: 4, color: Color(hex: 0xDBD2AC))
        ellipse(
            &context, x: center.x - radius, y: center.y - radius + 7, w: radius * 2, h: radius * 1.9,
            color: Color(hex: 0x76563C))
        let cap = Path(
            ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 1.85))
        context.fill(
            cap,
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xDBB27B), Color(hex: 0xB88050), Color(hex: 0x916040)]),
                center: CGPoint(x: center.x - 8, y: center.y - 12), startRadius: 0, endRadius: radius * 1.7))
        for index in 0..<7 {
            let angle = Double(index) * 2.4
            let distance = noise(Double(index + 3)) * radius * 0.65
            ellipse(
                &context, x: center.x + cos(angle) * distance - 2, y: center.y + sin(angle) * distance - 5, w: 5,
                h: 3.5, color: GardenPalette.cream.opacity(0.65))
        }
    }

    private func fern(_ context: inout GraphicsContext, x: Double, y: Double, angle: Double, size: Double) {
        var local = context
        local.translateBy(x: x, y: y)
        local.rotate(by: .radians(angle))
        line(&local, from: .zero, to: CGPoint(x: 0, y: -size), color: Color(hex: 0x829455).opacity(0.7), width: 0.8)
        for index in 0..<6 {
            let fraction = Double(index) / 6
            let y = -size * fraction
            let width = (1 - fraction) * size * 0.36 + 2
            for side in [-1.0, 1.0] {
                var leaf = Path()
                leaf.move(to: CGPoint(x: 0, y: y))
                leaf.addQuadCurve(
                    to: CGPoint(x: side * width, y: y - size * 0.22), control: CGPoint(x: side * width * 0.9, y: y + 3))
                leaf.addQuadCurve(to: CGPoint(x: 0, y: y), control: CGPoint(x: side * width * 0.75, y: y - size * 0.27))
                local.fill(leaf, with: .color(index.isMultiple(of: 2) ? Color(hex: 0x527C45) : Color(hex: 0x385D39)))
                line(
                    &local, from: CGPoint(x: 0, y: y), to: CGPoint(x: side * width * 0.85, y: y - size * 0.18),
                    color: Color(hex: 0xA6AE62).opacity(0.2), width: 0.5)
            }
        }
    }

    private func flower(_ context: inout GraphicsContext, x: Double, y: Double, size: Double, pale: Bool) {
        for index in 0..<5 {
            let angle = Double(index) * .pi * 2 / 5
            ellipse(
                &context, x: x + cos(angle) * size * 0.6 - size * 0.45, y: y + sin(angle) * size * 0.5 - size * 0.4,
                w: size * 0.9, h: size * 0.8, color: pale ? Color(hex: 0xF0E9D0) : Color(hex: 0xD9AE76))
        }
        ellipse(
            &context, x: x - size * 0.25, y: y - size * 0.25, w: size * 0.5, h: size * 0.5, color: GardenPalette.gold)
    }

    private func noise(_ seed: Double) -> Double {
        let value = sin(seed * 127.1 + 311.7) * 43758.5453
        return value - floor(value)
    }

    private func ellipse(_ context: inout GraphicsContext, x: Double, y: Double, w: Double, h: Double, color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
    }

    private func rounded(
        _ context: inout GraphicsContext, x: Double, y: Double, w: Double, h: Double, radius: Double, color: Color
    ) {
        context.fill(
            Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius), with: .color(color))
    }

    private func line(_ context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color, width: Double) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255)
    }
}
