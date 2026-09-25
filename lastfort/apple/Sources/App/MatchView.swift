import AudioToolbox
import SwiftUI

#if os(macOS)
  import AppKit
#else
  import UIKit
#endif

struct MatchView: View {
  @EnvironmentObject private var session: Session
  @EnvironmentObject private var profile: Profile
  @Environment(\.scenePhase) private var scenePhase
  @ObservedObject var match: MatchReplica
  let catalogue: Catalogue
  @StateObject private var controls = Controls()
  @State private var fullMap = false
  @StateObject private var terrain: TerrainImage
  init(match: MatchReplica, catalogue: Catalogue) {
    self.match = match
    self.catalogue = catalogue
    _terrain = StateObject(wrappedValue: TerrainImage(match.island))
  }
  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 500
      ZStack {
        GameCanvas(
          match: match, catalogue: catalogue, terrain: terrain,
          reducedMotion: profile.data.reducedMotion, aim: controls.aim)
        #if os(macOS)
          DesktopInput(controls: controls).id(controls.menu)
        #endif
        VStack(spacing: 8) {
          if compact { compactTopHUD } else { topHUD }
          if let me = match.me { stateBanner(me) }
          Spacer(minLength: 0)
          #if os(iOS)
            touchHUD(compact: compact)
          #endif
          bottomHUD(compact: compact)
        }.padding(12)
        if session.connection != .connected {
          VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            VStack(spacing: 4) {
              Text("Connection lost").font(.lfTitle(20)).foregroundStyle(Color.lfInkText)
              Text("Trying to resume your match…").font(.lfBody(14))
                .foregroundStyle(Color.lfInkMuted)
            }
            HStack(spacing: 8) {
              Button("Reconnect now") {
                controls.reset()
                session.connect()
              }.buttonStyle(LFButtonStyle(role: .primary))
              Button("Leave match") { session.leave() }.buttonStyle(LFButtonStyle(role: .quiet))
            }
          }
          .padding(24).frame(maxWidth: 360)
          .background(Color.lfInk.opacity(0.94), in: RoundedRectangle(cornerRadius: 18))
          .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.1)))
        }
        if controls.menu { menu }
      }
      .task(id: geometry.size) { await inputLoop(size: geometry.size) }
      .onChange(of: geometry.size) { _, _ in controls.pointer = nil }
      .onChange(of: match.me?.hp) { old, new in
        if let old, let new, new < old { feedback() }
      }
    }
    .foregroundStyle(.white).background(Color.lfInk)
    .environment(\.colorScheme, .dark)
    .onDisappear { controls.reset() }
    .onChange(of: scenePhase) { _, phase in if phase != .active { controls.reset() } }
    .sheet(isPresented: $fullMap) { fullMapSheet }
  }

  // MARK: Top

  private var menuButton: some View {
    Button {
      controls.menu = true
      controls.reset()
    } label: {
      Image(systemName: "line.3.horizontal").font(.system(size: 15, weight: .semibold))
        .frame(width: 22, height: 22)
    }.hud().accessibilityLabel("Match menu")
  }
  private var mapButton: some View {
    Button {
      fullMap = true
      controls.reset()
    } label: {
      IslandMap(match: match, terrain: terrain, detailed: false)
    }.buttonStyle(.plain).accessibilityLabel("Open island map")
  }
  private var compactTopHUD: some View {
    HStack(spacing: 6) {
      menuButton
      compassView(size: 13)
      Spacer(minLength: 0)
      HStack(spacing: 5) {
        Image(systemName: "person.2.fill").font(.system(size: 11))
        Text("\(match.state?.alive ?? match.players.count)").font(.lfDigits(14))
      }.hud()
      if let storm = match.state?.storm { stormView(storm, compact: true) }
      mapButton.frame(width: 58, height: 58)
    }
  }
  private var topHUD: some View {
    HStack(alignment: .top, spacing: 8) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          menuButton
          compassView(size: 15)
        }
        ForEach(Array(match.feed.prefix(3).enumerated()), id: \.offset) { _, item in
          Text(item).font(.lfBody(12, weight: .medium)).foregroundStyle(.white.opacity(0.85))
            .lineLimit(1).hud()
        }
      }
      Spacer(minLength: 0)
      VStack(alignment: .trailing, spacing: 6) {
        mapButton.frame(width: 132, height: 132)
        HStack(spacing: 0) {
          hudStat("Alive", "\(match.state?.alive ?? match.players.count)")
          Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 26)
          hudStat("Elims", "\(match.me?.k ?? 0)")
        }.hud(padding: 0).frame(width: 132)
        if let storm = match.state?.storm { stormView(storm, compact: false).frame(width: 132) }
      }
    }
  }
  private func hudStat(_ label: String, _ value: String) -> some View {
    VStack(spacing: 0) {
      Text(value).font(.lfDigits(17))
      Text(label).font(.lfLabel(10)).foregroundStyle(.white.opacity(0.65))
    }.frame(maxWidth: .infinity).padding(.vertical, 5)
  }
  private func compassView(size: CGFloat) -> some View {
    let angle = ((controls.aim * 180 / .pi + 90).truncatingRemainder(dividingBy: 360) + 360)
      .truncatingRemainder(dividingBy: 360)
    let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    return HStack(spacing: 6) {
      Image(systemName: "location.north.fill").font(.system(size: size - 3, weight: .bold))
        .rotationEffect(.degrees(angle))
      Text(directions[Int((angle + 22.5) / 45) % 8]).font(.lfDigits(size)).lineLimit(1)
        .frame(width: size * 2.2, alignment: .leading)
      Text("\(Int(angle))°").font(.lfDigits(size, weight: .medium)).lineLimit(1)
        .foregroundStyle(.white.opacity(0.7)).frame(width: size * 2.8, alignment: .trailing)
    }.hud().accessibilityLabel("Heading \(Int(angle)) degrees")
  }
  private func stormView(_ storm: Storm, compact: Bool) -> some View {
    let phase = match.start.rules.stormPhases[safe: storm.ph]
    let total = storm.sh ? (phase?.shrink ?? 0) : (phase?.wait ?? 0)
    let seconds = Int(ceil(storm.rem))
    let clock = "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    return VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 6) {
        Image(systemName: storm.sh ? "hurricane" : "timer").font(.system(size: 11, weight: .bold))
          .foregroundStyle(Color.lfStorm)
        if compact {
          Text(clock).font(.lfDigits(14)).lineLimit(1).fixedSize()
        } else {
          Text(storm.done ? "Final ring" : storm.sh ? "Shrinking" : "Storm \(storm.ph + 1)")
            .font(.lfLabel(12)).lineLimit(1).fixedSize()
          Spacer(minLength: 4)
          Text(clock).font(.lfDigits(14)).lineLimit(1).fixedSize()
        }
      }
      if !compact && total > 0 {
        Meter(
          value: storm.rem, total: total, color: .lfStorm, height: 3, track: .white.opacity(0.15))
      }
    }.hud().accessibilityLabel("Storm phase \(storm.ph + 1), \(seconds) seconds")
  }

  @ViewBuilder private func stateBanner(_ me: Player) -> some View {
    if me.s == .inBus {
      Button {
        controls.queue(.jump)
      } label: {
        Label("Drop now · \(Int(match.state?.bus?.rem ?? 0))s", systemImage: "arrow.down")
      }.buttonStyle(LFButtonStyle(role: .primary, size: .large))
    } else if me.s == .dropping {
      banner(
        me.alt > 0.35 ? "Freefall — steer to your landing" : "Gliding", icon: "wind")
    } else if me.s == .eliminated {
      HStack(spacing: 10) {
        Image(systemName: "eye").font(.system(size: 13, weight: .semibold))
        Text("Spectating \(match.target?.n ?? "survivors")").font(.lfBody(14, weight: .semibold))
        Button("Next") { controls.queue(.spectateNext) }
          .buttonStyle(LFButtonStyle(role: .neutral, size: .compact))
      }.hud()
    }
    if let storm = match.state?.storm, !storm.contains(me.x, me.y), me.s == .alive {
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
        Text("In the storm · −\(Int(storm.dps)) HP/s").font(.lfBody(14, weight: .semibold))
      }
      .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 8)
      .background(Color.lfDanger.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
    }
  }
  private func banner(_ text: String, icon: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon).font(.system(size: 13, weight: .semibold))
      Text(text).font(.lfBody(14, weight: .semibold))
    }.hud()
  }

  // MARK: Bottom

  private func bottomHUD(compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      if let me = match.me {
        HStack(alignment: .bottom, spacing: 8) {
          vitals(me).frame(maxWidth: compact ? 200 : 250)
          if me.rl || me.us {
            HStack(spacing: 6) {
              ProgressView().controlSize(.small).tint(.white)
              Text(
                me.rl
                  ? "Reloading \(String(format: "%.1f", me.rlt ?? 0))s"
                  : "Using \(me.selectedItem?.label ?? "item") \(String(format: "%.1f", me.ust ?? 0))s"
              ).font(.lfBody(13, weight: .semibold)).monospacedDigit().lineLimit(1)
            }.hud()
          }
          Spacer(minLength: 2)
          materials(me).fixedSize()
        }
        hotbar(me)
      }
    }
  }
  private func vitals(_ me: Player) -> some View {
    VStack(spacing: 6) {
      vital("Shield", me.sh, color: .lfShield, icon: "shield.fill")
      vital("Health", me.hp, color: .lfHealth, icon: "heart.fill")
    }.hud().accessibilityElement(children: .combine)
  }
  private func vital(_ label: String, _ value: Int, color: Color, icon: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
        .frame(width: 14)
      Meter(value: Double(value), total: 100, color: color, height: 7, track: .white.opacity(0.14))
      Text("\(value)").font(.lfDigits(14)).frame(width: 32, alignment: .trailing)
    }.accessibilityLabel("\(label) \(value)")
  }
  private func materials(_ me: Player) -> some View {
    Button {
      controls.material()
    } label: {
      HStack(spacing: 4) {
        ForEach(BuildingMaterial.allCases, id: \.self) { material in
          let selected = (me.bmat ?? .wood) == material
          HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(materialColor(material))
              .frame(width: 10, height: 10)
            Text("\(me.mats?[safe: material.index] ?? 0)").font(.lfDigits(13)).lineLimit(1)
          }
          .padding(.horizontal, 7).padding(.vertical, 5)
          .background(
            selected ? .white.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 7)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 7).strokeBorder(
              selected ? .white.opacity(0.6) : .clear, lineWidth: 1))
        }
      }
    }
    .hud(padding: 4)
    .accessibilityLabel(
      "Materials, building with \((me.bmat ?? .wood).rawValue). Tap to switch.")
  }
  private func hotbar(_ me: Player) -> some View {
    HStack(spacing: 5) {
      ForEach(0..<6) { slot in
        let item = me.inv?[safe: slot] ?? nil
        let selected = me.slot == slot
        let rarity = item?.r
        Button {
          controls.queue(.select, slot: slot)
        } label: {
          VStack(spacing: 3) {
            HStack {
              Text("\(slot + 1)").font(.lfDigits(10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
              Spacer()
              if let rarity {
                Circle().fill(Color(rgb: rarity.rgb)).frame(width: 6, height: 6)
              }
            }
            Image(
              systemName: slot == 0
                ? "hammer.fill"
                : item?.t == .weapon
                  ? "scope"
                  : item?.t == .consumable
                    ? "cross.case.fill" : item?.t == .ammo ? "circle.grid.2x2.fill" : "plus"
            )
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(item == nil && slot != 0 ? .white.opacity(0.25) : .white)
            Text(slot == 0 ? "Pickaxe" : item?.label ?? "")
              .font(.lfLabel(10)).lineLimit(1).minimumScaleFactor(0.7)
            Text(
              item?.t == .weapon
                ? "\(item?.l ?? 0) · \(me.ammo?[item?.w?.ammo ?? ""] ?? 0)"
                : item.map { "×\($0.n)" } ?? " "
            )
            .font(.lfDigits(11, weight: .medium)).foregroundStyle(.white.opacity(0.7))
          }
          .padding(.horizontal, 7).padding(.vertical, 6)
          .frame(maxWidth: .infinity).frame(height: 68)
          .background(
            Color.lfInk.opacity(selected ? 0.92 : 0.6), in: RoundedRectangle(cornerRadius: 10)
          )
          .overlay(alignment: .bottom) {
            if let rarity {
              RoundedRectangle(cornerRadius: 2).fill(Color(rgb: rarity.rgb))
                .frame(height: 3).padding(.horizontal, 10).padding(.bottom, 3)
            }
          }
          .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(
              selected ? .white : .white.opacity(0.12), lineWidth: selected ? 2 : 1)
          )
          .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Slot \(slot + 1), \(item?.label ?? (slot == 0 ? "Pickaxe" : "Empty"))")
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }.frame(maxWidth: 540).frame(maxWidth: .infinity, alignment: .trailing)
  }

  // MARK: Touch

  private func touchHUD(compact: Bool) -> some View {
    HStack(alignment: .bottom, spacing: 10) {
      if compact { moveStick(diameter: 70) }
      VStack(spacing: 8) {
        touchActions
        if !compact {
          HStack {
            moveStick(diameter: 96)
            Spacer()
            aimStick(diameter: 96)
          }.padding(.horizontal, 12).padding(.bottom, 18)
        }
      }
      if compact { aimStick(diameter: 70) }
    }.padding(.bottom, compact ? 18 : 0)
  }
  private func moveStick(diameter: Double) -> some View {
    TouchStick(label: "Move", diameter: diameter) { controls.move = $0 }
  }
  private func aimStick(diameter: Double) -> some View {
    TouchStick(label: match.me?.bm == true ? "Aim · Build" : "Aim · Fire", diameter: diameter) {
      vector in
      controls.pointer = nil
      if hypot(vector.dx, vector.dy) > 0.1 { controls.aim = atan2(vector.dy, vector.dx) }
      controls.fire = hypot(vector.dx, vector.dy) > 0.35
    }
  }
  private var touchActions: some View {
    VStack(spacing: 8) {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 6)], spacing: 6) {
        touchButton("Interact", "hand.tap") { controls.queue(.interact) }
        touchButton("Jump", "arrow.up") { controls.queue(.jump) }
        touchButton("Sprint", "figure.run", active: controls.sprint) {
          controls.sprint.toggle()
        }
        touchButton("Build", "square.stack.3d.up", active: match.me?.bm == true) {
          controls.toggleBuild()
        }
        touchButton("Reload", "arrow.clockwise") { controls.queue(.reload) }
        touchButton("Use", "cross.case") { controls.queue(.use, slot: match.me?.slot) }
        touchButton("Drop", "arrow.down.square") {
          controls.queue(.drop, slot: match.me?.slot)
        }
        touchButton("Emote", "sparkles") { controls.queue(.emote) }
        touchButton("Thank", "hand.wave") { controls.queue(.thank) }
      }
      if match.me?.bm == true {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(Piece.allCases, id: \.self) { piece in
              let selected = (match.me?.bp ?? .wall) == piece
              Button(piece.rawValue.capitalized) { controls.piece(piece) }
                .buttonStyle(
                  LFButtonStyle(role: selected ? .primary : .neutral, size: .compact)
                )
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Menu {
              ForEach(PieceEdit.allCases, id: \.self) { edit in
                Button(edit.rawValue.capitalized) { controls.queue(.edit, value: edit.rawValue) }
              }
              Button("Rotate ramp") { controls.queue(.edit, value: "none") }
            } label: {
              Label("Edit", systemImage: "pencil")
            }.buttonStyle(LFButtonStyle(role: .neutral, size: .compact))
            Button {
              controls.queue(.place)
            } label: {
              Label("Place", systemImage: "plus.square.fill")
            }.buttonStyle(LFButtonStyle(role: .success, size: .compact))
          }
        }
      }
    }
  }
  private func touchButton(
    _ label: String, _ icon: String, active: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: icon).font(.system(size: 15, weight: .semibold))
        Text(label).font(.lfLabel(10))
      }
      .foregroundStyle(active ? Color.lfInk : .white)
      .frame(maxWidth: .infinity, minHeight: 44)
      .background(
        active ? Color.lfAmber : Color.lfInk.opacity(0.6), in: RoundedRectangle(cornerRadius: 10)
      )
      .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(active ? 0 : 0.12)))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(active ? .isSelected : [])
  }

  // MARK: Menu and map

  private var menu: some View {
    ZStack {
      Color.black.opacity(0.45).ignoresSafeArea().onTapGesture { controls.menu = false }
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
              Text("Paused").font(.lfTitle(24)).tracking(-0.3)
              Text("Room \(match.start.code) · \(session.latency) ms").font(.lfBody(13))
                .foregroundStyle(Color.lfInkMuted).monospacedDigit()
            }
            Spacer()
            Button {
              controls.menu = false
            } label: {
              Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 30).background(.white.opacity(0.1), in: Circle())
            }.buttonStyle(.plain).accessibilityLabel("Resume")
          }
          Button {
            controls.menu = false
          } label: {
            Label("Resume match", systemImage: "play.fill")
          }.buttonStyle(LFButtonStyle(role: .primary, size: .large, expand: true))
          VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Squad", color: .lfInkMuted)
            ForEach(
              match.players.values.filter { $0.t == match.me?.t }.sorted { $0.id < $1.id }
            ) { player in
              HStack(spacing: 10) {
                Circle().fill(player.s == .eliminated ? Color.lfDanger : Color.lfHealth)
                  .frame(width: 7, height: 7)
                Text(player.n).font(.lfBody(14, weight: .semibold)).lineLimit(1)
                Spacer()
                if player.s == .eliminated {
                  Text("Eliminated").font(.lfLabel(12)).foregroundStyle(Color.lfInkMuted)
                } else {
                  HStack(spacing: 6) {
                    Meter(
                      value: Double(player.sh), total: 100, color: .lfShield, height: 4,
                      track: .white.opacity(0.12)
                    ).frame(width: 46)
                    Meter(
                      value: Double(player.hp), total: 100, color: .lfHealth, height: 4,
                      track: .white.opacity(0.12)
                    ).frame(width: 46)
                  }
                }
              }
              .padding(.horizontal, 12).padding(.vertical, 9)
              .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
              .accessibilityLabel(
                "\(player.n), \(player.s.rawValue), \(player.hp) health, \(player.sh) shield")
            }
          }
          VStack(spacing: 4) {
            Toggle(
              "Server autopilot",
              isOn: Binding(get: { session.autopilot }, set: { session.setAutopilot($0) }))
            Toggle("Reduce motion", isOn: $profile.data.reducedMotion)
            Toggle("Sound", isOn: $profile.data.sound)
            if session.options["TEST"] != nil {
              Toggle(
                "Pause server simulation",
                isOn: Binding(
                  get: { session.testPaused },
                  set: {
                    session.testPaused = $0
                    session.control($0 ? "pause" : "resume")
                  }))
              Button("Step 100 ticks") { session.control("step", count: 100) }
                .buttonStyle(LFButtonStyle(role: .neutral, size: .compact))
            }
          }.font(.lfBody(14, weight: .medium)).toggleStyle(.switch)
          Button("Leave match") {
            controls.reset()
            session.leave()
          }.buttonStyle(LFButtonStyle(role: .destructive, expand: true))
        }
        .padding(22).frame(maxWidth: 400)
        .background(Color.lfInk.opacity(0.96), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.1)))
      }.frame(maxWidth: 440).padding(20)
    }
  }
  private var fullMapSheet: some View {
    VStack(spacing: 16) {
      HStack {
        SectionTitle("Island map")
        Spacer()
        Button {
          fullMap = false
        } label: {
          Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
            .frame(width: 32, height: 32).background(Color.lfPanel2, in: Circle())
        }.buttonStyle(.plain).accessibilityLabel("Close")
      }
      IslandMap(match: match, terrain: terrain, detailed: true).aspectRatio(1, contentMode: .fit)
      HStack(spacing: 16) {
        legend("Current eye", .lfStorm)
        legend("Next eye", .white)
        legend("Your squad", .lfShield)
        legend("You", .white)
      }.font(.lfLabel(12)).foregroundStyle(Color.lfMuted)
    }
    .padding(20).frame(idealWidth: 720, idealHeight: 800)
    .background(Color.lfBackground)
  }
  private func legend(_ text: String, _ color: Color) -> some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 8, height: 8)
      Text(text)
    }
  }

  private func inputLoop(size: CGSize) async {
    while !Task.isCancelled {
      let step = match.start.rules.dt
      try? await Task.sleep(for: .seconds(step))
      if Task.isCancelled { return }
      controls.player = match.me
      if let pointer = controls.pointer, let me = match.me {
        let world = Camera(match: match, size: size).world(pointer)
        controls.aim = atan2(world.y - me.y, world.x - me.x)
      }
      guard session.connection == .connected, !session.autopilot else {
        _ = controls.drain()
        continue
      }
      let active = scenePhase == .active && !controls.menu && !fullMap
      if let frame = match.input(
        mx: active ? controls.move.dx : 0, my: active ? controls.move.dy : 0,
        aim: controls.aim, fire: active && controls.fire, sprint: active && controls.sprint,
        actions: active ? controls.drain() : [])
      {
        var message = ClientMessage(.input)
        message.f = frame
        await session.sendAwaited(message)
      }
    }
  }
  private func feedback() {
    #if os(iOS)
      if profile.data.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    #endif
    if profile.data.sound {
      #if os(macOS)
        NSSound(named: "Pop")?.play()
      #else
        AudioServicesPlaySystemSound(1104)
      #endif
    }
  }
}
extension View {
  fileprivate func hud(padding: CGFloat = 8) -> some View {
    self.padding(.horizontal, padding + 2).padding(.vertical, padding)
      .background(Color.lfInk.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.1)))
  }
}
struct IslandMap: View {
  @ObservedObject var match: MatchReplica
  let terrain: TerrainImage
  let detailed: Bool
  var body: some View {
    Canvas { context, size in
      let side = min(size.width, size.height)
      let scale = side / match.start.rules.mapSize
      if let image = terrain.image {
        context.draw(
          Image(decorative: image, scale: 1), in: CGRect(x: 0, y: 0, width: side, height: side))
      }
      if let storm = match.state?.storm {
        let current = CGRect(
          x: (storm.cx - storm.r) * scale, y: (storm.cy - storm.r) * scale,
          width: storm.r * 2 * scale, height: storm.r * 2 * scale)
        var path = Path(CGRect(origin: .zero, size: size))
        path.addEllipse(in: current)
        context.fill(path, with: .color(.lfStorm.opacity(0.45)), style: FillStyle(eoFill: true))
        context.stroke(Path(ellipseIn: current), with: .color(.lfStorm), lineWidth: 2)
        let target = CGRect(
          x: (storm.tx - storm.tr) * scale, y: (storm.ty - storm.tr) * scale,
          width: storm.tr * 2 * scale, height: storm.tr * 2 * scale)
        context.stroke(Path(ellipseIn: target), with: .color(.white), lineWidth: 1)
      }
      if let bus = match.state?.bus {
        context.line(
          [
            CGPoint(x: bus.x0 * scale, y: bus.y0 * scale),
            CGPoint(x: bus.x1 * scale, y: bus.y1 * scale),
          ], .white, width: 1)
        context.ellipse(bus.x * scale, bus.y * scale, 7, 7, .lfAccent)
      }
      for player in match.players.values where player.id == match.localID || player.t == match.me?.t
      {
        if player.s != .eliminated {
          context.ellipse(
            player.x * scale, player.y * scale, detailed ? 8 : 4, detailed ? 8 : 4,
            player.id == match.localID ? .white : .lfShield)
        }
      }
      if detailed {
        for poi in match.island.pois {
          context.label(
            poi.name.uppercased(), poi.x * scale, poi.y * scale, size: max(9, side / 42))
        }
      }
    }.clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityLabel(
      "Island, storm eye and squad positions")
  }
}
