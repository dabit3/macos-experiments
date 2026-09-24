import SwiftUI

/// The on-the-water screen: scenery, HUD, cast/strike/reel controls and result overlays.
struct FishingView: View {
  @EnvironmentObject var store: GameStore
  @State private var aim: Double = 0
  @State private var dragStartAim: Double = 0

  var body: some View {
    let session = store.session
    ZStack {
      if let session {
        SceneryView(
          waterway: session.waterway, weather: session.weather, dayProgress: session.dayProgress,
          session: session, splash: store.splash, aim: aim
        )
        .gesture(
          DragGesture(minimumDistance: 4)
            .onChanged { value in
              guard session.phase == .ready || session.phase == .charging else { return }
              aim = (dragStartAim + Double(value.translation.width) / 300).clamped(-1, 1)
            }
            .onEnded { _ in dragStartAim = aim }
        )
        .onTapGesture {
          if session.phase == .bite { store.strike() }
        }
        .accessibilityIdentifier("fishing.scene")

        LinearGradient(colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
          .ignoresSafeArea()
          .allowsHitTesting(false)

        if session.phase == .bite {
          RadialGradient(colors: [.clear, Theme.gold.opacity(0.28)], center: .center, startRadius: 180, endRadius: 520)
            .ignoresSafeArea()
            .opacity(0.6 + 0.4 * sin(session.phaseTime * 14))
            .allowsHitTesting(false)
        } else if session.phase == .fighting && session.tensionZone == .red {
          RadialGradient(colors: [.clear, Theme.red.opacity(0.35)], center: .center, startRadius: 160, endRadius: 520)
            .ignoresSafeArea()
            .opacity(0.6 + 0.4 * sin(session.phaseTime * 22))
            .allowsHitTesting(false)
        }

        VStack(spacing: 0) {
          topBar(session)
          Spacer()
          HStack(alignment: .bottom) {
            TensionGauge(session: session)
            Spacer()
            StatusBanner(session: session)
            Spacer()
            ControlCluster(session: session)
          }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)

        if session.phase == .charging {
          CastPowerBar(power: session.castPower)
        }
        if store.pendingCatch != nil {
          CatchCard()
        } else if session.phase == .lineSnapped || session.phase == .fishEscaped {
          OutcomeOverlay(snapped: session.phase == .lineSnapped)
        } else if session.phase == .dayOver {
          DayOverOverlay()
        }
      }
    }
    .ignoresSafeArea(edges: .bottom)
  }

  private func topBar(_ session: FishingSession) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Button { store.endDay() } label: {
        HStack(spacing: 6) {
          Image(systemName: "house.fill").font(.system(size: 12, weight: .bold))
          Text("END DAY").font(Theme.display(12)).kerning(0.8)
        }
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(Theme.ink)
        .hudChip()
      }
      .buttonStyle(PressStyle())
      .disabled(session.phase == .fighting)
      .opacity(session.phase == .fighting ? 0.5 : 1)
      .accessibilityIdentifier("fishing.endDay")

      HStack(spacing: 8) {
        Image(systemName: weatherIcon(session.weather)).symbolRenderingMode(.multicolor).font(.system(size: 18, weight: .bold))
        VStack(alignment: .leading, spacing: 0) {
          Text(session.waterway.name).font(Theme.display(13)).textCase(.uppercase).foregroundStyle(Theme.ink).lineLimit(1)
          Text("\(session.weather.label) · \(session.waterway.forecast.airTempF)°F").font(Theme.body(9)).foregroundStyle(Theme.inkDim).lineLimit(1)
        }
      }
      .fixedSize()
      .hudChip()

      Spacer(minLength: 4)

      HStack(spacing: 8) {
        DayDial(progress: session.dayProgress).frame(width: 22, height: 22)
        Text(session.clockLabel).font(Theme.mono(15)).foregroundStyle(Theme.ink).monospacedDigit().lineLimit(1).fixedSize()
          .accessibilityIdentifier("fishing.clock")
        Button { store.skipHour() } label: {
          Image(systemName: "forward.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
            .frame(width: 26, height: 22)
            .background(Capsule().fill(Theme.cyanDeep))
            .overlay(Capsule().strokeBorder(.white.opacity(0.3)))
        }
        .buttonStyle(PressStyle())
        .disabled(!(session.phase == .ready || session.phase == .soaking))
        .opacity(session.phase == .ready || session.phase == .soaking ? 1 : 0.35)
        .accessibilityIdentifier("fishing.skipHour")
      }
      .hudChip()

      Spacer(minLength: 4)

      HStack(spacing: 10) {
        HStack(spacing: 4) {
          Image(systemName: "basket.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.cyan)
          Text("\(store.profile.keepnet.count)/\(PlayerProfile.keepnetMaxCount)").font(Theme.mono(12)).foregroundStyle(Theme.ink)
          Text(store.profile.keepnetWeightLb.lbOz).font(Theme.mono(9)).foregroundStyle(Theme.inkDim)
        }
        .lineLimit(1)
        .fixedSize()
        Rectangle().fill(.white.opacity(0.14)).frame(width: 1, height: 18)
        LevelBadge(level: store.profile.level, size: 22)
        MeterBar(value: store.profile.levelProgress, height: 5).frame(width: 54)
        Rectangle().fill(.white.opacity(0.14)).frame(width: 1, height: 18)
        CurrencyChip(kind: .credits, amount: store.profile.credits, size: 12)
      }
      .hudChip()
    }
  }

  private func weatherIcon(_ kind: WeatherKind) -> String {
    switch kind {
    case .sunny: return "sun.max.fill"
    case .partlyCloudy: return "cloud.sun.fill"
    case .overcast: return "cloud.fill"
    case .rain: return "cloud.rain.fill"
    case .fog: return "cloud.fog.fill"
    }
  }
}

/// Tiny sun/moon arc showing how far through the fishing day we are.
struct DayDial: View {
  let progress: Double

  var body: some View {
    ZStack {
      Circle().stroke(.white.opacity(0.15), lineWidth: 2.5)
      Circle().trim(from: 0, to: progress.clamped(0.001, 1))
        .stroke(LinearGradient(colors: [Theme.gold, Theme.orange], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .rotationEffect(.degrees(-90))
      Image(systemName: progress < 0.85 ? "sun.max.fill" : "moon.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.gold)
    }
  }
}

/// Vertical line-tension meter with green/yellow/red zones, plus line-out distance.
struct TensionGauge: View {
  let session: FishingSession

  var body: some View {
    let t = session.lineTension.clamped(0, 1)
    HStack(alignment: .bottom, spacing: 8) {
      VStack(spacing: 5) {
        Image(systemName: "gauge.with.needle.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(zoneColor)
        GeometryReader { geo in
          let h = geo.size.height
          ZStack(alignment: .bottom) {
            Capsule().fill(Theme.night.opacity(0.75))
            VStack(spacing: 0) {
              Rectangle().fill(Theme.red.opacity(0.45)).frame(height: h * 0.15)
              Rectangle().fill(Theme.gold.opacity(0.30)).frame(height: h * 0.23)
              Rectangle().fill(Theme.green.opacity(0.25)).frame(height: h * 0.50)
              Rectangle().fill(Color.white.opacity(0.06)).frame(height: h * 0.12)
            }
            .clipShape(Capsule())
            Capsule()
              .fill(LinearGradient(colors: [zoneColor, zoneColor.opacity(0.55)], startPoint: .top, endPoint: .bottom))
              .frame(height: max(8, (h - 6) * t))
              .padding(3)
              .shadow(color: zoneColor.opacity(0.8), radius: 6)
              .animation(.linear(duration: 0.05), value: session.lineTension)
            Capsule().fill(.white).frame(width: 34, height: 3)
              .shadow(color: .black.opacity(0.5), radius: 1)
              .offset(y: -(h - 6) * t - 1)
          }
          .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
        }
        .frame(width: 24)
        Text("\(Int(session.lineTension * 100))%").font(Theme.mono(11)).foregroundStyle(zoneColor).monospacedDigit()
          .accessibilityIdentifier("fishing.tension")
      }
      .frame(height: 176)
      .hudChip(radius: 16)

      VStack(alignment: .leading, spacing: 6) {
        if let fish = session.fish, session.phase == .fighting {
          HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(Theme.orange)
            Text("FISH STAMINA").capsLabel(9)
          }
          MeterBar(value: fish.stamina, colors: [Theme.orange, Theme.red], height: 6).frame(width: 104)
        }
        HStack(spacing: 5) {
          Image(systemName: "arrow.left.and.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.cyan)
          Text("\(Int(session.lureDistanceFt)) ft").font(Theme.mono(16)).foregroundStyle(Theme.ink).monospacedDigit()
            .accessibilityIdentifier("fishing.distance")
        }
        Text("\(Int(session.lineLengthFt)) ft on spool").font(Theme.mono(8, weight: .medium)).foregroundStyle(Theme.inkDim)
        durability("ROD", session.rodDurability)
        durability("LINE", session.lineDurability)
      }
      .frame(width: 104, alignment: .leading)
      .hudChip(radius: 16)
    }
  }

  private func durability(_ label: String, _ value: Double) -> some View {
    HStack(spacing: 5) {
      Text(label).capsLabel(8).frame(width: 26, alignment: .leading)
      MeterBar(value: value, colors: value > 0.5 ? [Theme.green, Theme.greenDeep] : [Theme.orange, Theme.red], height: 4)
    }
  }

  private var zoneColor: Color {
    switch session.tensionZone {
    case .slack: return Theme.inkDim
    case .green: return Theme.green
    case .yellow: return Theme.gold
    case .red: return Theme.red
    }
  }
}

struct StatusBanner: View {
  let session: FishingSession

  var body: some View {
    let bite = session.phase == .bite
    HStack(spacing: 8) {
      if !bite { Image(systemName: status.2).font(.system(size: 13, weight: .bold)) }
      Text(status.0)
        .font(Theme.display(bite ? 34 : 15))
        .kerning(bite ? 3 : 1.2)
        .lineLimit(1)
        .fixedSize()
        .accessibilityIdentifier("fishing.status")
    }
    .foregroundStyle(status.1)
    .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
    .shadow(color: bite ? Theme.gold.opacity(0.9) : .clear, radius: 12)
    .padding(.horizontal, 16).padding(.vertical, 8)
    .background(Capsule().fill(Theme.night.opacity(bite ? 0 : 0.6)))
    .overlay(Capsule().strokeBorder(status.1.opacity(bite ? 0 : 0.35)))
    .scaleEffect(bite ? 1 + 0.08 * sin(session.phaseTime * 20) : 1)
    .padding(.bottom, 10)
    .animation(.easeOut(duration: 0.2), value: status.0)
  }

  private var status: (String, Color, String) {
    switch session.phase {
    case .ready: return ("HOLD CAST · DRAG TO AIM", Theme.ink, "hand.draw.fill")
    case .charging: return ("RELEASE TO CAST", Theme.gold, "arrow.up.right")
    case .flying: return ("CASTING…", Theme.ink, "wind")
    case .soaking:
      return session.rig.tackleKind.isBait ? ("WAITING FOR A BITE", Theme.ink, "hourglass") : ("HOLD REEL TO RETRIEVE", Theme.ink, "arrow.clockwise")
    case .bite: return ("STRIKE!", Theme.gold, "bolt.fill")
    case .fighting:
      switch session.tensionZone {
      case .slack: return ("KEEP THE LINE TIGHT", Theme.gold, "exclamationmark.circle.fill")
      case .green: return ("FISH ON · REEL", Theme.green, "fish.fill")
      case .yellow: return ("EASE OFF", Theme.gold, "hand.raised.fill")
      case .red: return ("LINE ABOUT TO SNAP", Theme.red, "exclamationmark.triangle.fill")
      }
    case .landed: return ("LANDED!", Theme.green, "checkmark.circle.fill")
    case .lineSnapped: return ("LINE SNAPPED", Theme.red, "scissors")
    case .fishEscaped: return ("FISH LOST", Theme.red, "xmark.circle.fill")
    case .dayOver: return ("DAY OVER", Theme.ink, "moon.stars.fill")
    }
  }
}

/// Press-and-hold button; reports press start/end without waiting for the touch to lift.
struct HoldButton: View {
  let title: String
  var icon: String? = nil
  var tone: ChromeButton.Tone = .cyan
  var diameter: CGFloat = 88
  var enabled = true
  let onPress: () -> Void
  let onRelease: () -> Void
  @State private var pressed = false

  var body: some View {
    ZStack {
      Circle().fill(Theme.night.opacity(0.45)).padding(-5)
      Circle().strokeBorder(gradient[0].opacity(pressed ? 0.9 : 0.35), lineWidth: 2).padding(-5)
      Circle().fill(LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom))
      Circle().fill(LinearGradient(colors: [.white.opacity(0.38), .clear], startPoint: .top, endPoint: .center)).padding(3)
      Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
      VStack(spacing: 1) {
        if let icon { Image(systemName: icon).font(.system(size: diameter * 0.26, weight: .heavy)) }
        Text(title.uppercased()).font(Theme.display(diameter * 0.15)).kerning(1)
      }
      .foregroundStyle(.white)
      .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
    }
    .frame(width: diameter, height: diameter)
    .scaleEffect(pressed ? 0.92 : 1)
    .brightness(pressed ? 0.1 : 0)
    .opacity(enabled ? 1 : 0.38)
    .saturation(enabled ? 1 : 0.2)
    .shadow(color: gradient[1].opacity(enabled ? 0.6 : 0), radius: pressed ? 16 : 8, y: 4)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityAddTraits(.isButton)
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in
          guard enabled, !pressed else { return }
          pressed = true
          onPress()
        }
        .onEnded { _ in
          guard pressed else { return }
          pressed = false
          onRelease()
        }
    )
    .onChange(of: enabled) { _, on in
      if !on && pressed {
        pressed = false
        onRelease()
      }
    }
    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
  }

  private var gradient: [Color] {
    switch tone {
    case .cyan: return [Theme.cyan, Theme.cyanDeep]
    case .gold: return [Theme.gold, Theme.goldDeep]
    case .green: return [Theme.green, Theme.greenDeep]
    case .red: return [Theme.red, Color(red: 0.5, green: 0.1, blue: 0.08)]
    case .slate: return [Color(red: 0.40, green: 0.50, blue: 0.60), Color(red: 0.16, green: 0.22, blue: 0.29)]
    }
  }
}

struct ControlCluster: View {
  @EnvironmentObject var store: GameStore
  let session: FishingSession

  var body: some View {
    let canCast = session.phase == .ready || session.phase == .charging
    let inWater = session.phase.lureIsInWater
    HStack(alignment: .bottom, spacing: 14) {
      VStack(spacing: 10) {
        VStack(spacing: 3) {
          Text("SPEED").capsLabel(8)
          HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { speed in
              let active = session.reelSpeed == speed
              Button { store.changeReelSpeed(speed - session.reelSpeed) } label: {
                Text("\(speed)").font(Theme.mono(11)).foregroundStyle(active ? Theme.night : Theme.ink)
                  .frame(width: 24, height: 22)
                  .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(active ? Theme.cyan : Color.white.opacity(0.08)))
              }
              .buttonStyle(PressStyle())
              .accessibilityIdentifier("fishing.reelSpeed.\(speed)")
            }
          }
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.night.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.14)))

        HoldButton(title: "Lift rod", icon: "arrow.up", tone: .slate, diameter: 62, enabled: session.phase == .fighting) {
          store.setRodRaised(true)
        } onRelease: {
          store.setRodRaised(false)
        }
        .accessibilityIdentifier("fishing.liftRod")
      }

      HoldButton(title: "Reel", icon: "arrow.clockwise", tone: .cyan, diameter: 90, enabled: inWater) {
        store.setReeling(true)
      } onRelease: {
        store.setReeling(false)
      }
      .accessibilityIdentifier("fishing.reel")

      if session.phase == .bite {
        Button { store.strike() } label: {
          ZStack {
            Circle().fill(Theme.gold.opacity(0.25)).padding(-10 - 6 * abs(sin(session.phaseTime * 9)))
            Circle().fill(LinearGradient(colors: [Theme.gold, Theme.orange], startPoint: .top, endPoint: .bottom))
            Circle().fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center)).padding(3)
            Circle().strokeBorder(.white, lineWidth: 3)
            VStack(spacing: 2) {
              Image(systemName: "bolt.fill").font(.system(size: 30, weight: .heavy))
              Text("STRIKE").font(Theme.display(18)).kerning(1.5)
            }
            .foregroundStyle(Color(red: 0.25, green: 0.12, blue: 0))
          }
          .frame(width: 108, height: 108)
          .shadow(color: Theme.gold.opacity(0.9), radius: 16)
          .scaleEffect(1 + 0.05 * sin(session.phaseTime * 18))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("fishing.strike")
      } else {
        HoldButton(title: canCast ? "Cast" : "Retrieve", icon: canCast ? "arrow.up.right" : "arrow.uturn.left", tone: canCast ? .green : .slate, diameter: 108, enabled: canCast || session.phase == .soaking) {
          if canCast { store.beginCast() } else { store.setReeling(true) }
        } onRelease: {
          if session.phase == .charging { store.releaseCast() } else { store.setReeling(false) }
        }
        .accessibilityIdentifier("fishing.cast")
      }
    }
  }
}

struct CastPowerBar: View {
  let power: Double

  var body: some View {
    VStack {
      Spacer()
      VStack(spacing: 6) {
        HStack {
          Text("CAST POWER").capsLabel(10, color: Theme.ink)
          Spacer()
          Text("\(Int(power * 100))%").font(Theme.mono(13)).foregroundStyle(power > 0.85 ? Theme.red : Theme.gold).monospacedDigit()
            .accessibilityIdentifier("fishing.castPower")
        }
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(Theme.night.opacity(0.8))
            LinearGradient(colors: [Theme.green, Theme.gold, Theme.red], startPoint: .leading, endPoint: .trailing)
              .clipShape(Capsule()).opacity(0.18)
            LinearGradient(colors: [Theme.green, Theme.gold, Theme.red], startPoint: .leading, endPoint: .trailing)
              .mask(alignment: .leading) { Capsule().frame(width: max(12, geo.size.width * power)) }
              .shadow(color: Theme.gold.opacity(0.7), radius: 6)
            ForEach(1..<4) { i in
              Rectangle().fill(.white.opacity(0.25)).frame(width: 1).offset(x: geo.size.width * Double(i) / 4)
            }
          }
        }
        .frame(width: 320, height: 16)
        .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1))
      }
      .hudChip(radius: 14)
      .frame(width: 350)
      .padding(.bottom, 160)
    }
    .allowsHitTesting(false)
  }
}

// MARK: - Overlays

struct CatchCard: View {
  @EnvironmentObject var store: GameStore
  @State private var appear = false

  var body: some View {
    if let record = store.pendingCatch {
      let species = record.species
      let mustRelease = store.profile.mustRelease(species)
      let full = !store.profile.keepnetHasRoom
      let special = record.grade == .trophy || record.grade == .unique
      let accent = special ? Theme.gold : Theme.cyan
      ZStack {
        Color.black.opacity(0.6).ignoresSafeArea()
        Sunburst(color: accent).frame(width: 800, height: 800).opacity(appear ? 1 : 0)
        HStack(spacing: 18) {
          ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LinearGradient(colors: [Color(red: 0.10, green: 0.34, blue: 0.46), Color(red: 0.03, green: 0.11, blue: 0.19)], startPoint: .top, endPoint: .bottom))
            RadialGradient(colors: [accent.opacity(0.35), .clear], center: .center, startRadius: 5, endRadius: 160)
            ForEach(0..<6) { i in
              Circle().fill(.white.opacity(0.12)).frame(width: CGFloat(4 + i % 3 * 3))
                .offset(x: CGFloat(i * 37 - 100), y: appear ? -80 : 70)
                .animation(.easeOut(duration: 1.8).delay(Double(i) * 0.12), value: appear)
            }
            FishIllustration(coloring: species.coloring).padding(18)
              .shadow(color: .black.opacity(0.6), radius: 10, y: 8)
              .rotationEffect(.degrees(appear ? -5 : 10))
              .scaleEffect(appear ? 1 : 0.6)
          }
          .frame(width: 300, height: 200)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(accent.opacity(0.5), lineWidth: 1.5))
          .overlay(alignment: .topLeading) { GradeTag(grade: record.grade).padding(10).scaleEffect(1.3, anchor: .topLeading) }

          VStack(alignment: .leading, spacing: 9) {
            Text(special ? "\(record.grade.label) CATCH!" : "YOU CAUGHT").capsLabel(12, color: accent)
            VStack(alignment: .leading, spacing: 1) {
              Text(species.name).font(Theme.display(32)).textCase(.uppercase).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityIdentifier("catch.species")
              Text(species.latinName).font(Theme.body(11)).italic().foregroundStyle(Theme.inkDim)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
              StatTile(icon: "scalemass.fill", label: "Weight", value: record.weightLb.lbOz, tint: Theme.gold)
              StatTile(icon: "ruler.fill", label: "Length", value: record.lengthIn.inchLabel, tint: Theme.cyan)
              StatTile(icon: "star.fill", label: "Experience", value: "+\(record.xpValue) XP", tint: Theme.green)
              StatTile(icon: "dollarsign.circle.fill", label: "Value", value: "\(record.sellPrice)", tint: Theme.gold)
            }
            if mustRelease {
              Label("Basic license: this species must be released", systemImage: "exclamationmark.triangle.fill")
                .font(Theme.body(10, weight: .bold)).foregroundStyle(Theme.orange)
            } else if full {
              Label("Keepnet full", systemImage: "exclamationmark.triangle.fill").font(Theme.body(10, weight: .bold)).foregroundStyle(Theme.orange)
            }
            HStack(spacing: 10) {
              ChromeButton(title: "Release", icon: "arrow.uturn.backward", tone: .slate, size: 14) { store.decide(keep: false) }
                .accessibilityIdentifier("catch.release")
              ChromeButton(title: "Keep", icon: "basket.fill", tone: .green, size: 14, minWidth: 130, disabled: mustRelease || full) { store.decide(keep: true) }
                .accessibilityIdentifier("catch.keep")
            }
          }
          .frame(width: 330)
        }
        .panel(padding: 18, radius: 22, light: true)
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(accent.opacity(0.35), lineWidth: 1))
        .scaleEffect(appear ? 1 : 0.8)
        .opacity(appear ? 1 : 0)
      }
      .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { appear = true } }
    }
  }
}

struct OutcomeOverlay: View {
  @EnvironmentObject var store: GameStore
  let snapped: Bool
  @State private var appear = false

  var body: some View {
    ZStack {
      Color.black.opacity(0.5).ignoresSafeArea()
      VStack(spacing: 12) {
        Image(systemName: snapped ? "scissors" : "fish")
          .font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.red)
          .frame(width: 64, height: 64)
          .background(Circle().fill(Theme.red.opacity(0.15)))
          .overlay(Circle().strokeBorder(Theme.red.opacity(0.4)))
          .rotationEffect(.degrees(appear ? 0 : -25))
        Text(snapped ? "LINE SNAPPED" : "THE FISH GOT AWAY").font(Theme.display(30)).kerning(2).foregroundStyle(Theme.ink)
        Text(snapped ? "The line went into the red for too long. Let the fish run when it surges and reel when it tires." : "The line went slack. Keep steady pressure so the hook stays set.")
          .font(Theme.body(12)).foregroundStyle(Theme.inkDim).multilineTextAlignment(.center).frame(maxWidth: 400)
        ChromeButton(title: "Try again", icon: "arrow.clockwise", tone: .cyan, minWidth: 160) { store.acknowledgeOutcome() }
          .accessibilityIdentifier("outcome.continue")
      }
      .panel(padding: 26, radius: 22, light: true)
      .scaleEffect(appear ? 1 : 0.85)
      .opacity(appear ? 1 : 0)
    }
    .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appear = true } }
  }
}

struct DayOverOverlay: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    ZStack {
      Color.black.opacity(0.55).ignoresSafeArea()
      VStack(spacing: 12) {
        Image(systemName: "moon.stars.fill").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.gold)
          .frame(width: 64, height: 64).background(Circle().fill(Theme.gold.opacity(0.15)))
        Text("THE DAY IS OVER").font(Theme.display(30)).kerning(2).foregroundStyle(Theme.ink)
        Text("Head back to camp, sell your catch and get ready for tomorrow.").font(Theme.body(12)).foregroundStyle(Theme.inkDim)
        ChromeButton(title: "End day", icon: "house.fill", tone: .green, minWidth: 160) { store.endDay() }
          .accessibilityIdentifier("dayover.endDay")
      }
      .panel(padding: 26, radius: 22, light: true)
    }
  }
}

// MARK: - Day summary

struct DaySummaryView: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    let catches = store.todaysCatches
    ZStack {
      SceneryView(waterway: store.currentWaterway, weather: store.currentWaterway.forecast.kind, dayProgress: 0.93, session: nil, splash: nil)
        .blur(radius: 6)
        .ignoresSafeArea()
      LinearGradient(colors: [Theme.night.opacity(0.5), Theme.night.opacity(0.85)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
      VStack(spacing: 10) {
        HStack(spacing: 12) {
          Image(systemName: "moon.stars.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.gold)
            .frame(width: 40, height: 40).background(Circle().fill(Theme.gold.opacity(0.15)))
          VStack(alignment: .leading, spacing: 0) {
            Text(store.currentWaterway.name.uppercased()).capsLabel(10, color: Theme.cyan)
            Text("DAY \(store.profile.gameDay) SUMMARY").font(Theme.display(26)).kerning(2).foregroundStyle(Theme.ink).lineLimit(1)
          }
          Spacer()
          PlayerStrip()
        }
        .frame(height: 46)

        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
              StatTile(icon: "fish.fill", label: "Catches", value: "\(catches.count)", tint: Theme.cyan)
              StatTile(icon: "arrow.up.right", label: "Casts", value: "\(store.session?.casts ?? 0)", tint: Theme.green)
              StatTile(icon: "scalemass.fill", label: "Best", value: catches.map(\.weightLb).max()?.lbOz ?? "—", tint: Theme.gold)
              StatTile(icon: "scissors", label: "Snaps", value: "\(store.profile.stats.lineBreaks)", tint: Theme.red)
            }
            SectionHeader(title: "Today's catches", icon: "list.bullet", trailing: catches.isEmpty ? nil : "\(catches.count) fish")
            if catches.isEmpty {
              EmptyState(icon: "fish", text: "No fish today. Try a different lure, time of day or spot.")
            }
            ScrollView {
              VStack(spacing: 4) {
                ForEach(catches) { record in CatchRow(record: record) }
              }
            }
          }
          .panel(padding: 12, radius: 18)

          VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Keepnet", icon: "basket.fill", tint: Theme.gold)
            VStack(spacing: 2) {
              Text("SALE VALUE").capsLabel(9)
              CurrencyChip(kind: .credits, amount: store.profile.keepnetValue, size: 24)
              Text("\(store.profile.keepnet.count) fish · \(store.profile.keepnetWeightLb.lbOz)").font(Theme.mono(10, weight: .medium)).foregroundStyle(Theme.inkDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.gold.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.gold.opacity(0.25)))
            ChromeButton(title: "Sell keepnet", icon: "dollarsign.circle.fill", tone: .gold, disabled: store.profile.keepnet.isEmpty) { store.sellKeepnet() }
              .frame(maxWidth: .infinity)
              .accessibilityIdentifier("summary.sell")
            if store.dayEarnings > 0 {
              HStack {
                Label("Earned today", systemImage: "checkmark.circle.fill").font(Theme.body(11, weight: .bold)).foregroundStyle(Theme.green)
                Spacer()
                CurrencyChip(kind: .credits, amount: store.dayEarnings)
              }
              .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Spacer(minLength: 0)
            ChromeButton(title: "Back to camp", icon: "house.fill", tone: .green, size: 16) { store.finishDay() }
              .frame(maxWidth: .infinity)
              .accessibilityIdentifier("summary.done")
          }
          .frame(width: 290)
          .panel(padding: 12, radius: 18)
          .animation(.spring(response: 0.4), value: store.dayEarnings)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
    }
  }
}
