import SwiftUI

@main
struct ArchipelagoApp: App {
  @StateObject private var store = GameStore()
  var body: some Scene {
    WindowGroup {
      ContentView(store: store)
        .preferredColorScheme(.light)
    }
  }
}

@MainActor
final class GameStore: ObservableObject {
  @Published var game = Game.initial
  @Published var paused = true
  @Published var speed = 1
  @Published var notice = "Welcome aboard. Your first route starts a small adventure."
  @Published var error: String?
  @Published var undoGame: Game?
  @Published var saved = false
  private let directory: URL
  private var timer: Timer?
  private var ticksSinceSave = 0
  var autoURL: URL { directory.appendingPathComponent("voyage.json") }
  var checkpointURL: URL { directory.appendingPathComponent("checkpoint.json") }

  init() {
    directory = URL.documentsDirectory.appendingPathComponent("Archipelago", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: autoURL.path) {
        game = try Game.decode(Data(contentsOf: autoURL))
        notice = "Welcome back. Your voyage is restored and safely paused."
      }
      saved = FileManager.default.fileExists(atPath: checkpointURL.path)
    } catch { self.error = error.localizedDescription }
    timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.pulse() }
    }
  }

  func pulse() {
    guard !paused else { return }
    let won = game.goalMet
    game.advance(steps: speed)
    if !won && game.goalMet { notice = "A thriving archipelago! Your first chapter is complete." }
    ticksSinceSave += speed
    if ticksSinceSave >= 24 { persist() }
  }

  @discardableResult
  func change(
    _ message: String, onError: ((String) -> Void)? = nil,
    action: (inout Game) throws -> Void
  ) -> Bool {
    do {
      var next = game
      try action(&next)
      undoGame = game
      game = next
      notice = message
      persist()
      return true
    } catch {
      if let onError {
        onError(error.localizedDescription)
      } else {
        self.error = error.localizedDescription
      }
      return false
    }
  }

  func persist() {
    do {
      try game.encoded().write(to: autoURL, options: .atomic)
      ticksSinceSave = 0
    } catch {
      self.error = error.localizedDescription
      paused = true
    }
  }

  func save() {
    do {
      try game.encoded().write(to: checkpointURL, options: .atomic)
      saved = true
      notice = "Checkpoint saved · \(game.delivered) delivered · \(game.budget) coins"
      persist()
    } catch { self.error = error.localizedDescription }
  }

  func reload() {
    do {
      let restored = try Game.decode(Data(contentsOf: checkpointURL))
      undoGame = game
      game = restored
      paused = true
      notice = "Checkpoint restored. Press play whenever you’re ready."
      persist()
    } catch { self.error = GameError.corruptSave.localizedDescription }
  }

  func undo() {
    guard let previous = undoGame else { return }
    game = previous
    undoGame = nil
    paused = true
    notice = "Last edit undone. The simulation returned to that moment."
    persist()
  }

  func restart() {
    undoGame = game
    game = .initial
    paused = true
    notice = "A fresh sea, a new beginning. Undo brings your old voyage back."
    persist()
  }

  func export() -> URL? {
    let url = directory.appendingPathComponent("Archipelago-voyage.json")
    do {
      try game.encoded().write(to: url, options: .atomic)
      notice = "Voyage exported to Files → Archipelago."
      return url
    } catch {
      self.error = error.localizedDescription
      return nil
    }
  }
}

enum Palette {
  static let ink = Color(hex: 0x173E43)
  static let muted = Color(hex: 0x6C8481)
  static let cream = Color(hex: 0xFBF8EF)
  static let teal = Color(hex: 0x186D68)
  static let coral = Color(hex: 0xCB765B)
  static let gold = Color(hex: 0xD2A345)
  static let line = Color(hex: 0xE3E8DD)
  static func resource(_ resource: Resource) -> Color {
    [Color(hex: 0xD4A947), Color(hex: 0x498B75), Color(hex: 0xAA8496)][resource.rawValue]
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB, red: Double((hex >> 16) & 255) / 255,
      green: Double((hex >> 8) & 255) / 255,
      blue: Double(hex & 255) / 255, opacity: 1)
  }
}

struct PressStyle: ButtonStyle {
  var prominent = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .semibold, design: .rounded))
      .foregroundStyle(prominent ? .white : Palette.ink)
      .padding(.horizontal, 16).frame(minHeight: 44)
      .background(
        prominent ? Palette.teal : Color.white.opacity(0.75),
        in: RoundedRectangle(cornerRadius: 13)
      )
      .opacity(configuration.isPressed ? 0.65 : 1)
  }
}

struct ContentView: View {
  @ObservedObject var store: GameStore
  @State private var selectedIsland = 4
  @State private var selectedRoute: Int?
  @State private var editor = false
  @State private var editingRoute: Int?
  @State private var help = false
  @State private var reset = false
  @State private var exportedURL: URL?
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        header
        HStack(alignment: .top, spacing: 18) {
          VStack(spacing: 14) {
            ocean
            routeShelf
          }
          inspector.frame(width: geometry.size.width > 1100 ? 294 : 258)
        }
        .padding(.horizontal, 24).padding(.bottom, 16)
        statusBar
      }
      .background(Palette.cream)
      .foregroundStyle(Palette.ink)
    }
    .sheet(isPresented: $editor) {
      RouteEditor(store: store, routeID: editingRoute) { routeID in
        selectedRoute = routeID
      }
      .presentationDetents([.height(630)])
      .presentationCornerRadius(30)
    }
    .sheet(isPresented: $help) { fieldGuide }
    .alert("Restart this voyage?", isPresented: $reset) {
      Button("Restart voyage", role: .destructive) {
        store.restart()
        selectedRoute = nil
      }
      Button("Keep sailing", role: .cancel) {}
    } message: {
      Text(
        "Begin again with 300 coins and four ferries. Your checkpoint stays safe, and Undo can recover this voyage."
      )
    }
    .alert(
      "A little course correction",
      isPresented: Binding(
        get: { store.error != nil }, set: { if !$0 { store.error = nil } }
      )
    ) {
      Button("Got it") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active {
        store.paused = true
        store.persist()
      }
    }
    .onChange(of: store.game.routes.map(\.id)) { _, ids in
      if let selectedRoute, !ids.contains(selectedRoute) { self.selectedRoute = nil }
    }
  }

  private var header: some View {
    HStack(spacing: 20) {
      ZStack {
        RoundedRectangle(cornerRadius: 18).fill(Palette.teal).frame(width: 56, height: 56)
        Image(systemName: "water.waves").font(.system(size: 28)).foregroundStyle(Palette.cream)
      }
      VStack(alignment: .leading, spacing: 1) {
        Text("Archipelago").font(.system(size: 37, weight: .regular, design: .serif))
        Text("A SMALL WORLD, WELL CONNECTED").font(.system(size: 9, weight: .bold))
          .tracking(2.5).foregroundStyle(Palette.muted)
      }
      Spacer(minLength: 5)
      headerStat(
        "COINS", value: "\(store.game.budget)", symbol: "circle.circle", color: Palette.gold)
      headerStat(
        "DELIVERED", value: "\(store.game.delivered)", symbol: "shippingbox", color: Palette.teal)
      Rectangle().fill(Palette.line).frame(width: 1, height: 38)
      Button {
        help = true
      } label: {
        Image(systemName: "book.closed").font(.system(size: 20))
      }
      .buttonStyle(PressStyle()).accessibilityLabel("Field guide")
      Button {
        store.save()
      } label: {
        Label("Save", systemImage: "square.and.arrow.down")
      }
      .buttonStyle(PressStyle())
      Menu {
        Button("Reload checkpoint", systemImage: "arrow.clockwise") { store.reload() }
          .disabled(!store.saved)
        Button("Export voyage JSON", systemImage: "square.and.arrow.up") {
          exportedURL = store.export()
        }
        if let exportedURL {
          ShareLink(item: exportedURL) {
            Label("Share exported voyage", systemImage: "square.and.arrow.up")
          }
        }
        Button("Restart voyage", systemImage: "arrow.counterclockwise", role: .destructive) {
          reset = true
        }
      } label: {
        Image(systemName: "ellipsis").font(.system(size: 22)).frame(width: 44, height: 44)
      }
      .accessibilityLabel("Voyage options")
    }
    .padding(.horizontal, 28).padding(.top, 20).padding(.bottom, 20)
  }

  private func headerStat(_ title: String, value: String, symbol: String, color: Color) -> some View
  {
    HStack(spacing: 9) {
      Image(systemName: symbol).font(.system(size: 24, weight: .light)).foregroundStyle(color)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.system(size: 9, weight: .bold)).tracking(1.6).foregroundStyle(
          Palette.muted)
        Text(value).font(.system(size: 24, weight: .medium, design: .rounded)).monospacedDigit()
      }
    }.frame(minWidth: 94, alignment: .leading)
  }

  private var ocean: some View {
    GeometryReader { geometry in
      ZStack {
        OceanCanvas(game: store.game, selectedIsland: selectedIsland, selectedRoute: selectedRoute)
        ForEach(store.game.islands) { island in
          let point = OceanCanvas.position(island, geometry.size)
          Button {
            selectedIsland = island.id
            selectedRoute = nil
          } label: {
            VStack(spacing: 5) {
              Color.clear.frame(height: 103)
              HStack(spacing: 6) {
                Circle().fill(island.underserved ? Palette.coral : Palette.teal)
                  .frame(width: 6, height: 6)
                Text(island.name).font(.system(size: 14, weight: .bold, design: .rounded))
              }
              .foregroundStyle(Palette.ink)
              .padding(.horizontal, 12).padding(.vertical, 7)
              .background(Palette.cream.opacity(0.94), in: Capsule())
              if let produces = island.produces {
                Text("\(island.inventory[produces.rawValue]) \(produces.name.lowercased()) ready")
                  .font(.system(size: 10, weight: .semibold)).foregroundStyle(
                    Palette.ink.opacity(0.7))
              } else {
                Text(island.underserved ? "Waiting for supplies" : "Supplies arriving")
                  .font(.system(size: 10, weight: .semibold)).foregroundStyle(
                    Palette.ink.opacity(0.7))
              }
            }.frame(width: 160, height: 162)
          }
          .buttonStyle(.plain)
          .position(x: point.x, y: point.y + 23)
          .accessibilityLabel(
            "\(island.name), \(island.underserved ? "needs supplies" : "ready"), select island"
          )
          .accessibilityIdentifier("island-\(island.id)")
        }
        VStack {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
              Text("THE SUNLIT ISLES").font(.system(size: 10, weight: .bold)).tracking(2)
              Text("Chapter 01  /  A helping hand")
                .font(.system(size: 13, weight: .medium, design: .serif))
            }
            Spacer()
            HStack(spacing: 6) {
              Circle().fill(store.paused ? Palette.gold : Palette.teal).frame(width: 6, height: 6)
              Text(store.paused ? "SEA PAUSED" : "SAILING · \(store.speed)×")
                .font(.system(size: 9, weight: .bold)).tracking(1.5)
            }.padding(10).background(.white.opacity(0.45), in: Capsule())
          }
          Spacer()
          HStack {
            Image(systemName: "location.north.line").font(.system(size: 30, weight: .ultraLight))
            Text("N").font(.system(size: 9, weight: .bold))
            Spacer()
            Text("Tap an island to explore").font(.system(size: 10, weight: .medium))
          }.opacity(0.6)
        }.padding(22).allowsHitTesting(false)
      }
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.8), lineWidth: 2))
    }
    .frame(maxHeight: .infinity)
    .accessibilityIdentifier("archipelago-map")
  }

  private var routeShelf: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("YOUR FERRY ROUTES").font(.system(size: 10, weight: .bold)).tracking(1.6)
        Text("\(store.game.routes.count) / 5 connections").font(.system(size: 10)).foregroundStyle(
          Palette.muted)
        Spacer()
        Button {
          editingRoute = nil
          editor = true
        } label: {
          Label("New route", systemImage: "plus").font(.system(size: 13, weight: .bold))
        }
        .accessibilityIdentifier("new-route")
      }
      if store.game.routes.isEmpty {
        HStack(spacing: 14) {
          Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
            .font(.system(size: 28, weight: .light)).foregroundStyle(Palette.teal)
          VStack(alignment: .leading, spacing: 4) {
            Text("Every great voyage starts with a connection.").font(
              .system(size: 14, weight: .medium, design: .serif))
            Text("Connect a producer to an island in need, then assign a ferry.")
              .font(.system(size: 11)).foregroundStyle(Palette.muted)
          }
          Spacer()
        }.padding(18).frame(maxWidth: .infinity, minHeight: 76)
          .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(store.game.routes) { route in
              Button {
                selectedRoute = route.id
              } label: {
                routeCard(route)
              }.buttonStyle(.plain).accessibilityIdentifier("route-\(route.id)")
            }
          }
        }
      }
    }.frame(height: 118)
  }

  private func routeCard(_ route: Route) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Circle().fill(Palette.resource(route.resource)).frame(width: 7, height: 7)
        Text(
          "\(store.game.islands[route.source].name) → \(store.game.islands[route.destination].name)"
        )
        .font(.system(size: 12, weight: .bold)).lineLimit(1)
      }
      HStack {
        Image(systemName: "ferry.fill")
        Text(
          route.ferryID.flatMap { id in Game.fleet.first { $0.id == id }?.name } ?? "Assign a ferry"
        )
        Spacer()
        Text("\(route.delivered) delivered").foregroundStyle(Palette.muted)
      }.font(.system(size: 10, weight: .medium))
      GeometryReader { g in
        Capsule().fill(Palette.line)
        Capsule().fill(Palette.resource(route.resource))
          .frame(width: max(3, g.size.width * route.progress))
      }.frame(height: 3)
    }
    .padding(14).frame(width: 280, height: 82)
    .background(.white, in: RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16).stroke(
        selectedRoute == route.id ? Palette.teal : Palette.line,
        lineWidth: selectedRoute == route.id ? 2 : 1))
  }

  private var inspector: some View {
    VStack(spacing: 14) {
      goalCard
      ScrollView(showsIndicators: false) {
        if let routeID = selectedRoute,
          let route = store.game.routes.first(where: { $0.id == routeID })
        {
          routeInspector(route)
        } else {
          islandInspector(store.game.islands[selectedIsland])
        }
      }
      .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 22))
      VStack(spacing: 10) {
        HStack {
          Text("PACE OF THE SEA").font(.system(size: 9, weight: .bold)).tracking(1.5)
          Spacer()
          Text("DAY \(String(format: "%02d", store.game.day))").font(
            .system(size: 9, weight: .bold)
          ).foregroundStyle(Palette.muted)
        }
        HStack(spacing: 8) {
          Button {
            store.paused.toggle()
            if store.paused { store.persist() }
          } label: {
            Image(systemName: store.paused ? "play.fill" : "pause.fill").frame(width: 22)
          }.buttonStyle(PressStyle(prominent: true))
            .accessibilityLabel(store.paused ? "Play simulation" : "Pause simulation")
            .accessibilityIdentifier("play-pause")
          ForEach([1, 2, 4], id: \.self) { speed in
            Button {
              store.speed = speed
            } label: {
              Text("\(speed)×").font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                  store.speed == speed ? Palette.ink : .white,
                  in: RoundedRectangle(cornerRadius: 12)
                )
                .foregroundStyle(store.speed == speed ? .white : Palette.ink)
            }.accessibilityLabel("\(speed) times speed")
          }
        }
      }
      .padding(16).background(Palette.line.opacity(0.4), in: RoundedRectangle(cornerRadius: 18))
    }
  }

  private var goalCard: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack {
        Image(systemName: store.game.goalMet ? "checkmark.seal.fill" : "sparkle")
        Text(store.game.goalMet ? "CHAPTER COMPLETE" : "YOUR FIRST CHAPTER")
          .font(.system(size: 9, weight: .bold)).tracking(1.6)
        Spacer()
        Text("01").font(.system(size: 20, weight: .light, design: .serif)).opacity(0.5)
      }
      Text(store.game.goalMet ? "A thriving archipelago." : "A little goes a long way.")
        .font(.system(size: 23, weight: .regular, design: .serif))
      VStack(spacing: 9) {
        goalLine("Deliver 36 crates", value: min(36, store.game.delivered), target: 36)
        goalLine(
          "Send grain to Lantern Isle", value: min(8, store.game.lanternDelivered), target: 8)
      }
      Text(
        store.game.goalMet
          ? "Keep sailing. There are more islands to care for."
          : "Connect the islands. Bring the distant light to life."
      )
      .font(.system(size: 10)).lineSpacing(3).opacity(0.75)
    }
    .padding(19).foregroundStyle(Palette.cream)
    .background(Palette.teal.gradient, in: RoundedRectangle(cornerRadius: 22))
  }

  private func goalLine(_ title: String, value: Int, target: Int) -> some View {
    VStack(spacing: 6) {
      HStack {
        Text(title)
        Spacer()
        Text("\(value)/\(target)").monospacedDigit()
      }.font(.system(size: 10, weight: .medium))
      GeometryReader { geometry in
        Capsule().fill(.white.opacity(0.15))
        Capsule().fill(Color(hex: 0xD9DCA5)).frame(
          width: geometry.size.width * Double(value) / Double(target))
      }.frame(height: 4)
    }
  }

  private func islandInspector(_ island: Island) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text(island.subtitle).font(.system(size: 8, weight: .bold)).tracking(1.5).foregroundStyle(
          Palette.muted)
        Text(island.name).font(.system(size: 29, weight: .regular, design: .serif))
        Label(
          island.underserved ? "Supplies needed" : "Ready to share",
          systemImage: island.underserved ? "exclamationmark.circle" : "checkmark.circle"
        )
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(island.underserved ? Palette.coral : Palette.teal)
      }
      Rectangle().fill(Palette.line).frame(height: 1)
      Text("ON THE DOCK").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(
        Palette.muted)
      ForEach(Resource.allCases, id: \.self) { resource in
        if island.needs.contains(resource) || island.produces == resource {
          HStack {
            Image(systemName: resource.symbol).foregroundStyle(Palette.resource(resource))
              .frame(width: 30, height: 32)
              .background(
                Palette.resource(resource).opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 3) {
              Text(resource.name).font(.system(size: 13, weight: .semibold))
              Text(island.produces == resource ? "+2 every 6 seconds" : "Uses 1 every 24 seconds")
                .font(.system(size: 9)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Text("\(island.inventory[resource.rawValue])").font(
              .system(size: 22, weight: .medium, design: .rounded)
            )
            .monospacedDigit()
          }
        }
      }
      if island.underserved {
        Text(
          island.id == 4
            ? "The lighthouse keeper is waiting for grain. A route from Sunfield will keep the light burning."
            : "A low stock is a gentle nudge. Connect a producer, assign a ferry and let the sea do the rest."
        )
        .font(.system(size: 12, design: .serif)).lineSpacing(5).foregroundStyle(Palette.muted)
      } else if island.produces != nil {
        Text("Fresh supplies gather here. Find a nearby island that needs them and chart a course.")
          .font(.system(size: 12, design: .serif)).lineSpacing(5).foregroundStyle(Palette.muted)
      }
      HStack {
        Text("LIFETIME RECEIVED").font(.system(size: 8, weight: .bold)).tracking(1)
        Spacer()
        Text("\(island.received) crates").font(.system(size: 11, weight: .semibold))
      }.foregroundStyle(Palette.muted)
    }.padding(20)
  }

  private func routeInspector(_ route: Route) -> some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("ROUTE \(String(format: "%02d", route.id + 1)) · \(route.resource.name.uppercased())")
        .font(.system(size: 9, weight: .bold)).tracking(1.4).foregroundStyle(
          Palette.resource(route.resource))
      Text(
        "\(store.game.islands[route.source].name)\n↳ \(store.game.islands[route.destination].name)"
      )
      .font(.system(size: 25, weight: .regular, design: .serif)).lineSpacing(3)
      HStack {
        Label("\(route.cargo) aboard", systemImage: "shippingbox")
        Spacer()
        Text(route.ferryID == nil ? "No ferry" : route.returning ? "Returning" : "Outbound")
      }.font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
      Text("ASSIGN A FERRY").font(.system(size: 9, weight: .bold)).tracking(1.4)
      ForEach(Game.fleet) { boat in
        let busy = store.game.routes.contains { $0.id != route.id && $0.ferryID == boat.id }
        Button {
          store.change(
            route.ferryID == boat.id
              ? "\(boat.name) returned to the fleet. Cargo is safely back on the dock."
              : "\(boat.name) is ready on route \(route.id + 1)."
          ) {
            try $0.assign(ferryID: route.ferryID == boat.id ? nil : boat.id, routeID: route.id)
          }
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "ferry.fill").font(.system(size: 19)).foregroundStyle(Palette.teal)
            VStack(alignment: .leading, spacing: 3) {
              Text(boat.name).font(.system(size: 13, weight: .semibold))
              Text(
                busy
                  ? "On another route"
                  : "\(boat.capacity) crates · \(boat.speed.formatted())× speed"
              )
              .font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Image(systemName: route.ferryID == boat.id ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(route.ferryID == boat.id ? Palette.teal : Palette.line)
          }
          .padding(10).frame(minHeight: 48)
          .background(
            route.ferryID == boat.id ? Palette.teal.opacity(0.08) : Palette.cream,
            in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).disabled(busy).opacity(busy ? 0.5 : 1)
          .accessibilityLabel(
            "\(boat.name), \(boat.capacity) crates, \(route.ferryID == boat.id ? "assigned" : busy ? "unavailable" : "assign ferry")"
          )
      }
      HStack(spacing: 8) {
        Button {
          editingRoute = route.id
          editor = true
        } label: {
          Label("Edit", systemImage: "pencil")
        }.buttonStyle(PressStyle())
        Button {
          store.change("Route removed. Cargo returned and 20 coins recovered.") {
            $0.removeRoute(id: route.id)
          }
          selectedRoute = nil
        } label: {
          Image(systemName: "trash")
        }.buttonStyle(PressStyle()).accessibilityLabel("Remove route")
      }
      Text(
        "Editing or unassigning returns all cargo to its source. Undo restores the previous voyage."
      )
      .font(.system(size: 9)).lineSpacing(3).foregroundStyle(Palette.muted)
    }.padding(18)
  }

  private var statusBar: some View {
    HStack {
      Circle().fill(Palette.teal).frame(width: 5, height: 5)
      Text(store.notice).font(.system(size: 11)).lineLimit(1)
      Spacer()
      Button {
        store.undo()
      } label: {
        Label("Undo", systemImage: "arrow.uturn.backward")
      }
      .font(.system(size: 12, weight: .semibold)).disabled(store.undoGame == nil)
      .frame(minHeight: 32)
    }
    .foregroundStyle(Palette.muted)
    .padding(.horizontal, 28).padding(.bottom, 10)
  }

  private var fieldGuide: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack {
        Text("The islander’s field guide").font(.system(size: 32, design: .serif))
        Spacer()
        Button("Done") { help = false }.buttonStyle(PressStyle())
      }
      Text(
        "A peaceful logistics puzzle. No storms, no timers to beat — just a small world to care for."
      )
      .font(.system(size: 17, design: .serif)).foregroundStyle(Palette.muted)
      ForEach(
        Array(
          [
            (
              "01", "Chart a course",
              "New route connects a producer to an island that needs its resource. Each connection costs 60 coins."
            ),
            (
              "02", "Give it a ferry",
              "Select a route card, then choose a boat. Capacity and speed matter. A boat serves one route at a time."
            ),
            (
              "03", "Let the sea move",
              "Press play. Ferries load, sail, unload and return. Each delivered crate earns 3 coins. Try 4× speed."
            ),
            (
              "04", "Care for the distant light",
              "Deliver 36 crates in total and at least 8 grain to Lantern Isle. Edit a route or add another to help it."
            ),
            (
              "05", "Keep your voyage",
              "Progress autosaves. Save makes a checkpoint; the ••• menu reloads or exports it. Undo reverses the latest edit and time since it."
            ),
          ].enumerated()), id: \.offset
      ) { _, item in
        HStack(alignment: .top, spacing: 18) {
          Text(item.0).font(.system(size: 22, design: .serif)).foregroundStyle(Palette.coral)
          VStack(alignment: .leading, spacing: 6) {
            Text(item.1).font(.system(size: 17, weight: .semibold))
            Text(item.2).font(.system(size: 14)).lineSpacing(4).foregroundStyle(Palette.muted)
          }
        }
      }
      Spacer()
    }.padding(32).foregroundStyle(Palette.ink).background(Palette.cream)
  }
}

struct RouteEditor: View {
  @ObservedObject var store: GameStore
  let routeID: Int?
  let completed: (Int) -> Void
  @State private var source = 0
  @State private var destination = 1
  @State private var editorError: String?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Text(routeID == nil ? "CHART A NEW COURSE" : "A CHANGE OF COURSE")
            .font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(Palette.muted)
          Text(routeID == nil ? "Bring the islands closer." : "Find a new horizon.")
            .font(.system(size: 31, design: .serif))
        }
        Spacer()
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
        }.buttonStyle(PressStyle()).accessibilityLabel("Cancel route")
      }
      VStack(alignment: .leading, spacing: 10) {
        Text("01   DEPART FROM").font(.system(size: 10, weight: .bold)).tracking(1.6)
        HStack(spacing: 10) {
          ForEach(store.game.islands.filter { $0.produces != nil }) { island in
            choice(island, selected: source == island.id) {
              source = island.id
              destination = store.game.possibleDestinations(source: source).first?.id ?? 1
            }
          }
        }
      }
      HStack {
        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
        Text("\(store.game.islands[source].produces?.name ?? "") travels from producer to neighbor")
      }
      .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.teal)
      .frame(maxWidth: .infinity).padding(16).background(
        Palette.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
      VStack(alignment: .leading, spacing: 10) {
        Text("02   DELIVER TO").font(.system(size: 10, weight: .bold)).tracking(1.6)
        HStack(spacing: 10) {
          ForEach(store.game.possibleDestinations(source: source)) { island in
            choice(island, selected: destination == island.id) { destination = island.id }
          }
        }
      }
      Spacer(minLength: 0)
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(routeID == nil ? "60 coins to open this route" : "Route changes are free")
            .font(.system(size: 15, weight: .semibold))
          Text(
            routeID == nil
              ? "Assign a ferry after charting your course."
              : "Cargo returns safely to its original source."
          )
          .font(.system(size: 12)).foregroundStyle(Palette.muted)
        }
        Spacer()
        Button {
          let targetID = routeID ?? store.game.nextRouteID
          let succeeded = store.change(
            routeID == nil
              ? "Route charted. Choose a ferry to bring it to life."
              : "Course updated. Cargo returned safely.",
            onError: { editorError = $0 }
          ) {
            if let routeID {
              try $0.editRoute(id: routeID, source: source, destination: destination)
            } else {
              try $0.createRoute(source: source, destination: destination)
            }
          }
          if succeeded {
            completed(targetID)
            dismiss()
          }
        } label: {
          Label(routeID == nil ? "Create route" : "Update route", systemImage: "arrow.right")
        }
        .buttonStyle(PressStyle(prominent: true))
      }
    }
    .padding(30).background(Palette.cream).foregroundStyle(Palette.ink)
    .onAppear {
      if let route = store.game.routes.first(where: { $0.id == routeID }) {
        source = route.source
        destination = route.destination
      }
    }
    .alert(
      "Couldn’t chart this route",
      isPresented: Binding(
        get: { editorError != nil }, set: { if !$0 { editorError = nil } }
      )
    ) {
      Button("Got it") { editorError = nil }
    } message: {
      Text(editorError ?? "")
    }
  }

  private func choice(_ island: Island, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: island.produces?.symbol ?? "house.lodge.fill")
          Spacer()
          Image(systemName: selected ? "checkmark.circle.fill" : "circle")
        }.foregroundStyle(selected ? Palette.teal : Palette.muted)
        Text(island.name).font(.system(size: 16, weight: .semibold, design: .rounded))
        Text(island.produces.map { "\($0.name) producer" } ?? "Island community")
          .font(.system(size: 11)).foregroundStyle(Palette.muted)
      }
      .padding(16).frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
      .background(
        selected ? Palette.teal.opacity(0.07) : .white, in: RoundedRectangle(cornerRadius: 16)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16).stroke(
          selected ? Palette.teal : Palette.line, lineWidth: selected ? 2 : 1))
    }.buttonStyle(.plain).accessibilityLabel("\(island.name), \(selected ? "selected" : "choose")")
  }
}
