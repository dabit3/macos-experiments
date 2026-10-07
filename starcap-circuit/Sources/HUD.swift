import SwiftUI

struct RaceHUD: View {
  @ObservedObject var client: RaceClient

  private var elapsed: Double {
    max(0, (client.serverNow - (client.state?.startAt ?? 0)) / 1000)
  }

  var body: some View {
    ZStack {
      SpeedOverlay(
        boost: client.me?.boost ?? 0, stun: client.me?.stun ?? 0, time: client.clock
      ).ignoresSafeArea().allowsHitTesting(false)
      VStack(spacing: 0) {
        HStack(alignment: .top, spacing: 12) {
          itemButton
          VStack(alignment: .leading, spacing: 5) {
            lapBadge
            timer
            autoDriver
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 6) {
            positionBadge
            MiniMap(state: client.state, playerID: client.playerID, track: client.state?.track ?? 0)
              .frame(width: 92, height: 80).padding(6)
              .background(ink.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
              .allowsHitTesting(false)
          }
        }
        Spacer()
        HStack(alignment: .bottom) {
          steering
          Spacer()
          gauge
          Spacer()
          pedals
        }
      }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 10)
      overlays
    }
  }

  @ViewBuilder private var overlays: some View {
    if client.countdown > 0 {
      VStack(spacing: 8) {
        let n = client.countdown
        OutlinedText(
          text: "\(n)", size: 150,
          fill: n == 3 ? [.white, cherry] : n == 2 ? [.white, .orange] : [.white, sunshine],
          stroke: 4
        )
        .id(n).transition(.scale(scale: 2.2).combined(with: .opacity))
        Ribbon(
          text: n == 2 ? "HOLD GAS NOW FOR A ROCKET START!" : "GET READY…",
          tint: n == 2 ? .orange : skyBlue)
      }
      .animation(.spring(response: 0.3, dampingFraction: 0.55), value: client.countdown)
      .allowsHitTesting(false)
    } else if elapsed < 0.9 && client.state?.phase == "racing" {
      OutlinedText(text: "GO!", size: 140, fill: [.white, mintGlow], stroke: 4)
        .scaleEffect(1 + elapsed * 0.5).opacity(1 - max(0, elapsed - 0.5) * 2.5)
        .allowsHitTesting(false)
    } else if !client.toast.isEmpty {
      VStack {
        Spacer().frame(height: 96)
        OutlinedText(text: client.toast, size: 30, fill: [.white, client.toastTint], stroke: 2.5)
          .padding(.horizontal, 26).padding(.vertical, 6)
          .background(Parallelogram().fill(ink.opacity(0.55)))
          .transition(.scale(scale: 0.4).combined(with: .opacity))
          .id(client.toast)
        Spacer()
      }
      .animation(.spring(response: 0.25, dampingFraction: 0.5), value: client.toast)
      .allowsHitTesting(false)
    }
    if (client.me?.finish ?? 0) > 0 && client.state?.phase == "racing" {
      VStack(spacing: 8) {
        OutlinedText(text: "FINISH!", size: 84, fill: [.white, sunshine], stroke: 3.5)
        Text(String(format: "%.2fs • waiting for your rival…", (client.me?.finish ?? 0) / 1000))
          .font(label(13)).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 7)
          .background(ink.opacity(0.75), in: Capsule())
      }
      .padding(.horizontal, 40).padding(.vertical, 14)
      .background(Checkers().opacity(0.25).clipShape(RoundedRectangle(cornerRadius: 20)))
      .allowsHitTesting(false)
    }
  }

  private var positionBadge: some View {
    let rank = client.me?.rank ?? 1
    let (number, suffix) = ordinal(rank)
    let fill: [Color] =
      rank == 1 ? [sunshine, .orange] : [.white, Color(red: 0.55, green: 0.8, blue: 1)]
    return HStack(alignment: .top, spacing: 2) {
      OutlinedText(text: number, size: 66, fill: fill, stroke: 3)
      OutlinedText(text: suffix, size: 26, fill: fill, stroke: 2).padding(.top, 8)
    }
    .id(rank).transition(.scale(scale: 1.6).combined(with: .opacity))
    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: rank)
    .accessibilityLabel("Position \(rank)")
  }

  private var lapBadge: some View {
    HStack(alignment: .firstTextBaseline, spacing: 5) {
      Text("LAP").font(display(13)).foregroundStyle(.white)
      OutlinedText(
        text: "\(client.me?.lap ?? 1)", size: 30, fill: [.white, mintGlow], stroke: 2)
      Text("/\(client.state?.laps ?? 2)").font(display(16)).foregroundStyle(.white)
    }
    .padding(.horizontal, 12).padding(.vertical, 2)
    .background(Parallelogram().fill(ink.opacity(0.6)))
  }

  private var timer: some View {
    HStack(spacing: 5) {
      Image(systemName: "stopwatch.fill")
      Text(
        String(format: "%d:%04.1f", Int(elapsed) / 60, elapsed.truncatingRemainder(dividingBy: 60))
      )
      .monospacedDigit()
    }
    .font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(.white)
    .padding(.horizontal, 10).padding(.vertical, 5)
    .background(ink.opacity(0.5), in: Capsule())
  }

  @ViewBuilder private var autoDriver: some View {
    Button {
      if client.autoDrive {
        client.autoDrive = false
        client.throttle = false
        client.steer = 0
        client.drift = false
      } else {
        client.autoDrive = true
      }
    } label: {
      Label(
        client.autoDrive ? "AUTOMATED DRIVER • TAP TO TAKE OVER" : "AUTO DRIVER: OFF",
        systemImage: "steeringwheel"
      )
      .font(label(8)).foregroundStyle(client.autoDrive ? ink : .white.opacity(0.8))
      .padding(.horizontal, 8).padding(.vertical, 5)
      .background(client.autoDrive ? sunshine : ink.opacity(0.4), in: Capsule())
    }.buttonStyle(.plain)
      .accessibilityLabel(client.autoDrive ? "Disable automated driver" : "Enable automated driver")
  }

  private var itemButton: some View {
    let roulette = (client.me?.roulette ?? 0) > 0
    let item =
      roulette ? Item.order[Int(client.clock * 14) % 4] : client.me?.item ?? ""
    let ready = !roulette && !item.isEmpty
    let tint = Item.colors[item] ?? .white
    return Button {
      client.item()
    } label: {
      VStack(spacing: 3) {
        ZStack {
          Circle().fill(ink).frame(width: 78, height: 78).offset(y: 4)
          Circle().fill(.white).frame(width: 78, height: 78)
          Circle().fill(
            RadialGradient(
              colors: [skyBlue.opacity(0.9), ink], center: .center, startRadius: 4, endRadius: 36)
          )
          .frame(width: 64, height: 64)
          if item.isEmpty {
            Image(systemName: "questionmark").font(.system(size: 26, weight: .black))
              .foregroundStyle(.white.opacity(0.3))
          } else {
            Image(systemName: Item.symbols[item] ?? "questionmark")
              .font(.system(size: 32, weight: .black)).foregroundStyle(tint)
              .shadow(color: tint.opacity(0.8), radius: ready ? 8 : 0)
              .scaleEffect(roulette ? 0.85 + 0.15 * abs(sin(client.clock * 20)) : 1)
          }
          Circle().strokeBorder(ink, lineWidth: 3).frame(width: 78, height: 78)
          if ready {
            Circle().strokeBorder(tint, lineWidth: 4).frame(width: 90, height: 90)
              .opacity(0.4 + 0.6 * abs(sin(client.clock * 5)))
          }
        }.frame(width: 90, height: 90)
        Text(roulette ? "ROLLING…" : ready ? "TAP! \(Item.names[item] ?? "")" : "ITEM")
          .font(display(10)).foregroundStyle(ready ? ink : .white)
          .padding(.horizontal, 8).padding(.vertical, 3)
          .background(ready ? tint : ink.opacity(0.55), in: Capsule())
      }
    }.buttonStyle(.plain).accessibilityLabel("Use item")
  }

  private var gauge: some View {
    let me = client.me
    let charge = me?.charge ?? 0
    let tier = Turbo.tier(charge)
    return VStack(spacing: 4) {
      if charge > 0 {
        HStack(spacing: 4) {
          ForEach(0..<3) { i in
            let low = i == 0 ? 0 : Turbo.thresholds[i - 1]
            let fill = max(0, min(1, (charge - low) / (Turbo.thresholds[i] - low)))
            ZStack(alignment: .leading) {
              Parallelogram().fill(ink.opacity(0.55))
              Parallelogram().fill(Turbo.colors[i]).frame(width: 34 * fill)
              Parallelogram().stroke(ink, lineWidth: 1.5)
            }.frame(width: 34, height: 11)
          }
        }
        Text(tier > 0 ? "\(Turbo.names[tier - 1]) READY • RELEASE!" : "CHARGING DRIFT…")
          .font(display(10)).foregroundStyle(tier > 0 ? Turbo.colors[tier - 1] : .white)
          .shadow(color: ink, radius: 0, x: 1, y: 1)
      }
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        OutlinedText(text: "\(Int((me?.speed ?? 0) * 3.6))", size: 34, stroke: 2)
          .monospacedDigit()
        Text("KM/H").font(display(10)).foregroundStyle(.white).shadow(
          color: ink, radius: 0, x: 1, y: 1)
      }
    }.padding(.bottom, 2).allowsHitTesting(false)
  }

  private var steering: some View {
    HStack(spacing: 12) {
      HoldControl(
        symbol: "arrowtriangle.left.fill", label: "LEFT", color: .white, size: 74,
        active: client.steer < -0.1
      ) { down in
        client.autoDrive = false
        client.steer = down ? -1 : 0
      }
      HoldControl(
        symbol: "arrowtriangle.right.fill", label: "RIGHT", color: .white, size: 74,
        active: client.steer > 0.1
      ) { down in
        client.autoDrive = false
        client.steer = down ? 1 : 0
      }
    }
  }

  private var pedals: some View {
    HStack(alignment: .bottom, spacing: 10) {
      HoldControl(
        symbol: "stop.fill", label: "BRAKE", color: cherry, size: 54, active: client.brake
      ) { down in
        client.autoDrive = false
        client.brake = down
      }
      HoldControl(
        symbol: "sparkles", label: "DRIFT", color: Turbo.colors[0], size: 66, active: client.drift
      ) { down in
        client.autoDrive = false
        client.drift = down
      }
      HoldControl(
        symbol: "chevron.up.2", label: "GAS", color: sunshine, size: 84, active: client.throttle
      ) { down in
        client.autoDrive = false
        client.throttle = down
      }
    }
  }
}

struct HoldControl: View {
  let symbol: String
  let label: String
  let color: Color
  let size: CGFloat
  let active: Bool
  let action: (Bool) -> Void
  @State private var held = false
  var body: some View {
    VStack(spacing: 2) {
      Image(systemName: symbol).font(.system(size: size * 0.3, weight: .black))
      Text(label).font(display(max(9, size * 0.13)))
    }
    .foregroundStyle(active ? ink : color)
    .frame(width: size, height: size)
    .background(
      ZStack {
        Circle().fill(ink.opacity(0.55)).offset(y: active ? 1 : 4)
        Circle().fill(active ? AnyShapeStyle(color) : AnyShapeStyle(.ultraThinMaterial))
        Circle().fill(ink.opacity(active ? 0 : 0.35))
      }
    )
    .overlay(Circle().strokeBorder(color, lineWidth: 3))
    .shadow(color: active ? color.opacity(0.8) : .clear, radius: 10)
    .scaleEffect(active ? 0.93 : 1)
    .offset(y: active ? 3 : 0)
    .animation(.spring(response: 0.15, dampingFraction: 0.6), value: active)
    .contentShape(Circle())
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          if !held {
            held = true
            action(true)
          }
        }
        .onEnded { _ in
          held = false
          action(false)
        }
    )
    .accessibilityLabel(label)
    .accessibilityAddTraits(.isButton)
    .accessibilityAction {
      action(true)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { action(false) }
    }
  }
}

struct SpeedOverlay: View {
  let boost: Double
  let stun: Double
  let time: Double
  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height * 0.55)
      if boost > 0 {
        for i in 0..<34 {
          let seed = Double(i) * 12.9898
          let angle = seed.truncatingRemainder(dividingBy: .pi * 2)
          let phase = (time * 2.6 + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
          let reach = max(size.width, size.height) * 0.75
          let inner = reach * (0.45 + phase * 0.5)
          var line = Path()
          line.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
          line.addLine(
            to: CGPoint(
              x: center.x + cos(angle) * (inner + 70), y: center.y + sin(angle) * (inner + 70)))
          context.stroke(
            line, with: .color(.white.opacity(0.55 * min(1, boost) * (1 - phase))), lineWidth: 3)
        }
        context.fill(
          Path(CGRect(origin: .zero, size: size)),
          with: .radialGradient(
            Gradient(colors: [.clear, .orange.opacity(0.25 * min(1, boost))]), center: center,
            startRadius: size.height * 0.5, endRadius: size.width * 0.65))
      }
      if stun > 0 {
        context.fill(
          Path(CGRect(origin: .zero, size: size)),
          with: .radialGradient(
            Gradient(colors: [.clear, cherry.opacity(0.45 * min(1, stun))]), center: center,
            startRadius: size.height * 0.35, endRadius: size.width * 0.6))
      }
    }
  }
}

struct Checkers: View {
  var body: some View {
    Canvas { context, size in
      let cell: CGFloat = 14
      for x in 0..<Int(size.width / cell) + 1 {
        for y in 0..<Int(size.height / cell) + 1 where (x + y) % 2 == 0 {
          context.fill(
            Path(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)),
            with: .color(.white))
        }
      }
    }.background(ink)
  }
}
