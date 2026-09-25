import SwiftUI

@main
struct DuskAnglerApp: App {
  var body: some Scene {
    WindowGroup { AnglerView() }
  }
}

struct AnglerView: View {
  @StateObject private var store = GameStore()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var panel: Panel?
  @State private var showTutorial = false
  private let clock = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

  enum Panel: String, Identifiable {
    case journal, settings
    var id: String { rawValue }
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        LakeBackdrop(violet: store.lake == .violet)
        if store.phase == .home {
          home
        } else if store.phase == .caught, let record = store.latest {
          CatchView(
            record: record, total: store.progress.total,
            personalBest: store.progress.total > 1 && record.score >= store.progress.best,
            again: store.begin
          ) {
            store.phase = .home
          }
        } else if store.phase == .failed {
          failure
        } else if store.phase == .landing {
          landing
        } else {
          gameplay(height: geometry.size.height)
        }
        if store.paused { pauseOverlay }
        if showTutorial { tutorial }
      }
      .foregroundStyle(Palette.text)
      .font(TypeStyle.body(15))
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.phase)
    }
    .preferredColorScheme(.dark)
    .sheet(item: $panel) { item in
      FieldPanel(store: store, panel: item) {
        panel = nil
        showTutorial = true
      }
    }
    .onReceive(clock) { _ in store.tick(0.05) }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { store.pause() }
    }
  }

  // MARK: Home

  private var home: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Dusk Angler").font(TypeStyle.display(30))
          Text("Cast, hook and play the line\nbefore the light is gone.")
            .font(TypeStyle.body(15)).foregroundStyle(Palette.text.opacity(0.82))
        }
        .shadow(color: Palette.night.opacity(0.9), radius: 6, y: 1)
        Spacer()
        IconButton(systemImage: "gearshape", label: "Settings", identifier: "settings") {
          panel = .settings
        }
      }
      .padding(.top, 8)
      .padding(.bottom, 44)
      .padding(.horizontal, 20)
      .background(
        LinearGradient(
          colors: [Palette.night.opacity(0.95), Palette.night.opacity(0.8), .clear],
          startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea(edges: .top)
      )
      .padding(.horizontal, -20)
      Spacer(minLength: 20)
      VStack(alignment: .leading, spacing: 16) {
        Text("Choose your water").font(TypeStyle.label(13)).foregroundStyle(Palette.muted)
        HStack(spacing: 10) {
          ForEach(Lake.allCases) { lake in lakeOption(lake) }
        }
        HStack(spacing: 12) {
          Stat(
            value: "\(store.progress.total)", label: store.progress.total == 1 ? "Catch" : "Catches"
          )
          Stat(
            value: store.progress.best == 0 ? "—" : "\(store.progress.best)", label: "Best score")
          Stat(value: "\(store.progress.bait)", label: "Glow bait")
        }
        .padding(.vertical, 2)
        ActionButton(
          title: "Cast at \(store.lake.name)", systemImage: "scope",
          identifier: "Cast at \(store.lake.name)"
        ) {
          if store.progress.tutorialSeen { store.begin() } else { showTutorial = true }
        }
        ActionButton(
          title: "Field journal", systemImage: "book.pages", kind: .secondary,
          identifier: "Field journal"
        ) { panel = .journal }
      }
      .panel()
      .padding(.bottom, 8)
    }
    .padding(.horizontal, 20)
  }

  private func lakeOption(_ lake: Lake) -> some View {
    let locked = lake == .violet && !store.progress.violetUnlocked
    let selected = store.lake == lake
    return Button {
      store.lake = lake
      store.feedback()
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Circle().fill(lake == .amber ? Palette.sunset : Palette.violet).frame(width: 8, height: 8)
          Text(lake.name).font(TypeStyle.label(15)).lineLimit(1).minimumScaleFactor(0.8)
          Spacer(minLength: 0)
          if locked { Image(systemName: "lock.fill").font(.system(size: 11)) }
        }
        Text(
          locked
            ? "\(3 - store.progress.total) more \(3 - store.progress.total == 1 ? "catch" : "catches") to open"
            : lake == .amber ? "Perch, trout, koi" : "Trout, char, koi"
        )
        .font(TypeStyle.body(12)).foregroundStyle(Palette.muted).lineLimit(1)
        .minimumScaleFactor(0.8)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        Palette.raised.opacity(selected ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 14)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14).strokeBorder(
          selected ? Palette.sunset : Palette.line, lineWidth: selected ? 1.5 : 1)
      )
      .opacity(locked ? 0.6 : 1)
    }
    .buttonStyle(PressedActionStyle())
    .disabled(locked)
    .accessibilityLabel(lake.name)
    .accessibilityValue(locked ? "Locked" : selected ? "Selected" : "")
    .accessibilityIdentifier("lake-\(lake.rawValue)")
  }

  // MARK: Gameplay

  private var step: Int {
    switch store.phase {
    case .aiming: return 0
    case .waiting, .bite: return 1
    default: return 2
    }
  }

  private var headline: String {
    switch store.phase {
    case .aiming: return "Pick a fish"
    case .waiting: return "Watch the float"
    case .bite: return "Bite — hook it!"
    default: return store.duel.species.name
    }
  }

  private func gameplay(height: CGFloat) -> some View {
    ZStack(alignment: .top) {
      if store.phase == .duel {
        duelStage.frame(height: height * 0.24).offset(y: height * 0.16)
      } else {
        castingStage.frame(height: height * 0.24).offset(y: height * 0.41)
      }
      VStack(spacing: 14) {
        HStack(alignment: .center) {
          VStack(alignment: .leading, spacing: 2) {
            Text(store.lake.name).font(TypeStyle.body(13)).foregroundStyle(Palette.muted)
            Text(headline).font(TypeStyle.display(22))
              .foregroundStyle(store.phase == .bite ? Palette.sunset : Palette.text)
              .lineLimit(1).minimumScaleFactor(0.7)
          }
          Spacer()
          IconButton(systemImage: "pause.fill", label: "Pause fishing", identifier: "pause") {
            store.pause()
          }
        }
        StepIndicator(step: step)
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
      .padding(.bottom, 28)
      .background(
        LinearGradient(
          stops: [
            .init(color: Palette.night.opacity(0.92), location: 0),
            .init(color: Palette.night.opacity(0.7), location: 0.65),
            .init(color: .clear, location: 1),
          ], startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea(edges: .top))
      VStack {
        Spacer()
        controlDeck.padding(.horizontal, 16).padding(.bottom, 8)
      }
    }
  }

  private var castingStage: some View {
    GeometryReader { geometry in
      ZStack {
        WaterSparkles(time: reduceMotion ? 0 : store.phaseTime)
        if store.phase == .aiming {
          Color.clear.contentShape(Rectangle())
            .onTapGesture { location in
              store.aim = CGPoint(
                x: location.x / geometry.size.width, y: location.y / geometry.size.height)
              if let index = Casting.target(x: store.aim.x, y: store.aim.y) {
                store.selected = index
              }
            }
          ForEach(0..<3, id: \.self) { index in
            let species = store.lake.species[index]
            let chosen = Casting.target(x: store.aim.x, y: store.aim.y) == index
            Button {
              store.target(index)
            } label: {
              VStack(spacing: 4) {
                ZStack {
                  Ellipse().stroke(Palette.text.opacity(0.35), lineWidth: 1)
                    .frame(width: 86, height: 24).offset(y: 16)
                  FishArt(species: species, silhouette: true)
                    .frame(width: 88, height: 46)
                    .shadow(
                      color: (species.rare ? Palette.violet : Palette.sunset).opacity(0.8),
                      radius: 10)
                }
                Text(species.name).font(TypeStyle.label(12))
                  .padding(.horizontal, 8).padding(.vertical, 3)
                  .background(Palette.night.opacity(chosen ? 0.8 : 0.45), in: Capsule())
                  .foregroundStyle(chosen ? Palette.text : Palette.text.opacity(0.75))
              }
              .frame(width: 118, height: 84)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(
              x: geometry.size.width * Casting.positions[index].0,
              y: geometry.size.height * Casting.positions[index].1
            )
            .accessibilityLabel("Aim at \(species.name)")
            .accessibilityAddTraits(chosen ? .isSelected : [])
            .accessibilityIdentifier("fish-\(index)")
          }
          Circle()
            .strokeBorder(Palette.sunset, lineWidth: 2)
            .frame(width: 70, height: 70)
            .overlay(Circle().fill(Palette.sunset).frame(width: 5, height: 5))
            .position(
              x: geometry.size.width * store.aim.x, y: geometry.size.height * store.aim.y - 10
            )
            .allowsHitTesting(false)
        } else {
          let point = CGPoint(
            x: geometry.size.width * store.aim.x, y: geometry.size.height * store.aim.y)
          Path { p in
            p.move(to: CGPoint(x: geometry.size.width * 0.85, y: geometry.size.height + 200))
            p.addQuadCurve(
              to: point,
              control: CGPoint(x: geometry.size.width * 0.38, y: geometry.size.height * 0.45))
          }
          .stroke(Palette.text.opacity(0.55), lineWidth: 1)
          ZStack {
            ForEach(0..<3) { index in
              Ellipse()
                .stroke(
                  (store.phase == .bite ? Palette.sunset : Palette.text)
                    .opacity(0.6 - Double(index) * 0.15), lineWidth: 1.5
                )
                .frame(width: CGFloat(45 + index * 34), height: CGFloat(17 + index * 13))
            }
            Capsule().fill(Palette.danger).frame(width: 8, height: 16).offset(y: -10)
            Capsule().fill(Palette.text).frame(width: 8, height: 10).offset(y: -19)
          }
          .offset(y: store.phase == .bite && !reduceMotion ? 6 : 0)
          .scaleEffect(store.phase == .bite && !reduceMotion ? 1.15 : 1)
          .position(point)
        }
      }
    }
  }

  private var duelStage: some View {
    ZStack {
      WaterSparkles(time: reduceMotion ? 0 : store.duel.elapsed)
      Ellipse().stroke(Palette.text.opacity(0.22), lineWidth: 1)
        .frame(width: 270, height: 75).offset(y: 48)
      FishArt(species: store.duel.species)
        .frame(width: 250, height: 140)
        .shadow(
          color: (store.duel.surging ? Palette.danger : Palette.sunset).opacity(0.3), radius: 20
        )
        .rotationEffect(
          .degrees(
            reduceMotion
              ? 0
              : sin(store.duel.elapsed * (store.duel.surging ? 9 : 2))
                * (store.duel.surging ? 10 : 3))
        )
        .offset(y: reduceMotion ? 0 : sin(store.duel.elapsed * 2) * 6)
    }
    .accessibilityHidden(true)
  }

  @ViewBuilder private var controlDeck: some View {
    if store.phase == .aiming {
      aimDeck
    } else if store.phase == .waiting || store.phase == .bite {
      hookDeck
    } else if store.phase == .duel {
      duelDeck
    }
  }

  private var aimDeck: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 14) {
        FishArt(species: store.activeSpecies).frame(width: 72, height: 42)
        VStack(alignment: .leading, spacing: 3) {
          HStack {
            Text(store.activeSpecies.name).font(TypeStyle.title(18))
              .lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            RarityTag(rare: store.activeSpecies.rare)
          }
          Text(store.activeSpecies.behavior).font(TypeStyle.body(13))
            .foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
      }
      if store.progress.bait >= 2 {
        Toggle(isOn: $store.useBait) {
          VStack(alignment: .leading, spacing: 1) {
            Text("Use glow bait").font(TypeStyle.label(15))
            Text("Spend 2 of \(store.progress.bait) to draw a rare fish")
              .font(TypeStyle.body(12)).foregroundStyle(Palette.muted)
          }
        }
        .tint(Palette.violet)
        .accessibilityIdentifier("glow-bait")
      }
      ActionButton(
        title: "Cast", systemImage: "arrow.up.forward", identifier: "Cast the line",
        action: store.cast)
    }
    .panel()
  }

  private var hookDeck: some View {
    let biting = store.phase == .bite
    return VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text(biting ? "Tap Hook now" : "Wait for the float to dip")
          .font(TypeStyle.title(18))
        Text(biting ? "The bite won’t last long." : "Hooking too early spooks the fish.")
          .font(TypeStyle.body(13)).foregroundStyle(Palette.muted)
      }
      Meter(
        fraction: biting ? 1 - store.phaseTime / GameStore.biteWindow : 0,
        color: Palette.sunset
      )
      .accessibilityHidden(true)
      ActionButton(
        title: biting ? "Hook" : "Waiting…", systemImage: biting ? "bolt.fill" : nil,
        kind: biting ? .primary : .secondary, identifier: "hook", action: store.hook)
    }
    .panel()
  }

  private var duelDeck: some View {
    let duel = store.duel
    let zone = TensionZone(duel.tension)
    return VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Landed").font(TypeStyle.label(13)).foregroundStyle(Palette.muted)
          Spacer()
          Text("\(Int(duel.landed * 100))%").font(TypeStyle.number(15))
        }
        Meter(fraction: duel.landed, color: Palette.sunset)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Landed \(Int(duel.landed * 100)) percent")
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline) {
          Text("Line tension").font(TypeStyle.label(13)).foregroundStyle(Palette.muted)
          Spacer()
          Text(duel.slack > 1 ? "Slack · \(max(0, Int(ceil(5 - duel.slack))))s" : zone.word)
            .font(TypeStyle.label(13)).foregroundStyle(zone.color)
          Text("\(Int(duel.tension * 100))%").font(TypeStyle.number(15))
            .frame(minWidth: 48, alignment: .trailing)
        }
        TensionMeter(tension: duel.tension)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Line tension \(Int(duel.tension * 100)) percent, \(zone.word)")
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Surges").font(TypeStyle.label(13)).foregroundStyle(Palette.muted)
          Spacer()
          Text(
            duel.surging
              ? String(format: "Surging · %.1fs", duel.surgeRemaining)
              : String(format: "Next in %.1fs", duel.secondsToSurge)
          )
          .font(TypeStyle.label(13)).monospacedDigit()
          .foregroundStyle(
            duel.surging ? Palette.danger : duel.warning ? Palette.amber : Palette.text)
        }
        SurgeForecast(elapsed: duel.elapsed)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        duel.surging ? "Fish surging" : "Next surge in \(Int(ceil(duel.secondsToSurge))) seconds")
      ReelButton(
        holding: $store.holding, tension: duel.tension, surging: duel.surging,
        warning: duel.warning, elapsed: duel.elapsed)
    }
    .panel()
  }

  // MARK: Overlays

  private var failure: some View {
    VStack(spacing: 0) {
      Spacer()
      VStack(alignment: .leading, spacing: 18) {
        Text("The fish got away").font(TypeStyle.label(13)).foregroundStyle(Palette.sunset)
        Text(store.failure.components(separatedBy: "|").first ?? "Gone")
          .font(TypeStyle.display(28)).fixedSize(horizontal: false, vertical: true)
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "lightbulb").foregroundStyle(Palette.amber)
          Text(store.failure.components(separatedBy: "|").last ?? "")
            .font(TypeStyle.body(15)).foregroundStyle(Palette.text.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
        }
        ActionButton(
          title: "Try again", systemImage: "arrow.counterclockwise", identifier: "Cast again",
          action: store.begin)
        ActionButton(title: "Back to shore", kind: .quiet, identifier: "home") {
          store.phase = .home
        }
      }
      .panel(padding: 22)
    }
    .padding(.horizontal, 16).padding(.bottom, 8)
  }

  private var pauseOverlay: some View {
    ZStack {
      Palette.night.opacity(0.7).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 14) {
        Text("Paused").font(TypeStyle.display(28))
        Text("Your line stays where it is.").font(TypeStyle.body(15)).foregroundStyle(Palette.muted)
          .padding(.bottom, 6)
        ActionButton(title: "Resume", systemImage: "play.fill") { store.paused = false }
        ActionButton(
          title: "Restart cast", systemImage: "arrow.counterclockwise", kind: .secondary,
          identifier: "Start a fresh cast", action: store.begin)
        ActionButton(title: "Back to shore", kind: .quiet, identifier: "pause-home") {
          store.paused = false
          store.phase = .home
        }
      }
      .panel(padding: 22)
      .padding(.horizontal, 20)
    }
  }

  private var tutorial: some View {
    ZStack {
      Palette.night.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          VStack(alignment: .leading, spacing: 8) {
            Text("How to fish").font(TypeStyle.display(32))
            Text("Three moves. About a minute per fish.")
              .font(TypeStyle.body(15)).foregroundStyle(Palette.muted)
          }
          tutorialRow(
            "scope", title: "Aim",
            text: "Tap a fish silhouette on the water, then Cast. Rare fish glow violet.")
          tutorialRow(
            "hand.tap", title: "Hook",
            text: "Wait for the float to dip, then tap Hook before the bar runs out.")
          VStack(alignment: .leading, spacing: 14) {
            tutorialRow(
              "hand.raised", title: "Reel",
              text:
                "Hold the reel pad to pull the fish in. Let go when a red surge arrives, or the line snaps."
            )
            VStack(alignment: .leading, spacing: 10) {
              TensionMeter(tension: 0.46)
              SurgeForecast(elapsed: 1.2)
            }
            .padding(.leading, 58)
            .accessibilityHidden(true)
          }
        }
        .padding(24)
      }
      .safeAreaInset(edge: .bottom) {
        ActionButton(title: "Start fishing", systemImage: "arrow.right", identifier: "Let’s fish") {
          store.progress.tutorialSeen = true
          store.save()
          showTutorial = false
          store.begin()
        }
        .padding(.horizontal, 24).padding(.bottom, 8)
      }
    }
  }

  private func tutorialRow(_ symbol: String, title: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
        .foregroundStyle(Palette.sunset)
        .frame(width: 44, height: 44)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(TypeStyle.title(18))
        Text(text).font(TypeStyle.body(15)).foregroundStyle(Palette.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var landing: some View {
    GeometryReader { geometry in
      let leap = reduceMotion ? 0.5 : sin(min(1, store.phaseTime / 1.3) * .pi)
      ZStack {
        WaterSparkles(time: reduceMotion ? 0 : store.phaseTime * 8)
          .frame(height: 260).offset(y: geometry.size.height * 0.2)
        Ellipse().stroke(Palette.sunset.opacity(0.8), lineWidth: 2)
          .frame(width: 120 + store.phaseTime * 110, height: 40 + store.phaseTime * 30)
          .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.66)
        FishArt(species: store.duel.species)
          .frame(width: 290, height: 170)
          .rotationEffect(.degrees(-25 * leap))
          .shadow(color: Palette.sunset.opacity(0.5), radius: 24)
          .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.64 - leap * 150)
        VStack(spacing: 6) {
          Spacer()
          Text("Landed").font(TypeStyle.display(36))
          Text(store.duel.species.name).font(TypeStyle.body(16)).foregroundStyle(Palette.muted)
          Spacer().frame(height: 70)
        }
      }
    }
  }
}
