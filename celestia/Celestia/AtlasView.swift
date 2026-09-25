import SwiftUI

struct AtlasView: View {
  @EnvironmentObject private var store: Observatory
  @State private var zoom = 1.0
  @State private var pan = CGSize.zero
  @State private var dragOrigin = CGSize.zero
  @State private var pinchOrigin = 1.0
  var constellation: String
  var lines: Bool

  private func point(_ horizontal: Horizontal, center: CGPoint, radius: Double) -> CGPoint {
    let distance = (90 - horizontal.altitude) / 90 * radius
    let angle = horizontal.azimuth * .pi / 180
    return CGPoint(x: center.x - sin(angle) * distance, y: center.y - cos(angle) * distance)
  }

  var body: some View {
    GeometryReader { geometry in
      let radius = min(geometry.size.width * 0.405, geometry.size.height * 0.405) * zoom
      let center = CGPoint(
        x: geometry.size.width / 2 + pan.width, y: geometry.size.height / 2 + pan.height)
      let positions = Catalog.stars.map {
        ($0, Astronomy.position($0, at: store.plan.date, site: store.plan.site))
      }
      ZStack {
        Canvas { context, size in
          let horizon = CGRect(
            x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
          context.fill(
            Path(ellipseIn: horizon),
            with: .radialGradient(
              Gradient(colors: [
                Color(red: 0.035, green: 0.085, blue: 0.15),
                Color(red: 0.055, green: 0.12, blue: 0.20),
                Color(red: 0.17, green: 0.19, blue: 0.24),
              ]),
              center: center, startRadius: radius * 0.1, endRadius: radius))
          for fraction in [1.0 / 3, 2.0 / 3, 1.0] {
            let r = radius * fraction
            let path = Path(
              ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            context.stroke(
              path, with: .color(Palette.gold.opacity(fraction == 1 ? 0.45 : 0.13)),
              style: StrokeStyle(lineWidth: 0.7, dash: fraction == 1 ? [] : [2, 5]))
          }
          for angle in stride(from: 0.0, to: 360.0, by: 5) {
            let a = angle * .pi / 180
            var tick = Path()
            let tickLength = angle.truncatingRemainder(dividingBy: 30) == 0 ? 9.0 : 4.0
            tick.move(
              to: CGPoint(x: center.x - sin(a) * (radius + 7), y: center.y - cos(a) * (radius + 7)))
            tick.addLine(
              to: CGPoint(
                x: center.x - sin(a) * (radius + 7 + tickLength),
                y: center.y - cos(a) * (radius + 7 + tickLength)))
            context.stroke(tick, with: .color(Palette.gold.opacity(0.35)), lineWidth: 0.8)
          }
          for (label, angle) in [("N", 0.0), ("E", 90.0), ("S", 180.0), ("W", 270.0)] {
            let a = angle * .pi / 180
            let p = CGPoint(
              x: center.x - sin(a) * (radius + 29), y: center.y - cos(a) * (radius + 29))
            context.draw(
              Text(label).font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.gold), at: p)
          }
          for angle in [0.0, 90.0] {
            let a = angle * .pi / 180
            var path = Path()
            path.move(to: CGPoint(x: center.x - sin(a) * radius, y: center.y - cos(a) * radius))
            path.addLine(to: CGPoint(x: center.x + sin(a) * radius, y: center.y + cos(a) * radius))
            context.stroke(path, with: .color(Palette.muted.opacity(0.10)), lineWidth: 0.7)
          }
          context.draw(
            Text("ZENITH").font(.system(size: 8, design: .monospaced)).tracking(2).foregroundStyle(
              Palette.muted.opacity(0.5)), at: CGPoint(x: center.x, y: center.y + 13))
          context.draw(
            Text("30°").font(.system(size: 9, design: .monospaced)).foregroundStyle(
              Palette.muted.opacity(0.6)), at: CGPoint(x: center.x + radius * 0.66, y: center.y + 8)
          )
          if lines {
            for ids in Catalog.paths {
              for pair in zip(ids, ids.dropFirst()) {
                if let first = positions.first(where: { $0.0.id == pair.0 }),
                  let second = positions.first(where: { $0.0.id == pair.1 }),
                  first.1.altitude >= 0, second.1.altitude >= 0
                {
                  let emphasized =
                    constellation == "All constellations" || first.0.constellation == constellation
                  var path = Path()
                  path.move(to: point(first.1, center: center, radius: radius))
                  path.addLine(to: point(second.1, center: center, radius: radius))
                  context.stroke(
                    path, with: .color(Palette.gold.opacity(emphasized ? 0.58 : 0.10)),
                    lineWidth: 0.8)
                }
              }
            }
            let triangle = ["vega", "deneb", "altair", "vega"].compactMap { id in
              positions.first { $0.0.id == id }
            }
            if triangle.allSatisfy({ $0.1.altitude > 0 }) {
              var path = Path()
              for (index, star) in triangle.enumerated() {
                let p = point(star.1, center: center, radius: radius)
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
              }
              context.stroke(
                path, with: .color(Palette.gold.opacity(0.22)),
                style: StrokeStyle(lineWidth: 0.8, dash: [4, 6]))
            }
          }
          for (star, horizontal) in positions where horizontal.altitude >= 0 {
            let p = point(horizontal, center: center, radius: radius)
            let selected = star.id == store.selectedID
            let highlighted =
              constellation == "All constellations" || star.constellation == constellation
            let r = max(1.25, 3.6 - star.magnitude * 0.52)
            let color =
              ["antares", "arcturus", "betelgeuse", "aldebaran"].contains(star.id)
              ? Color(red: 0.95, green: 0.72, blue: 0.48) : Palette.ivory
            context.fill(
              Path(ellipseIn: CGRect(x: p.x - r * 4, y: p.y - r * 4, width: r * 8, height: r * 8)),
              with: .radialGradient(
                Gradient(colors: [color.opacity(highlighted ? 0.25 : 0.06), .clear]), center: p,
                startRadius: 0, endRadius: r * 4))
            context.fill(
              Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
              with: .color(color.opacity(highlighted ? 1 : 0.25)))
            if selected {
              context.stroke(
                Path(ellipseIn: CGRect(x: p.x - 13, y: p.y - 13, width: 26, height: 26)),
                with: .color(Palette.gold), lineWidth: 1)
              context.stroke(
                Path(ellipseIn: CGRect(x: p.x - 18, y: p.y - 18, width: 36, height: 36)),
                with: .color(Palette.gold.opacity(0.18)), lineWidth: 1)
            }
            if (star.magnitude < 1.4 || selected) && highlighted {
              context.draw(
                Text(star.name).font(
                  .system(
                    size: selected ? 14 : 11, weight: selected ? .medium : .regular, design: .serif)
                ).foregroundStyle(selected ? Palette.gold : Palette.ivory.opacity(0.8)),
                at: CGPoint(x: p.x + (selected ? 21 : 10), y: p.y - 13), anchor: .leading)
            }
          }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
          let nearby = positions.filter { $0.1.altitude >= 0 }.min {
            let a = point($0.1, center: center, radius: radius)
            let b = point($1.1, center: center, radius: radius)
            return hypot(a.x - location.x, a.y - location.y)
              < hypot(b.x - location.x, b.y - location.y)
          }
          if let nearby {
            let p = point(nearby.1, center: center, radius: radius)
            if hypot(p.x - location.x, p.y - location.y) < 28 { store.selectedID = nearby.0.id }
          }
        }
        .gesture(
          DragGesture(minimumDistance: 8).onChanged { value in
            pan = CGSize(
              width: dragOrigin.width + value.translation.width,
              height: dragOrigin.height + value.translation.height)
          }.onEnded { _ in dragOrigin = pan }
        )
        .simultaneousGesture(
          MagnifyGesture().onChanged { value in
            zoom = min(3, max(0.75, pinchOrigin * value.magnification))
          }.onEnded { _ in pinchOrigin = zoom }
        )
        .accessibilityLabel(
          "Interactive all-sky atlas. North is up, east is left. Select stars using the catalog, or tap stars on the map."
        )
        VStack {
          Spacer()
          HStack {
            HStack(spacing: 7) {
              Circle().fill(Palette.mint).frame(width: 4, height: 4)
              Text("LOOKING UP · GEOMETRIC SKY").font(.system(size: 8, design: .monospaced))
                .tracking(1)
            }.foregroundStyle(Palette.muted)
            Spacer()
            HStack(spacing: 5) {
              Button {
                zoom = max(0.75, zoom - 0.25)
                pinchOrigin = zoom
              } label: {
                Image(systemName: "minus")
              }
              .accessibilityLabel("Zoom out")
              Button {
                zoom = min(3, zoom + 0.25)
                pinchOrigin = zoom
              } label: {
                Image(systemName: "plus")
              }
              .accessibilityLabel("Zoom in")
              Button {
                zoom = 1
                pinchOrigin = 1
                pan = .zero
                dragOrigin = .zero
              } label: {
                Image(systemName: "scope")
              }
              .accessibilityLabel("Reset atlas view")
            }.buttonStyle(InstrumentButton())
          }.padding(12)
        }
      }.clipped()
    }
  }
}

struct AltitudePlot: View {
  let star: Star
  let date: Date
  let site: ObservingSite

  var body: some View {
    VStack(spacing: 4) {
      Canvas { context, size in
        func p(_ step: Int) -> CGPoint {
          let time = date.addingTimeInterval(Double(step - 24) * 900)
          let altitude = Astronomy.position(star, at: time, site: site).altitude
          return CGPoint(x: Double(step) / 48 * size.width, y: (90 - altitude) / 180 * size.height)
        }
        let horizon = size.height / 2
        var line = Path()
        line.move(to: CGPoint(x: 0, y: horizon))
        line.addLine(to: CGPoint(x: size.width, y: horizon))
        context.stroke(
          line, with: .color(Palette.muted.opacity(0.4)),
          style: StrokeStyle(lineWidth: 0.7, dash: [3, 3]))
        var curve = Path()
        curve.move(to: p(0))
        for step in 1...48 { curve.addLine(to: p(step)) }
        var fill = curve
        fill.addLine(to: CGPoint(x: size.width, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()
        context.fill(
          fill,
          with: .linearGradient(
            Gradient(colors: [Palette.gold.opacity(0.16), .clear]), startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height)))
        context.stroke(curve, with: .color(Palette.gold), lineWidth: 1.6)
        let now = p(24)
        var cursor = Path()
        cursor.move(to: CGPoint(x: now.x, y: 0))
        cursor.addLine(to: CGPoint(x: now.x, y: size.height))
        context.stroke(cursor, with: .color(Palette.ivory.opacity(0.3)), lineWidth: 0.7)
        context.fill(
          Path(ellipseIn: CGRect(x: now.x - 3, y: now.y - 3, width: 6, height: 6)),
          with: .color(Palette.gold))
        context.draw(
          Text("0°").font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted),
          at: CGPoint(x: 6, y: horizon - 7))
      }.frame(height: 82)
      HStack {
        Text(Astronomy.formatted(date.addingTimeInterval(-21600), site: site, pattern: "HH:mm"))
        Spacer()
        Text("NOW")
        Spacer()
        Text(Astronomy.formatted(date.addingTimeInterval(21600), site: site, pattern: "HH:mm"))
      }.font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
    }.accessibilityLabel(
      "Altitude over twelve hours centered on the selected time. Dashed line is the horizon.")
  }
}
