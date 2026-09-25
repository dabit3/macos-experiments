import CoreText
import SwiftUI

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
  }
}

struct Palette {
  let dark: Bool
  init(_ scheme: ColorScheme) { dark = scheme == .dark }
  var canvas: Color { Color(hex: dark ? 0x101E29 : 0xF3EEDA) }
  var surface: Color { Color(hex: dark ? 0x1B303D : 0xFFFAEB) }
  var raised: Color { Color(hex: dark ? 0x27424F : 0xFFFFFF) }
  var sunken: Color { Color(hex: dark ? 0x122630 : 0xE9E8D5) }
  var outline: Color { Color(hex: dark ? 0x385260 : 0xCFD5C4) }
  var text: Color { Color(hex: dark ? 0xFFF5DF : 0x173D3C) }
  var muted: Color { Color(hex: dark ? 0xBCCCD0 : 0x4B6763) }
  var accent: Color { Color(hex: dark ? 0xDFFF80 : 0x22594C) }
  var onAccent: Color { Color(hex: dark ? 0x182C29 : 0xF2FFC7) }
  var danger: Color { Color(hex: dark ? 0xFF5D5D : 0xD53838) }
  var boardLight: Color { Color(hex: dark ? 0xE8EDD7 : 0xFFF4D7) }
  var boardDark: Color { Color(hex: dark ? 0x78A8A1 : 0x8FB8A3) }
  func team(_ team: Team) -> Color {
    Color(hex: team == .tidal ? (dark ? 0x64DDC8 : 0x087F73) : (dark ? 0xFF8B71 : 0xB8442C))
  }
}

enum BrandFont {
  static func display(_ size: CGFloat) -> Font {
    .custom("BarlowCondensed-ExtraBold", size: size, relativeTo: .title)
  }
  static func body(_ size: CGFloat = 14) -> Font {
    .custom("Inter-Regular", size: size, relativeTo: .body)
  }
  static func register() {
    for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }
}

extension Path {
  mutating func m(_ x: CGFloat, _ y: CGFloat) { move(to: CGPoint(x: x, y: y)) }
  mutating func l(_ x: CGFloat, _ y: CGFloat) { addLine(to: CGPoint(x: x, y: y)) }
  mutating func q(_ cx: CGFloat, _ cy: CGFloat, _ x: CGFloat, _ y: CGFloat) {
    addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
  }
  mutating func c(
    _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat, _ y: CGFloat
  ) {
    addCurve(
      to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
  }
  mutating func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
    addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
  }
  mutating func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
    addRoundedRect(
      in: CGRect(x: x, y: y, width: w, height: h), cornerSize: CGSize(width: r, height: r))
  }
  mutating func base(_ w: CGFloat) {
    m(50 - w, 86)
    q(50 - w, 78, 56 - w, 78)
    l(44 + w, 78)
    q(50 + w, 78, 50 + w, 86)
    q(50 + w, 94, 44 + w, 94)
    l(56 - w, 94)
    q(50 - w, 94, 50 - w, 86)
    closeSubpath()
  }
}

enum PieceArtwork {
  static func body(_ kind: PieceKind) -> Path {
    var p = Path()
    switch kind {
    case .pawn:
      p.base(24)
      p.m(34, 78)
      p.q(38, 58, 44, 50)
      p.l(56, 50)
      p.q(62, 58, 66, 78)
      p.closeSubpath()
      p.rounded(38, 45, 24, 7, 3.5)
      p.circle(50, 32, 13)
    case .rook:
      p.base(28)
      p.m(31, 78)
      p.l(34, 40)
      p.l(66, 40)
      p.l(69, 78)
      p.closeSubpath()
      p.m(29, 40)
      p.l(29, 18)
      p.l(39, 18)
      p.l(39, 26)
      p.l(45, 26)
      p.l(45, 18)
      p.l(55, 18)
      p.l(55, 26)
      p.l(61, 26)
      p.l(61, 18)
      p.l(71, 18)
      p.l(71, 40)
      p.closeSubpath()
    case .knight:
      p.base(28)
      p.m(30, 78)
      p.c(30, 60, 38, 52, 44, 44)
      p.c(36, 46, 30, 44, 30, 38)
      p.c(30, 34, 34, 34, 37, 33)
      p.l(41, 28)
      p.c(43, 24, 50, 20, 52, 15)
      p.l(56, 22)
      p.l(62, 14)
      p.c(66, 22, 70, 30, 70, 44)
      p.c(70, 58, 70, 66, 70, 78)
      p.closeSubpath()
    case .bishop:
      p.base(26)
      p.m(34, 78)
      p.q(38, 62, 40, 56)
      p.l(60, 56)
      p.q(62, 62, 66, 78)
      p.closeSubpath()
      p.m(50, 22)
      p.c(64, 30, 66, 44, 60, 56)
      p.l(40, 56)
      p.c(34, 44, 36, 30, 50, 22)
      p.closeSubpath()
      p.circle(50, 16, 5)
    case .queen:
      p.base(29)
      p.m(31, 78)
      p.q(36, 60, 38, 48)
      p.l(62, 48)
      p.q(64, 60, 69, 78)
      p.closeSubpath()
      p.m(34, 48)
      p.l(26, 24)
      p.l(38, 38)
      p.l(42, 18)
      p.l(50, 36)
      p.l(58, 18)
      p.l(62, 38)
      p.l(74, 24)
      p.l(66, 48)
      p.closeSubpath()
      p.circle(26, 22, 3.6)
      p.circle(42, 15, 3.6)
      p.circle(58, 15, 3.6)
      p.circle(74, 22, 3.6)
    case .king:
      p.base(29)
      p.m(31, 78)
      p.q(36, 60, 38, 48)
      p.l(62, 48)
      p.q(64, 60, 69, 78)
      p.closeSubpath()
      p.m(34, 48)
      p.c(28, 40, 30, 30, 40, 30)
      p.l(60, 30)
      p.c(70, 30, 72, 40, 66, 48)
      p.closeSubpath()
      p.rounded(47, 8, 6, 22, 2)
      p.rounded(41, 14, 18, 6, 2)
    }
    return p
  }

  static func draw(_ piece: Piece, in context: GraphicsContext, size: CGSize) {
    var c = context
    let scale = min(size.width, size.height) / 100
    c.translateBy(x: (size.width - scale * 100) / 2, y: (size.height - scale * 100) / 2)
    c.scaleBy(x: scale, y: scale)
    let white = piece.color == .white
    let outline = Color(hex: white ? 0x263E45 : 0xD7F0DB)
    let body = body(piece.kind)
    c.fill(
      Path(ellipseIn: CGRect(x: 18, y: 87, width: 64, height: 10)),
      with: .color(.black.opacity(0.22)))
    c.fill(body.offsetBy(dx: 0, dy: 3), with: .color(Color(hex: 0x263E45)))
    let colors =
      white
      ? [Color.white, Color(hex: 0xFFF6DD), Color(hex: 0xDFCDA4)]
      : [Color(hex: 0x557887), Color(hex: 0x203844), Color(hex: 0x132931)]
    c.fill(
      body,
      with: .linearGradient(
        Gradient(colors: colors), startPoint: CGPoint(x: 20, y: 8), endPoint: CGPoint(x: 80, y: 94))
    )
    c.stroke(
      body, with: .color(outline),
      style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
    var bevel = c
    bevel.clip(to: body)
    bevel.stroke(
      body.offsetBy(dx: 1.8, dy: 2.2), with: .color(.white.opacity(white ? 0.85 : 0.3)),
      lineWidth: 2)
    var detail = Path()
    switch piece.kind {
    case .knight:
      c.fill(
        Path(ellipseIn: CGRect(x: 55.8, y: 27.8, width: 4.4, height: 4.4)), with: .color(outline))
      detail.m(62, 46)
      detail.l(60, 66)
    case .bishop:
      detail.m(50, 30)
      detail.l(50, 48)
      detail.m(40, 56)
      detail.l(60, 56)
    case .rook:
      detail.m(34, 40)
      detail.l(66, 40)
    case .queen, .king:
      detail.m(38, 48)
      detail.l(62, 48)
      detail.m(36, 56)
      detail.l(64, 56)
    case .pawn: break
    }
    c.stroke(detail, with: .color(outline), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
    var base = Path()
    base.m(30, 86)
    base.l(70, 86)
    c.stroke(
      base, with: .color(Color(hex: white ? 0xC2AE7D : 0x719992)),
      style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
  }
}

struct PieceGlyph: View {
  let piece: Piece
  var body: some View {
    Canvas { context, size in PieceArtwork.draw(piece, in: context, size: size) }
      .accessibilityLabel(
        "\(piece.color.label) \(piece.kind.label)\(piece.promoted ? ", promoted" : "")")
  }
}

struct SwapmateMark: View {
  @Environment(\.colorScheme) private var scheme
  var body: some View {
    Canvas { context, size in
      let palette = Palette(scheme)
      var c = context
      c.scaleBy(x: size.width / 100, y: size.height / 100)
      var first = Path()
      first.rounded(6, 6, 58, 58, 18)
      var second = Path()
      second.rounded(36, 36, 58, 58, 18)
      c.fill(first, with: .color(palette.team(.tidal)))
      c.fill(second, with: .color(palette.team(.ember)))
      var arrow = Path()
      arrow.addArc(
        center: CGPoint(x: 50, y: 50), radius: 22, startAngle: .degrees(135),
        endAngle: .degrees(-63), clockwise: true)
      arrow.m(58, 24)
      arrow.l(70, 30)
      arrow.l(62, 40)
      c.stroke(
        arrow, with: .color(palette.accent),
        style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
    }.accessibilityHidden(true)
  }
}

struct ArcadeBackdrop: View {
  @Environment(\.colorScheme) private var scheme
  var body: some View {
    let p = Palette(scheme)
    Canvas { c, size in
      c.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .linearGradient(
          Gradient(colors: [p.canvas, p.sunken, p.canvas]), startPoint: .zero,
          endPoint: CGPoint(x: size.width, y: size.height)))
      for y in stride(from: 20.0, to: size.height, by: 28) {
        for x in stride(from: 20.0, to: size.width, by: 28) {
          c.fill(
            Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
            with: .color(p.text.opacity(0.035)))
        }
      }
      for i in 0..<4 {
        let r = CGFloat(190 + i * 52)
        c.stroke(
          Path(
            ellipseIn: CGRect(
              x: size.width * 0.12 - r, y: size.height * 0.48 - r, width: 2 * r, height: 2 * r)),
          with: .color(p.team(.tidal).opacity(0.06)), lineWidth: 1)
      }
      var corner = Path()
      corner.m(size.width, size.height * 0.6)
      corner.l(size.width * 0.6, size.height)
      corner.l(size.width, size.height)
      corner.closeSubpath()
      c.fill(corner, with: .color(p.team(.ember).opacity(0.035)))
    }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
  }
}

struct ArenaIllustration: View {
  @Environment(\.colorScheme) private var scheme
  var body: some View {
    Canvas { context, size in
      let p = Palette(scheme)
      var c = context
      c.scaleBy(x: size.width / 480, y: size.height / 224)
      c.fill(
        Path(ellipseIn: CGRect(x: 35, y: 24, width: 400, height: 170)),
        with: .color(p.team(.tidal).opacity(0.10)))
      func arena(_ x: CGFloat, _ y: CGFloat, _ angle: Double, _ team: Team, _ piece: Piece) {
        var slab = c
        slab.translateBy(x: x, y: y)
        slab.rotate(by: .radians(angle))
        var path = Path()
        path.rounded(-78, -54, 156, 110, 16)
        slab.fill(path.offsetBy(dx: 0, dy: 12), with: .color(p.canvas))
        slab.fill(path, with: .color(p.team(team)))
        var grid = slab
        var clip = Path()
        clip.rounded(-72, -48, 144, 98, 10)
        grid.clip(to: clip)
        for row in 0..<4 {
          for col in 0..<6 {
            grid.fill(
              Path(CGRect(x: -72 + col * 24, y: -48 + row * 24, width: 24, height: 24)),
              with: .color(
                (row + col).isMultiple(of: 2) ? p.boardLight : p.team(team).opacity(0.45)))
          }
        }
        slab.rotate(by: .radians(-angle))
        slab.translateBy(x: -50, y: -117)
        PieceArtwork.draw(piece, in: slab, size: CGSize(width: 100, height: 128))
      }
      arena(148, 135, -0.15, .tidal, Piece(color: .white, kind: .knight))
      arena(330, 145, 0.16, .ember, Piece(color: .black, kind: .queen))
      var arrow = Path()
      arrow.m(188, 56)
      arrow.q(245, 14, 290, 53)
      arrow.m(278, 51)
      arrow.l(291, 54)
      arrow.l(288, 41)
      for point in [CGPoint(x: 58, y: 83), CGPoint(x: 410, y: 67), CGPoint(x: 247, y: 176)] {
        arrow.m(point.x - 4, point.y)
        arrow.l(point.x + 4, point.y)
        arrow.m(point.x, point.y - 4)
        arrow.l(point.x, point.y + 4)
      }
      c.stroke(arrow, with: .color(p.accent), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }.aspectRatio(2.15, contentMode: .fit).accessibilityHidden(true)
  }
}

struct ResultMedal: View {
  let color: Color
  let won: Bool
  var body: some View {
    ZStack {
      Canvas { c, size in
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        var star = Path()
        for i in 0..<32 {
          let a = Double(i) * .pi / 16
          let r = i.isMultiple(of: 2) ? 42.0 : 36.0
          let point = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
          if i == 0 { star.move(to: point) } else { star.addLine(to: point) }
        }
        star.closeSubpath()
        c.fill(star, with: .color(color))
        c.stroke(
          Path(ellipseIn: CGRect(x: center.x - 29, y: center.y - 29, width: 58, height: 58)),
          with: .color(.white.opacity(0.35)), lineWidth: 1.5)
      }
      Image(systemName: won ? "trophy.fill" : "shield.fill").font(.system(size: 36))
        .foregroundStyle(Color(hex: 0x101E29))
    }.frame(width: 88, height: 88).accessibilityHidden(true)
  }
}

struct Panel<Content: View>: View {
  @Environment(\.colorScheme) private var scheme
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette(scheme).surface, in: RoundedRectangle(cornerRadius: 20))
      .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette(scheme).outline, lineWidth: 1))
  }
}

struct ArcadeButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var scheme
  @Environment(\.isEnabled) private var enabled
  var primary = false
  func makeBody(configuration: Configuration) -> some View {
    let p = Palette(scheme)
    configuration.label.font(.custom("Inter-SemiBold", size: 14))
      .padding(.horizontal, 16).padding(.vertical, 12)
      .foregroundStyle(primary ? p.onAccent : p.text)
      .background(primary ? p.accent : p.raised, in: RoundedRectangle(cornerRadius: 10))
      .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
  }
}
