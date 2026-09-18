import SwiftUI

struct PostcardPalette {
    let skyTop: Color
    let skyHorizon: Color
    let mist: Color
    let accent: Color
    let deep: Color
    let foliage: Color
    let stoneLight: Color
    let stoneShade: Color
    let glow: Color

    static let ink = Color(hex: 0x2F3F49)
    static let paper = Color(hex: 0xFBF7EE)
    static let ivory = Color(hex: 0xFFF9EA)
    static let gold = Color(hex: 0xD9AF5C)
    static let goldDeep = Color(hex: 0xB4863A)

    static func chapter(_ index: Int) -> PostcardPalette {
        [
            PostcardPalette(
                skyTop: Color(hex: 0xBFD9D2), skyHorizon: Color(hex: 0xEEEBDC), mist: Color(hex: 0xCFDFD8),
                accent: Color(hex: 0xC97A62), deep: Color(hex: 0x6E4E48), foliage: Color(hex: 0x5F8F7D),
                stoneLight: Color(hex: 0xF1E7D2), stoneShade: Color(hex: 0xC9BBA1), glow: Color(hex: 0xFFE9B8)
            ),
            PostcardPalette(
                skyTop: Color(hex: 0xEBC9B3), skyHorizon: Color(hex: 0xF7ECDF), mist: Color(hex: 0xE9D3C2),
                accent: Color(hex: 0xC66F55), deep: Color(hex: 0x7F4638), foliage: Color(hex: 0x7F9474),
                stoneLight: Color(hex: 0xF3E3D0), stoneShade: Color(hex: 0xCDAE96), glow: Color(hex: 0xFFE3BC)
            ),
            PostcardPalette(
                skyTop: Color(hex: 0xC9C0E3), skyHorizon: Color(hex: 0xF1ECF2), mist: Color(hex: 0xD6CCE5),
                accent: Color(hex: 0x9A80C2), deep: Color(hex: 0x584B7C), foliage: Color(hex: 0x7397A3),
                stoneLight: Color(hex: 0xEFE7F0), stoneShade: Color(hex: 0xBFB1CF), glow: Color(hex: 0xFFEEDC)
            ),
            PostcardPalette(
                skyTop: Color(hex: 0xA9A6C9), skyHorizon: Color(hex: 0xF3D6C8), mist: Color(hex: 0xCFC3D2),
                accent: Color(hex: 0xC4857E), deep: Color(hex: 0x4E5279), foliage: Color(hex: 0x6F9491),
                stoneLight: Color(hex: 0xEDE0DF), stoneShade: Color(hex: 0xB6ACC2), glow: Color(hex: 0xFFD9B3)
            ),
        ][index % 4]
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB, red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1
        )
    }
}

struct WorldProjection {
    let scale: Double
    let origin: CGPoint

    init(chapter: Chapter, size: CGSize) {
        let points = chapter.tiles.map { Self.raw($0.point) }
        let minX = (points.map(\.x).min() ?? 0) - 28
        let maxX = (points.map(\.x).max() ?? 0) + 28
        let minY = (points.map(\.y).min() ?? 0) - 64
        let maxY = (points.map(\.y).max() ?? 0) + 96
        scale = min((size.width - 16) / (maxX - minX), (size.height - 10) / (maxY - minY), 2.2)
        origin = CGPoint(
            x: size.width / 2 - (minX + maxX) / 2 * scale,
            y: size.height / 2 - (minY + maxY) / 2 * scale
        )
    }

    static func raw(_ point: WorldPoint) -> CGPoint {
        CGPoint(x: (point.x - point.y) * 25, y: (point.x + point.y) * 13 - point.z * 25)
    }

    func point(_ world: WorldPoint) -> CGPoint {
        let raw = Self.raw(world)
        return CGPoint(x: raw.x * scale + origin.x, y: raw.y * scale + origin.y)
    }
}

struct PostcardWorld: View {
    let chapter: Chapter
    let state: PuzzleState
    var interactive = false
    var movingTo: Int?
    var rejectedTile: Int?
    var feedbackTick = 0
    var focusedMechanism: Int?
    var drifting = false
    var onTile: (Int) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angles = [Double]()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !drifting)) { timeline in
            let phase = drifting && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0
            scene
                .offset(y: sin(phase * 0.9) * 2.2)
        }
        .onAppear { angles = state.orientations.map { Double($0) * .pi / 2 } }
        .onChange(of: state.orientations) { old, new in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.48)) {
                if angles.count != new.count {
                    angles = new.map { Double($0) * .pi / 2 }
                } else {
                    for index in new.indices where old[index] != new[index] {
                        angles[index] += .pi / 2
                    }
                }
            }
        }
    }

    private var scene: some View {
        GeometryReader { geometry in
            let projection = WorldProjection(chapter: chapter, size: geometry.size)
            let palette = PostcardPalette.chapter(chapter.id)
            let currentAngles = angles.isEmpty ? state.orientations.map { Double($0) * .pi / 2 } : angles
            ZStack {
                Architecture(
                    chapter: chapter, state: state, angle0: currentAngles[0],
                    angle1: currentAngles.count > 1 ? currentAngles[1] : 0
                )
                .accessibilityHidden(true)
                if let focusedMechanism {
                    let tile = chapter.tiles[chapter.mechanisms[focusedMechanism].center]
                    Ellipse()
                        .stroke(palette.accent.opacity(0.9), style: StrokeStyle(lineWidth: 1.6, dash: [3, 3]))
                        .frame(width: 44 * projection.scale, height: 25 * projection.scale)
                        .position(projection.point(tile.point))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                ForEach(chapter.tiles) { tile in
                    Ellipse()
                        .stroke(palette.deep, lineWidth: 2)
                        .frame(width: 40 * projection.scale, height: 23 * projection.scale)
                        .phaseAnimator(
                            [false, true, false],
                            trigger: rejectedTile == tile.id ? feedbackTick : 0
                        ) { content, expanded in
                            content
                                .scaleEffect(expanded ? 1.4 : 0.9)
                                .opacity(expanded ? 0.95 : 0)
                        } animation: { _ in
                            reduceMotion ? .linear(duration: 0.1) : .easeInOut(duration: 0.3)
                        }
                        .position(projection.point(tile.point))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                if interactive {
                    ForEach(chapter.tiles) { tile in
                        Button { onTile(tile.id) } label: {
                            Circle().fill(.clear).frame(width: 46, height: 46).contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tile.name)
                        .accessibilityValue(accessibilityValue(tile))
                        .accessibilityHint("Walk here if the path is connected")
                        .position(projection.point(tile.point))
                    }
                }
                Traveler(palette: palette, walking: movingTo != nil)
                    .frame(width: 22 * projection.scale, height: 34 * projection.scale)
                    .position(travelerPosition(projection))
                    .animation(
                        reduceMotion || movingTo == nil ? nil : .easeInOut(duration: 0.32),
                        value: movingTo ?? state.tile
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private func travelerPosition(_ projection: WorldProjection) -> CGPoint {
        var point = projection.point(chapter.tiles[movingTo ?? state.tile].point)
        point.y -= 16 * projection.scale
        return point
    }

    private func accessibilityValue(_ tile: Tile) -> String {
        if tile.id == state.tile {
            return "Traveler is here"
        }
        if case let .switchTile(bit) = tile.kind, state.switches & (1 << bit) != 0 {
            return "Sun seal lit"
        }
        return chapter.path(to: tile.id, state: state) == nil ? "Not connected" : "Connected"
    }
}

struct Architecture: View, Animatable {
    let chapter: Chapter
    let state: PuzzleState
    nonisolated var angle0: Double
    nonisolated var angle1: Double

    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(angle0, angle1) }
        set { angle0 = newValue.first; angle1 = newValue.second }
    }

    var body: some View {
        Canvas { context, size in
            let projection = WorldProjection(chapter: chapter, size: size)
            let palette = PostcardPalette.chapter(chapter.id)
            var painter = WorldPainter(context: context, projection: projection, palette: palette)
            let ordered = chapter.tiles.sorted { $0.point.x + $0.point.y < $1.point.x + $1.point.y }
            painter.island(chapter.tiles.map(\.point))
            for tile in ordered {
                painter.shadow(tile.point, pivot: isPivot(tile))
            }
            for tile in ordered {
                painter.column(tile.point, pivot: isPivot(tile), goal: tile.id == chapter.destination)
            }
            for path in chapter.walkways {
                painter.bridge(chapter.tiles[path.from].point, chapter.tiles[path.to].point, moving: false)
            }
            for (index, mechanism) in chapter.mechanisms.enumerated() {
                let angle = index == 0 ? angle0 : angle1
                let center = chapter.tiles[mechanism.center].point
                for offset in [0, mechanism.elbow ? 1 : 2] {
                    let arm = angle + Double(offset) * .pi / 2
                    let orientation = arm / (.pi / 2)
                    let lower = Int(floor(orientation))
                    let fraction = orientation - floor(orientation)
                    let lowDock = chapter.tiles[mechanism.docks[(lower % 4 + 4) % 4]].point
                    let highDock = chapter.tiles[mechanism.docks[((lower + 1) % 4 + 4) % 4]].point
                    let endpoint = WorldPoint(
                        x: center.x + sin(arm) * 2, y: center.y - cos(arm) * 2,
                        z: lowDock.z * (1 - fraction) + highDock.z * fraction
                    )
                    painter.bridge(center, endpoint, moving: true)
                }
            }
            for tile in ordered {
                painter.surface(tile.point, pivot: isPivot(tile))
                switch tile.kind {
                case let .switchTile(bit):
                    painter.seal(tile.point, lit: state.switches & (1 << bit) != 0)
                case .destination:
                    painter.portal(tile.point, open: state.switches == chapter.requiredSwitches)
                case let .pivot(index):
                    painter.pivot(tile.point, index: index, numbered: chapter.mechanisms.count > 1)
                case .start:
                    painter.lantern(tile.point)
                case .floor:
                    painter.marker(tile.point, color: palette.foliage.opacity(0.55))
                }
            }
            for tile in ordered where tile.kind == .floor && tile.id % 2 == 1 {
                painter.cypress(WorldPoint(x: tile.point.x - 0.3, y: tile.point.y - 0.31, z: tile.point.z))
            }
        }
    }

    private func isPivot(_ tile: Tile) -> Bool {
        if case .pivot = tile.kind {
            return true
        }
        return false
    }
}

struct WorldPainter {
    var context: GraphicsContext
    let projection: WorldProjection
    let palette: PostcardPalette
    private var scale: Double {
        projection.scale
    }

    mutating func island(_ points: [WorldPoint]) {
        guard !points.isEmpty else { return }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let center = WorldPoint(
            x: ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2 + 0.6,
            y: ((ys.min() ?? 0) + (ys.max() ?? 0)) / 2 + 0.6,
            z: -1.7
        )
        let p = projection.point(center)
        let spread = Double((xs.max() ?? 0) - (xs.min() ?? 0) + 4) * 25 * scale
        let rect = CGRect(x: p.x - spread / 2, y: p.y - spread * 0.19, width: spread, height: spread * 0.38)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [palette.mist.opacity(0.55), palette.mist.opacity(0)]),
            center: p, startRadius: 0, endRadius: spread / 2
        ))
    }

    mutating func shadow(_ point: WorldPoint, pivot: Bool) {
        let ground = projection.point(WorldPoint(x: point.x + 0.6, y: point.y + 0.55, z: -1.42))
        let width = (pivot ? 62 : 56) * scale
        let rect = CGRect(x: ground.x - width / 2, y: ground.y - width * 0.15, width: width, height: width * 0.3)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [palette.deep.opacity(0.16), palette.deep.opacity(0)]),
            center: ground, startRadius: 0, endRadius: width / 2
        ))
    }

    mutating func column(_ point: WorldPoint, pivot: Bool, goal: Bool) {
        let width = pivot ? 0.56 : 0.48
        let footZ = -1.2
        let top = corners(point, width: width)
        let bottom = corners(WorldPoint(x: point.x, y: point.y, z: footZ), width: width)
        let light = goal ? palette.accent : palette.stoneLight
        let shade = goal ? palette.deep : palette.stoneShade
        gradientPolygon(
            [top[2], top[3], bottom[3], bottom[2]],
            from: light,
            to: shade.opacity(0.9),
            top: top[3].y,
            bottom: bottom[3].y
        )
        gradientPolygon(
            [top[1], top[2], bottom[2], bottom[1]],
            from: shade,
            to: palette.deep.opacity(0.85),
            top: top[1].y,
            bottom: bottom[1].y
        )

        // Cornice band beneath the cap and a foundation band at the foot.
        let corniceZ = point.z - 0.16
        let cornice = corners(WorldPoint(x: point.x, y: point.y, z: corniceZ), width: width)
        let corniceLow = corners(WorldPoint(x: point.x, y: point.y, z: corniceZ - 0.09), width: width)
        polygon([cornice[1], cornice[2], corniceLow[2], corniceLow[1]], color: palette.deep.opacity(0.22))
        polygon([cornice[2], cornice[3], corniceLow[3], corniceLow[2]], color: palette.deep.opacity(0.13))
        let footTop = corners(WorldPoint(x: point.x, y: point.y, z: footZ + 0.24), width: width)
        polygon([footTop[1], footTop[2], bottom[2], bottom[1]], color: palette.deep.opacity(0.3))
        polygon([footTop[2], footTop[3], bottom[3], bottom[2]], color: palette.deep.opacity(0.18))

        // Fluting on the sunlit face.
        let height = bottom[3].y - top[3].y
        if height > 30 * scale {
            for fraction in [0.35, 0.65] {
                let upper = lerp(top[3], top[2], fraction)
                let lower = lerp(bottom[3], bottom[2], fraction)
                var line = Path()
                line.move(to: CGPoint(x: upper.x, y: upper.y + 9 * scale))
                line.addLine(to: CGPoint(x: lower.x, y: lower.y - 7 * scale))
                context.stroke(line, with: .color(palette.deep.opacity(0.1)), lineWidth: 0.9 * scale)
            }
        }

        // A tall column gets an arched niche on its shaded face.
        if height > 44 * scale {
            let anchor = lerp(top[1], top[2], 0.5)
            let rect = CGRect(
                x: anchor.x - 4 * scale, y: anchor.y + 14 * scale,
                width: 8 * scale, height: min(height - 30 * scale, 22 * scale)
            )
            var niche = Path()
            niche.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            niche.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.width / 2))
            niche.addArc(
                center: CGPoint(x: rect.midX, y: rect.minY + rect.width / 2), radius: rect.width / 2,
                startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
            )
            niche.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            niche.closeSubpath()
            context.fill(niche, with: .linearGradient(
                Gradient(colors: [palette.deep.opacity(0.5), palette.deep.opacity(0.22)]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            ))
        }
        polygon(top, color: PostcardPalette.ivory)
    }

    mutating func surface(_ point: WorldPoint, pivot: Bool) {
        let width = pivot ? 0.55 : 0.48
        let cap = corners(point, width: width)
        context.fill(polygonPath(cap), with: .linearGradient(
            Gradient(colors: [PostcardPalette.ivory, palette.stoneLight.opacity(0.9)]),
            startPoint: cap[0], endPoint: cap[2]
        ))
        context.stroke(polygonPath(cap), with: .color(.white.opacity(0.75)), lineWidth: 0.7 * scale)
        let inlay = corners(point, width: width - 0.14)
        context.stroke(polygonPath(inlay), with: .color(palette.deep.opacity(0.16)), lineWidth: 0.6 * scale)
    }

    mutating func bridge(_ from: WorldPoint, _ to: WorldPoint, moving: Bool) {
        let length = hypot(to.x - from.x, to.y - from.y)
        guard length > 0.01 else { return }
        let nx = -(to.y - from.y) / length * 0.27
        let ny = (to.x - from.x) / length * 0.27
        let worlds = [
            WorldPoint(x: from.x + nx, y: from.y + ny, z: from.z),
            WorldPoint(x: to.x + nx, y: to.y + ny, z: to.z),
            WorldPoint(x: to.x - nx, y: to.y - ny, z: to.z),
            WorldPoint(x: from.x - nx, y: from.y - ny, z: from.z),
        ]
        let top = worlds.map(projection.point)
        let bottom = worlds.map { projection.point(WorldPoint(x: $0.x, y: $0.y, z: $0.z - 0.22)) }
        let side = moving ? palette.deep : palette.stoneShade
        let sideLight = moving ? palette.deep.opacity(0.85) : palette.stoneLight
        polygon([top[0], top[1], bottom[1], bottom[0]], color: side)
        polygon([top[1], top[2], bottom[2], bottom[1]], color: sideLight)
        polygon([top[2], top[3], bottom[3], bottom[2]], color: sideLight)
        polygon(top, color: moving ? palette.accent : PostcardPalette.ivory)
        if abs(to.z - from.z) > 0.1 {
            stairs(from.z < to.z ? from : to, from.z < to.z ? to : from, moving: moving)
        } else {
            if moving {
                let runner = [
                    WorldPoint(x: from.x + nx * 0.4, y: from.y + ny * 0.4, z: from.z),
                    WorldPoint(x: to.x + nx * 0.4, y: to.y + ny * 0.4, z: to.z),
                    WorldPoint(x: to.x - nx * 0.4, y: to.y - ny * 0.4, z: to.z),
                    WorldPoint(x: from.x - nx * 0.4, y: from.y - ny * 0.4, z: from.z),
                ].map(projection.point)
                polygon(runner, color: PostcardPalette.ivory.opacity(0.28))
            }
            balustrade(from, to, nx: nx, ny: ny, moving: moving)
        }
    }

    private mutating func balustrade(_ from: WorldPoint, _ to: WorldPoint, nx: Double, ny: Double, moving: Bool) {
        let posts = 5
        for side in [1.0, -1.0] {
            for index in 1 ..< posts {
                let t = Double(index) / Double(posts)
                let base = WorldPoint(
                    x: from.x + (to.x - from.x) * t + nx * side * 0.92,
                    y: from.y + (to.y - from.y) * t + ny * side * 0.92,
                    z: from.z + (to.z - from.z) * t
                )
                let foot = projection.point(base)
                let head = projection.point(WorldPoint(x: base.x, y: base.y, z: base.z + 0.16))
                var post = Path()
                post.move(to: foot)
                post.addLine(to: head)
                context.stroke(
                    post, with: .color(moving ? PostcardPalette.ivory.opacity(0.7) : palette.deep.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 1.1 * scale, lineCap: .round)
                )
            }
        }
    }

    mutating func stairs(_ low: WorldPoint, _ high: WorldPoint, moving: Bool) {
        let length = hypot(high.x - low.x, high.y - low.y)
        let inset = min(0.52 / length, 0.4)
        let dx = high.x - low.x
        let dy = high.y - low.y
        let nx = -dy / length * 0.28
        let ny = dx / length * 0.28
        let count = max(3, Int(ceil((high.z - low.z) * 7)))
        let rise = (high.z - low.z) / Double(count)
        let ordered = (0 ..< count).sorted { dx + dy > 0 ? $0 < $1 : $0 > $1 }
        for step in ordered {
            let start = inset + (1 - 2 * inset) * Double(step) / Double(count)
            let end = inset + (1 - 2 * inset) * Double(step + 1) / Double(count)
            let z = low.z + rise * Double(step + 1)
            let near = WorldPoint(x: low.x + dx * start, y: low.y + dy * start, z: z)
            let far = WorldPoint(x: low.x + dx * end, y: low.y + dy * end, z: z)
            let top = [
                WorldPoint(x: near.x + nx, y: near.y + ny, z: z),
                WorldPoint(x: far.x + nx, y: far.y + ny, z: z),
                WorldPoint(x: far.x - nx, y: far.y - ny, z: z),
                WorldPoint(x: near.x - nx, y: near.y - ny, z: z),
            ].map(projection.point)
            let lowerLeft = projection.point(WorldPoint(x: near.x + nx, y: near.y + ny, z: z - rise))
            let lowerRight = projection.point(WorldPoint(x: near.x - nx, y: near.y - ny, z: z - rise))
            polygon([top[0], top[3], lowerRight, lowerLeft], color: moving ? palette.deep : palette.stoneShade)
            polygon(top, color: moving ? palette.accent : PostcardPalette.ivory)
            var edge = Path()
            edge.move(to: top[0])
            edge.addLine(to: top[3])
            context.stroke(edge, with: .color(palette.deep.opacity(0.55)), lineWidth: 0.8 * scale)
        }
    }

    mutating func seal(_ world: WorldPoint, lit: Bool) {
        let p = projection.point(world)
        if lit {
            let glow = CGRect(x: p.x - 30 * scale, y: p.y - 40 * scale, width: 60 * scale, height: 60 * scale)
            context.fill(Path(ellipseIn: glow), with: .radialGradient(
                Gradient(colors: [PostcardPalette.gold.opacity(0.42), PostcardPalette.gold.opacity(0)]),
                center: CGPoint(x: p.x, y: p.y - 10 * scale), startRadius: 0, endRadius: 30 * scale
            ))
        }
        let rect = CGRect(x: p.x - 11 * scale, y: p.y - 5.5 * scale, width: 22 * scale, height: 11 * scale)
        context.fill(Path(ellipseIn: rect), with: .color(lit ? PostcardPalette.gold : palette.stoneShade.opacity(0.8)))
        context.stroke(
            Path(ellipseIn: rect.insetBy(dx: 3.4 * scale, dy: 1.7 * scale)),
            with: .color(lit ? PostcardPalette.ivory : palette.deep.opacity(0.8)),
            lineWidth: 0.9 * scale
        )
        context.fill(
            Path(ellipseIn: rect.insetBy(dx: 8 * scale, dy: 4 * scale)),
            with: .color(lit ? PostcardPalette.ivory : palette.deep.opacity(0.55))
        )
        for index in 0 ..< 12 {
            let angle = Double(index) * .pi / 6
            let long = index % 3 == 0 ? 4.5 : 2.6
            var ray = Path()
            ray.move(to: CGPoint(x: p.x + cos(angle) * 12 * scale, y: p.y + sin(angle) * 6.2 * scale))
            ray.addLine(to: CGPoint(
                x: p.x + cos(angle) * (12 + long) * scale, y: p.y + sin(angle) * (6.2 + long * 0.55) * scale
            ))
            context.stroke(
                ray, with: .color(lit ? PostcardPalette.goldDeep : palette.deep.opacity(0.5)),
                style: StrokeStyle(lineWidth: 0.9 * scale, lineCap: .round)
            )
        }
    }

    mutating func pivot(_ world: WorldPoint, index: Int, numbered: Bool) {
        let p = projection.point(world)
        let rect = CGRect(x: p.x - 12 * scale, y: p.y - 6.5 * scale, width: 24 * scale, height: 13 * scale)
        context.fill(Path(ellipseIn: rect), with: .color(palette.accent.opacity(0.14)))
        context.stroke(Path(ellipseIn: rect), with: .color(palette.accent), lineWidth: 1.3 * scale)
        context.stroke(
            Path(ellipseIn: rect.insetBy(dx: 3 * scale, dy: 1.6 * scale)),
            with: .color(palette.accent.opacity(0.55)),
            style: StrokeStyle(lineWidth: 0.7 * scale, dash: [1.6 * scale, 2.4 * scale])
        )
        if numbered {
            context.draw(
                Text(index == 0 ? "I" : "II")
                    .font(.custom("Baskerville-SemiBold", size: 9.5 * scale))
                    .foregroundColor(palette.deep),
                at: p
            )
        } else {
            marker(world, color: palette.deep)
        }
    }

    mutating func marker(_ world: WorldPoint, color: Color) {
        let p = projection.point(world)
        context.fill(
            Path(ellipseIn: CGRect(x: p.x - 2.4 * scale, y: p.y - 1.5 * scale, width: 4.8 * scale, height: 3 * scale)),
            with: .color(color)
        )
    }

    mutating func lantern(_ world: WorldPoint) {
        let p = projection.point(WorldPoint(x: world.x + 0.3, y: world.y - 0.3, z: world.z))
        var post = Path()
        post.move(to: p)
        post.addLine(to: CGPoint(x: p.x, y: p.y - 17 * scale))
        context.stroke(post, with: .color(palette.deep), style: StrokeStyle(lineWidth: 1.2 * scale, lineCap: .round))
        let glow = CGRect(x: p.x - 9 * scale, y: p.y - 28 * scale, width: 18 * scale, height: 18 * scale)
        context.fill(Path(ellipseIn: glow), with: .radialGradient(
            Gradient(colors: [PostcardPalette.gold.opacity(0.45), PostcardPalette.gold.opacity(0)]),
            center: CGPoint(x: p.x, y: p.y - 19 * scale), startRadius: 0, endRadius: 9 * scale
        ))
        let lamp = CGRect(x: p.x - 2.6 * scale, y: p.y - 22.5 * scale, width: 5.2 * scale, height: 6 * scale)
        context.fill(Path(roundedRect: lamp, cornerRadius: 1.2 * scale), with: .color(PostcardPalette.gold))
        context.stroke(
            Path(roundedRect: lamp, cornerRadius: 1.2 * scale),
            with: .color(palette.deep),
            lineWidth: 0.7 * scale
        )
    }

    mutating func portal(_ world: WorldPoint, open: Bool) {
        let p = projection.point(world)
        if open {
            let glow = CGRect(x: p.x - 42 * scale, y: p.y - 66 * scale, width: 84 * scale, height: 84 * scale)
            context.fill(Path(ellipseIn: glow), with: .radialGradient(
                Gradient(colors: [palette.glow.opacity(0.75), palette.glow.opacity(0)]),
                center: CGPoint(x: p.x, y: p.y - 24 * scale), startRadius: 0, endRadius: 42 * scale
            ))
        }
        let rect = CGRect(x: p.x - 16 * scale, y: p.y - 47 * scale, width: 32 * scale, height: 49 * scale)
        let depth = rect.offsetBy(dx: 6 * scale, dy: -3 * scale)
        context.fill(arch(depth), with: .color(palette.deep))
        context.fill(arch(rect), with: .linearGradient(
            Gradient(colors: [PostcardPalette.ivory, palette.stoneLight]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        ))
        context.stroke(
            arch(rect.insetBy(dx: 2.2 * scale, dy: 2.2 * scale)),
            with: .color(palette.deep.opacity(0.28)),
            lineWidth: 0.7 * scale
        )
        let opening = CGRect(x: p.x - 8.5 * scale, y: p.y - 35 * scale, width: 17 * scale, height: 38 * scale)
        context.fill(arch(opening), with: .linearGradient(
            Gradient(colors: [open ? PostcardPalette.gold : palette.deep, open ? Color(hex: 0xFFF6D6) : palette.mist]),
            startPoint: CGPoint(x: p.x, y: opening.minY), endPoint: CGPoint(x: p.x, y: opening.maxY)
        ))
        if !open {
            for offset in [-9.0, 0.0, 9.0] {
                let bar = CGRect(
                    x: opening.minX,
                    y: p.y - 14 * scale + offset * scale,
                    width: opening.width,
                    height: 1.4 * scale
                )
                context.fill(Path(bar), with: .color(PostcardPalette.ivory.opacity(0.5)))
            }
        }
        let keystone = CGPoint(x: p.x, y: rect.minY + 5.5 * scale)
        polygon([
            CGPoint(x: keystone.x, y: keystone.y - 3 * scale), CGPoint(x: keystone.x + 2.4 * scale, y: keystone.y),
            CGPoint(x: keystone.x, y: keystone.y + 3 * scale), CGPoint(x: keystone.x - 2.4 * scale, y: keystone.y),
        ], color: open ? PostcardPalette.gold : palette.accent)
        let finial = CGPoint(x: p.x, y: rect.minY - 4 * scale)
        context.fill(
            Path(ellipseIn: CGRect(
                x: finial.x - 1.8 * scale,
                y: finial.y - 1.8 * scale,
                width: 3.6 * scale,
                height: 3.6 * scale
            )),
            with: .color(palette.accent)
        )
    }

    private func arch(_ rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.width / 2
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + radius), radius: radius,
            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    mutating func cypress(_ world: WorldPoint) {
        let p = projection.point(world)
        context.fill(
            Path(CGRect(x: p.x - scale, y: p.y - 10 * scale, width: 2 * scale, height: 11 * scale)),
            with: .color(palette.deep)
        )
        var shape = Path()
        shape.move(to: CGPoint(x: p.x, y: p.y - 30 * scale))
        shape.addCurve(
            to: CGPoint(x: p.x, y: p.y - 5 * scale),
            control1: CGPoint(x: p.x + 13 * scale, y: p.y - 9 * scale),
            control2: CGPoint(x: p.x + 6 * scale, y: p.y - 6 * scale)
        )
        shape.addCurve(
            to: CGPoint(x: p.x, y: p.y - 30 * scale),
            control1: CGPoint(x: p.x - 8 * scale, y: p.y - 4 * scale),
            control2: CGPoint(x: p.x - 8 * scale, y: p.y - 13 * scale)
        )
        context.fill(shape, with: .linearGradient(
            Gradient(colors: [palette.foliage.opacity(0.78), palette.foliage]),
            startPoint: CGPoint(x: p.x - 8 * scale, y: p.y), endPoint: CGPoint(x: p.x + 8 * scale, y: p.y)
        ))
        var shade = Path()
        shade.move(to: CGPoint(x: p.x, y: p.y - 30 * scale))
        shade.addCurve(
            to: CGPoint(x: p.x, y: p.y - 5 * scale),
            control1: CGPoint(x: p.x + 13 * scale, y: p.y - 9 * scale),
            control2: CGPoint(x: p.x + 6 * scale, y: p.y - 6 * scale)
        )
        shade.addCurve(
            to: CGPoint(x: p.x, y: p.y - 30 * scale),
            control1: CGPoint(x: p.x + 1.5 * scale, y: p.y - 10 * scale),
            control2: CGPoint(x: p.x + 2 * scale, y: p.y - 20 * scale)
        )
        context.fill(shade, with: .color(palette.deep.opacity(0.22)))
    }

    private func corners(_ point: WorldPoint, width: Double) -> [CGPoint] {
        [
            WorldPoint(x: point.x - width, y: point.y - width, z: point.z),
            WorldPoint(x: point.x + width, y: point.y - width, z: point.z),
            WorldPoint(x: point.x + width, y: point.y + width, z: point.z),
            WorldPoint(x: point.x - width, y: point.y + width, z: point.z),
        ].map(projection.point)
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private func polygonPath(_ points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }

    private mutating func polygon(_ points: [CGPoint], color: Color) {
        context.fill(polygonPath(points), with: .color(color))
    }

    private mutating func gradientPolygon(_ points: [CGPoint], from: Color, to: Color, top: Double, bottom: Double) {
        let x = points.first?.x ?? 0
        context.fill(polygonPath(points), with: .linearGradient(
            Gradient(colors: [from, to]),
            startPoint: CGPoint(x: x, y: top), endPoint: CGPoint(x: x, y: bottom)
        ))
    }
}

struct Traveler: View {
    let palette: PostcardPalette
    var walking = false

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            context.fill(
                Path(ellipseIn: CGRect(x: w * 0.16, y: h * 0.9, width: w * 0.7, height: h * 0.09)),
                with: .color(palette.deep.opacity(0.22))
            )
            var cloak = Path()
            cloak.move(to: CGPoint(x: w * 0.5, y: h * 0.04))
            cloak.addCurve(
                to: CGPoint(x: w * 0.9, y: h * 0.9),
                control1: CGPoint(x: w * 0.86, y: h * 0.2),
                control2: CGPoint(x: w * 0.66, y: h * 0.58)
            )
            cloak.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.9), control: CGPoint(x: w * 0.5, y: h * 1.02))
            cloak.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.04),
                control1: CGPoint(x: w * 0.3, y: h * 0.5),
                control2: CGPoint(x: w * 0.1, y: h * 0.26)
            )
            context.fill(
                cloak,
                with: .linearGradient(
                    Gradient(colors: [palette.accent, palette.deep, PostcardPalette.ink]),
                    startPoint: CGPoint(x: w * 0.2, y: 0),
                    endPoint: CGPoint(x: w * 0.9, y: h)
                )
            )
            var hem = Path()
            hem.move(to: CGPoint(x: w * 0.16, y: h * 0.86))
            hem.addQuadCurve(to: CGPoint(x: w * 0.86, y: h * 0.86), control: CGPoint(x: w * 0.5, y: h * 0.97))
            context.stroke(hem, with: .color(PostcardPalette.gold.opacity(0.7)), lineWidth: max(0.8, w * 0.03))
            var hood = Path()
            hood.move(to: CGPoint(x: w * 0.5, y: h * 0.04))
            hood.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.42), control: CGPoint(x: w * 0.84, y: h * 0.16))
            hood.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.42), control: CGPoint(x: w * 0.5, y: h * 0.56))
            hood.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.04), control: CGPoint(x: w * 0.16, y: h * 0.16))
            context.fill(hood, with: .color(palette.deep))
            context.fill(
                Path(ellipseIn: CGRect(x: w * 0.36, y: h * 0.26, width: w * 0.28, height: h * 0.17)),
                with: .color(Color(hex: 0xF3D2B4))
            )
            var scarf = Path()
            scarf.move(to: CGPoint(x: w * 0.26, y: h * 0.44))
            scarf.addQuadCurve(to: CGPoint(x: w * 0.74, y: h * 0.44), control: CGPoint(x: w * 0.5, y: h * 0.54))
            context.stroke(scarf, with: .color(PostcardPalette.ivory), lineWidth: max(1, w * 0.06))
            let stride = walking ? 0.1 : 0.06
            for x in [0.5 - stride - 0.04, 0.5 + stride - 0.02] {
                context.fill(
                    Path(
                        roundedRect: CGRect(x: w * x, y: h * 0.89, width: w * 0.07, height: h * 0.09),
                        cornerRadius: w * 0.02
                    ),
                    with: .color(PostcardPalette.ink)
                )
            }
        }
    }
}
