import SwiftUI

enum MuseumType {
  static func display(_ size: CGFloat) -> Font {
    .custom("Baskerville", size: size, relativeTo: .title)
  }

  static func italic(_ size: CGFloat) -> Font {
    .custom("Baskerville-Italic", size: size, relativeTo: .title)
  }
}

struct MuseumAtmosphere: View {
  var body: some View {
    ZStack {
      Palette.ink
      RadialGradient(
        colors: [Palette.stone.opacity(0.48), .clear], center: .topTrailing,
        startRadius: 0, endRadius: 580)
      Canvas { context, size in
        for index in 0..<140 {
          let x = CGFloat((index * 137 + 29) % 997) / 997 * size.width
          let y = CGFloat((index * 233 + 71) % 991) / 991 * size.height
          context.fill(
            Path(ellipseIn: CGRect(x: x, y: y, width: 0.7, height: 0.7)),
            with: .color(Palette.paper.opacity(0.09)))
        }
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct DecoRule: View {
  var color = Palette.gold
  var body: some View {
    HStack(spacing: 8) {
      Rectangle().fill(color.opacity(0.3)).frame(height: 0.5)
      Diamond().stroke(color.opacity(0.75), lineWidth: 0.8).frame(width: 5, height: 8)
      Rectangle().fill(color.opacity(0.3)).frame(height: 0.5)
    }
    .accessibilityHidden(true)
  }
}

struct MuseumEmblem: View {
  var body: some View {
    ZStack {
      Circle().stroke(Palette.gold.opacity(0.55), lineWidth: 0.7)
      Circle().stroke(Palette.gold.opacity(0.22), lineWidth: 0.5).padding(4)
      Text("M").font(MuseumType.display(22)).offset(y: 1)
      Diamond().fill(Palette.gold).frame(width: 3, height: 5).offset(y: 15)
    }
    .foregroundStyle(Palette.gold)
    .frame(width: 42, height: 42)
    .accessibilityHidden(true)
  }
}

struct EngravedFrame: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addRect(rect.insetBy(dx: 1, dy: 1))
    path.addRect(rect.insetBy(dx: 5, dy: 5))
    for x in [rect.minX + 10, rect.maxX - 10] {
      for y in [rect.minY + 10, rect.maxY - 10] {
        path.addPath(
          Diamond().path(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)))
      }
    }
    return path
  }
}

struct MuseumHero: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false
  var body: some View {
    GeometryReader { geometry in
      Image("MuseumHero")
        .resizable()
        .scaledToFill()
        .frame(width: geometry.size.width, height: geometry.size.height)
        .scaleEffect(appeared && !reduceMotion ? 1.025 : 1)
        .overlay(alignment: .bottom) {
          LinearGradient(
            colors: [.clear, Palette.ink.opacity(0.35), Palette.ink],
            startPoint: .top, endPoint: .bottom
          ).frame(height: geometry.size.height * 0.26)
        }
        .clipped()
        .onAppear {
          withAnimation(reduceMotion ? nil : .easeOut(duration: 4)) { appeared = true }
        }
    }
    .accessibilityHidden(true)
  }
}

struct ArtifactMount: View {
  let artifactID: Int
  var size: CGFloat = 160
  var body: some View {
    ZStack {
      RadialGradient(
        colors: [ArtifactShape.color(artifactID).opacity(0.18), .clear], center: .center,
        startRadius: 5, endRadius: size * 0.65)
      Circle().stroke(Palette.gold.opacity(0.16), lineWidth: 0.5)
        .frame(width: size * 1.15, height: size * 1.15)
      Circle().trim(from: 0.03, to: 0.97)
        .stroke(Palette.gold.opacity(0.5), style: StrokeStyle(lineWidth: 0.7, dash: [1, 8]))
        .rotationEffect(.degrees(90))
        .frame(width: size * 1.28, height: size * 1.28)
      Jewel(size: size, artifactID: artifactID)
        .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 12)
    }
    .frame(height: size * 1.4)
    .accessibilityHidden(true)
  }
}
