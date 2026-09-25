import SwiftUI

enum Field {
  static let paper = Color(red: 0.95, green: 0.94, blue: 0.88)
  static let ink = Color(red: 0.13, green: 0.25, blue: 0.20)
  static let muted = Color(red: 0.36, green: 0.41, blue: 0.34)
  static let orange = Color(red: 0.72, green: 0.29, blue: 0.13)
  static let line = Color(red: 0.76, green: 0.78, blue: 0.66)
  static let serif = Font.system(.title, design: .serif).weight(.medium)
}

struct MapProjection {
  let trail: Trail
  let size: CGSize

  func position(_ point: TrailPoint) -> CGPoint {
    let latitudes = trail.points.map(\.latitude)
    let longitudes = trail.points.map(\.longitude)
    let latMin = latitudes.min() ?? 0
    let latMax = latitudes.max() ?? 1
    let lonMin = longitudes.min() ?? 0
    let lonMax = longitudes.max() ?? 1
    let longitudeScale = cos((latMin + latMax) / 2 * .pi / 180)
    let width = max(0.001, (lonMax - lonMin) * longitudeScale)
    let height = max(0.001, latMax - latMin)
    let scale = min(size.width * 0.68 / width, size.height * 0.74 / height)
    return CGPoint(
      x: size.width / 2 + (point.longitude - (lonMin + lonMax) / 2) * longitudeScale * scale,
      y: size.height / 2 - (point.latitude - (latMin + latMax) / 2) * scale)
  }
}

struct TopoArtwork: View {
  let trail: Trail
  var fraction: Double = 0.5
  var waypoints: [Waypoint] = []
  var labels = true

  var body: some View {
    Canvas { context, size in
      let bounds = CGRect(origin: .zero, size: size)
      context.fill(Path(bounds), with: .color(Field.paper))
      let warm = trail.id == "juniper"
      let contour =
        warm
        ? Color(red: 0.68, green: 0.53, blue: 0.34)
        : Color(red: 0.45, green: 0.55, blue: 0.36)
      let contours =
        warm
        ? TerrainContours.juniper
        : (trail.id == "mirror" ? TerrainContours.mirror : TerrainContours.granite)
      for (index, segments) in contours.enumerated() {
        var contourPath = Path()
        for segment in segments {
          contourPath.move(
            to: CGPoint(x: segment.start.x * size.width, y: segment.start.y * size.height))
          contourPath.addLine(
            to: CGPoint(x: segment.end.x * size.width, y: segment.end.y * size.height))
        }
        context.stroke(
          contourPath, with: .color(contour.opacity(index % 5 == 0 ? 0.50 : 0.28)),
          lineWidth: index % 5 == 0 ? 1.0 : 0.65)
      }

      var lake = Path()
      let lx = size.width * (trail.id == "mirror" ? 0.50 : 0.77)
      let ly = size.height * 0.42
      lake.move(to: CGPoint(x: lx - 24, y: ly - 32))
      lake.addCurve(
        to: CGPoint(x: lx + 18, y: ly + 55), control1: CGPoint(x: lx + 55, y: ly - 75),
        control2: CGPoint(x: lx + 35, y: ly + 25))
      lake.addCurve(
        to: CGPoint(x: lx - 24, y: ly - 32), control1: CGPoint(x: lx - 45, y: ly + 75),
        control2: CGPoint(x: lx - 45, y: ly + 10))
      context.fill(
        lake,
        with: .color(
          warm
            ? Color(red: 0.85, green: 0.78, blue: 0.60) : Color(red: 0.64, green: 0.78, blue: 0.76))
      )
      context.stroke(lake, with: .color(contour.opacity(0.5)), lineWidth: 1)
      var stream = Path()
      stream.move(to: CGPoint(x: lx + 18, y: ly + 55))
      stream.addCurve(
        to: CGPoint(x: size.width * 0.72, y: size.height + 30),
        control1: CGPoint(x: lx - 70, y: ly + 110),
        control2: CGPoint(x: size.width, y: size.height * 0.92))
      context.stroke(
        stream, with: .color(Color(red: 0.52, green: 0.68, blue: 0.67).opacity(warm ? 0.2 : 0.65)),
        lineWidth: 2)

      let projection = MapProjection(trail: trail, size: size)
      var route = Path()
      for (index, point) in trail.points.enumerated() {
        let p = projection.position(point)
        if index == 0 { route.move(to: p) } else { route.addLine(to: p) }
      }
      context.stroke(
        route, with: .color(Field.paper),
        style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
      context.stroke(
        route, with: .color(Field.orange),
        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
      for (index, waypoint) in waypoints.enumerated() {
        let p = projection.position(trail.point(at: waypoint.fraction))
        let rect = CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)
        context.fill(Path(ellipseIn: rect), with: .color(Field.ink))
        context.stroke(Path(ellipseIn: rect), with: .color(Field.paper), lineWidth: 2)
        context.draw(
          Text("\(index + 1)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white), at: p)
      }
      let cursor = projection.position(trail.point(at: fraction))
      context.fill(
        Path(ellipseIn: CGRect(x: cursor.x - 15, y: cursor.y - 15, width: 30, height: 30)),
        with: .color(Field.orange.opacity(0.15)))
      context.fill(
        Path(ellipseIn: CGRect(x: cursor.x - 7, y: cursor.y - 7, width: 14, height: 14)),
        with: .color(Field.orange))
      context.stroke(
        Path(ellipseIn: CGRect(x: cursor.x - 7, y: cursor.y - 7, width: 14, height: 14)),
        with: .color(.white), lineWidth: 3)
      if labels {
        context.draw(
          Text(trail.landscape.uppercased()).font(
            .system(size: 9, weight: .semibold, design: .serif)
          ).tracking(2).foregroundStyle(Field.muted),
          at: CGPoint(x: size.width * 0.31, y: size.height * 0.12))
        context.draw(
          Text(warm ? "DRY WASH" : "SILVER CREEK").font(.system(size: 8, weight: .medium)).tracking(
            1.5
          ).foregroundStyle(Field.muted), at: CGPoint(x: size.width * 0.80, y: size.height * 0.76))
        context.draw(
          Text("\(Int(trail.points.map(\.elevation).max() ?? 0)) m").font(
            .system(size: 9, design: .monospaced)
          ).foregroundStyle(Field.muted), at: CGPoint(x: size.width * 0.22, y: size.height * 0.42))
      }
    }
  }
}

struct InteractiveMap: View {
  let trail: Trail
  let fraction: Double
  let waypoints: [Waypoint]
  @State private var zoom = 1.0
  @State private var offset = CGSize.zero
  @GestureState private var drag = CGSize.zero
  @GestureState private var magnify = 1.0

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        TopoArtwork(trail: trail, fraction: fraction, waypoints: waypoints)
          .scaleEffect(zoom * magnify)
          .offset(x: offset.width + drag.width, y: offset.height + drag.height)
          .gesture(
            DragGesture().updating($drag) { value, state, _ in state = value.translation }
              .onEnded { value in
                offset = CGSize(
                  width: min(
                    geometry.size.width,
                    max(-geometry.size.width, offset.width + value.translation.width)),
                  height: min(
                    geometry.size.height,
                    max(-geometry.size.height, offset.height + value.translation.height)))
              }
          )
          .simultaneousGesture(
            MagnifyGesture().updating($magnify) { value, state, _ in state = value.magnification }
              .onEnded { zoom = min(3, max(1, zoom * $0.magnification)) }
          )
          .accessibilityLabel("Illustrative topographic map of \(trail.name)")
          .accessibilityIdentifier("trailMap")
        VStack {
          HStack {
            Label("OFFLINE ATLAS", systemImage: "map")
              .font(.system(size: 9, weight: .bold)).tracking(1.5)
              .padding(10).background(Field.paper.opacity(0.95), in: Capsule())
            Spacer()
            VStack(spacing: 2) {
              Text("N").font(.system(size: 10, weight: .bold))
              Image(systemName: "location.north.fill").font(.system(size: 21))
            }
          }
          Spacer()
          HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
              Text("ILLUSTRATIVE ROUTE").font(.system(size: 8, weight: .bold)).tracking(1.2)
              Text("Pan to explore · \(zoom, specifier: "%.1f")×").font(.system(size: 10))
            }
            .padding(9).background(
              Field.paper.opacity(0.95), in: RoundedRectangle(cornerRadius: 10))
            Spacer()
            VStack(spacing: 0) {
              mapButton("plus", label: "Zoom in") { zoom = min(3, zoom + 0.4) }
              Divider().frame(width: 26)
              mapButton("minus", label: "Zoom out") { zoom = max(1, zoom - 0.4) }
              Divider().frame(width: 26)
              mapButton("scope", label: "Recenter map") {
                zoom = 1
                offset = .zero
              }
            }
            .background(Field.paper, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Field.line.opacity(0.6)))
          }
        }
        .padding(18)
        .foregroundStyle(Field.ink)
      }
      .clipped()
      .onChange(of: trail.id) {
        zoom = 1
        offset = .zero
      }
    }
  }

  func mapButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: { withAnimation(.easeInOut(duration: 0.25), action) }) {
      Image(systemName: symbol).font(.system(size: 15, weight: .medium)).frame(
        width: 42, height: 40)
    }
    .accessibilityLabel(label)
  }
}

struct ElevationProfile: View {
  let trail: Trail
  @Binding var fraction: Double

  var body: some View {
    VStack(spacing: 0) {
      GeometryReader { geometry in
        let low = (trail.points.map(\.elevation).min() ?? 0) - 30
        let high = (trail.points.map(\.elevation).max() ?? 1) + 30
        let distances = trail.distances
        let positions = trail.points.enumerated().map { index, point in
          CGPoint(
            x: distances[index] / trail.distance * geometry.size.width,
            y: (1 - (point.elevation - low) / (high - low)) * geometry.size.height)
        }
        ZStack {
          Path { path in
            path.move(to: CGPoint(x: 0, y: geometry.size.height))
            for point in positions { path.addLine(to: point) }
            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
            path.closeSubpath()
          }
          .fill(
            LinearGradient(
              colors: [Field.ink.opacity(0.25), Field.ink.opacity(0.03)], startPoint: .top,
              endPoint: .bottom))
          Path { path in
            for (index, point) in positions.enumerated() {
              if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
          }.stroke(Field.ink, lineWidth: 1.5)
          Path { path in
            let x = fraction * geometry.size.width
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
          }.stroke(Field.orange, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
          Circle().fill(Field.orange).frame(width: 9, height: 9)
            .position(
              x: fraction * geometry.size.width,
              y: (1 - (trail.point(at: fraction).elevation - low) / (high - low))
                * geometry.size.height)
        }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0).onChanged {
            fraction = min(1, max(0, $0.location.x / geometry.size.width))
          })
      }
      .frame(height: 42)
      Slider(value: $fraction, in: 0...1)
        .tint(Field.orange)
        .accessibilityLabel("Elevation route position")
        .accessibilityValue(
          "\(Int(trail.point(at: fraction).elevation)) meters at \(String(format: "%.1f", trail.distance * fraction)) kilometers"
        )
      HStack {
        Text("0 km")
        Spacer()
        Text("DRAG TO EXPLORE").tracking(1.5)
        Spacer()
        Text("\(trail.distance, specifier: "%.1f") km")
      }.font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(Field.muted)
    }
  }
}
