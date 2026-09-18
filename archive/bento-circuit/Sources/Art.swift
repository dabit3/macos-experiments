import SwiftUI

enum Palette {
  static let paper = Color(red: 0.96, green: 0.94, blue: 0.88)
  static let cream = Color(red: 1, green: 0.98, blue: 0.93)
  static let ink = Color(red: 0.12, green: 0.21, blue: 0.18)
  static let muted = Color(red: 0.39, green: 0.44, blue: 0.37)
  static let orange = Color(red: 0.73, green: 0.23, blue: 0.12)
  static let sage = Color(red: 0.70, green: 0.76, blue: 0.62)
  static let wood = Color(red: 0.68, green: 0.43, blue: 0.25)
  static let gold = Color(red: 0.70, green: 0.53, blue: 0.27)
  static let line = Color(red: 0.81, green: 0.80, blue: 0.72)
}

struct PaperBackground: View {
  var body: some View {
    Palette.paper.overlay {
      Canvas { context, size in
        for index in 0..<2200 {
          let x = CGFloat((index * 137 + 17) % 997) / 997 * size.width
          let y = CGFloat((index * 263 + 31) % 991) / 991 * size.height
          context.fill(
            Path(ellipseIn: CGRect(x: x, y: y, width: 0.8, height: 1.3)),
            with: .color(Palette.ink.opacity(index.isMultiple(of: 3) ? 0.08 : 0.035)))
        }
      }.allowsHitTesting(false)
    }.ignoresSafeArea()
  }
}

struct MicroLabel: View {
  let text: String
  var color = Palette.muted
  var body: some View {
    Text(text).font(.system(size: 9, weight: .semibold, design: .monospaced))
      .tracking(1.8).foregroundStyle(color)
  }
}

struct CircuitMark: View {
  var color = Palette.orange
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 9).stroke(color, lineWidth: 1.6)
      HStack(spacing: 4) {
        VStack(spacing: 4) {
          RoundedRectangle(cornerRadius: 2).fill(color)
          RoundedRectangle(cornerRadius: 2).fill(color)
        }
        RoundedRectangle(cornerRadius: 2).fill(color)
      }.padding(7)
    }.frame(width: 33, height: 33).accessibilityHidden(true)
  }
}

struct PackingSeal: View {
  var title = "MADE"
  var subtitle = "TO FIT"
  var color = Palette.orange
  var body: some View {
    ZStack {
      Circle().stroke(color, lineWidth: 1)
      Circle().stroke(color.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [1, 3])).padding(
        4)
      VStack(spacing: 2) {
        Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2)
        Rectangle().fill(color).frame(width: 30, height: 0.5)
        Text(subtitle).font(.system(size: 11, weight: .bold, design: .serif))
      }
    }.foregroundStyle(color).frame(width: 62, height: 62).accessibilityHidden(true)
  }
}

struct Perforation: View {
  var color = Palette.line
  var body: some View {
    Line().stroke(color, style: StrokeStyle(lineWidth: 1, dash: [2, 4])).frame(height: 1)
      .accessibilityHidden(true)
  }
  private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
      Path { path in
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
      }
    }
  }
}

struct FoodArt: View {
  let ingredient: Ingredient
  var seed = 0
  var body: some View {
    Image("Food-\(ingredient.rawValue)").resizable().scaledToFit()
      .rotationEffect(.degrees(Double(seed % 3 - 1) * 5))
      .shadow(color: Palette.ink.opacity(0.24), radius: 1.5, x: 0, y: 2)
      .accessibilityHidden(true)
  }
}

struct FuroshikiCloth: View {
  var body: some View {
    Palette.sage.opacity(0.55).overlay {
      Canvas { context, size in
        for row in 0..<14 {
          for column in 0..<18 {
            let center = CGPoint(x: CGFloat(column * 28 + (row % 2) * 14), y: CGFloat(row * 16))
            for radius in [6.0, 10.0, 14.0] {
              var path = Path()
              path.addArc(
                center: center, radius: radius, startAngle: .degrees(180),
                endAngle: .degrees(0), clockwise: false)
              context.stroke(path, with: .color(Palette.cream.opacity(0.6)), lineWidth: 0.8)
            }
          }
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 5))
    .overlay(
      RoundedRectangle(cornerRadius: 4).stroke(Palette.cream.opacity(0.65), lineWidth: 1).padding(5)
    )
    .shadow(color: Palette.ink.opacity(0.10), radius: 3, y: 4)
  }
}

struct BentoFrame: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 22)
      .fill(
        LinearGradient(
          colors: [Color(red: 0.33, green: 0.23, blue: 0.17), Palette.ink, .black.opacity(0.92)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 20).stroke(Palette.gold.opacity(0.85), lineWidth: 1).padding(
          2)
        RoundedRectangle(cornerRadius: 16)
          .fill(
            LinearGradient(
              colors: [Color(red: 0.84, green: 0.67, blue: 0.45), Palette.wood],
              startPoint: .top, endPoint: .bottom)
          ).padding(7)
        Canvas { context, size in
          for index in 0..<90 {
            let y = CGFloat(index) / 90 * size.height
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addQuadCurve(
              to: CGPoint(x: size.width, y: y + 2),
              control: CGPoint(x: size.width * 0.4, y: y + CGFloat(index % 4)))
            context.stroke(path, with: .color(Palette.ink.opacity(0.08)), lineWidth: 0.5)
          }
        }.clipShape(RoundedRectangle(cornerRadius: 15)).padding(8)
        RoundedRectangle(cornerRadius: 10).fill(Palette.ink.opacity(0.45)).padding(13)
      }
      .shadow(color: .black.opacity(0.19), radius: 1, y: 4)
      .shadow(color: Palette.ink.opacity(0.20), radius: 13, x: 3, y: 17)
      .accessibilityHidden(true)
  }
}

struct PolyominoArt: View {
  let piece: FoodPiece
  var turns = 0
  let cellSize: CGFloat
  var selected = false
  var showLetter = false
  var decorative = false

  var body: some View {
    let cells = piece.rotated(turns)
    let width = (cells.map(\.x).max() ?? 0) + 1
    let height = (cells.map(\.y).max() ?? 0) + 1
    ZStack(alignment: .topLeading) {
      ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
        RoundedRectangle(cornerRadius: cellSize * 0.12)
          .fill(
            LinearGradient(
              colors: piece.ingredient.isSweet
                ? [
                  Color(red: 0.93, green: 0.84, blue: 0.63),
                  Color(red: 0.84, green: 0.71, blue: 0.47),
                ]
                : [Palette.sage, Color(red: 0.50, green: 0.61, blue: 0.43)],
              startPoint: .topLeading, endPoint: .bottomTrailing)
          )
          .opacity(decorative ? 0 : 1)
          .frame(width: cellSize - 1, height: cellSize - 1)
          .overlay {
            FoodArt(ingredient: piece.ingredient, seed: index)
              .padding(decorative ? -cellSize * 0.06 : -cellSize * 0.02)
          }
          .position(x: (CGFloat(cell.x) + 0.5) * cellSize, y: (CGFloat(cell.y) + 0.5) * cellSize)
      }
      if !decorative {
        Canvas { context, _ in
          let set = Set(cells)
          var path = Path()
          for cell in cells {
            let x = CGFloat(cell.x) * cellSize
            let y = CGFloat(cell.y) * cellSize
            let edges: [(Cell, CGPoint, CGPoint)] = [
              (Cell(x: cell.x, y: cell.y - 1), CGPoint(x: x, y: y), CGPoint(x: x + cellSize, y: y)),
              (
                Cell(x: cell.x + 1, y: cell.y), CGPoint(x: x + cellSize, y: y),
                CGPoint(x: x + cellSize, y: y + cellSize)
              ),
              (
                Cell(x: cell.x, y: cell.y + 1), CGPoint(x: x + cellSize, y: y + cellSize),
                CGPoint(x: x, y: y + cellSize)
              ),
              (Cell(x: cell.x - 1, y: cell.y), CGPoint(x: x, y: y + cellSize), CGPoint(x: x, y: y)),
            ]
            for (neighbor, start, end) in edges where !set.contains(neighbor) {
              path.move(to: start)
              path.addLine(to: end)
            }
          }
          context.stroke(
            path, with: .color(selected ? Palette.orange : Palette.ink.opacity(0.65)),
            style: StrokeStyle(lineWidth: selected ? 3 : 1.2, lineCap: .round, lineJoin: .round))
        }
      }
      if showLetter, let marked = cells.first {
        Text(piece.id).font(
          .system(size: max(9, cellSize * 0.20), weight: .bold, design: .monospaced)
        )
        .foregroundStyle(Palette.cream).padding(3)
        .background(Palette.ink, in: RoundedRectangle(cornerRadius: 3))
        .offset(x: CGFloat(marked.x) * cellSize + 3, y: CGFloat(marked.y) * cellSize + 3)
      }
    }
    .frame(width: CGFloat(width) * cellSize, height: CGFloat(height) * cellSize)
    .accessibilityHidden(true)
  }
}

struct LunchIllustration: View {
  var ribbon = false
  var body: some View {
    let lunch = LunchBook.all[2]
    GeometryReader { geometry in
      let cell = (geometry.size.width - 34) / 5
      ZStack {
        BentoFrame()
        HStack(spacing: 4) {
          RoundedRectangle(cornerRadius: 6).fill(Palette.sage)
          RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.88, green: 0.78, blue: 0.55))
            .frame(width: cell * 2)
        }.padding(16)
        Image("Food-shiso").resizable().scaledToFit().frame(width: cell * 2.3)
          .rotationEffect(.degrees(-35)).offset(x: -cell * 1.2, y: -cell * 0.8)
        ZStack(alignment: .topLeading) {
          ForEach(lunch.pieces) { piece in
            PolyominoArt(piece: piece, cellSize: cell, decorative: true)
              .offset(x: CGFloat(piece.solution.x) * cell, y: CGFloat(piece.solution.y) * cell)
          }
          Rectangle().fill(Palette.ink.gradient).frame(width: 5, height: cell * 4 + 3)
            .overlay(
              Rectangle().fill(Palette.gold.opacity(0.5)).frame(width: 1), alignment: .leading
            )
            .offset(x: cell * 3 - 2.5)
        }.frame(width: cell * 5, height: cell * 4, alignment: .topLeading)
        if ribbon { ParcelRibbon() }
      }
    }.aspectRatio(1.2, contentMode: .fit).accessibilityHidden(true)
  }
}

struct ParcelRibbon: View {
  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Rectangle().fill(Palette.orange.gradient).frame(width: 20)
          .overlay {
            HStack {
              Color.white.opacity(0.25).frame(width: 1)
              Spacer()
              Color.black.opacity(0.16).frame(width: 1)
            }.padding(.horizontal, 3)
          }
        Rectangle().fill(Palette.orange.gradient).frame(height: 17)
        ForEach([-1.0, 1.0], id: \.self) { direction in
          Ellipse().fill(Palette.orange.gradient)
            .overlay(Ellipse().stroke(Palette.cream.opacity(0.5), lineWidth: 1.5))
            .frame(width: 44, height: 23)
            .rotationEffect(.degrees(direction * -32)).offset(x: direction * 20, y: -12)
        }
        RoundedRectangle(cornerRadius: 4).fill(Palette.orange.gradient).frame(width: 19, height: 20)
          .overlay(
            RoundedRectangle(cornerRadius: 3).stroke(Palette.cream.opacity(0.4), lineWidth: 1))
      }.frame(width: proxy.size.width, height: proxy.size.height)
    }.shadow(color: .black.opacity(0.3), radius: 3, y: 4).accessibilityHidden(true)
  }
}

struct PrimaryButton: ButtonStyle {
  var light = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 15, weight: .semibold))
      .frame(maxWidth: .infinity).frame(minHeight: 56)
      .foregroundStyle(light ? Palette.ink : Palette.cream)
      .background(light ? Palette.cream : Palette.orange, in: RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 5)
          .stroke(light ? Palette.line : Palette.cream.opacity(0.3), lineWidth: 0.7).padding(4)
      )
      .compositingGroup()
      .shadow(
        color: (light ? Palette.ink : Palette.orange).opacity(0.16),
        radius: 0, y: configuration.isPressed ? 0 : 3
      )
      .offset(y: configuration.isPressed ? 2 : 0).opacity(configuration.isPressed ? 0.85 : 1)
  }
}

struct IconButton: View {
  let symbol: String
  let label: String
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 16, weight: .medium))
        .frame(width: 44, height: 44)
        .background(Palette.cream.opacity(0.7), in: Circle())
        .overlay(Circle().stroke(Palette.line, lineWidth: 0.8).padding(3))
    }.foregroundStyle(Palette.ink).accessibilityLabel(label).accessibilityIdentifier(label)
  }
}

struct ControlKey: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(Palette.cream.opacity(enabled ? 1 : 0.35))
      .background(
        configuration.isPressed ? Palette.cream.opacity(0.13) : .clear,
        in: RoundedRectangle(cornerRadius: 5))
  }
}
