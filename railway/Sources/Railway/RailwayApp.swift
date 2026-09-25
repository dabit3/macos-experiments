import AppKit
import RailwayCore
import SwiftUI

@main
struct RailwayApp: App {
  @State private var store = RailwayStore()
  var body: some Scene {
    WindowGroup {
      ContentView(store: store)
        .frame(minWidth: 1120, minHeight: 780)
        .onAppear {
          NSApplication.shared.setActivationPolicy(.regular)
          if let iconURL = Bundle.main.url(forResource: "Railway", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
          {
            NSApplication.shared.applicationIconImage = icon
          }
          NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    .defaultSize(width: 1440, height: 940)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(after: .saveItem) {
        Button("Save dispatch") { store.saveCheckpoint() }.keyboardShortcut("s")
        Button("Reload dispatch") { store.loadCheckpoint() }.keyboardShortcut("o")
      }
    }
  }
}

@MainActor @Observable
final class RailwayStore {
  var simulation = Simulation()
  var notice = "Welcome to the morning shift."
  var hasCheckpoint = false
  var showGuide = false
  var showReset = false
  private var tickCount = 0
  private let directory: URL

  init() {
    directory = URL.applicationSupportDirectory.appending(
      path: "Railway", directoryHint: .isDirectory)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let auto = directory.appending(path: "autosave.json")
      if FileManager.default.fileExists(atPath: auto.path) {
        simulation = try Simulation.decoded(Data(contentsOf: auto))
        simulation.paused = true
        notice = "Shift restored · paused for inspection."
      }
      hasCheckpoint = FileManager.default.fileExists(
        atPath: directory.appending(path: "checkpoint.json").path)
    } catch { notice = "Could not restore shift: \(error.localizedDescription)" }
  }
  func change(_ action: (inout Simulation) -> Void) {
    action(&simulation)
    persist()
  }
  func tick() {
    simulation.tick(0.05)
    tickCount += 1
    if tickCount % 40 == 0 && !simulation.paused { persist() }
  }
  func persist() {
    do {
      try simulation.encoded().write(
        to: directory.appending(path: "autosave.json"), options: .atomic)
    } catch { notice = "Autosave failed: \(error.localizedDescription)" }
  }
  func saveCheckpoint() {
    do {
      try simulation.encoded().write(
        to: directory.appending(path: "checkpoint.json"), options: .atomic)
      hasCheckpoint = true
      notice =
        "Dispatch saved · \(clock(simulation.elapsed)) · \(simulation.delivered)/2 delivered."
    } catch { notice = "Save failed: \(error.localizedDescription)" }
  }
  func loadCheckpoint() {
    do {
      var restored = try Simulation.decoded(
        Data(contentsOf: directory.appending(path: "checkpoint.json")))
      restored.paused = true
      simulation = restored
      persist()
      notice = "Saved dispatch reloaded · paused for inspection."
    } catch { notice = "Could not load save: \(error.localizedDescription). Current shift kept." }
  }
  func reset() {
    simulation = Simulation()
    persist()
    notice = "Fresh morning shift. Your saved dispatch is still available."
  }
  func exportTimetable() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "Railway-timetable.csv"
    panel.title = "Export dispatch timetable"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    let rows = simulation.trains.map { train in
      [
        train.id, train.name, train.origin.title, train.destination.title, train.state.rawValue,
        train.departure.map(clock) ?? "", train.arrival.map(clock) ?? "",
      ].joined(separator: ",")
    }
    let csv =
      "service,name,origin,destination,state,departure,arrival\n" + rows.joined(separator: "\n")
      + "\n"
    do {
      try csv.write(to: url, atomically: true, encoding: .utf8)
      notice = "Timetable exported to \(url.lastPathComponent)."
    } catch { notice = "Export failed: \(error.localizedDescription)" }
  }
}

func clock(_ elapsed: Double) -> String {
  let seconds = Int(elapsed)
  return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

enum Palette {
  static let ink = Color(red: 0.12, green: 0.22, blue: 0.19)
  static let muted = Color(red: 0.40, green: 0.46, blue: 0.39)
  static let paper = Color(red: 0.96, green: 0.95, blue: 0.90)
  static let line = Color(red: 0.83, green: 0.84, blue: 0.77)
  static let brass = Color(red: 0.72, green: 0.53, blue: 0.25)
  static let red = Color(red: 0.72, green: 0.25, blue: 0.20)
  static let blue = Color(red: 0.23, green: 0.43, blue: 0.55)
}

struct ContentView: View {
  @Bindable var store: RailwayStore
  private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
  var body: some View {
    VStack(spacing: 0) {
      header
      Rectangle().fill(Palette.line).frame(height: 1)
      HStack(spacing: 0) {
        VStack(spacing: 0) {
          mapHeading
          DioramaView(simulation: store.simulation)
            .overlay(alignment: .bottomLeading) { mapLegend.padding(22) }
          timetable
        }
        Rectangle().fill(Palette.line).frame(width: 1)
        desk.frame(width: 310)
      }
      Rectangle().fill(Palette.line).frame(height: 1)
      HStack {
        Image(systemName: "externaldrive").font(.system(size: 11))
        Text(store.notice).lineLimit(1)
        Spacer()
        Text("LOCAL DISPATCH  /  ALL SYSTEMS INTERLOCKED").font(
          .system(size: 9, weight: .medium, design: .monospaced))
      }
      .font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.horizontal, 24).frame(
        height: 34)
    }
    .background(Palette.paper).foregroundStyle(Palette.ink)
    .onReceive(timer) { _ in store.tick() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) {
      _ in store.persist()
    }
    .sheet(isPresented: $store.showGuide) { guide }
    .alert("Begin a new morning shift?", isPresented: $store.showReset) {
      Button("Cancel", role: .cancel) {}
      Button("Reset shift", role: .destructive) { store.reset() }
    } message: {
      Text(
        "This resets trains, signals and the timetable. Your manual saved dispatch stays available via Reload."
      )
    }
  }
  private var header: some View {
    HStack(spacing: 17) {
      Image(systemName: "tram.fill").font(.system(size: 26, weight: .light))
        .frame(width: 48, height: 48).background(Palette.ink).foregroundStyle(Palette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
      VStack(alignment: .leading, spacing: 2) {
        Text("Railway").font(.system(size: 34, weight: .regular, design: .serif))
        Text("THE STILLWATER LINE").font(.system(size: 9, weight: .semibold, design: .monospaced))
          .tracking(2.6)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text("MORNING SHIFT").font(.system(size: 9, weight: .semibold)).tracking(1.5)
          .foregroundStyle(Palette.muted)
        Text("08:\(clock(store.simulation.elapsed))").font(
          .system(size: 20, weight: .regular, design: .monospaced))
      }
      Rectangle().fill(Palette.line).frame(width: 1, height: 34).padding(.horizontal, 8)
      Button {
        store.saveCheckpoint()
      } label: {
        Label("Save", systemImage: "square.and.arrow.down")
      }
      .buttonStyle(QuietButton()).accessibilityIdentifier("saveDispatch")
      Button {
        store.loadCheckpoint()
      } label: {
        Label("Reload", systemImage: "arrow.counterclockwise")
      }
      .buttonStyle(QuietButton()).disabled(!store.hasCheckpoint).accessibilityIdentifier(
        "reloadDispatch")
      Menu {
        Button("Export timetable…", systemImage: "square.and.arrow.up") { store.exportTimetable() }
        Button("Field guide", systemImage: "book") { store.showGuide = true }
        Divider()
        Button("Reset shift…", role: .destructive) { store.showReset = true }
      } label: {
        Image(systemName: "ellipsis").frame(width: 32, height: 32)
      }
      .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("More actions")
    }.padding(.leading, 28).padding(.trailing, 22).padding(.top, 22).padding(.bottom, 18)
  }
  private var mapHeading: some View {
    HStack {
      Text("01").font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundStyle(Palette.brass)
      Text("Stillwater National Forest").font(.system(size: 17, weight: .regular, design: .serif))
      Spacer()
      Circle().fill(store.simulation.paused ? Palette.brass : Color.green).frame(
        width: 6, height: 6)
      Text(store.simulation.paused ? "SIMULATION PAUSED" : "LIVE RAILWAY")
        .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1)
    }.padding(.horizontal, 26).frame(height: 48)
  }
  private var mapLegend: some View {
    HStack(spacing: 14) {
      Label("Station", systemImage: "square.fill")
      Label("Signal", systemImage: "circle.fill")
      Label("Points", systemImage: "arrow.triangle.branch")
    }
    .font(.system(size: 9)).foregroundStyle(Palette.ink.opacity(0.65))
    .padding(.horizontal, 12).padding(.vertical, 9)
    .background(Palette.paper.opacity(0.9), in: Capsule())
  }
  private var timetable: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("THE MORNING TIMETABLE").font(.system(size: 9, weight: .semibold)).tracking(1.5)
        Spacer()
        Text("\(store.simulation.delivered) OF 2 ARRIVED").font(
          .system(size: 9, weight: .medium, design: .monospaced)
        )
        .foregroundStyle(Palette.muted)
      }
      HStack(spacing: 28) {
        ForEach(store.simulation.trains) { train in
          HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(train.id == "R01" ? Palette.red : Palette.blue)
              .frame(width: 4, height: 33)
            VStack(alignment: .leading, spacing: 5) {
              Text("\(train.origin.code)  →  \(train.destination.code)").font(
                .system(size: 12, weight: .semibold, design: .monospaced))
              Text("\(train.id)  ·  \(train.name)").font(.system(size: 10)).foregroundStyle(
                Palette.muted)
            }
            Spacer(minLength: 6)
            Text(
              train.arrival.map { "08:\(clock($0))" }
                ?? (train.state == .ready ? "Scheduled" : "En route")
            )
            .font(.system(size: 11, design: .monospaced))
            if train.state == .delivered {
              Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.ink)
            }
          }
          if train.id == "R01" { Rectangle().fill(Palette.line).frame(width: 1, height: 30) }
        }
      }
    }.padding(.horizontal, 26).padding(.vertical, 18).background(Palette.paper)
  }
  private var desk: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          sectionTitle("DISPATCH DESK")
          Spacer()
          Button {
            store.showGuide = true
          } label: {
            Image(systemName: "questionmark.circle").font(.system(size: 15))
          }
          .buttonStyle(.plain).accessibilityLabel("Open field guide")
        }
        HStack(spacing: 9) {
          Button {
            store.change { $0.paused.toggle() }
          } label: {
            Label(
              store.simulation.paused ? "Run railway" : "Pause",
              systemImage: store.simulation.paused ? "play.fill" : "pause.fill"
            )
            .frame(maxWidth: .infinity).frame(height: 37)
          }
          .buttonStyle(.plain).background(Palette.ink).foregroundStyle(Palette.paper)
          .clipShape(RoundedRectangle(cornerRadius: 7)).keyboardShortcut(.space, modifiers: [])
          .accessibilityIdentifier("toggleSimulation")
          Picker(
            "Speed",
            selection: Binding(
              get: { store.simulation.speed }, set: { value in store.change { $0.speed = value } })
          ) {
            Text("1×").tag(1.0)
            Text("2×").tag(2.0)
            Text("4×").tag(4.0)
          }.labelsHidden().frame(width: 69).accessibilityLabel("Simulation speed")
        }
        ForEach(store.simulation.trains) { train in serviceCard(train) }
        VStack(alignment: .leading, spacing: 11) {
          HStack {
            sectionTitle("INTERLOCKING")
            Spacer()
            Image(systemName: store.simulation.corridorOwner == nil ? "lock.open" : "lock.fill")
              .foregroundStyle(Palette.brass)
          }
          HStack {
            Circle().fill(store.simulation.corridorOwner == nil ? Palette.muted : Palette.brass)
              .frame(width: 7, height: 7)
            Text("BLOCK 01").font(.system(size: 10, weight: .semibold, design: .monospaced))
            Spacer()
            Text(store.simulation.corridorLabel).font(.system(size: 10)).foregroundStyle(
              Palette.muted)
          }
          switchButton("W1", name: store.simulation.scenic ? "Forest loop" : "Main line") {
            _ = $0.toggleWestSwitch()
          }
          switchButton("W2", name: store.simulation.eastSwitch.title) { _ = $0.toggleEastSwitch() }
        }
        VStack(alignment: .leading, spacing: 10) {
          sectionTitle("APPROACH SIGNALS")
          ForEach(Station.allCases, id: \.self) { station in
            let clear = store.simulation.signals[station.rawValue] == true
            Button {
              store.change { $0.toggleSignal(station) }
            } label: {
              HStack {
                Circle().fill(clear ? Color(red: 0.28, green: 0.48, blue: 0.34) : Palette.red)
                  .frame(width: 8, height: 8)
                Text(station.title).font(.system(size: 11))
                Spacer()
                Text(clear ? "CLEAR" : "STOP").font(
                  .system(size: 9, weight: .semibold, design: .monospaced)
                )
                .foregroundStyle(clear ? Palette.ink : Palette.red)
              }.padding(.horizontal, 10).frame(height: 30)
                .background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain).accessibilityLabel(
              "\(station.title) signal \(clear ? "clear" : "stop")"
            )
            .accessibilityIdentifier("signal-\(station.rawValue)")
          }
        }
        VStack(alignment: .leading, spacing: 9) {
          sectionTitle("DISPATCH JOURNAL")
          ForEach(store.simulation.journal.prefix(4)) { entry in
            HStack(alignment: .top, spacing: 10) {
              Text(clock(entry.time)).font(.system(size: 9, design: .monospaced)).foregroundStyle(
                Palette.brass)
              Text(entry.text).font(.system(size: 10)).fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }.padding(22)
    }
    .background(Color(red: 0.93, green: 0.93, blue: 0.87))
  }
  private func sectionTitle(_ title: String) -> some View {
    Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(
      Palette.muted)
  }
  private func switchButton(
    _ code: String, name: String, action: @escaping (inout Simulation) -> Void
  ) -> some View {
    Button {
      store.change(action)
    } label: {
      HStack {
        Text(code).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(
          Palette.brass)
        Text(name).font(.system(size: 11))
        Spacer()
        Image(
          systemName: store.simulation.corridorOwner == nil ? "arrow.triangle.branch" : "lock.fill"
        )
        .font(.system(size: 11)).foregroundStyle(Palette.muted)
      }.padding(.horizontal, 10).frame(height: 32).background(
        Palette.paper, in: RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain).disabled(store.simulation.corridorOwner != nil)
    .accessibilityLabel("\(code) points \(name)").accessibilityIdentifier("switch-\(code)")
  }
  private func serviceCard(_ train: Train) -> some View {
    VStack(alignment: .leading, spacing: 11) {
      HStack {
        Image(systemName: "tram.fill").font(.system(size: 17)).foregroundStyle(
          train.id == "R01" ? Palette.red : Palette.blue)
        VStack(alignment: .leading, spacing: 2) {
          Text(train.name).font(.system(size: 18, weight: .regular, design: .serif))
          Text("\(train.id)  /  \(train.origin.title)").font(.system(size: 9)).foregroundStyle(
            Palette.muted)
        }
        Spacer()
        if train.state == .delivered {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.ink)
        } else {
          Text(train.state == .ready ? "READY" : train.waiting.isEmpty ? "MOVING" : "HELD")
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            .padding(5).background(Palette.line.opacity(0.5), in: Capsule())
        }
      }
      if train.state == .ready {
        HStack {
          Text("TO").font(.system(size: 9, weight: .semibold)).foregroundStyle(Palette.muted)
          Picker(
            "Destination for \(train.name)",
            selection: Binding(
              get: { train.destination },
              set: { value in store.change { $0.setDestination(train.id, station: value) } })
          ) {
            ForEach(Station.allCases.filter { $0 != train.origin }, id: \.self) { station in
              Text(station.title).tag(station)
            }
          }.labelsHidden().accessibilityIdentifier("destination-\(train.id)")
        }
        Button {
          store.change { _ = $0.dispatch(train.id) }
        } label: {
          HStack {
            Text("Dispatch \(train.id)").font(.system(size: 11, weight: .medium))
            Spacer()
            Image(systemName: "arrow.right").font(.system(size: 11))
          }.padding(.horizontal, 12).frame(height: 32)
            .background(Palette.ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
        }.buttonStyle(.plain).accessibilityIdentifier("dispatch-\(train.id)")
      } else {
        Text("→  \(train.destination.title)").font(.system(size: 11))
        HStack(spacing: 5) {
          Circle().fill(train.waiting.isEmpty ? Palette.muted : Palette.brass).frame(
            width: 5, height: 5)
          Text(
            train.state == .delivered
              ? "Arrived at 08:\(clock(train.arrival ?? 0))"
              : train.waiting.isEmpty ? "On the line · protected route" : train.waiting
          )
          .font(.system(size: 10)).foregroundStyle(Palette.muted)
        }.frame(height: 20)
      }
    }.padding(14).background(Palette.paper, in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line.opacity(0.6)))
  }
  private var guide: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("A small railway.\nA considered rhythm.").font(.system(size: 32, design: .serif))
      Text("YOUR FIRST MORNING SHIFT").font(.system(size: 10, weight: .semibold)).tracking(2)
        .foregroundStyle(Palette.brass)
      guideRow(
        "01", "Send the services",
        "Dispatch The Fox and Bluebird, then Run railway. The Fox has a clear route to Pine Summit."
      )
      guideRow(
        "02", "Hold the line",
        "Stillwater starts at STOP. Bluebird will stop before the junction. Clear its signal while The Fox owns Block 01: the interlock keeps Bluebird safe."
      )
      guideRow(
        "03", "Change the points",
        "After The Fox arrives, set W2 to Stillwater. Bluebird can now enter the block and reach Alder Grove. W1 selects the forest loop before a route is reserved."
      )
      guideRow(
        "04", "Keep your shift",
        "Pause and Save. Reload restores that checkpoint, paused. Reset starts a new shift without deleting the checkpoint. The menu exports your real timetable."
      )
      Text(
        "Space pauses · ⌘S saves · ⌘O reloads. Signals guard entry; a train already admitted continues safely. Both points lock until the train reaches its platform."
      )
      .font(.system(size: 11)).foregroundStyle(Palette.muted)
      Button("Take the desk") { store.showGuide = false }.buttonStyle(QuietButton())
        .frame(maxWidth: .infinity, alignment: .trailing).keyboardShortcut(.defaultAction)
    }.padding(34).frame(width: 540).background(Palette.paper).foregroundStyle(Palette.ink)
  }
  private func guideRow(_ number: String, _ title: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 17) {
      Text(number).font(.system(size: 18, design: .monospaced)).foregroundStyle(Palette.brass)
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(.system(size: 14, weight: .semibold))
        Text(text).font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(
          horizontal: false, vertical: true)
      }
    }
  }
}

struct QuietButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 12, weight: .medium))
      .padding(.horizontal, 13).frame(height: 34)
      .background(
        configuration.isPressed ? Palette.line : Palette.ink.opacity(0.05),
        in: RoundedRectangle(cornerRadius: 7))
  }
}
