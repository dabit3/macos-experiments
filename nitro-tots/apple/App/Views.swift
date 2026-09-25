import SpriteKit
import SwiftUI

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

private let nitro = Color(red: 0.0, green: 0.73, blue: 0.64)
private let pink = Color(red: 1, green: 0.26, blue: 0.45)
private let ink = Color(red: 0.12, green: 0.12, blue: 0.22)
func raceTime(_ ticks: Int) -> String {
  String(format: "%d:%05.2f", max(0, ticks) / 1800, Double(max(0, ticks) % 1800) / 30)
}
struct Art: View {
  let name: String
  var body: some View {
    #if os(macOS)
      if let image = NSImage(named: name) { Image(nsImage: image).resizable().scaledToFill() }
    #else
      if let image = UIImage(named: name) { Image(uiImage: image).resizable().scaledToFill() }
    #endif
  }
}
struct PillButton: ButtonStyle {
  var color = nitro
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.custom("Fredoka-SemiBold", size: 17)).padding(.horizontal, 20)
      .padding(.vertical, 13)
      .foregroundStyle(.white).background(color, in: RoundedRectangle(cornerRadius: 16))
      .shadow(color: .black.opacity(0.2), radius: 0, y: configuration.isPressed ? 1 : 4)
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
  }
}
struct Card<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
      .overlay(RoundedRectangle(cornerRadius: 22).stroke(.primary.opacity(0.08)))
  }
}
struct RootView: View {
  @Bindable var model: AppModel
  @Environment(\.scenePhase) private var phase
  @Environment(\.colorScheme) private var colorScheme
  var body: some View {
    ZStack {
      LinearGradient(
        colors: colorScheme == .dark
          ? [ink, Color(red: 0.08, green: 0.23, blue: 0.26)]
          : [Color(red: 1, green: 0.91, blue: 0.8), Color(red: 0.88, green: 0.96, blue: 0.93)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      ).ignoresSafeArea()
      if model.screen == .race, let race = model.session {
        RaceView(model: model, race: race).id(ObjectIdentifier(race))
      } else {
        ScrollView {
          VStack(spacing: 24) {
            if model.screen != .title { header }
            switch model.screen {
            case .title: title
            case .garage: GarageView(model: model)
            case .track: TrackView(model: model)
            case .online: online
            case .lobby: lobby
            case .podium: podium
            case .settings: SettingsView(model: model)
            case .race: EmptyView()
            }
          }.frame(maxWidth: 1100).padding(24).frame(maxWidth: .infinity)
        }
        .id(model.screen)
        .foregroundStyle(colorScheme == .dark ? .white : ink)
      }
      if let error = model.notice ?? model.connection.error {
        VStack {
          Spacer()
          HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(error).font(.callout).textSelection(.enabled)
            Spacer()
            Button("Dismiss") {
              model.notice = nil
              model.connection.error = nil
            }
          }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).padding()
        }
      }
    }
    .font(.custom("Nunito-Regular", size: 16))
    .buttonStyle(PillButton())
    .preferredColorScheme(
      model.preferences.theme == "dark" ? .dark : model.preferences.theme == "light" ? .light : nil
    )
    .onChange(of: phase) { _, phase in if phase != .active { model.clearControls() } }
    .onChange(of: model.preferences.theme) { _, _ in model.save() }
  }
  private var header: some View {
    HStack {
      Button {
        model.save()
        model.go(model.room != nil ? .lobby : .title)
      } label: {
        Image(systemName: "arrow.left")
      }
      Text(model.screen == .podium ? "THE PODIUM" : model.screen.rawValue.uppercased())
        .font(.custom("Fredoka-Bold", size: 30))
      Spacer()
      if model.room != nil { Text("ROOM \(model.roomCode)").font(.headline) }
    }
  }
  private var title: some View {
    VStack(spacing: 24) {
      VStack(alignment: .leading, spacing: 4) {
        Text("TINY KARTS. BIG TROUBLE.").font(.custom("Nunito-ExtraBold", size: 13)).tracking(3)
          .lineLimit(1).minimumScaleFactor(0.6)
        Text("NITRO TOTS").font(.custom("Fredoka-Bold", size: 54))
          .lineLimit(1).minimumScaleFactor(0.5)
        Text("Toybox racing. Full-throttle fun.").font(.custom("Nunito-Regular", size: 20))
      }
      .foregroundStyle(.white).padding(28)
      .frame(maxWidth: .infinity, minHeight: 330, alignment: .bottomLeading)
      .background {
        Art(name: "arcade-keyart.jpg")
          .overlay(
            LinearGradient(
              colors: [.clear, ink.opacity(0.95)], startPoint: .top, endPoint: .bottom))
      }
      .clipShape(RoundedRectangle(cornerRadius: 28))
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
        ForEach(PlayMode.allCases) { mode in
          Button {
            model.chooseMode(mode)
          } label: {
            VStack(alignment: .leading, spacing: 10) {
              Image(
                systemName: mode == .battle
                  ? "burst.fill" : mode == .timeTrial ? "stopwatch.fill" : "flag.checkered"
              ).font(.title)
              Text(mode.rawValue)
              Text(
                mode == .grandPrix
                  ? "Three races. One cup."
                  : mode == .quick
                    ? "Pick a track and race."
                    : mode == .battle ? "Pop balloons. Score hits." : "Beat your best ghost."
              )
              .font(.custom("Nunito-Regular", size: 13))
            }.frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
          }.buttonStyle(PillButton(color: mode == .battle ? pink : nitro))
        }
        Button {
          model.go(.online)
        } label: {
          Label("Online Multiplayer", systemImage: "network").frame(
            maxWidth: .infinity, minHeight: 90)
        }
      }
      ViewThatFits(in: .horizontal) {
        HStack {
          titleButtons
          Spacer()
          playerBadge
        }
        VStack(spacing: 16) {
          HStack { titleButtons }
          playerBadge
        }
      }
      if !model.preferences.lastRoom.isEmpty {
        Button("Rejoin room \(model.preferences.lastRoom)") {
          model.go(.online)
          if TokenStore.read(model.preferences.server) != nil {
            model.connect()
          } else {
            model.connect(.join(model.preferences.lastRoom))
          }
        }
      }
      Text("WASD / arrows to drive · Space to drift · Z to use item · Q to look back")
        .font(.footnote).foregroundStyle(.secondary)
    }
  }
  @ViewBuilder private var titleButtons: some View {
    Button("Garage") { model.go(.garage) }
    Button("Settings") { model.go(.settings) }
  }
  private var playerBadge: some View {
    HStack {
      Art(name: "\(model.preferences.character).jpg").frame(width: 48, height: 48).clipShape(
        Circle())
      Text(model.preferences.name).font(.headline).lineLimit(1)
    }
  }
  private var online: some View {
    Card {
      VStack(alignment: .leading, spacing: 20) {
        Text("Race together").font(.custom("Fredoka-Bold", size: 36))
        Text(
          "Host a room or join friends using their room code. A Nitro Tots server must be running.")
        TextField("Your name", text: $model.preferences.name).textFieldStyle(.roundedBorder)
        TextField("WebSocket server", text: $model.preferences.server).textFieldStyle(
          .roundedBorder
        )
        .autocorrectionDisabled()
        HStack {
          Text("Connection: \(model.connection.state.rawValue)")
          Spacer()
          Button(model.connection.state == .failed ? "Try again" : "Connect / resume") {
            model.connect()
          }
        }
        Divider()
        TextField("ROOM CODE", text: $model.roomCode).textFieldStyle(.roundedBorder)
          .autocorrectionDisabled()
        ViewThatFits {
          HStack { onlineButtons }
          VStack { onlineButtons }
        }
      }
    }
  }
  @ViewBuilder private var onlineButtons: some View {
    Button("Join room") { model.connect(.join(model.roomCode)) }.disabled(
      model.roomCode.trimmingCharacters(in: .whitespaces).isEmpty)
    Button("Create room") { model.connect(.create(model.settings)) }
    Button("Garage") { model.go(.garage) }
  }
  private var lobby: some View {
    VStack(spacing: 20) {
      if let room = model.room {
        Card {
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Text("ROOM \(room.code)").font(.custom("Fredoka-Bold", size: 38)).textSelection(
                .enabled)
              ShareLink(item: room.code) { Image(systemName: "square.and.arrow.up") }
              Spacer()
              Text("\(room.players.count) / \(room.settings.maxPlayers)")
            }
            ForEach(room.players) { player in
              HStack {
                Art(name: "\(player.character).jpg").frame(width: 48, height: 48).clipShape(
                  Circle())
                VStack(alignment: .leading) {
                  Text(player.name).font(.headline)
                  Text("\(Catalog.shared.kart(player.kart).name) · \(player.platform)").font(
                    .caption)
                }
                Spacer()
                Text(
                  !player.connected
                    ? "Reconnecting…" : player.host ? "HOST" : player.ready ? "READY" : "Not ready")
              }
            }
            HStack {
              if let me = room.players.first(where: { $0.id == model.connection.playerId }) {
                Button(me.ready ? "Not ready" : "Ready!") {
                  model.connection.send(.ready(!me.ready))
                }
              }
              Button("Garage") { model.go(.garage) }
              if model.isHost { Button("Start race") { model.connection.send(.start) } }
              Spacer()
              Button("Leave room") { model.leave() }.buttonStyle(PillButton(color: pink))
            }
          }
        }
        RaceSettings(settings: $model.settings, includeMode: true)
          .disabled(!model.isHost || !["lobby", "matchOver"].contains(room.status))
        if model.isHost {
          Button("Apply room settings") { model.connection.send(.settings(model.settings)) }
        }
      } else {
        Text("Reconnect to restore your room.")
        Button("Online") { model.go(.online) }
      }
    }
  }
  private var podium: some View {
    VStack(spacing: 20) {
      Text(model.matchFinished ? "CUP COMPLETE!" : "FINISH!").font(
        .custom("Fredoka-Bold", size: 44)
      ).foregroundStyle(pink)
      Card {
        VStack(alignment: .leading, spacing: 18) {
          Text("Standings").font(.custom("Fredoka-Bold", size: 28))
          ForEach(Array(model.table.enumerated()), id: \.element.slot) { index, racer in
            HStack {
              Text("#\(index + 1)").font(.custom("Fredoka-Bold", size: 28)).frame(width: 60)
              Art(name: "\(racer.character).jpg").frame(width: 46, height: 46).clipShape(Circle())
              Text(racer.name).font(.headline)
              Spacer()
              Text("\(racer.points) PTS").font(.headline)
              Text(racer.places.map { "#\($0)" }.joined(separator: " / ")).font(.caption)
            }
          }
        }
      }
      ForEach(Array(model.races.enumerated()), id: \.offset) { index, history in
        Card {
          VStack(alignment: .leading, spacing: 10) {
            Text("Race \(index + 1) · \(Catalog.shared.track(history.trackId).name)").font(
              .headline)
            ForEach(history.results) { result in
              HStack {
                Text("\(result.place). \(result.name)")
                Spacer()
                Text(result.lapTicks.map(raceTime).joined(separator: " · ")).font(.caption)
                Text(result.finishTick < 0 ? "DNF" : raceTime(result.raceTicks)).monospacedDigit()
                if model.session?.sim.isBattle == true { Text("\(result.score) hits") }
              }
            }
          }
        }
      }
      ViewThatFits {
        HStack { resultsButtons }
        VStack { resultsButtons }
      }
    }
  }
  @ViewBuilder private var resultsButtons: some View {
    if !model.online {
      Button(model.matchFinished ? "Race again" : "Next race") { model.next() }
    } else if !model.matchFinished && model.isHost {
      Button("Next race / finish cup") { model.next() }
    }
    if model.online { Button("Back to lobby") { model.returnToLobby() } }
    Button("Main menu") { model.leave() }
  }
}
struct GarageView: View {
  @Bindable var model: AppModel
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      TextField("Racer name", text: $model.preferences.name).textFieldStyle(.roundedBorder).onSubmit
      { model.save() }
      Text("Pick your tot").font(.custom("Fredoka-Bold", size: 30))
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {
        ForEach(Catalog.shared.characters) { tot in
          Button {
            model.preferences.character = tot.id
            model.save()
            model.feedback.sound("select", preferences: model.preferences)
          } label: {
            VStack {
              Art(name: "\(tot.id).jpg").frame(height: 120).clipped().clipShape(
                RoundedRectangle(cornerRadius: 14))
              Text(tot.name).font(.headline)
              Text(tot.tagline).font(.caption).lineLimit(2)
            }.padding(8).background(
              model.preferences.character == tot.id ? nitro.opacity(0.3) : .white.opacity(0.6),
              in: RoundedRectangle(cornerRadius: 18))
          }.buttonStyle(.plain)
        }
      }
      Text("Pick your ride").font(.custom("Fredoka-Bold", size: 30))
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 16) {
        ForEach(Catalog.shared.karts) { kart in
          Button {
            model.preferences.kart = kart.id
            model.save()
          } label: {
            VStack {
              Art(name: "kart-\(kart.id).png").frame(width: 80, height: 100)
              Text(kart.name).font(.headline)
            }.frame(maxWidth: .infinity).padding(12).background(
              model.preferences.kart == kart.id ? pink.opacity(0.25) : .white.opacity(0.6),
              in: RoundedRectangle(cornerRadius: 18))
          }.buttonStyle(.plain)
        }
      }
      let stats = Stats(model.preferences.character, model.preferences.kart)
      Card {
        VStack {
          stat("Speed", stats.speed)
          stat("Acceleration", stats.accel)
          stat("Handling", stats.handling)
          stat("Weight", stats.mass)
        }
      }
      Button("Save & go") {
        model.save()
        model.go(model.room != nil ? .lobby : .title)
      }
    }
  }
  private func stat(_ label: String, _ value: Double) -> some View {
    HStack {
      Text(label).frame(width: 110, alignment: .leading)
      ProgressView(value: min(1, value)).tint(nitro)
    }
  }
}
struct TrackView: View {
  @Bindable var model: AppModel
  var body: some View {
    VStack(spacing: 20) {
      Text(model.playMode.rawValue).font(.custom("Fredoka-Bold", size: 36))
      if model.playMode == .grandPrix {
        Picker("Cup", selection: $model.settings.cupId) {
          ForEach(Catalog.shared.cups) { cup in Text(cup.name).tag(cup.id) }
        }.pickerStyle(.segmented)
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: 18) {
        ForEach(
          Catalog.shared.tracks.filter {
            model.playMode == .grandPrix
              ? Catalog.shared.cup(model.settings.cupId).trackIds.contains($0.id)
              : $0.isArena == (model.playMode == .battle)
          }
        ) { track in
          Button {
            model.settings.trackId = track.id
          } label: {
            VStack(alignment: .leading, spacing: 8) {
              Art(name: "\(track.id).jpg").frame(height: 150).clipped().clipShape(
                RoundedRectangle(cornerRadius: 16))
              Text(track.name).font(.custom("Fredoka-Bold", size: 22))
              Text(track.location).font(.caption)
              Text(track.description).font(.callout).lineLimit(3)
              if model.playMode == .timeTrial, let best = model.bestTime(track.id) {
                Text("BEST  \(raceTime(best))").font(.headline)
              }
              MiniMap(track: track, racers: [], localSlot: 0).frame(height: 90)
            }.padding(14).background(
              model.settings.trackId == track.id ? nitro.opacity(0.18) : .white.opacity(0.7),
              in: RoundedRectangle(cornerRadius: 22))
          }.buttonStyle(.plain)
        }
      }
      RaceSettings(settings: $model.settings, includeMode: false)
      Button("LET'S RACE!") {
        model.save()
        model.startLocal()
      }
    }
  }
}
struct RaceSettings: View {
  @Binding var settings: RoomSettings
  var includeMode: Bool
  var body: some View {
    Card {
      VStack(alignment: .leading, spacing: 16) {
        if includeMode {
          Picker("Mode", selection: $settings.mode) {
            Text("Race").tag(GameMode.race)
            Text("Time Trial").tag(GameMode.timeTrial)
            Text("Battle").tag(GameMode.battle)
          }
          Toggle("Grand Prix", isOn: $settings.grandPrix)
          Picker("Cup", selection: $settings.cupId) {
            ForEach(Catalog.shared.cups) { Text($0.name).tag($0.id) }
          }
          Picker("Track", selection: $settings.trackId) {
            ForEach(Catalog.shared.tracks) { Text($0.name).tag($0.id) }
          }
        }
        if settings.mode == .battle {
          Stepper(
            "Battle: \(settings.battleSeconds) seconds", value: $settings.battleSeconds,
            in: 30...300, step: 30)
        } else {
          Stepper("\(settings.laps) laps", value: $settings.laps, in: 1...9)
        }
        if settings.mode != .timeTrial {
          Toggle("Fill empty seats with bots", isOn: $settings.fillBots)
          Stepper("Maximum racers: \(settings.maxPlayers)", value: $settings.maxPlayers, in: 2...8)
          if includeMode {
            Stepper(
              "Minimum players: \(settings.minPlayers)", value: $settings.minPlayers, in: 1...8)
          }
          HStack {
            Text("Bot skill")
            Slider(value: $settings.botSkill, in: 0.2...1)
            Text("\(Int(settings.botSkill * 100))%")
          }
        }
      }
    }
  }
}
struct SettingsView: View {
  @Bindable var model: AppModel
  var body: some View {
    Card {
      VStack(alignment: .leading, spacing: 20) {
        Picker("Theme", selection: $model.preferences.theme) {
          Text("System").tag("system")
          Text("Light").tag("light")
          Text("Dark").tag("dark")
        }
        Picker("Controls", selection: $model.preferences.controls) {
          Text("Auto").tag("auto")
          Text("Keyboard").tag("keyboard")
          Text("Touch").tag("touch")
        }
        Picker("Camera", selection: $model.preferences.camera) {
          Text("Chase").tag("chase")
          Text("Fixed north").tag("fixed")
        }
        Toggle("Auto accelerate", isOn: $model.preferences.autoAccelerate)
        Toggle("Haptics", isOn: $model.preferences.haptics)
        Toggle("Reduce motion", isOn: $model.preferences.reduceMotion)
        HStack {
          Text("Music")
          Slider(value: $model.preferences.musicVolume).onChange(of: model.preferences.musicVolume)
          { _, _ in model.feedback.volumes(model.preferences) }
        }
        HStack {
          Text("Sound effects")
          Slider(value: $model.preferences.sfxVolume)
        }
        Divider()
        Text("DRIVING SCHOOL").font(.custom("Fredoka-Bold", size: 24))
        Text(
          "WASD / arrows: gas, brake and steer\nSpace / Shift: hop and drift\nZ / X / Enter / E / Control: use item\nQ / Option: look behind (hold while using an item to throw backwards)\nEscape / P: pause\n\nHold a drift to charge blue, orange, then pink sparks. Release for a mini-turbo. Press gas just before GO for a rocket start. Holding too early stalls the engine."
        )
        Text(
          "On touch screens, drag the steering pad and hold the gas, brake, drift and look-back controls. Tap the item slot to use your item."
        )
        Button("Save settings") {
          model.save()
          model.go(model.room != nil ? .lobby : .title)
        }
      }
    }
  }
}
struct MiniMap: View {
  let track: Track, racers: [Racer], localSlot: Int
  var body: some View {
    Canvas { context, size in
      let width = track.boundsMax.x - track.boundsMin.x + 50
      let height = track.boundsMax.y - track.boundsMin.y + 50
      let scale = min(size.width / width, size.height / height)
      func point(_ p: V2) -> CGPoint {
        CGPoint(
          x: (p.x - track.boundsMin.x - width / 2 + 25) * scale + size.width / 2,
          y: (p.y - track.boundsMin.y - height / 2 + 25) * scale + size.height / 2)
      }
      var path = Path()
      for (i, s) in track.samples.enumerated() {
        if i == 0 { path.move(to: point(s.pos)) } else { path.addLine(to: point(s.pos)) }
      }
      path.closeSubpath()
      context.stroke(
        path, with: .color(track.theme.roadEdge.color),
        style: StrokeStyle(lineWidth: 5, lineJoin: .round))
      for racer in racers {
        let p = point(racer.pos)
        let radius = racer.slot == localSlot ? 4.0 : 2.5
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)),
          with: .color(racer.slot == localSlot ? .yellow : .white))
      }
    }
  }
}
struct RaceView: View {
  @Bindable var model: AppModel
  let race: RaceSession
  @State private var scene: RaceScene
  init(model: AppModel, race: RaceSession) {
    self.model = model
    self.race = race
    _scene = State(initialValue: RaceScene(model: model, race: race))
  }
  private var touch: Bool {
    #if os(iOS)
      return model.preferences.controls != "keyboard"
    #else
      return model.preferences.controls == "touch"
    #endif
  }
  var body: some View {
    let _ = model.frame
    ZStack {
      GameSurface(scene: scene, model: model).ignoresSafeArea()
      VStack {
        HStack(alignment: .top) {
          VStack(alignment: .leading) {
            Text(race.sim.track.name).font(.custom("Fredoka-Bold", size: 22))
            Text("Race \(race.info.raceIndex + 1) / \(race.info.totalRaces)")
            if let me = race.local {
              Text(
                race.sim.isBattle
                  ? "\(me.score) hits · \(me.balloons) balloons"
                  : "#\(me.position)  ·  Lap \(min(race.info.laps, me.lap + 1))/\(race.info.laps)"
              )
              .font(.custom("Fredoka-Bold", size: 26))
              Text("\(Int(abs(me.speed))) km/h  ·  \(raceTime(race.sim.tick - 120))")
                .monospacedDigit()
              if me.driftDir != 0 || me.boostTicks > 0 {
                ProgressView(
                  value: me.boostTicks > 0 ? 1 : clamp(Double(me.driftCharge) / 110, 0, 1)
                )
                .tint(
                  me.boostTicks > 0
                    ? .yellow : [Color.cyan, .cyan, .orange, .purple][driftTier(me.driftCharge)]
                )
                .accessibilityLabel(me.boostTicks > 0 ? "Boost active" : "Drift charge")
              }
            }
            if race.online {
              Text("\(model.connection.latency) ms · \(model.connection.state.rawValue)").font(
                .caption)
            }
          }.padding(12).background(ink.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
          Spacer()
          VStack {
            Button {
              model.control("escape", down: true)
            } label: {
              Image(systemName: "pause.fill")
            }
            MiniMap(track: race.sim.track, racers: race.sim.racers, localSlot: race.localSlot)
              .frame(width: 115, height: 95).padding(8).background(
                ink.opacity(0.7), in: RoundedRectangle(cornerRadius: 15))
          }
        }
        Spacer()
        if race.sim.phase == .countdown {
          Text("\(max(1, (120 - race.sim.tick + 29) / 30))").font(.custom("Fredoka-Bold", size: 96))
            .shadow(color: .black, radius: 5)
        }
        if race.local?.wrongWayTicks ?? 0 > 30 {
          Text("WRONG WAY!").font(.title.bold()).foregroundStyle(.yellow)
        }
        Spacer()
        if touch {
          TouchControls(model: model, race: race)
        } else {
          Button(
            itemLabel(race.local)
          ) {
            model.control("item", down: true)
            model.control("item", down: false)
          }.frame(maxWidth: .infinity, alignment: .trailing)
        }
      }.padding(16).foregroundStyle(.white)
      if model.paused {
        Color.black.opacity(0.5).ignoresSafeArea()
        Card {
          VStack(spacing: 20) {
            Text("PIT STOP").font(.custom("Fredoka-Bold", size: 32))
            if race.online { Text("The online race continues while you're paused.") }
            Button("Resume") { model.paused = false }
            Button("Leave race") { model.leave() }.buttonStyle(PillButton(color: pink))
          }
        }.frame(maxWidth: 400)
      }
    }
  }
}
struct TouchControls: View {
  @Bindable var model: AppModel
  let race: RaceSession
  var body: some View {
    HStack(alignment: .bottom) {
      VStack(spacing: 12) {
        hold("LOOK BACK", "look", width: 108)
        Text("‹       ›").font(.system(size: 42, weight: .bold)).frame(width: 130, height: 100)
          .background(ink.opacity(0.72), in: RoundedRectangle(cornerRadius: 28))
          .gesture(
            DragGesture(minimumDistance: 0).onChanged { value in
              model.steer(clamp((value.location.x - 65) / 48, -1, 1))
            }.onEnded { _ in model.steer(0) }
          )
          .accessibilityLabel("Steering pad")
      }
      Spacer(minLength: 8)
      VStack(spacing: 12) {
        hold(itemLabel(race.local), "item", width: 130)
        HStack(spacing: 10) {
          hold("DRIFT", "drift", width: 62)
          hold("GAS", "gas", width: 68)
        }
        hold("BRAKE", "brake", width: 130)
      }
    }
  }
  private func hold(_ title: String, _ key: String, width: CGFloat) -> some View {
    HoldControl(title: title, width: width) { model.control(key, down: $0) }
  }
}
struct HoldControl: View {
  let title: String, width: CGFloat
  let changed: (Bool) -> Void
  @State private var down = false
  var body: some View {
    Text(title).font(.custom("Fredoka-SemiBold", size: 13)).multilineTextAlignment(.center)
      .frame(width: width, height: 48).background(
        down ? nitro : ink.opacity(0.8), in: RoundedRectangle(cornerRadius: 16)
      )
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.5)))
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { _ in
          if !down {
            down = true
            changed(true)
          }
        }
        .onEnded { _ in
          down = false
          changed(false)
        }
      )
      .onDisappear { if down { changed(false) } }
      .accessibilityAddTraits(.isButton).accessibilityAction {
        changed(true)
        changed(false)
      }
  }
}
private func itemLabel(_ racer: Racer?) -> String {
  guard let racer else { return "ITEM" }
  if racer.rouletteTicks > 0 { return "Rolling…" }
  guard let item = racer.item else { return "No item" }
  return item.label + (racer.itemCharges > 1 ? " ×\(racer.itemCharges)" : "")
}
