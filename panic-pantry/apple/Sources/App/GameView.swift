import SwiftUI

struct GameView: View {
  @Bindable var client: GameClient
  @Environment(\.scenePhase) private var scenePhase
  private var blocked: Bool {
    client.showMenu || client.showHelp || client.showEmotes || client.connection != .connected
      || scenePhase != .active
  }
  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 520 && geometry.size.width > geometry.size.height
      VStack(spacing: compact ? 2 : 10) {
        HStack(alignment: .top, spacing: 6) {
          ticketRail(compact: compact)
          Button {
            client.showMenu = true
          } label: {
            Image(systemName: "line.3.horizontal").frame(width: 28, height: 22)
          }.buttonStyle(ArcadeButtonStyle(color: PantryStyle.ink)).accessibilityLabel(
            "Kitchen menu")
        }
        HStack(spacing: 0) {
          if compact && client.showTouch {
            Joystick(onMove: client.movement).frame(width: 102, height: 102).disabled(blocked)
          }
          ZStack {
            if let level = client.level {
              KitchenCanvas(
                level: level, snapshot: client.snapshot, previous: client.previousSnapshot,
                received: client.snapshotDate, playerID: client.playerID, effects: client.effects
              ) { x, y in
                guard !blocked else { return }
                client.press(interact: true, target: (x, y))
                PlatformActions.haptic(success: nil)
              }
            }
            if client.snapshot?.phase == .countdown {
              VStack(spacing: 0) {
                Text("GET READY!").font(PantryStyle.font(24, weight: "Black"))
                Text("\(max(1, Int(ceil(client.snapshot?.countdown ?? 0))))")
                  .font(PantryStyle.font(compact ? 76 : 110, weight: "Black"))
              }.foregroundStyle(PantryStyle.butter).shadow(
                color: PantryStyle.ink, radius: 0, x: 3, y: 5)
            }
          }
          if compact && client.showTouch {
            actionControls(compact: true).frame(width: 164).disabled(blocked)
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        if client.level?.tutorial == true {
          Text(coaching).font(PantryStyle.font(compact ? 11 : 13)).multilineTextAlignment(.center)
            .padding(compact ? 4 : 10).frame(maxWidth: 680)
            .background(PantryStyle.butter.opacity(0.2), in: Capsule())
        }
        HStack(spacing: 12) {
          score
          Spacer(minLength: 0)
          if geometry.size.width > 750 {
            VStack {
              Text(client.level?.name ?? "").font(PantryStyle.font(16, weight: "ExtraBold"))
              Text("WASD · Space grab · Hold E work · F dash · 1–6 pings")
                .font(PantryStyle.font(11)).foregroundStyle(.secondary)
            }
          }
          Spacer(minLength: 0)
          clock
        }
        if !compact && client.showTouch {
          HStack {
            Joystick(onMove: client.movement).frame(width: 112, height: 112)
            Spacer(minLength: 10)
            actionControls(compact: false)
          }.frame(maxWidth: 650).disabled(blocked)
        }
      }.padding(compact ? 8 : 12)
      if client.showMenu || client.showEmotes {
        Color.black.opacity(0.6).ignoresSafeArea()
        ScrollView {
          VStack {
            Spacer(minLength: 12)
            PantryCard {
              if client.showEmotes { emotes } else { menu }
            }.frame(maxWidth: 430)
            Spacer(minLength: 12)
          }.frame(minHeight: geometry.size.height)
        }.padding(.horizontal, 20)
      }
    }
    .background(KeyboardCapture(enabled: !blocked, onChange: handleKeys))
    .onChange(of: blocked) { _, value in if value { client.clearInput() } }
    .onChange(of: client.snapshot?.tick) { _, _ in
      for event in client.snapshot?.events ?? [] {
        if event.kind == "served" { PlatformActions.haptic(success: true) }
        if ["burnt", "fire", "expired"].contains(event.kind) {
          PlatformActions.haptic(success: false)
        }
      }
    }
    .onChange(of: Int(ceil(client.snapshot?.countdown ?? 0))) { _, value in
      if value > 0 && client.snapshot?.phase == .countdown { PlatformActions.haptic(success: nil) }
    }
    .onDisappear { client.clearInput() }
  }
  private func ticketRail(compact: Bool) -> some View {
    ScrollView(.horizontal) {
      HStack(spacing: 10) {
        ForEach(Array((client.snapshot?.orders ?? []).enumerated()), id: \.element.id) {
          index, order in
          VStack(alignment: .leading, spacing: compact ? 2 : 5) {
            HStack {
              Text("#\(order.id)").font(.custom("JetBrainsMono-Medium", size: 10))
              Spacer()
              Text(index == 0 ? "UP NEXT" : "\(Int(ceil(order.remaining)))s").font(
                PantryStyle.font(10, weight: "Black"))
            }.foregroundStyle(order.fraction < 0.25 ? PantryStyle.paprika : PantryStyle.ink)
            if !compact {
              Text(order.dish.label).font(PantryStyle.font(13, weight: "Black")).lineLimit(1)
            }
            HStack(spacing: 5) {
              ForEach(Array(order.dish.ingredients.enumerated()), id: \.offset) { _, ingredient in
                IngredientPicture(ingredient: ingredient).frame(
                  width: compact ? 20 : 27, height: compact ? 20 : 27)
              }
              Image(systemName: order.dish.cooked ? "flame.fill" : "leaf.fill").font(
                .system(size: 12)
              )
              .foregroundStyle(PantryStyle.paprika)
            }
            GeometryReader { geometry in
              Capsule().fill(PantryStyle.ink.opacity(0.15))
              Capsule().fill(order.fraction < 0.25 ? PantryStyle.paprika : PantryStyle.basil)
                .frame(width: geometry.size.width * order.fraction)
            }.frame(height: 5)
          }
          .padding(9).frame(width: compact ? 110 : 145)
          .background(PantryStyle.cream, in: RoundedRectangle(cornerRadius: 8))
          .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(
              index == 0 ? PantryStyle.butter : PantryStyle.ink.opacity(0.2), lineWidth: 2)
          )
          .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1 : 1))
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(
            "\(order.dish.label), \(Int(order.remaining)) seconds remaining. \(index == 0 ? "Next in line" : "")"
          )
        }
        if client.snapshot?.orders.isEmpty ?? true {
          Text("Waiting for orders…").font(PantryStyle.font(14)).padding(12)
        }
      }.padding(3)
    }.scrollIndicators(.hidden)
  }
  private var score: some View {
    HStack(spacing: 8) {
      Image(systemName: "dollarsign.circle.fill").font(.system(size: 28)).foregroundStyle(
        PantryStyle.butter)
      VStack(alignment: .leading, spacing: 3) {
        HStack(alignment: .firstTextBaseline) {
          Text("\(client.snapshot?.score ?? 0)").font(PantryStyle.font(28, weight: "Black"))
            .monospacedDigit()
          Text("×\(client.snapshot?.combo ?? 1)").font(PantryStyle.font(14, weight: "Black"))
            .foregroundStyle(PantryStyle.paprika)
        }
        Stars(
          count: client.level?.thresholds(players: client.room?.players.count ?? 1)
            .filter { (client.snapshot?.score ?? 0) >= $0 }.count ?? 0, size: 13)
      }
    }.accessibilityElement(children: .combine)
  }
  private var clock: some View {
    let overtime = client.snapshot?.phase == .overtime
    let seconds = max(
      0, Int(ceil(overtime ? (client.snapshot?.overtime ?? 0) : (client.snapshot?.timeLeft ?? 0))))
    return HStack(spacing: 6) {
      Image(systemName: "stopwatch.fill").font(.system(size: 24))
      VStack(alignment: .trailing) {
        if overtime { Text("OVERTIME").font(PantryStyle.font(10, weight: "Black")) }
        Text(String(format: "%d:%02d", seconds / 60, seconds % 60)).font(
          .custom("JetBrainsMono-Medium", size: 28))
      }
    }.foregroundStyle(seconds < 20 ? PantryStyle.paprika : PantryStyle.basil)
      .accessibilityLabel("\(overtime ? "Overtime" : "Time left") \(seconds) seconds")
  }
  private func actionControls(compact: Bool) -> some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        Button {
          client.press(dash: true)
        } label: {
          Label("Dash", systemImage: "bolt.fill")
        }
        .buttonStyle(ArcadeButtonStyle(color: PantryStyle.plum))
        if !compact {
          Button {
            client.showEmotes = true
          } label: {
            Image(systemName: "face.smiling")
          }
          .buttonStyle(ArcadeButtonStyle(color: PantryStyle.ink)).accessibilityLabel("Quick pings")
        }
      }
      HStack(spacing: 8) {
        Button {
          client.press(interact: true)
          PlatformActions.haptic(success: nil)
        } label: {
          Text("Grab")
        }.buttonStyle(ArcadeButtonStyle(color: PantryStyle.basil))
        HoldButton(label: "Action", onHold: client.action)
      }
    }
  }
  private var menu: some View {
    VStack(spacing: 14) {
      Text("Kitchen menu").font(PantryStyle.font(26, weight: "Black"))
      Text("The shared match keeps running.").font(PantryStyle.font(13)).foregroundStyle(.secondary)
      Button("Back to cooking") { client.showMenu = false }.buttonStyle(ArcadeButtonStyle())
        .keyboardShortcut(.cancelAction)
      Button("Quick pings") {
        client.showMenu = false
        client.showEmotes = true
      }
      Button("How to play") {
        client.showMenu = false
        client.showHelp = true
      }
      Toggle("Show touch controls", isOn: $client.showTouch).onChange(of: client.showTouch) {
        _, _ in client.clearInput()
      }
      HStack {
        Text("Appearance")
        Spacer()
        ThemeButton(client: client)
      }
      Text("\(client.rtt) ms · Room \(client.room?.code ?? "")").font(PantryStyle.font(12))
      Button("Leave kitchen") { client.leave() }.buttonStyle(
        ArcadeButtonStyle(color: PantryStyle.ink))
    }
  }
  private var emotes: some View {
    VStack(spacing: 16) {
      Text("QUICK PINGS").font(PantryStyle.font(24, weight: "Black"))
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
        ForEach(Array(Chef.emotes.enumerated()), id: \.offset) { index, text in
          Button("\(index + 1)  \(text)") {
            client.press(emote: index)
            client.showEmotes = false
          }.buttonStyle(ArcadeButtonStyle(color: PantryStyle.plum))
        }
      }
      Button("Close") { client.showEmotes = false }.keyboardShortcut(.cancelAction)
    }
  }
  private var coaching: String {
    guard let me = client.me, let level = client.level, let snapshot = client.snapshot else {
      return "Grab tomatoes from a crate to get started."
    }
    let cells = Kitchen.cells(level: level, snapshot: snapshot)
    if cells.contains(where: { ($0.state.fire ?? 0) > 0 }) {
      return "Fire! Grab the extinguisher and hold Action toward the flames."
    }
    switch me.held {
    case .ingredient(_, let chopped):
      return chopped
        ? "Drop the chopped tomato into a pot. Three matching ingredients make soup."
        : "Drop it on a cutting board. Hold Action with empty hands to chop."
    case .plate(let contents, _):
      return contents.isEmpty
        ? "Face a ready pot and Grab to scoop soup onto your plate."
        : "Take your plated dish to the blue pass and press Grab to serve!"
    case .stack(_, let dirty):
      return dirty
        ? "Drop the dirty plates into the sink. Hold Action with empty hands to wash."
        : "Put the plates back on the rack."
    case .extinguisher: return "Hold Action facing the fire to put it out."
    case .pot(_, _, _, let burnt):
      return burnt ? "Empty the burnt pot into the trash." : "Place the pot on a stove to cook."
    case nil:
      if let facing = cells.last(where: {
        Int(floor($0.x)) == Int(floor(me.x)) + me.facing.dx
          && Int(floor($0.y)) == Int(floor(me.y)) + me.facing.dy
      }) {
        if facing.symbol == "B", facing.state.item != nil {
          return "Hold Action with empty hands until chopping finishes."
        }
        if facing.symbol == "K", facing.state.item != nil {
          return "Hold Action with empty hands to wash the plates."
        }
      }
      if cells.contains(where: {
        if case .pot(_, let cook, _, let burnt) = $0.state.item { return cook >= 1 && !burnt }
        return false
      }) {
        return "Soup is ready! Grab a clean plate, then face the pot and Grab to scoop."
      }
      return "Grab tomatoes → chop → three in a pot → cook → plate → serve."
    }
  }
  private func handleKeys(_ keys: Set<String>, _ pressed: String?) {
    client.movement(
      x: (keys.contains("right") ? 1 : 0) - (keys.contains("left") ? 1 : 0),
      y: (keys.contains("down") ? 1 : 0) - (keys.contains("up") ? 1 : 0))
    client.action(keys.contains("action"))
    switch pressed {
    case "grab": client.press(interact: true)
    case "dash": client.press(dash: true)
    case "escape": client.showMenu.toggle()
    case "pings": client.showEmotes.toggle()
    default:
      if let pressed, let index = Int(pressed), (1...6).contains(index) {
        client.press(emote: index - 1)
      }
    }
  }
}

struct HoldButton: View {
  let label: String
  let onHold: (Bool) -> Void
  @State private var held = false
  @Environment(\.isEnabled) private var enabled
  var body: some View {
    Text(label).font(PantryStyle.font(15, weight: "ExtraBold"))
      .foregroundStyle(.white).padding(.horizontal, 16).frame(minHeight: 50)
      .background(PantryStyle.paprika.gradient, in: RoundedRectangle(cornerRadius: 14))
      .shadow(color: PantryStyle.paprikaDark, radius: 0, y: held ? 1 : 4)
      .scaleEffect(held ? 0.96 : 1)
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { _ in
          if !held {
            held = true
            onHold(true)
          }
        }.onEnded { _ in
          held = false
          onHold(false)
        }
      )
      .onDisappear { onHold(false) }
      .onChange(of: enabled) { _, value in
        if !value {
          held = false
          onHold(false)
        }
      }
      .accessibilityAddTraits(.isButton)
      .accessibilityLabel("Hold to chop, wash or spray")
      .accessibilityAction {
        held.toggle()
        onHold(held)
      }
      .accessibilityValue(held ? "Working, activate to stop" : "Stopped, activate to work")
  }
}

struct Joystick: View {
  let onMove: (Double, Double) -> Void
  @State private var offset = CGSize.zero
  @Environment(\.isEnabled) private var enabled
  var body: some View {
    GeometryReader { geometry in
      let radius = geometry.size.width * 0.34
      ZStack {
        Circle().fill(PantryStyle.ink.opacity(0.12))
        Circle().stroke(PantryStyle.ink.opacity(0.25), lineWidth: 3)
        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right").font(.system(size: 64))
          .foregroundStyle(PantryStyle.ink.opacity(0.15))
        Circle().fill(PantryStyle.butter.gradient).frame(width: 48, height: 48)
          .overlay(Circle().stroke(PantryStyle.ink.opacity(0.3), lineWidth: 2))
          .shadow(color: PantryStyle.ink.opacity(0.3), radius: 2, y: 3).offset(offset)
      }.contentShape(Circle())
        .gesture(
          DragGesture(minimumDistance: 0).onChanged { value in
            let dx = value.location.x - geometry.size.width / 2
            let dy = value.location.y - geometry.size.height / 2
            let length = max(1, hypot(dx, dy) / radius)
            offset = CGSize(width: dx / length, height: dy / length)
            onMove(offset.width / radius, offset.height / radius)
          }.onEnded { _ in
            offset = .zero
            onMove(0, 0)
          }
        )
        .accessibilityElement().accessibilityLabel("Movement joystick")
        .accessibilityAction(named: "Move left") { onMove(-1, 0) }
        .accessibilityAction(named: "Move right") { onMove(1, 0) }
        .accessibilityAction(named: "Move up") { onMove(0, -1) }
        .accessibilityAction(named: "Move down") { onMove(0, 1) }
        .accessibilityAction(named: "Stop") { onMove(0, 0) }
    }.onDisappear { onMove(0, 0) }
      .onChange(of: enabled) { _, value in
        if !value {
          offset = .zero
          onMove(0, 0)
        }
      }
  }
}
