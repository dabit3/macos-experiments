import SwiftUI

enum GardenStyle {
  static let ink = Color(red: 0.18, green: 0.24, blue: 0.23)
  static let muted = Color(red: 0.43, green: 0.46, blue: 0.40)
  static let paper = Color(red: 0.96, green: 0.95, blue: 0.89)
  static let green = Color(red: 0.22, green: 0.39, blue: 0.30)
  static let brass = Color(red: 0.65, green: 0.46, blue: 0.20)
  static let coral = Color(red: 0.76, green: 0.35, blue: 0.24)
  static let wires: [Color] = [
    Color(red: 0.76, green: 0.35, blue: 0.24),
    Color(red: 0.30, green: 0.49, blue: 0.49),
    Color(red: 0.61, green: 0.46, blue: 0.21),
    Color(red: 0.39, green: 0.45, blue: 0.31),
  ]
}

struct BoardView: View {
  @EnvironmentObject private var store: GardenStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      ZStack {
        RoundedRectangle(cornerRadius: 24).fill(GardenStyle.paper)
        Canvas { context, canvasSize in
          for x in stride(from: 20.0, to: canvasSize.width, by: 20) {
            for y in stride(from: 20.0, to: canvasSize.height, by: 20) {
              context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                with: .color(GardenStyle.brass.opacity(0.25)))
            }
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))

        VStack {
          HStack {
            Label("SERIES WORKBENCH", systemImage: "square.grid.3x3")
              .font(.system(size: 10, weight: .bold, design: .monospaced))
              .tracking(1.5)
            Spacer()
            Text("\(store.circuit.components.count) PARTS  /  \(store.circuit.wires.count) WIRES")
              .font(.system(size: 10, design: .monospaced))
          }
          Spacer()
          HStack {
            Text("01")
              .font(.system(size: 38, weight: .ultraLight, design: .serif))
            VStack(alignment: .leading, spacing: 3) {
              Text("A little light. A complete loop.")
                .font(.system(size: 13, weight: .medium, design: .serif))
              Text("IDEAL DC  •  SERIES ONLY  •  NO HARDWARE")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(0.8)
            }
            Spacer()
          }
        }
        .padding(22)
        .foregroundStyle(GardenStyle.muted)
        .allowsHitTesting(false)

        TimelineView(
          .animation(minimumInterval: 1 / 24, paused: reduceMotion || store.reading.current == 0)
        ) { timeline in
          let phase =
            timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
          Canvas { context, _ in
            for (index, wire) in store.circuit.wires.enumerated() {
              guard let from = point(wire.from, size: size),
                let to = point(wire.to, size: size)
              else { continue }
              let path = wirePath(from: from, to: to, wire: wire)
              let color = GardenStyle.wires[index % GardenStyle.wires.count]
              context.stroke(
                path, with: .color(.black.opacity(0.07)),
                style: StrokeStyle(lineWidth: 8, lineCap: .round))
              context.stroke(
                path, with: .color(color),
                style: StrokeStyle(
                  lineWidth: store.selectedWireID == wire.id ? 6 : 3.5, lineCap: .round))
              if store.reading.current > 0 {
                context.stroke(
                  path, with: .color(.white.opacity(0.72)),
                  style: StrokeStyle(
                    lineWidth: 2, lineCap: .round, dash: [3, 19], dashPhase: -phase * 44))
              }
            }
          }
        }
        .allowsHitTesting(false)

        if store.circuit.components.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
              .font(.system(size: 44, weight: .ultraLight))
            Text("Make your first connection.")
              .font(.system(size: 25, weight: .regular, design: .serif))
            Text(
              "Start with a battery from the parts tray.\nAdd a switch, resistor and lamp, then wire a loop."
            )
            .font(.system(size: 13))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
          }
          .foregroundStyle(GardenStyle.muted)
        }
        ForEach(store.circuit.components) { component in
          ComponentView(component: component, boardSize: size)
            .position(x: component.x * size.width, y: component.y * size.height)
        }
      }
      .overlay(
        RoundedRectangle(cornerRadius: 24).stroke(GardenStyle.brass.opacity(0.20), lineWidth: 1))
    }
  }

  private func point(_ terminal: Terminal, size: CGSize) -> CGPoint? {
    guard let component = store.circuit.components.first(where: { $0.id == terminal.componentID })
    else { return nil }
    let offset = store.dragOffsets[component.id, default: .zero]
    return CGPoint(
      x: component.x * size.width + (terminal.side == 0 ? -85 : 85) + offset.width,
      y: component.y * size.height + offset.height)
  }

  private func wirePath(from: CGPoint, to: CGPoint, wire: Wire) -> Path {
    var path = Path()
    path.move(to: from)
    if abs(from.y - to.y) < 40 {
      path.addCurve(
        to: to, control1: CGPoint(x: from.x + (to.x - from.x) * 0.3, y: from.y - 20),
        control2: CGPoint(x: from.x + (to.x - from.x) * 0.7, y: to.y - 20))
    } else {
      let sign: CGFloat = wire.from.side == 0 ? -1 : 1
      let reach: CGFloat = min(55, abs(from.y - to.y) * 0.3)
      path.addCurve(
        to: to, control1: CGPoint(x: from.x + sign * reach, y: from.y),
        control2: CGPoint(x: to.x + (wire.to.side == 0 ? -reach : reach), y: to.y))
    }
    return path
  }
}

struct ComponentView: View {
  @EnvironmentObject private var store: GardenStore
  let component: Component
  let boardSize: CGSize
  @GestureState private var dragOffset = CGSize.zero

  private var active: Bool { store.selectedID == component.id }
  private var brightness: Double { store.reading.brightness }

  var body: some View {
    ZStack {
      VStack(spacing: 7) {
        HStack {
          Text(component.kind.title.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.2)
          Spacer()
          Circle().fill(active ? GardenStyle.green : GardenStyle.brass.opacity(0.5)).frame(
            width: 5, height: 5)
        }
        Spacer(minLength: 0)
        Text(valueLabel)
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
          .foregroundStyle(
            component.kind == .toggle && component.closed ? GardenStyle.green : GardenStyle.muted)
      }
      .padding(12)
      .frame(width: 144, height: 112)
      .overlay {
        if component.kind == .toggle {
          Button {
            store.toggle(component.id)
          } label: {
            SchematicSymbol(kind: .toggle, closed: component.closed, brightness: 0)
              .frame(width: 120, height: 43)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(component.closed ? "Open switch" : "Close switch")
          .accessibilityIdentifier("switch.toggle")
        } else {
          SchematicSymbol(kind: component.kind, closed: component.closed, brightness: brightness)
            .frame(width: 120, height: 43)
        }
      }
      .background(
        RoundedRectangle(cornerRadius: 15)
          .fill(Color(red: 0.995, green: 0.99, blue: 0.96))
          .shadow(color: GardenStyle.ink.opacity(0.10), radius: 7, x: 0, y: 4)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 15).stroke(
          active ? GardenStyle.green : GardenStyle.brass.opacity(0.30), lineWidth: active ? 1.7 : 1)
      )
      .onTapGesture { store.select(component.id) }
      .gesture(
        DragGesture(minimumDistance: 10)
          .updating($dragOffset) { value, state, _ in state = value.translation }
          .onEnded { value in
            store.move(
              component.id, x: component.x + value.translation.width / boardSize.width,
              y: component.y + value.translation.height / boardSize.height)
          }
      )
      ForEach(0..<2) { side in
        Button {
          store.terminalTapped(component.terminal(side))
        } label: {
          ZStack {
            Circle().fill(GardenStyle.brass.opacity(0.15)).frame(width: 31, height: 31)
            Circle().fill(
              LinearGradient(
                colors: [Color(red: 0.91, green: 0.77, blue: 0.47), GardenStyle.brass],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            ).frame(width: 19, height: 19)
            Circle().fill(GardenStyle.ink.opacity(0.75)).frame(width: 6, height: 6)
            if store.pendingTerminal == component.terminal(side) {
              Circle().stroke(GardenStyle.green, lineWidth: 2).frame(width: 36, height: 36)
            }
          }
          .frame(width: 44, height: 50)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: side == 0 ? 15 : 185, y: 56)
        .accessibilityLabel("\(component.kind.title) \(side == 0 ? "left" : "right") terminal")
        .accessibilityIdentifier("\(component.kind.rawValue).terminal.\(side)")
      }
    }
    .frame(width: 200, height: 112)
    .offset(dragOffset)
    .onChange(of: dragOffset) { _, offset in
      if offset == .zero {
        store.dragOffsets.removeValue(forKey: component.id)
      } else {
        store.dragOffsets[component.id] = offset
      }
    }
  }

  private var valueLabel: String {
    switch component.kind {
    case .battery: "\(Int(component.value)) V  /  DC"
    case .resistor: "\(Int(component.value)) Ω"
    case .lamp: "\(Int(brightness * 100))%  /  100 Ω"
    case .toggle: component.closed ? "CLOSED" : "OPEN"
    }
  }
}

struct SchematicSymbol: View {
  var kind: ComponentKind
  var closed: Bool
  var brightness: Double

  var body: some View {
    Canvas { context, size in
      let width = size.width
      let mid = size.height / 2
      if kind == .lamp {
        context.fill(
          Path(ellipseIn: CGRect(x: width / 2 - 37, y: mid - 37, width: 74, height: 74)),
          with: .radialGradient(
            Gradient(colors: [
              Color.yellow.opacity(brightness), Color.orange.opacity(brightness * 0.45), .clear,
            ]),
            center: CGPoint(x: width / 2, y: mid), startRadius: 2, endRadius: 37))
        context.fill(
          Path(ellipseIn: CGRect(x: width / 2 - 16, y: mid - 16, width: 32, height: 32)),
          with: .color(Color(red: 1, green: 0.83, blue: 0.37).opacity(brightness)))
      }
      var path = Path()
      path.move(to: CGPoint(x: 4, y: mid))
      path.addLine(to: CGPoint(x: width * 0.28, y: mid))
      switch kind {
      case .battery:
        path.move(to: CGPoint(x: width * 0.40, y: mid - 10))
        path.addLine(to: CGPoint(x: width * 0.40, y: mid + 10))
        path.move(to: CGPoint(x: width * 0.57, y: mid - 19))
        path.addLine(to: CGPoint(x: width * 0.57, y: mid + 19))
        path.move(to: CGPoint(x: width * 0.28, y: mid))
        path.addLine(to: CGPoint(x: width * 0.40, y: mid))
        path.move(to: CGPoint(x: width * 0.57, y: mid))
        path.addLine(to: CGPoint(x: width - 4, y: mid))
      case .toggle:
        path.addLine(to: CGPoint(x: width * 0.32, y: mid))
        path.addLine(to: CGPoint(x: width * 0.69, y: closed ? mid : mid - 18))
        path.move(to: CGPoint(x: width * 0.7, y: mid))
        path.addLine(to: CGPoint(x: width - 4, y: mid))
        for x in [width * 0.30, width * 0.70] {
          path.addEllipse(in: CGRect(x: x - 3, y: mid - 3, width: 6, height: 6))
        }
      case .resistor:
        for index in 0...6 {
          path.addLine(
            to: CGPoint(
              x: width * (0.28 + Double(index) * 0.07), y: mid + (index % 2 == 0 ? -9 : 9)))
        }
        path.addLine(to: CGPoint(x: width * 0.73, y: mid))
        path.addLine(to: CGPoint(x: width - 4, y: mid))
      case .lamp:
        path.addLine(to: CGPoint(x: width / 2 - 18, y: mid))
        path.addEllipse(in: CGRect(x: width / 2 - 18, y: mid - 18, width: 36, height: 36))
        path.move(to: CGPoint(x: width / 2 - 12, y: mid - 12))
        path.addLine(to: CGPoint(x: width / 2 + 12, y: mid + 12))
        path.move(to: CGPoint(x: width / 2 + 12, y: mid - 12))
        path.addLine(to: CGPoint(x: width / 2 - 12, y: mid + 12))
        path.move(to: CGPoint(x: width / 2 + 18, y: mid))
        path.addLine(to: CGPoint(x: width - 4, y: mid))
      }
      context.stroke(
        path, with: .color(GardenStyle.ink),
        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
    }
    .animation(.easeInOut(duration: 0.25), value: brightness)
  }
}
