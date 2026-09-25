import SwiftUI

struct PlayGardenView: View {
  @ObservedObject var store: GardenStore
  let time: Double
  @State private var drawnPath: [GardenPoint] = []
  @State private var gestureOrigin = CGPoint.zero
  @State private var isDrawing = false

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 5) {
          eyebrow(store.rules.mode.subtitle)
          Text(store.rules.mode.title).font(.system(size: 24, design: .serif)).tracking(-0.5)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text("\(Int(ceil(store.rules.timeRemaining)))")
            .font(.system(size: 29, weight: .light, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(
              store.rules.timeRemaining < 15 ? NectarPalette.petal(.rose) : NectarPalette.cream
            )
            .accessibilityLabel("\(Int(ceil(store.rules.timeRemaining))) seconds remaining")
          eyebrow("SECONDS")
        }
        iconButton("pause", label: "Pause game", id: "pause-game") { store.paused = true }
          .padding(.trailing, -12)
      }
      .padding(.horizontal, 24)
      .padding(.top, 6)

      HStack(spacing: 8) {
        Image(systemName: "drop.fill").font(.system(size: 12)).foregroundStyle(NectarPalette.honey)
        Text("\(store.rules.score)").font(.system(size: 16, weight: .semibold)).monospacedDigit()
        Text(store.rules.mode.isDaily ? "banked" : "/ \(store.rules.mode.target) honey")
          .font(.system(size: 12)).foregroundStyle(NectarPalette.sage)
        Spacer()
        ForEach(0..<3, id: \.self) { index in
          Image(systemName: index < store.rules.hearts ? "heart.fill" : "heart")
            .font(.system(size: 10))
            .foregroundStyle(
              index < store.rules.hearts
                ? NectarPalette.petal(.rose) : NectarPalette.sage.opacity(0.4))
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(store.rules.score) honey banked, \(store.rules.hearts) lives")
      .padding(.horizontal, 26)
      .padding(.top, 17)

      GeometryReader { geo in
        Capsule().fill(NectarPalette.sage.opacity(0.15))
        Capsule().fill(NectarPalette.honey)
          .frame(
            width: geo.size.width
              * (store.rules.mode.isDaily
                ? store.rules.timeRemaining / store.rules.mode.duration
                : min(1, Double(store.rules.score) / Double(store.rules.mode.target))))
      }
      .frame(height: 2)
      .padding(.horizontal, 26)
      .padding(.top, 12)

      HStack(spacing: 9) {
        Text(store.rules.pollen == 6 ? "BANK NOW" : "NEXT BLOOM")
          .font(.system(size: 10, weight: .semibold)).tracking(1)
          .foregroundStyle(
            store.rules.pollen == 6 ? NectarPalette.honey : NectarPalette.cream.opacity(0.8))
        ForEach(BloomColor.allCases, id: \.rawValue) { color in
          let active = store.rules.expected == color && store.rules.pollen < 6
          HStack(spacing: 5) {
            Text(color.mark).font(.system(size: 10, weight: .bold))
              .frame(width: 20, height: 20)
              .background(NectarPalette.petal(color).opacity(active ? 1 : 0.3), in: Circle())
              .foregroundStyle(active ? NectarPalette.ink : NectarPalette.cream.opacity(0.5))
            if active {
              Text(color.name).font(.system(size: 13, weight: .medium)).foregroundStyle(
                NectarPalette.petal(color))
            }
          }
          if color != .iris {
            Image(systemName: "chevron.right").font(.system(size: 7)).foregroundStyle(
              NectarPalette.sage)
          }
        }
        Spacer()
        Text("×\(store.rules.multiplier)")
          .font(.system(size: 16, weight: .semibold, design: .serif)).foregroundStyle(
            NectarPalette.honey)
      }
      .padding(.horizontal, 26)
      .padding(.top, 14)
      .padding(.bottom, 10)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        store.rules.pollen == 6
          ? "Pollen full, return to hive"
          : "Next flower: \(store.rules.expected.name), number \(store.rules.expected.mark)")

      GeometryReader { geo in
        Canvas { context, size in
          drawGarden(context: context, size: size)
        }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              guard !store.isFlying else { return }
              if !isDrawing {
                gestureOrigin = value.startLocation
                isDrawing = true
                drawnPath = [store.rules.bee]
              }
              let point = normalized(value.location, in: geo.size)
              if drawnPath.last.map({ $0.distance(to: point) > 0.014 }) ?? true {
                drawnPath.append(point)
              }
            }
            .onEnded { value in
              defer {
                drawnPath = []
                isDrawing = false
              }
              guard !store.isFlying else { return }
              let point = normalized(value.location, in: geo.size)
              let movement = hypot(
                value.location.x - gestureOrigin.x, value.location.y - gestureOrigin.y)
              if movement < 12 {
                store.tap(point)
              } else {
                drawnPath.append(point)
                store.sendFlight(drawnPath)
              }
            }
        )
        .accessibilityRepresentation {
          VStack {
            ForEach(store.rules.flowers) { flower in
              Button {
                store.tap(flower.position)
              } label: {
                Text(
                  "\(flower.color.name) flower \(flower.id + 1)\(flower.cooldown > 0 ? ", resting" : "")"
                )
              }
              .accessibilityIdentifier("flower-\(flower.id)")
            }
            Button("Return to hive, bank \(store.rules.carriedScore) honey") { store.tap(.hive) }
              .accessibilityIdentifier("hive")
          }
        }
      }
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 7) {
          Text("POLLEN \(store.rules.pollen) / 6")
            .font(.system(size: 10, weight: .medium)).tracking(1.5).foregroundStyle(
              NectarPalette.sage)
          HStack(spacing: 5) {
            ForEach(0..<6, id: \.self) { index in
              Capsule().fill(
                index < store.rules.pollen ? NectarPalette.honey : NectarPalette.sage.opacity(0.22)
              )
              .frame(width: 18, height: 8)
            }
          }
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text("\(store.rules.carriedScore) to bank")
            .font(.system(size: 15, weight: .medium)).foregroundStyle(NectarPalette.honey)
          Text(store.rules.pollen == 0 ? "Fill up, then fly home" : "Tap the hive to keep it")
            .font(.system(size: 10)).foregroundStyle(NectarPalette.sage)
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        "\(store.rules.pollen) of 6 pollen, \(store.rules.carriedScore) honey to bank"
      )
      .padding(.horizontal, 26)
      .padding(.top, 10)

      Text(store.toastAge < 6 ? store.toast : hint)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(NectarPalette.cream.opacity(0.78))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .padding(.horizontal, 24)
    }
  }

  private var hint: String {
    if store.rules.pollen == 6 { return "Your satchel is golden. Bank at the hive." }
    if store.rules.pollen == 0 { return "Trace to Gold 1 · tap for a direct flight" }
    return "Follow \(store.rules.expected.name) \(store.rules.expected.mark) · bank any time"
  }

  private func normalized(_ point: CGPoint, in size: CGSize) -> GardenPoint {
    GardenPoint(x: point.x / size.width, y: point.y / size.height)
  }

  private func drawGarden(context: GraphicsContext, size: CGSize) {
    func point(_ value: GardenPoint) -> CGPoint {
      CGPoint(x: value.x * size.width, y: value.y * size.height)
    }
    let radius = min(42, size.width * 0.105, size.height * 0.09)
    for flower in store.rules.flowers {
      let p = point(flower.position)
      var stem = Path()
      stem.move(to: CGPoint(x: p.x, y: p.y + radius * 0.25))
      stem.addQuadCurve(
        to: CGPoint(x: p.x + (flower.id % 2 == 0 ? -20 : 16), y: p.y + radius * 1.4),
        control: CGPoint(x: p.x - 20, y: p.y + radius))
      context.stroke(
        stem, with: .color(NectarPalette.sage.opacity(0.27)),
        style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
    for hazard in store.rules.hazards {
      let p = point(hazard.position)
      if hazard.kind == .web {
        BotanicalDrawing.web(
          in: context, at: p, radius: hazard.radius * max(size.width, size.height))
      } else {
        for index in 0..<3 {
          let y = p.y + Double(index - 1) * 9
          let shift = store.rules.windActive ? sin(time * 2 + Double(index)) * 8 : 0
          var gust = Path()
          gust.move(to: CGPoint(x: p.x - 27 + shift, y: y))
          gust.addCurve(
            to: CGPoint(x: p.x + 26 + shift, y: y - 4),
            control1: CGPoint(x: p.x + 45, y: y + 8),
            control2: CGPoint(x: p.x + 20, y: y - 19))
          context.stroke(
            gust, with: .color(NectarPalette.cream.opacity(store.rules.windActive ? 0.45 : 0.12)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        context.draw(
          Text("\(store.rules.windActive ? "GUST" : "LULL") · \(store.rules.windChangeIn)s")
            .font(.system(size: 9, weight: .semibold)).tracking(0.5)
            .foregroundColor(
              store.rules.windActive ? NectarPalette.cream : NectarPalette.sage),
          at: CGPoint(x: p.x, y: p.y + 28))
      }
    }
    if store.rules.route.count > 1 {
      strokeRoute(store.rules.route, context: context, size: size, opacity: 0.12)
    }
    for flower in store.rules.flowers {
      let resting = flower.cooldown > 0
      let wave =
        store.waveAge < 2.4 ? sin(max(0, store.waveAge - flower.position.y * 0.6) * .pi) * 0.12 : 0
      var flowerContext = context
      flowerContext.opacity = resting ? 0.45 : 1
      BotanicalDrawing.flower(
        in: flowerContext, at: point(flower.position), radius: radius * (1 + max(0, wave)),
        color: flower.color,
        rotation: Double(flower.id * 21) + sin(time * 0.65 + Double(flower.id)) * 2,
        openness: resting ? 0.35 : 1,
        active: !resting && flower.color == store.rules.expected && store.rules.pollen < 6)
    }
    BotanicalDrawing.hive(
      in: context, at: point(.hive), size: store.rules.pollen == 6 ? 39 : 33,
      ready: store.rules.pollen > 0)
    context.draw(
      Text(store.rules.pollen > 0 ? "BANK HONEY" : "HOME")
        .font(.system(size: 10, weight: .semibold)).tracking(1.3).foregroundColor(
          NectarPalette.honey),
      at: CGPoint(x: size.width * 0.5, y: size.height * 0.91 + 28))
    strokeRoute(store.flightPath, context: context, size: size, opacity: 0.6)
    strokeRoute(drawnPath, context: context, size: size, opacity: 0.9)
    for burst in store.particles {
      let age = store.clock - burst.created
      let center = point(burst.point)
      for index in 0..<16 {
        let angle = Double(index) * 2.4
        let distance = age * (30 + Double(index % 4) * 13)
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance, width: 3,
              height: 3)),
          with: .color(NectarPalette.lightPetal(burst.color).opacity(max(0, 1 - age / 1.5))))
      }
    }
    BotanicalDrawing.bee(in: context, at: point(store.beeVisual), size: 15, time: time)
    if let feedback = store.hazardFeedback {
      let origin = point(feedback.hazard.position)
      let center = CGPoint(
        x: min(size.width - 51, max(51, origin.x)), y: origin.y - 45)
      let rect = CGRect(x: center.x - 50, y: center.y - 21, width: 100, height: 42)
      context.fill(
        Path(roundedRect: rect, cornerRadius: 12),
        with: .color(NectarPalette.ink.opacity(0.95)))
      let isWeb = feedback.hazard.kind == .web
      context.draw(
        Text(isWeb ? "−1 LIFE" : "−5 SECONDS")
          .font(.system(size: 11, weight: .bold)).foregroundColor(NectarPalette.petal(.rose)),
        at: CGPoint(x: center.x, y: center.y - 7))
      context.draw(
        Text(isWeb ? "Pollen lost" : "Headwind")
          .font(.system(size: 10)).foregroundColor(NectarPalette.cream),
        at: CGPoint(x: center.x, y: center.y + 8))
    }
    if store.waveAge < 2.4 {
      context.draw(
        Text("BLOSSOM WAVE").font(.system(size: 25, weight: .regular, design: .serif)).tracking(3)
          .foregroundColor(NectarPalette.cream),
        at: CGPoint(x: size.width * 0.5, y: size.height * 0.40))
      context.draw(
        Text("+30 · A LITTLE MAGIC").font(.system(size: 9, weight: .semibold)).tracking(2)
          .foregroundColor(NectarPalette.honey),
        at: CGPoint(x: size.width * 0.5, y: size.height * 0.40 + 27))
    }
  }
}

func strokeRoute(_ route: [GardenPoint], context: GraphicsContext, size: CGSize, opacity: Double) {
  guard let first = route.first, route.count > 1 else { return }
  var line = Path()
  line.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
  for point in route.dropFirst() {
    line.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
  }
  context.stroke(
    line, with: .color(NectarPalette.honey.opacity(opacity)),
    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [3, 5]))
}

struct GardenSnapshot: View {
  let rules: GardenRules

  var body: some View {
    Canvas { context, size in
      let radius = min(size.width * 0.085, size.height * 0.088)
      let inset = radius + 4
      let inner = CGSize(width: size.width - 16, height: max(1, size.height - inset * 2))
      var garden = context
      garden.translateBy(x: 8, y: inset)
      strokeRoute(rules.route, context: garden, size: inner, opacity: 0.6)
      for flower in rules.flowers {
        BotanicalDrawing.flower(
          in: garden,
          at: CGPoint(x: flower.position.x * inner.width, y: flower.position.y * inner.height),
          radius: radius, color: flower.color,
          rotation: Double(flower.id * 18), number: false)
      }
      BotanicalDrawing.hive(
        in: garden, at: CGPoint(x: inner.width * 0.5, y: inner.height * 0.91), size: 20, ready: true
      )
      BotanicalDrawing.bee(
        in: garden, at: CGPoint(x: inner.width * 0.62, y: inner.height * 0.8), size: 13, time: 0)
    }
    .accessibilityLabel(
      "Your garden snapshot with \(rules.totalBlooms) pollinated blooms and your flight route")
  }
}

struct ShareGardenCard: View {
  let rules: GardenRules

  var body: some View {
    VStack(spacing: 16) {
      eyebrow("A SMALL FLIGHT. A WILD WORLD.")
      Text("Nectar Dash").font(.system(size: 45, design: .serif)).tracking(-2)
      Text(rules.mode.title).font(.system(size: 13)).foregroundStyle(NectarPalette.sage)
      GardenSnapshot(rules: rules).frame(height: 270).padding(.horizontal, 12)
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text("\(rules.score)").font(.system(size: 70, design: .serif))
        eyebrow("HONEY BANKED")
      }
      Text(
        "\(rules.totalBlooms) blooms  ·  \(rules.longestChain)-bloom chain  ·  \(rules.waveCount) blossom waves"
      )
      .font(.system(size: 12)).foregroundStyle(NectarPalette.sage)
      Text(rules.mode.dailySeed.map { "DAILY GARDEN · \($0) UTC" } ?? "GROWN WITH A LITTLE COURAGE")
        .font(.system(size: 8, weight: .medium)).tracking(2).foregroundStyle(NectarPalette.honey)
    }
    .padding(.vertical, 26)
    .frame(width: 390, height: 620)
    .foregroundStyle(NectarPalette.cream)
    .background(BotanicalBackdrop(lush: true))
    .environment(\.colorScheme, .dark)
  }
}
