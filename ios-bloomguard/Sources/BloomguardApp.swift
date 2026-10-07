import AVFoundation
import SwiftUI

@main
struct BloomguardApp: App {
  var body: some Scene {
    WindowGroup {
      BloomguardView()
        .preferredColorScheme(.light)
    }
  }
}

@MainActor @Observable
final class GardenStore {
  struct Plot: Equatable {
    let lane: Int
    let column: Int
  }
  var garden = Garden()
  var screen = "home"
  var selected: Seed = .peashooter
  var shovel = false
  var emberTarget: Plot?
  var guide = false
  var unlocked: Int
  var best: Int
  var bestWave: Int
  var medals: [Int]
  var sound: Bool
  var savedResult = false
  private var player: AVAudioPlayer?

  init() {
    let defaults = UserDefaults.standard
    unlocked = max(0, defaults.integer(forKey: "unlocked"))
    best = defaults.integer(forKey: "best")
    bestWave = defaults.integer(forKey: "bestWave")
    medals = defaults.array(forKey: "medals") as? [Int] ?? [0, 0, 0, 0]
    sound = defaults.object(forKey: "sound") as? Bool ?? true
  }

  func start(level: Int = 0, endless: Bool = false) {
    garden = Garden(level: level, endless: endless)
    selected = .peashooter
    shovel = false
    emberTarget = nil
    screen = "game"
    savedResult = false
    tone(523)
  }

  func tick() {
    guard screen == "game" else { return }
    garden.tick(1.0 / 30)
    if garden.finished && !savedResult {
      savedResult = true
      if garden.phase == .won {
        unlocked = max(unlocked, min(3, garden.level + 1))
        medals[garden.level] = max(
          medals[garden.level], garden.rescuers.count >= 4 ? 3 : garden.rescuers.count >= 2 ? 2 : 1)
      }
      if garden.endless {
        best = max(best, garden.score)
        bestWave = max(bestWave, garden.wavesCleared)
      }
      let defaults = UserDefaults.standard
      defaults.set(unlocked, forKey: "unlocked")
      defaults.set(medals, forKey: "medals")
      defaults.set(best, forKey: "best")
      defaults.set(bestWave, forKey: "bestWave")
      tone(garden.phase == .won ? 784 : 220)
    }
  }

  func place(lane: Int, column: Int) {
    if shovel {
      garden.remove(lane: lane, column: column)
      tone(294)
      return
    }
    if selected == .ember {
      if let reason = garden.unavailable(.ember, lane: lane, column: column) {
        garden.notify(reason, error: true)
        tone(180)
        return
      }
      let target = Plot(lane: lane, column: column)
      if emberTarget != target {
        emberTarget = target
        garden.notify("Blast preview · tap this plot again to plant, or choose another.")
        tone(330)
        return
      }
    }
    let success = garden.plant(selected, lane: lane, column: column)
    if success { emberTarget = nil }
    if success { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    tone(success ? 440 : 180)
  }

  func collect(_ id: Int? = nil) {
    guard !garden.drops.isEmpty else { return }
    garden.collect(id)
    tone(880)
  }

  func toggleSound() {
    sound.toggle()
    UserDefaults.standard.set(sound, forKey: "sound")
    if sound { tone(659) }
  }

  func tone(_ frequency: Double) {
    guard sound else { return }
    let rate = 22050
    let count = 2205
    var data = Data()
    func bytes(_ value: UInt32, _ length: Int) {
      for index in 0..<length { data.append(UInt8((value >> (index * 8)) & 255)) }
    }
    data.append(contentsOf: "RIFF".utf8)
    bytes(UInt32(36 + count * 2), 4)
    data.append(contentsOf: "WAVEfmt ".utf8)
    bytes(16, 4)
    bytes(1, 2)
    bytes(1, 2)
    bytes(UInt32(rate), 4)
    bytes(UInt32(rate * 2), 4)
    bytes(2, 2)
    bytes(16, 2)
    data.append(contentsOf: "data".utf8)
    bytes(UInt32(count * 2), 4)
    for index in 0..<count {
      let envelope = sin(Double(index) / Double(count) * .pi) * 0.18
      let sample = Int16(sin(Double(index) * frequency * 2 * .pi / Double(rate)) * envelope * 32767)
      bytes(UInt32(UInt16(bitPattern: sample)), 2)
    }
    player = try? AVAudioPlayer(data: data)
    player?.play()
  }
}

struct BloomguardView: View {
  @State private var store = GardenStore()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        if store.screen == "game" {
          Backdrop()
          game
        } else {
          TimelineView(.animation(paused: reduceMotion)) { timeline in
            DawnScene(phase: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate)
          }.ignoresSafeArea()
          if store.screen == "home" { home } else { chapters }
        }
        if store.guide { guide }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: store.screen)
    }
    .fontDesign(.rounded)
    .foregroundStyle(Color.ink)
    .onReceive(timer) { _ in store.tick() }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active && store.garden.phase == .playing && store.screen == "game" {
        store.garden.phase = .paused
      }
    }
  }

  // MARK: Home

  private var home: some View {
    ZStack(alignment: .topTrailing) {
      HStack(alignment: .bottom, spacing: 0) {
        VStack(alignment: .leading, spacing: 0) {
          Spacer()
          HStack(spacing: 8) {
            Image(systemName: "leaf.fill").font(.system(size: 12, weight: .bold))
            Text("Lane defense").font(.system(size: 13, weight: .semibold))
          }.foregroundStyle(Color.pine.opacity(0.85))
          Text("Bloomguard").font(.system(size: 58, weight: .heavy)).tracking(-2)
            .minimumScaleFactor(0.6).lineLimit(1).padding(.top, 2)
          Text("Grow a garden that guards itself\nfrom a parade of clockwork pests.")
            .font(.system(size: 14, weight: .medium)).foregroundStyle(Color.ink.opacity(0.7))
            .lineSpacing(2).padding(.top, 6)
          HStack(spacing: 10) {
            pill("Play", icon: "play.fill", style: .primary) { store.screen = "chapters" }
            pill("Endless", icon: "infinity", style: .dark) { store.start(endless: true) }
              .accessibilityIdentifier("endless")
          }.padding(.top, 20)
          HStack(spacing: 14) {
            Button("How to play") { store.guide = true }
              .font(.system(size: 13, weight: .semibold))
            if store.best > 0 {
              Text("Best \(store.best.formatted())")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.ink.opacity(0.55))
            }
          }.padding(.top, 14)
        }
        .frame(maxWidth: 330, alignment: .leading)
        .padding(.bottom, 8)
        Spacer(minLength: 0)
        ZStack(alignment: .bottom) {
          Cottage().frame(width: 330, height: 220).offset(y: -58)
          HStack(alignment: .bottom, spacing: -14) {
            GardenArt(seed: .marigold).frame(width: 104, height: 104)
            GardenArt(seed: .peashooter).frame(width: 126, height: 126)
            GardenArt(seed: .frost).frame(width: 100, height: 100)
            GardenArt(seed: .bramble).frame(width: 92, height: 92).offset(y: -4)
          }.offset(y: 10)
        }
        .frame(maxWidth: 440)
        .padding(.bottom, 14)
      }
      .padding(.horizontal, 28).padding(.vertical, 18)
      iconButton("Toggle sound", icon: store.sound ? "speaker.wave.2.fill" : "speaker.slash.fill") {
        store.toggleSound()
      }.padding(20)
    }
  }

  // MARK: Chapters

  private var chapters: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        iconButton("Back", icon: "chevron.left") { store.screen = "home" }
        VStack(alignment: .leading, spacing: 1) {
          Text("Chapters").font(.system(size: 28, weight: .heavy)).tracking(-0.5)
          Text("Keep 4 robins for three stars · 2 for two")
            .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.ink.opacity(0.6))
        }
        Spacer()
        pill("Endless", icon: "infinity", style: .dark) { store.start(endless: true) }
      }
      Spacer(minLength: 0)
      HStack(spacing: 12) {
        ForEach(0..<4) { index in chapterCard(index) }
      }
      Spacer(minLength: 0)
    }.padding(.horizontal, 24).padding(.vertical, 16)
  }

  private func chapterCard(_ index: Int) -> some View {
    let open = index <= store.unlocked
    let bands: [[Color]] = [
      [Color(red: 0.99, green: 0.86, blue: 0.64), Color(red: 0.97, green: 0.72, blue: 0.46)],
      [Color(red: 0.92, green: 0.64, blue: 0.44), Color(red: 0.72, green: 0.43, blue: 0.27)],
      [Color(red: 0.70, green: 0.87, blue: 0.90), Color(red: 0.40, green: 0.66, blue: 0.75)],
      [Color(red: 0.40, green: 0.44, blue: 0.68), Color(red: 0.18, green: 0.22, blue: 0.40)],
    ]
    return Button {
      if open { store.start(level: index) }
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        ZStack(alignment: .topLeading) {
          LinearGradient(colors: bands[index], startPoint: .top, endPoint: .bottom)
          if index == 3 {
            Circle().fill(Color.cream.opacity(0.85)).frame(width: 22, height: 22)
              .position(x: 118, y: 18)
          }
          GardenArt(seed: Seed.allCases[index]).frame(height: 86).frame(maxWidth: .infinity)
            .offset(y: 10).saturation(open ? 1 : 0.15)
          HStack {
            Text("\(index + 1)").font(.system(size: 12, weight: .heavy))
              .frame(width: 26, height: 26)
              .background(Color.ink, in: RoundedRectangle(cornerRadius: 8))
              .foregroundStyle(Color.cream)
            Spacer()
            if !open {
              Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.cream).frame(width: 26, height: 26)
                .background(Color.ink.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
          }.padding(10)
        }.frame(height: 96).clipped()
        VStack(alignment: .leading, spacing: 5) {
          Text(Chapter.all[index].title).font(.system(size: 16, weight: .bold))
            .lineLimit(1).minimumScaleFactor(0.7)
          Text(open ? Chapter.all[index].lesson : "Clear chapter \(index) to unlock")
            .font(.system(size: 11, weight: .medium)).lineSpacing(1)
            .foregroundStyle(Color.ink.opacity(0.62))
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 28, alignment: .topLeading)
          HStack(spacing: 2) {
            ForEach(0..<3) { star in
              Image(systemName: "star.fill").font(.system(size: 11))
                .foregroundStyle(star < store.medals[index] ? Color.gold : Color.ink.opacity(0.14))
            }
            Spacer()
            Image(systemName: open ? "play.fill" : "lock.fill")
              .font(.system(size: 10, weight: .bold))
              .frame(width: 28, height: 28)
              .background(open ? Color.gold : Color.ink.opacity(0.08), in: Circle())
              .foregroundStyle(open ? Color.ink : Color.ink.opacity(0.4))
          }.padding(.top, 4)
        }.padding(12)
      }
      .background(Color.cream.opacity(open ? 1 : 0.92), in: RoundedRectangle(cornerRadius: 20))
      .shadow(color: .ink.opacity(open ? 0.18 : 0.06), radius: 12, y: 6)
    }.buttonStyle(.plain).disabled(!open)
  }

  // MARK: Game

  private var game: some View {
    ZStack {
      VStack(spacing: 6) {
        hud
        GardenBoard(store: store)
        HStack(spacing: 6) {
          ForEach(Seed.allCases, id: \.self) { seed in seedPacket(seed) }
          Button {
            store.shovel.toggle()
            store.emberTarget = nil
          } label: {
            VStack(spacing: 3) {
              ShovelArt().frame(width: 24, height: 24)
              Text("Shovel").font(.system(size: 10, weight: .semibold))
            }.frame(width: 58, height: 60)
              .background(
                store.shovel ? Color.gold : Color.cream.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 14)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(
                  store.shovel ? Color.gold : Color.cream.opacity(0.14), lineWidth: 1.5)
              )
              .foregroundStyle(store.shovel ? Color.ink : Color.cream)
          }.buttonStyle(.plain).accessibilityIdentifier("shovel")
        }
        HStack(spacing: 6) {
          if store.garden.noticeTime > 0 && store.garden.noticeIsError {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Color.gold)
          }
          Text(
            store.garden.noticeTime > 0
              ? store.garden.notice
              : store.shovel
                ? "Tap a plant to dig it up for half its cost."
                : store.selected == .ember
                  ? "Emberbud: tap a plot to preview the blast, tap again to plant."
                  : "\(store.selected.name) · \(store.selected.detail). Tap an empty plot."
          )
          .lineLimit(1).minimumScaleFactor(0.7)
          Spacer(minLength: 0)
        }.font(.system(size: 12, weight: .medium)).foregroundStyle(Color.cream.opacity(0.85))
          .frame(height: 16).padding(.horizontal, 4)
      }.padding(.horizontal, 8).padding(.vertical, 6)
      if store.garden.phase == .paused { pause }
      if store.garden.finished { results }
    }
  }

  private var hud: some View {
    HStack(spacing: 10) {
      Button {
        store.collect()
      } label: {
        HStack(spacing: 8) {
          SunCoin().frame(width: 26, height: 26)
            .shadow(color: .gold.opacity(store.garden.drops.isEmpty ? 0 : 0.8), radius: 6)
          Text("\(store.garden.sunshine)").font(.system(size: 22, weight: .heavy))
            .monospacedDigit().foregroundStyle(Color.cream)
          if store.garden.endless {
            Text("/ 500").font(.system(size: 11, weight: .semibold))
              .foregroundStyle(Color.cream.opacity(0.5))
          }
          if !store.garden.drops.isEmpty {
            Text("Gather").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.ink)
              .padding(.horizontal, 8).padding(.vertical, 3)
              .background(Color.gold, in: Capsule())
          }
        }.padding(.leading, 8).padding(.trailing, 12).frame(height: 40)
          .background(Color.black.opacity(0.25), in: Capsule())
      }.buttonStyle(.plain)
        .accessibilityLabel("Gather sunshine, \(store.garden.sunshine) available")
        .accessibilityIdentifier("collect")
      VStack(alignment: .leading, spacing: 4) {
        Text(store.garden.title).font(.system(size: 15, weight: .bold))
          .foregroundStyle(Color.cream)
        HStack(spacing: 8) {
          if store.garden.endless {
            Text("Wave \(store.garden.wave)")
          } else {
            HStack(spacing: 3) {
              ForEach(0..<3) { wave in
                Capsule().fill(wave < store.garden.wave ? Color.gold : Color.cream.opacity(0.25))
                  .frame(width: 16, height: 4)
              }
            }
            Text("Wave \(store.garden.wave) of 3")
          }
          Text("\(store.garden.score.formatted()) pts").foregroundStyle(Color.cream.opacity(0.55))
        }
        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.cream.opacity(0.85))
      }
      Spacer(minLength: 0)
      Text(
        store.garden.nextWave > 0
          ? "Next wave soon"
          : store.garden.wave == 1 && store.garden.pests.isEmpty && store.garden.waveTime < 17
            ? "Plant your first guardians"
            : store.garden.endless && store.garden.wave >= 4 && !store.garden.schedule.isEmpty
              ? "Next: lane \((store.garden.schedule.first?.lane ?? 0) + 1)"
              : store.garden.pests.count == 1
                ? "1 pest on the path" : "\(store.garden.pests.count) pests on the path"
      )
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(Color.cream.opacity(0.85))
      .lineLimit(1).minimumScaleFactor(0.7)
      .padding(.horizontal, 12).frame(height: 30)
      .background(Color.black.opacity(0.25), in: Capsule())
      iconButton("Pause", icon: "pause.fill", light: true) { store.garden.togglePause() }
        .accessibilityIdentifier("pause")
    }
  }

  private func seedPacket(_ seed: Seed) -> some View {
    let selected = store.selected == seed && !store.shovel
    let cooldown = store.garden.cooldowns[seed] ?? 0
    let poor = store.garden.sunshine < seed.cost
    let ready = cooldown <= 0 && !poor
    return Button {
      store.selected = seed
      store.shovel = false
      store.emberTarget = nil
      if store.garden.sunshine < seed.cost {
        store.garden.notify(
          "Need \(seed.cost - store.garden.sunshine) more sunshine for \(seed.name).", error: true)
      } else if cooldown > 0 {
        store.garden.notify("\(seed.name) is resting for \(Int(ceil(cooldown)))s.", error: true)
      } else {
        store.garden.notify(
          seed == .ember
            ? "Emberbud: tap a plot to preview the blast, tap again to plant."
            : "\(seed.name) · \(seed.detail). Tap an empty plot.")
      }
    } label: {
      HStack(spacing: 8) {
        GardenArt(seed: seed).frame(width: 46, height: 46)
          .background(seed.tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))
        VStack(alignment: .leading, spacing: 3) {
          Text(seed.name).font(.system(size: 12, weight: .bold)).lineLimit(1)
            .minimumScaleFactor(0.75)
          HStack(spacing: 4) {
            SunCoin().frame(width: 11, height: 11)
            Text("\(seed.cost)").font(.system(size: 12, weight: .bold)).monospacedDigit()
              .foregroundStyle(poor ? Color.terracotta : Color.ink)
          }
          Text(cooldown > 0 ? "\(Int(ceil(cooldown)))s" : poor ? "Need sun" : "Ready")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(ready ? Color.moss : Color.ink.opacity(0.45))
        }
        Spacer(minLength: 0)
      }.padding(.horizontal, 7).frame(maxWidth: .infinity).frame(height: 60)
        .background(Color.cream, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .bottom) {
          if cooldown > 0 {
            RoundedRectangle(cornerRadius: 14).fill(Color.ink.opacity(0.16))
              .frame(height: 60 * min(1, cooldown / seed.cooldown))
          }
        }
        .overlay(
          RoundedRectangle(cornerRadius: 14).stroke(
            selected ? Color.gold : Color.clear, lineWidth: 2.5)
        )
        .opacity(poor && !selected ? 0.75 : 1)
        .offset(y: selected ? -3 : 0)
        .shadow(color: .black.opacity(selected ? 0.3 : 0.15), radius: selected ? 8 : 3, y: 3)
        .foregroundStyle(Color.ink)
    }.buttonStyle(.plain).accessibilityLabel("\(seed.name), \(seed.cost) sunshine, \(seed.detail)")
      .accessibilityIdentifier("seed-\(seed.rawValue)")
  }

  // MARK: Overlays

  private var pause: some View {
    modal {
      VStack(spacing: 6) {
        Text("Paused").font(.system(size: 30, weight: .heavy)).tracking(-0.5)
        Text(
          store.garden.endless
            ? "Wave \(store.garden.wave) · \(store.garden.score.formatted()) points so far"
            : "\(store.garden.title) · Wave \(store.garden.wave) of 3"
        )
        .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink.opacity(0.6))
      }
      HStack(spacing: 10) {
        pill("Resume", icon: "play.fill", style: .primary) { store.garden.togglePause() }
        pill("How to play", icon: "book.fill", style: .quiet) { store.guide = true }
      }.padding(.top, 14)
      HStack(spacing: 8) {
        textButton(
          store.sound ? "Sound on" : "Sound off",
          icon: store.sound ? "speaker.wave.2.fill" : "speaker.slash.fill"
        ) { store.toggleSound() }
        Circle().fill(Color.ink.opacity(0.25)).frame(width: 3, height: 3)
        if store.garden.endless {
          textButton("Finish and save record", icon: "flag.fill") {
            store.garden.retire()
            store.tick()
          }
        } else {
          textButton("Leave garden", icon: "arrow.uturn.left") { store.screen = "home" }
        }
      }.padding(.top, 10)
    }
  }

  private var results: some View {
    let won = store.garden.phase == .won
    let retired = store.garden.phase == .retired
    let medal = store.medals[store.garden.level]
    return modal {
      HStack(spacing: 20) {
        ZStack {
          Circle().fill(
            RadialGradient(
              colors: [.gold.opacity(won || retired ? 0.55 : 0.18), .clear], center: .center,
              startRadius: 8, endRadius: 52)
          ).frame(width: 104, height: 104)
          GardenArt(seed: won || retired ? .marigold : .bramble).frame(width: 84, height: 84)
        }
        VStack(alignment: .leading, spacing: 6) {
          Text(won ? "Chapter cleared" : retired ? "Record saved" : "The garden fell")
            .font(.system(size: 30, weight: .heavy)).tracking(-0.5)
          Text(
            won
              ? store.garden.level < 3
                ? "\(Chapter.all[store.garden.level + 1].title) is now open."
                : "All four chapters defended."
              : retired
                ? "Every wave you secured counts toward your best."
                : "Plant Sunbells first, then cover all five lanes."
          )
          .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink.opacity(0.62))
          if won {
            HStack(spacing: 3) {
              ForEach(0..<3) { index in
                Image(systemName: "star.fill").font(.system(size: 18))
                  .foregroundStyle(index < medal ? Color.gold : Color.ink.opacity(0.14))
                  .shadow(color: .gold.opacity(index < medal ? 0.6 : 0), radius: 4)
              }
            }.padding(.top, 2)
          }
        }
        Spacer(minLength: 0)
      }.frame(maxWidth: 440)
      HStack(spacing: 0) {
        resultStat(store.garden.score.formatted(), "Points")
        divider
        resultStat("\(store.garden.wavesCleared)", "Waves")
        divider
        resultStat(
          store.garden.endless ? store.best.formatted() : "\(store.garden.rescuers.count) of 5",
          store.garden.endless ? "Best" : "Robins")
      }
      .padding(.vertical, 12).frame(maxWidth: 440)
      .background(Color.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
      HStack(spacing: 10) {
        pill(
          won && store.garden.level < 3 ? "Next chapter" : "Play again", icon: "arrow.right",
          style: .primary
        ) {
          store.start(
            level: won && store.garden.level < 3 ? store.garden.level + 1 : store.garden.level,
            endless: store.garden.endless)
        }
        pill("Chapters", icon: "square.grid.2x2.fill", style: .quiet) {
          store.screen = "chapters"
        }
      }
    }
  }

  private var divider: some View {
    Rectangle().fill(Color.ink.opacity(0.1)).frame(width: 1, height: 34)
  }

  private func resultStat(_ value: String, _ label: String) -> some View {
    VStack(spacing: 2) {
      Text(value).font(.system(size: 26, weight: .heavy)).monospacedDigit()
      Text(label).font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.ink.opacity(0.55))
    }.frame(maxWidth: .infinity)
  }

  private var guide: some View {
    ZStack {
      Color.night.opacity(0.85).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text("How to play").font(.system(size: 26, weight: .heavy)).tracking(-0.5)
          Spacer()
          iconButton("Close guide", icon: "xmark") { store.guide = false }
        }
        HStack(spacing: 12) {
          step(1, "Gather", "Tap gold drops, or the sun counter to take them all.")
          step(2, "Plant", "Pick a seed, then tap a plot. Plants fire to the right.")
          step(3, "Hold", "Cover every lane. A second breach in a lane ends the run.")
        }
        HStack(spacing: 8) {
          ForEach(Seed.allCases, id: \.self) { seed in
            VStack(alignment: .leading, spacing: 4) {
              GardenArt(seed: seed).frame(width: 44, height: 44)
              Text(seed.name).font(.system(size: 12, weight: .bold)).lineLimit(1)
                .minimumScaleFactor(0.8)
              Text(seed.detail).font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.ink.opacity(0.6)).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
          }
        }
        Text(
          store.garden.endless
            ? "Endless holds 500 sunshine. From wave 4, pests arrive in packs; watch the next lane."
            : "Shovel refunds half a plant's cost. Emberbud previews its blast before it plants."
        )
        .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.ink.opacity(0.62))
      }.padding(22).frame(maxWidth: 680)
        .background(Color.cream, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
        .padding(16)
    }
  }

  private func step(_ number: Int, _ title: String, _ body: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text("\(number)").font(.system(size: 13, weight: .heavy)).foregroundStyle(Color.cream)
        .frame(width: 28, height: 28).background(Color.ink, in: Circle())
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.system(size: 14, weight: .bold))
        Text(body).font(.system(size: 12, weight: .medium))
          .foregroundStyle(Color.ink.opacity(0.65)).lineSpacing(1)
          .fixedSize(horizontal: false, vertical: true)
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }

  private func modal<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ZStack {
      Color.night.opacity(0.8).ignoresSafeArea()
      VStack(spacing: 12, content: content).padding(.horizontal, 30).padding(.vertical, 26)
        .background(Color.cream, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.45), radius: 28, y: 12)
        .padding(20)
    }
  }

  // MARK: Controls

  private enum PillStyle { case primary, dark, quiet }

  private func pill(
    _ text: String, icon: String, style: PillStyle, perform: @escaping () -> Void
  ) -> some View {
    Button(action: perform) {
      HStack(spacing: 8) {
        Image(systemName: icon).font(.system(size: 12, weight: .bold))
        Text(text)
      }.font(.system(size: 15, weight: .bold))
        .padding(.horizontal, 22).frame(height: 48)
        .background(
          style == .primary ? Color.gold : style == .dark ? Color.ink : Color.ink.opacity(0.08),
          in: Capsule()
        )
        .foregroundStyle(style == .dark ? Color.cream : Color.ink)
        .shadow(color: .ink.opacity(style == .quiet ? 0 : 0.25), radius: 8, y: 4)
    }.buttonStyle(.plain)
  }

  private func textButton(_ text: String, icon: String, perform: @escaping () -> Void)
    -> some View
  {
    Button(action: perform) {
      Label(text, systemImage: icon).font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 12).frame(height: 36)
    }.buttonStyle(.plain).foregroundStyle(Color.ink.opacity(0.8))
  }

  private func iconButton(
    _ label: String, icon: String, light: Bool = false, perform: @escaping () -> Void
  ) -> some View {
    Button(action: perform) {
      Image(systemName: icon).font(.system(size: 15, weight: .bold)).frame(
        width: 44, height: 44
      )
      .background(light ? Color.black.opacity(0.25) : Color.cream, in: Circle())
      .foregroundStyle(light ? Color.cream : Color.ink)
      .shadow(color: .ink.opacity(light ? 0 : 0.15), radius: 6, y: 3)
    }.buttonStyle(.plain).accessibilityLabel(label)
  }
}
