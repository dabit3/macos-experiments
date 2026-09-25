import SwiftUI

enum Palette {
  static let ink = Color(red: 0.035, green: 0.075, blue: 0.12)
  static let sky = Color(red: 0.09, green: 0.17, blue: 0.23)
  static let cream = Color(red: 0.95, green: 0.90, blue: 0.77)
  static let mint = Color(red: 0.60, green: 0.76, blue: 0.65)
  static let coral = Color(red: 0.98, green: 0.49, blue: 0.39)
  static let brick = Color(red: 0.46, green: 0.28, blue: 0.25)
  static let roof = Color(red: 0.67, green: 0.43, blue: 0.33)
  static let muted = Color(red: 0.61, green: 0.69, blue: 0.71)
}

struct Pen {
  var context: GraphicsContext

  func oval(_ rect: CGRect, _ color: Color) {
    context.fill(Path(ellipseIn: rect), with: .color(color))
  }

  func box(_ rect: CGRect, _ color: Color, radius: CGFloat = 0) {
    context.fill(
      Path(roundedRect: rect, cornerRadius: radius), with: .color(color))
  }

  func shape(_ points: [CGPoint], _ color: Color) {
    guard let first = points.first else { return }
    var path = Path()
    path.move(to: first)
    for point in points.dropFirst() { path.addLine(to: point) }
    path.closeSubpath()
    context.fill(path, with: .color(color))
  }

  func line(_ points: [CGPoint], _ color: Color, width: CGFloat = 1) {
    guard let first = points.first else { return }
    var path = Path()
    path.move(to: first)
    for point in points.dropFirst() { path.addLine(to: point) }
    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
  }
}

enum Illustration {
  static func raccoon(_ context: GraphicsContext, snacks: Int, happy: Bool) {
    let p = Pen(context: context)
    let fur = Color(red: 0.66, green: 0.72, blue: 0.77)
    let light = Color(red: 0.85, green: 0.86, blue: 0.82)
    let mask = Color(red: 0.12, green: 0.17, blue: 0.23)
    p.oval(CGRect(x: 13, y: 86, width: 79, height: 10), .black.opacity(0.18))
    var tailContext = context
    tailContext.translateBy(x: 77, y: 74)
    tailContext.rotate(by: .degrees(-32))
    let tail = Pen(context: tailContext)
    tail.oval(CGRect(x: -8, y: -10, width: 49, height: 24), fur)
    for index in 0..<3 {
      tail.oval(CGRect(x: CGFloat(index * 13), y: -10, width: 9, height: 24), mask)
    }
    p.oval(CGRect(x: 23, y: 48, width: 53, height: 43), fur)
    p.oval(CGRect(x: 35, y: 53, width: 28, height: 35), light)
    p.oval(CGRect(x: 23, y: 83, width: 23, height: 9), mask)
    p.oval(CGRect(x: 54, y: 83, width: 23, height: 9), mask)
    p.shape(
      [CGPoint(x: 17, y: 29), CGPoint(x: 15, y: 3), CGPoint(x: 40, y: 18)], fur)
    p.shape(
      [CGPoint(x: 62, y: 17), CGPoint(x: 85, y: 3), CGPoint(x: 85, y: 32)], fur)
    p.shape(
      [CGPoint(x: 22, y: 21), CGPoint(x: 20, y: 10), CGPoint(x: 33, y: 19)], mask)
    p.shape(
      [CGPoint(x: 68, y: 19), CGPoint(x: 80, y: 10), CGPoint(x: 80, y: 23)], mask)
    p.oval(CGRect(x: 14, y: 15, width: 73, height: 47), fur)
    p.shape(
      [
        CGPoint(x: 14, y: 33), CGPoint(x: 32, y: 25), CGPoint(x: 49, y: 33),
        CGPoint(x: 67, y: 25), CGPoint(x: 88, y: 34), CGPoint(x: 78, y: 48),
        CGPoint(x: 61, y: 49), CGPoint(x: 49, y: 41), CGPoint(x: 34, y: 49),
        CGPoint(x: 22, y: 47),
      ], mask)
    p.oval(CGRect(x: 35, y: 41, width: 30, height: 19), light)
    if happy {
      p.line(
        [CGPoint(x: 28, y: 37), CGPoint(x: 34, y: 33), CGPoint(x: 39, y: 37)], .white,
        width: 2.6)
      p.line(
        [CGPoint(x: 61, y: 37), CGPoint(x: 66, y: 33), CGPoint(x: 72, y: 37)], .white,
        width: 2.6)
    } else {
      p.oval(CGRect(x: 28, y: 31, width: 11, height: 12), .white)
      p.oval(CGRect(x: 61, y: 31, width: 11, height: 12), .white)
      p.oval(CGRect(x: 33, y: 33, width: 5, height: 7), Palette.ink)
      p.oval(CGRect(x: 66, y: 33, width: 5, height: 7), Palette.ink)
      p.oval(CGRect(x: 34, y: 33, width: 2, height: 2), .white)
      p.oval(CGRect(x: 67, y: 33, width: 2, height: 2), .white)
    }
    p.shape(
      [CGPoint(x: 44, y: 44), CGPoint(x: 57, y: 44), CGPoint(x: 50, y: 51)], mask)
    p.line([CGPoint(x: 46, y: 54), CGPoint(x: 51, y: 56), CGPoint(x: 56, y: 53)], mask)
    p.oval(CGRect(x: 19, y: 45, width: 10, height: 4), Palette.coral.opacity(0.6))
    p.oval(CGRect(x: 73, y: 45, width: 10, height: 4), Palette.coral.opacity(0.6))
    p.shape(
      [CGPoint(x: 25, y: 57), CGPoint(x: 72, y: 58), CGPoint(x: 67, y: 66), CGPoint(x: 28, y: 64)],
      Palette.mint)
    p.shape(
      [CGPoint(x: 66, y: 59), CGPoint(x: 90, y: 59), CGPoint(x: 82, y: 70), CGPoint(x: 69, y: 65)],
      Palette.mint)
    if snacks > 0 {
      for index in 0..<min(snacks, 7) {
        var snackContext = context
        snackContext.translateBy(x: 76 + CGFloat(index % 2) * 2, y: 73 - CGFloat(index) * 12)
        snackContext.scaleBy(x: 0.68, y: 0.68)
        snack(snackContext, kind: index)
      }
    }
    p.oval(CGRect(x: 22, y: 69, width: 19, height: 10), mask)
    p.line([CGPoint(x: 65, y: 72), CGPoint(x: 85, y: 81)], fur, width: 11)
    p.oval(CGRect(x: 82, y: 79, width: 15, height: 8), mask)
  }

  static func snack(_ context: GraphicsContext, kind: Int = 0) {
    context.draw(Image("Snack\(kind % 3)"), in: CGRect(x: 0, y: 0, width: 36, height: 20))
  }

  static func planter(_ context: GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat = 1) {
    var c = context
    c.translateBy(x: x, y: y)
    c.scaleBy(x: scale, y: scale)
    let p = Pen(context: c)
    p.box(
      CGRect(x: 0, y: 0, width: 31, height: 12), Color(red: 0.24, green: 0.46, blue: 0.43),
      radius: 2)
    p.box(CGRect(x: -2, y: 0, width: 35, height: 4), Palette.mint, radius: 1)
    for index in 0..<5 {
      let x = CGFloat(index * 6 + 3)
      p.line([CGPoint(x: x, y: 1), CGPoint(x: x - 2, y: -13)], Palette.mint, width: 2)
      p.oval(CGRect(x: x - 8, y: -14, width: 10, height: 5), Palette.mint)
      p.oval(
        CGRect(x: x - 1, y: -9, width: 9, height: 5), Color(red: 0.39, green: 0.66, blue: 0.54))
    }
  }

  static func tower(_ context: GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat = 1) {
    var c = context
    c.translateBy(x: x, y: y)
    c.scaleBy(x: scale, y: scale)
    let p = Pen(context: c)
    p.line([CGPoint(x: 8, y: 33), CGPoint(x: 3, y: 64)], Palette.cream, width: 3)
    p.line([CGPoint(x: 37, y: 33), CGPoint(x: 43, y: 64)], Palette.cream, width: 3)
    p.line([CGPoint(x: 5, y: 47), CGPoint(x: 42, y: 61)], Palette.cream, width: 1)
    p.line([CGPoint(x: 40, y: 47), CGPoint(x: 4, y: 61)], Palette.cream, width: 1)
    p.box(CGRect(x: 0, y: 3, width: 45, height: 37), Palette.mint, radius: 4)
    for index in 0..<4 {
      p.box(
        CGRect(x: CGFloat(index * 12 + 3), y: 5, width: 5, height: 32), Palette.ink.opacity(0.20))
    }
    p.oval(CGRect(x: 0, y: -2, width: 45, height: 12), Palette.mint)
    p.shape(
      [CGPoint(x: -4, y: 4), CGPoint(x: 22, y: -12), CGPoint(x: 49, y: 4)], Palette.cream)
    p.line([CGPoint(x: -1, y: 15), CGPoint(x: 46, y: 15)], Palette.cream.opacity(0.7), width: 2)
    p.line([CGPoint(x: -1, y: 32), CGPoint(x: 46, y: 32)], Palette.cream.opacity(0.7), width: 2)
  }

  static func roof(
    _ context: GraphicsContext, center: CGPoint, width: CGFloat, garden: Bool, id: Int
  ) {
    var c = context
    c.translateBy(x: center.x, y: center.y)
    let p = Pen(context: c)
    let w = width / 2
    p.box(CGRect(x: -w + 4, y: 5, width: width, height: 51), .black.opacity(0.16), radius: 5)
    p.shape(
      [CGPoint(x: -w, y: 1), CGPoint(x: w, y: 1), CGPoint(x: w, y: 43), CGPoint(x: -w, y: 43)],
      id % 2 == 0 ? Palette.brick : Color(red: 0.56, green: 0.29, blue: 0.31))
    p.shape(
      [
        CGPoint(x: w, y: 1), CGPoint(x: w + 9, y: -7), CGPoint(x: w + 9, y: 35),
        CGPoint(x: w, y: 43),
      ],
      Palette.ink.opacity(0.6))
    for row in 0..<6 {
      let y = CGFloat(row * 7 + 4)
      p.line(
        [CGPoint(x: -w, y: y), CGPoint(x: w, y: y)], Palette.cream.opacity(0.07), width: 0.6)
      for column in 0..<5 {
        let x = -w + CGFloat(column) * 18 + (row.isMultiple(of: 2) ? 0 : 9)
        if x < w {
          p.line(
            [CGPoint(x: x, y: y), CGPoint(x: x, y: y + 6)],
            Palette.ink.opacity(0.17), width: 0.6)
        }
      }
    }
    p.shape(
      [
        CGPoint(x: -w, y: -21), CGPoint(x: -w + 9, y: -29), CGPoint(x: w + 9, y: -29),
        CGPoint(x: w + 9, y: -7), CGPoint(x: w, y: 1), CGPoint(x: -w, y: 1),
      ],
      Palette.roof)
    p.box(
      CGRect(x: -w + 5, y: -23, width: width - 7, height: 19),
      garden ? Color(red: 0.28, green: 0.44, blue: 0.41) : Palette.brick, radius: 2)
    for index in 0..<45 {
      let x = -w + 6 + CGFloat((index * 17 + id * 7) % 101) / 101 * (width - 10)
      let y = -22 + CGFloat((index * 13) % 17)
      p.line(
        [CGPoint(x: x, y: y), CGPoint(x: x + 2, y: y)],
        Palette.cream.opacity(0.11), width: 0.7)
    }
    p.line(
      [CGPoint(x: -w, y: 1), CGPoint(x: w, y: 1), CGPoint(x: w + 9, y: -7)],
      Palette.cream.opacity(0.42), width: 2)
    for index in 0..<3 {
      let x = -w + 10 + CGFloat(index) * (width - 15) / 3
      p.box(CGRect(x: x, y: 12, width: 10, height: 16), Palette.ink, radius: 2)
      p.box(
        CGRect(x: x + 2, y: 13, width: 6, height: 12),
        (index + id) % 3 == 0 ? Palette.cream : Palette.cream.opacity(0.22), radius: 1)
      p.line([CGPoint(x: x, y: 21), CGPoint(x: x + 10, y: 21)], Palette.brick)
    }
    p.line([CGPoint(x: -w + 8, y: 36), CGPoint(x: -w + 24, y: 36)], Palette.roof.opacity(0.5))
    if garden { planter(c, x: -w + 5, y: -17, scale: 0.55) }
  }
}

struct RaccoonArt: View {
  var snacks = 1
  var happy = false

  var body: some View {
    Canvas { context, size in
      var c = context
      c.scaleBy(x: size.width / 100, y: size.height / 100)
      Pen(context: c).oval(CGRect(x: 40, y: 92, width: 28, height: 3), .black.opacity(0.25))
      c.draw(Image("RaccoonPortrait"), in: CGRect(x: -5, y: 6, width: 96, height: 96))
      for index in 0..<min(max(snacks, 0), 7) {
        var snackContext = c
        snackContext.translateBy(x: 74 + CGFloat(index % 2), y: 39 - CGFloat(index) * 6.2)
        snackContext.scaleBy(x: 0.66, y: 0.66)
        Illustration.snack(snackContext, kind: index)
      }
    }
    .accessibilityHidden(true)
  }
}

struct CityBackdrop: View {
  var dawn = false
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        LinearGradient(
          colors: [
            Palette.ink, Palette.sky,
            dawn
              ? Color(red: 0.56, green: 0.35, blue: 0.39)
              : Color(red: 0.13, green: 0.23, blue: 0.27),
          ],
          startPoint: .top, endPoint: .bottom)
        Canvas { context, size in
          let p = Pen(context: context)
          for index in 0..<2400 {
            let x = CGFloat((index * 127 + 53) % 997) / 997 * size.width
            let y = CGFloat((index * 331 + 71) % 991) / 991 * size.height
            p.oval(
              CGRect(x: x, y: y, width: 0.7, height: 0.7),
              Palette.cream.opacity(index.isMultiple(of: 3) ? 0.055 : 0.025))
          }
          for index in 0..<65 {
            let x = CGFloat((index * 79 + 13) % 397) / 397 * size.width
            let y = CGFloat((index * 47 + 23) % 431) / 800 * size.height
            let diameter: CGFloat = index % 6 == 0 ? 2.2 : 1.1
            p.oval(
              CGRect(x: x, y: y, width: diameter, height: diameter),
              Palette.cream.opacity(index % 3 == 0 ? 0.6 : 0.24))
          }
          p.oval(
            CGRect(x: size.width - 66, y: size.height * 0.28, width: 24, height: 24),
            Palette.cream.opacity(0.45))
          p.oval(
            CGRect(x: size.width - 58, y: size.height * 0.28 - 3, width: 22, height: 22),
            Palette.sky)
          for layer in 0..<2 {
            for index in 0..<9 {
              let width = size.width / 7
              let x = CGFloat(index) * width - 20 + CGFloat(layer * 10)
              let height = CGFloat(55 + (index * 39 + layer * 23) % 110)
              let base = size.height * (layer == 0 ? 0.89 : 1.0)
              let color = layer == 0 ? Palette.ink.opacity(0.10) : Palette.ink.opacity(0.16)
              p.box(CGRect(x: x, y: base - height, width: width - 3, height: height), color)
              p.box(CGRect(x: x + 10, y: base - height - 9, width: 8, height: 12), color)
              for row in 0..<4 {
                for column in 0..<2 {
                  if (row + column + index) % 3 != 0 {
                    p.box(
                      CGRect(
                        x: x + 12 + CGFloat(column * 19), y: base - height + 15 + CGFloat(row * 22),
                        width: 5, height: 8),
                      Palette.cream.opacity(layer == 0 ? 0.025 : 0.04), radius: 1)
                  }
                }
              }
            }
          }
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}

struct HeroScene: View {
  var celebration = false
  var snacks = 4
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      let w = geometry.size.width
      let h = geometry.size.height
      TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { timeline in
        let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
        ZStack {
          Image("TowerScene")
            .resizable()
            .scaledToFill()
            .frame(width: w, height: h)
            .clipped()
            .mask {
              LinearGradient(
                stops: [
                  .init(color: .clear, location: 0),
                  .init(color: .white, location: 0.15),
                  .init(color: .white, location: 0.85),
                  .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
          Canvas { context, size in
            let p = Pen(context: context)
            for index in 0..<(celebration ? 13 : 5) {
              let phase = time * 0.3 + Double(index)
              let x = w * CGFloat(0.10 + Double((index * 31) % 80) / 100)
              let y = h * CGFloat(0.25 + Double((index * 17) % 60) / 100) + CGFloat(sin(phase)) * 5
              p.oval(
                CGRect(x: x, y: y, width: 2, height: 2),
                Palette.cream.opacity(0.4 + sin(phase) * 0.3))
            }
          }
          RaccoonArt(snacks: snacks, happy: celebration)
            .frame(width: min(w * 0.72, h * 0.95), height: min(w * 0.72, h * 0.95))
            .rotationEffect(.degrees(reduceMotion ? 0 : sin(time * 1.7) * 0.8), anchor: .bottom)
            .position(x: w * 0.48, y: h * 0.46)
        }
      }
    }
    .accessibilityHidden(true)
  }
}
