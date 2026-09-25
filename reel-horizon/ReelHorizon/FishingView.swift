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

        VStack {
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
        .padding(12)

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
    HStack(alignment: .top, spacing: 10) {
      Button { store.endDay() } label: {
        HStack(spacing: 6) {
          Image(systemName: "house.fill").font(.system(size: 13, weight: .bold))
          Text("End day").font(Theme.display(13))
        }
        .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.panelStroke))
      }
      .disabled(session.phase == .fighting)
      .accessibilityIdentifier("fishing.endDay")

      VStack(alignment: .leading, spacing: 2) {
        Text(session.waterway.name).font(Theme.display(15)).textCase(.uppercase).foregroundStyle(Theme.ink)
        HStack(spacing: 6) {
          Image(systemName: weatherIcon(session.weather)).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.gold)
          Text("\(session.weather.label) · \(session.waterway.forecast.airTempF)°F").font(Theme.body(11)).foregroundStyle(Theme.inkDim)
        }
      }
      .padding(.horizontal, 10).padding(.vertical, 5)
      .background(RoundedRectangle(cornerRadius: 6).fill(Theme.panel))
      .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.panelStroke))

      Spacer()

      HStack(spacing: 8) {
        Image(systemName: "clock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.cyan)
        Text(session.clockLabel).font(Theme.mono(15)).foregroundStyle(Theme.ink).monospacedDigit()
          .accessibilityIdentifier("fishing.clock")
        Button { store.skipHour() } label: {
          Image(systemName: "forward.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            .frame(width: 26, height: 26).background(RoundedRectangle(cornerRadius: 5).fill(Theme.cyanDeep))
        }
        .disabled(!(session.phase == .ready || session.phase == .soaking))
        .opacity(session.phase == .ready || session.phase == .soaking ? 1 : 0.4)
        .accessibilityIdentifier("fishing.skipHour")
      }
      .padding(.horizontal, 10).padding(.vertical, 5)
      .background(RoundedRectangle(cornerRadius: 6).fill(Theme.panel))
      .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.panelStroke))

      Spacer()

      HStack(spacing: 10) {
        HStack(spacing: 4) {
          Image(systemName: "basket.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.cyan)
          Text("\(store.profile.keepnet.count)/\(PlayerProfile.keepnetMaxCount)").font(Theme.mono(12)).foregroundStyle(Theme.ink)
          Text(store.profile.keepnetWeightLb.lbOz).font(Theme.mono(10)).foregroundStyle(Theme.inkDim)
        }
        .lineLimit(1)
        .fixedSize()
        Divider().frame(height: 18).overlay(Theme.panelStroke)
        LevelBadge(level: store.profile.level, size: 24)
        MeterBar(value: store.profile.levelProgress, height: 5).frame(width: 60)
        Divider().frame(height: 18).overlay(Theme.panelStroke)
        CurrencyChip(kind: .credits, amount: store.profile.credits, size: 12)
      }
      .padding(.horizontal, 10).padding(.vertical, 7)
      .background(RoundedRectangle(cornerRadius: 6).fill(Theme.panel))
      .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.panelStroke))
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

/// Vertical line-tension meter with green/yellow/red zones, plus line-out distance.
struct TensionGauge: View {
  let session: FishingSession

  var body: some View {
    HStack(alignment: .bottom, spacing: 8) {
      VStack(spacing: 4) {
        Text("LINE").capsLabel(10)
        GeometryReader { geo in
          let h = geo.size.height
          ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.6))
            VStack(spacing: 0) {
              Rectangle().fill(Theme.red.opacity(0.35)).frame(height: h * 0.15)
              Rectangle().fill(Theme.gold.opacity(0.35)).frame(height: h * 0.23)
              Rectangle().fill(Theme.green.opacity(0.35)).frame(height: h * 0.50)
              Rectangle().fill(Color.white.opacity(0.1)).frame(height: h * 0.12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
            RoundedRectangle(cornerRadius: 4)
              .fill(LinearGradient(colors: [zoneColor, zoneColor.opacity(0.6)], startPoint: .top, endPoint: .bottom))
              .frame(height: max(4, h * session.lineTension.clamped(0, 1)))
              .padding(3)
              .animation(.linear(duration: 0.05), value: session.lineTension)
            // Needle
            Rectangle().fill(.white).frame(height: 2)
              .offset(y: -h * session.lineTension.clamped(0, 1) + 1)
          }
          .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.panelStroke))
        }
        .frame(width: 26)
        Text("\(Int(session.lineTension * 100))%").font(Theme.mono(10)).foregroundStyle(zoneColor).monospacedDigit()
          .accessibilityIdentifier("fishing.tension")
      }
      .frame(height: 170)

      VStack(alignment: .leading, spacing: 6) {
        if let fish = session.fish, session.phase == .fighting {
          HStack(spacing: 4) {
            Image(systemName: "bolt.fill").font(.system(size: 10)).foregroundStyle(Theme.gold)
            Text("STAMINA").capsLabel(10)
          }
          MeterBar(value: fish.stamina, colors: [Theme.orange, Theme.red], height: 6).frame(width: 90)
        }
        HStack(spacing: 4) {
          Image(systemName: "arrow.left.and.right").font(.system(size: 10)).foregroundStyle(Theme.cyan)
          Text("\(Int(session.lureDistanceFt)) ft").font(Theme.mono(13)).foregroundStyle(Theme.ink).monospacedDigit()
            .accessibilityIdentifier("fishing.distance")
        }
        Text("\(Int(session.lineLengthFt)) ft spool").font(Theme.mono(9)).foregroundStyle(Theme.inkDim)
        HStack(spacing: 4) {
          Text("ROD").capsLabel(9)
          MeterBar(value: session.rodDurability, colors: [Theme.green, Theme.greenDeep], height: 4).frame(width: 50)
        }
        HStack(spacing: 4) {
          Text("LINE").capsLabel(9)
          MeterBar(value: session.lineDurability, colors: [Theme.green, Theme.greenDeep], height: 4).frame(width: 50)
        }
      }
      .padding(8)
      .background(RoundedRectangle(cornerRadius: 6).fill(Theme.panel))
      .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.panelStroke))
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
    Text(status.0)
      .font(Theme.display(session.phase == .bite ? 30 : 16))
      .kerning(1.2)
      .foregroundStyle(status.1)
      .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
      .padding(.horizontal, 14).padding(.vertical, 6)
      .background(Capsule().fill(Color.black.opacity(session.phase == .bite ? 0.0 : 0.45)))
      .scaleEffect(session.phase == .bite ? 1 + 0.08 * sin(session.phaseTime * 20) : 1)
      .accessibilityIdentifier("fishing.status")
      .padding(.bottom, 8)
  }

  private var status: (String, Color) {
    switch session.phase {
    case .ready: return ("HOLD CAST · DRAG TO AIM", Theme.ink)
    case .charging: return ("RELEASE TO CAST", Theme.gold)
    case .flying: return ("CASTING…", Theme.ink)
    case .soaking:
      return (session.rig.tackleKind.isBait ? "WAITING FOR A BITE" : "HOLD REEL TO RETRIEVE", Theme.ink)
    case .bite: return ("STRIKE!", Theme.gold)
    case .fighting:
      switch session.tensionZone {
      case .slack: return ("KEEP THE LINE TIGHT", Theme.gold)
      case .green: return ("FISH ON · REEL", Theme.green)
      case .yellow: return ("EASE OFF", Theme.gold)
      case .red: return ("LINE ABOUT TO SNAP", Theme.red)
      }
    case .landed: return ("LANDED!", Theme.green)
    case .lineSnapped: return ("LINE SNAPPED", Theme.red)
    case .fishEscaped: return ("FISH LOST", Theme.red)
    case .dayOver: return ("DAY OVER", Theme.ink)
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
      Circle().fill(
        LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom))
      Circle().strokeBorder(.white.opacity(0.55), lineWidth: 2)
      Circle().strokeBorder(.black.opacity(0.4), lineWidth: 6).padding(2)
      VStack(spacing: 2) {
        if let icon { Image(systemName: icon).font(.system(size: diameter * 0.26, weight: .heavy)) }
        Text(title).font(Theme.display(diameter * 0.17)).kerning(1)
      }
      .foregroundStyle(.white)
      .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
    }
    .frame(width: diameter, height: diameter)
    .scaleEffect(pressed ? 0.93 : 1)
    .brightness(pressed ? 0.12 : 0)
    .opacity(enabled ? 1 : 0.4)
    .shadow(color: .black.opacity(0.5), radius: 5, y: 3)
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
    .animation(.easeOut(duration: 0.08), value: pressed)
  }

  private var gradient: [Color] {
    switch tone {
    case .cyan: return [Theme.cyan, Theme.cyanDeep]
    case .gold: return [Theme.gold, Theme.goldDeep]
    case .green: return [Theme.green, Theme.greenDeep]
    case .red: return [Theme.red, Color(red: 0.5, green: 0.1, blue: 0.08)]
    case .slate: return [Color(red: 0.45, green: 0.55, blue: 0.65), Color(red: 0.2, green: 0.27, blue: 0.34)]
    }
  }
}

struct ControlCluster: View {
  @EnvironmentObject var store: GameStore
  let session: FishingSession

  var body: some View {
    let canCast = session.phase == .ready || session.phase == .charging
    let inWater = session.phase.lureIsInWater
    HStack(alignment: .bottom, spacing: 12) {
      VStack(spacing: 8) {
        // Reel speed selector
        HStack(spacing: 2) {
          ForEach(1...3, id: \.self) { speed in
            Button { store.changeReelSpeed(speed - session.reelSpeed) } label: {
              Text("\(speed)").font(Theme.mono(11)).foregroundStyle(session.reelSpeed == speed ? .black : Theme.ink)
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 4).fill(session.reelSpeed == speed ? Theme.cyan : Color.white.opacity(0.08)))
            }
            .accessibilityIdentifier("fishing.reelSpeed.\(speed)")
          }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.panelStroke))

        HoldButton(title: "Lift rod", icon: "arrow.up", tone: .slate, diameter: 64, enabled: session.phase == .fighting) {
          store.setRodRaised(true)
        } onRelease: {
          store.setRodRaised(false)
        }
        .accessibilityIdentifier("fishing.liftRod")
      }

      HoldButton(title: "Reel", icon: "arrow.clockwise", tone: .cyan, diameter: 92, enabled: inWater) {
        store.setReeling(true)
      } onRelease: {
        store.setReeling(false)
      }
      .accessibilityIdentifier("fishing.reel")

      if session.phase == .bite {
        Button { store.strike() } label: {
          ZStack {
            Circle().fill(LinearGradient(colors: [Theme.gold, Theme.orange], startPoint: .top, endPoint: .bottom))
            Circle().strokeBorder(.white, lineWidth: 3)
            VStack(spacing: 2) {
              Image(systemName: "bolt.fill").font(.system(size: 28, weight: .heavy))
              Text("STRIKE").font(Theme.display(18)).kerning(1)
            }
            .foregroundStyle(.black.opacity(0.85))
          }
          .frame(width: 108, height: 108)
          .shadow(color: Theme.gold.opacity(0.9), radius: 14)
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
      VStack(spacing: 4) {
        Text("CAST POWER").capsLabel(11, color: Theme.ink)
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.6))
          LinearGradient(colors: [Theme.green, Theme.gold, Theme.red], startPoint: .leading, endPoint: .trailing)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(0.35)
          GeometryReader { geo in
            RoundedRectangle(cornerRadius: 6)
              .fill(LinearGradient(colors: [Theme.green, Theme.gold, Theme.red], startPoint: .leading, endPoint: .trailing))
              .frame(width: geo.size.width * power)
          }
        }
        .frame(width: 320, height: 18)
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
        Text("\(Int(power * 100))%").font(Theme.mono(12)).foregroundStyle(Theme.ink).monospacedDigit()
          .accessibilityIdentifier("fishing.castPower")
      }
      .padding(10)
      .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel))
      .padding(.bottom, 150)
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
      ZStack {
        Color.black.opacity(0.55).ignoresSafeArea()
        HStack(spacing: 18) {
          ZStack {
            RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [Color(red: 0.10, green: 0.30, blue: 0.40), Color(red: 0.04, green: 0.12, blue: 0.20)], startPoint: .top, endPoint: .bottom))
            FishIllustration(coloring: species.coloring).padding(16)
              .shadow(color: .black.opacity(0.6), radius: 8, y: 6)
              .rotationEffect(.degrees(appear ? -6 : 8))
          }
          .frame(width: 300, height: 190)
          .overlay(alignment: .topLeading) { GradeTag(grade: record.grade).padding(10).scaleEffect(1.3, anchor: .topLeading) }

          VStack(alignment: .leading, spacing: 8) {
            Text(record.grade == .trophy || record.grade == .unique ? "\(record.grade.label) CATCH!" : "YOU CAUGHT").capsLabel(13, color: record.grade == .common || record.grade == .young ? Theme.cyan : Theme.gold)
            Text(species.name).font(Theme.display(34)).textCase(.uppercase).foregroundStyle(Theme.ink)
              .accessibilityIdentifier("catch.species")
            Text(species.latinName).font(Theme.body(12)).italic().foregroundStyle(Theme.inkDim)
            HStack(spacing: 20) {
              detail("scalemass.fill", "Weight", record.weightLb.lbOz)
              detail("ruler.fill", "Length", record.lengthIn.inchLabel)
            }
            HStack(spacing: 20) {
              detail("star.fill", "Experience", "+\(record.xpValue) XP")
              detail("dollarsign.circle.fill", "Value", "\(record.sellPrice)")
            }
            if mustRelease {
              Label("Basic license: this species must be released", systemImage: "exclamationmark.triangle.fill")
                .font(Theme.body(11, weight: .bold)).foregroundStyle(Theme.orange)
            } else if full {
              Label("Keepnet full", systemImage: "exclamationmark.triangle.fill").font(Theme.body(11, weight: .bold)).foregroundStyle(Theme.orange)
            }
            HStack(spacing: 10) {
              ChromeButton(title: "Release", icon: "arrow.uturn.backward", tone: .slate, size: 15) { store.decide(keep: false) }
                .accessibilityIdentifier("catch.release")
              ChromeButton(title: "Keep", icon: "basket.fill", tone: .green, size: 15, disabled: mustRelease || full) { store.decide(keep: true) }
                .accessibilityIdentifier("catch.keep")
            }
          }
          .frame(width: 340)
        }
        .panel(padding: 18, radius: 16, light: true)
        .scaleEffect(appear ? 1 : 0.8)
        .opacity(appear ? 1 : 0)
      }
      .onAppear { withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { appear = true } }
    }
  }

  private func detail(_ icon: String, _ label: String, _ value: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.gold)
      VStack(alignment: .leading, spacing: 0) {
        Text(label).capsLabel(9)
        Text(value).font(Theme.mono(14)).foregroundStyle(Theme.ink)
      }
    }
  }
}

struct OutcomeOverlay: View {
  @EnvironmentObject var store: GameStore
  let snapped: Bool

  var body: some View {
    ZStack {
      Color.black.opacity(0.35).ignoresSafeArea()
      VStack(spacing: 12) {
        Image(systemName: snapped ? "scissors" : "fish").font(.system(size: 36, weight: .bold)).foregroundStyle(Theme.red)
        Text(snapped ? "LINE SNAPPED" : "THE FISH GOT AWAY").font(Theme.display(30)).kerning(2).foregroundStyle(Theme.ink)
        Text(snapped ? "The line went into the red for too long. Let the fish run when it surges and reel when it tires." : "The line went slack. Keep steady pressure so the hook stays set.")
          .font(Theme.body(13)).foregroundStyle(Theme.inkDim).multilineTextAlignment(.center).frame(maxWidth: 420)
        ChromeButton(title: "Continue", tone: .cyan) { store.acknowledgeOutcome() }
          .accessibilityIdentifier("outcome.continue")
      }
      .panel(padding: 24, radius: 14, light: true)
    }
  }
}

struct DayOverOverlay: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    ZStack {
      Color.black.opacity(0.5).ignoresSafeArea()
      VStack(spacing: 12) {
        Image(systemName: "moon.stars.fill").font(.system(size: 36, weight: .bold)).foregroundStyle(Theme.gold)
        Text("THE DAY IS OVER").font(Theme.display(30)).kerning(2).foregroundStyle(Theme.ink)
        Text("Head back to camp, sell your catch and get ready for tomorrow.").font(Theme.body(13)).foregroundStyle(Theme.inkDim)
        ChromeButton(title: "End day", icon: "house.fill", tone: .green) { store.endDay() }
          .accessibilityIdentifier("dayover.endDay")
      }
      .panel(padding: 24, radius: 14, light: true)
    }
  }
}

// MARK: - Day summary

struct DaySummaryView: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    let catches = store.todaysCatches
    ZStack {
      SceneryView(waterway: store.currentWaterway, weather: store.currentWaterway.forecast.kind, dayProgress: 0.93, session: nil, splash: nil).blur(radius: 4)
      Color.black.opacity(0.5).ignoresSafeArea()
      VStack(spacing: 12) {
        HStack {
          Text("DAY \(store.profile.gameDay) SUMMARY").font(Theme.display(26)).kerning(2).foregroundStyle(Theme.ink)
          Spacer()
          PlayerStrip()
        }
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Today's catches").capsLabel(13, color: Theme.cyan)
            if catches.isEmpty {
              Text("No fish today. Try a different lure, time of day or spot.").font(Theme.body(12)).foregroundStyle(Theme.inkDim)
            }
            ScrollView {
              VStack(spacing: 4) {
                ForEach(catches) { record in CatchRow(record: record) }
              }
            }
          }
          .panel(padding: 12, radius: 10)

          VStack(alignment: .leading, spacing: 10) {
            Text("Keepnet").capsLabel(13, color: Theme.cyan)
            summaryRow("Fish kept", "\(store.profile.keepnet.count)")
            summaryRow("Total weight", store.profile.keepnetWeightLb.lbOz)
            summaryRow("Sale value", "\(store.profile.keepnetValue)")
            ChromeButton(title: "Sell keepnet", icon: "dollarsign.circle.fill", tone: .gold, disabled: store.profile.keepnet.isEmpty) { store.sellKeepnet() }
              .frame(maxWidth: .infinity)
              .accessibilityIdentifier("summary.sell")
            if store.dayEarnings > 0 {
              HStack { Text("Earned today").capsLabel(11); Spacer(); CurrencyChip(kind: .credits, amount: store.dayEarnings) }
            }
            Divider().overlay(Theme.panelStroke)
            summaryRow("Catches", "\(catches.count)")
            summaryRow("Casts", "\(store.session?.casts ?? 0)")
            summaryRow("Line breaks", "\(store.profile.stats.lineBreaks)")
            Spacer()
            ChromeButton(title: "Back to camp", icon: "house.fill", tone: .green, size: 16) { store.finishDay() }
              .frame(maxWidth: .infinity)
              .accessibilityIdentifier("summary.done")
          }
          .frame(width: 300)
          .panel(padding: 12, radius: 10)
        }
      }
      .padding(14)
    }
  }

  private func summaryRow(_ label: String, _ value: String) -> some View {
    HStack { Text(label).capsLabel(11); Spacer(); Text(value).font(Theme.mono(13)).foregroundStyle(Theme.ink) }
  }
}
