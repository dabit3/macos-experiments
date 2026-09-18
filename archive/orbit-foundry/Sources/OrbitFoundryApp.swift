import SwiftUI

@main
struct OrbitFoundryApp: App {
  @State private var store = FlightStore()
  var body: some Scene {
    WindowGroup {
      ObservatoryView(store: store)
        .preferredColorScheme(.dark)
        .tint(Palette.cyan)
    }
  }
}

enum Palette {
  static let background = Color(red: 0.028, green: 0.043, blue: 0.104)
  static let panel = Color(red: 0.060, green: 0.081, blue: 0.153)
  static let ivory = Color(red: 0.96, green: 0.92, blue: 0.83)
  static let muted = Color(red: 0.56, green: 0.62, blue: 0.72)
  static let copper = Color(red: 0.82, green: 0.49, blue: 0.30)
  static let cyan = Color(red: 0.35, green: 0.89, blue: 0.94)
}

struct Engraving: View {
  let text: String
  var color: Color = Palette.muted
  var body: some View {
    Text(text.uppercased())
      .font(.system(.caption2, design: .monospaced).weight(.medium))
      .tracking(2)
      .foregroundStyle(color)
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct InstrumentButton: ButtonStyle {
  var filled = true
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.subheadline, design: .rounded).weight(.semibold))
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .foregroundStyle(filled ? Palette.background : Palette.ivory)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 17)
      .background(filled ? Palette.cyan : Palette.panel)
      .clipShape(RoundedRectangle(cornerRadius: 17))
      .opacity(configuration.isPressed ? 0.7 : 1)
  }
}

struct ObservatoryView: View {
  @Bindable var store: FlightStore
  @State private var activeMission: Mission?
  @State private var settings = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 43.0

  var body: some View {
    ZStack {
      Palette.background.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          HStack {
            HStack(spacing: 10) {
              Image(systemName: "circle.hexagongrid")
                .font(.title2).foregroundStyle(Palette.copper)
              Text("ORBIT\nFOUNDRY")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .tracking(3)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            Spacer()
            Button {
              settings = true
            } label: {
              Image(systemName: "slider.horizontal.3")
                .frame(width: 48, height: 48)
                .background(Palette.panel, in: Circle())
            }
            .accessibilityLabel("Flight settings")
          }
          VStack(alignment: .leading, spacing: 10) {
            Engraving(text: "An orbital puzzle • Vol. 01", color: Palette.copper)
            Text("Small probe.\nInfinite pull.")
              .font(.system(size: min(headlineSize, 68), weight: .regular, design: .serif))
              .tracking(-1.7)
              .fixedSize(horizontal: false, vertical: true)
              .accessibilityAddTraits(.isHeader)
            Text("Find your way through gravity.")
              .font(.subheadline).foregroundStyle(Palette.muted)
          }
          TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion)) { context in
            SolarArtwork(time: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate)
          }
          .frame(height: 250)
          .accessibilityLabel("A copper planet with cyan orbital paths and a tiny luminous probe")
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Engraving(
                text: store.completed == 8 ? "Atlas complete" : "Continue your expedition",
                color: Palette.cyan)
              Spacer()
              Text("\(store.completed) / 08")
                .font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.muted)
                .fixedSize()
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            HStack(alignment: .center, spacing: 16) {
              Text(store.nextMission.number)
                .font(.system(size: 40, weight: .ultraLight, design: .rounded)).foregroundStyle(
                  Palette.copper)
              VStack(alignment: .leading, spacing: 4) {
                Text(store.nextMission.name).font(.title2.weight(.medium))
                Text(store.nextMission.subtitle).font(.caption).foregroundStyle(Palette.muted)
              }
            }
            Button {
              activeMission = store.nextMission
            } label: {
              HStack {
                Text(store.completed == 0 ? "Begin first flight" : "Enter flight")
                Spacer()
                Image(systemName: "arrow.up.right")
              }.padding(.horizontal, 20)
            }.buttonStyle(InstrumentButton())
          }
          .padding(20)
          .background(Palette.panel.opacity(0.65), in: RoundedRectangle(cornerRadius: 24))
          Group {
            if typeSize.isAccessibilitySize {
              VStack(alignment: .leading, spacing: 10) {
                Text("Mission atlas").font(.title2.weight(.medium))
                Engraving(text: "8 coordinates")
              }
            } else {
              HStack {
                Text("Mission atlas").font(.title2.weight(.medium))
                Spacer()
                Engraving(text: "8 coordinates")
              }
            }
          }.padding(.top, 8)
          VStack(spacing: 0) {
            ForEach(Mission.all) { mission in
              Button {
                activeMission = mission
              } label: {
                MissionRow(
                  mission: mission, record: store.record(for: mission.id),
                  unlocked: store.unlocked(mission.id))
              }
              .buttonStyle(.plain)
              .disabled(!store.unlocked(mission.id))
              .accessibilityLabel(
                "\(mission.number), \(mission.name), \(store.unlocked(mission.id) ? "available" : "locked, complete the previous mission")"
              )
            }
          }
          Text("Eight small journeys. One universal force.")
            .font(.footnote).foregroundStyle(Palette.muted).frame(maxWidth: .infinity).padding(
              .bottom, 20)
        }.padding(.horizontal, 24).padding(.top, 8)
      }.clipped()
    }
    .foregroundStyle(Palette.ivory)
    .fullScreenCover(item: $activeMission) { mission in
      MissionView(mission: mission, store: store) { activeMission = nil }
    }
    .sheet(isPresented: $settings) { SettingsView(store: store) }
  }
}

struct MissionRow: View {
  let mission: Mission
  let record: FlightRecord?
  let unlocked: Bool
  var body: some View {
    HStack(spacing: 15) {
      ZStack {
        Circle().stroke(Palette.copper.opacity(0.4), lineWidth: 1).frame(width: 43, height: 43)
        Ellipse().stroke(Palette.muted.opacity(0.35), lineWidth: 0.5).frame(width: 61, height: 25)
          .rotationEffect(.degrees(-40))
        Text(mission.number).font(.system(.caption, design: .monospaced))
      }.frame(width: 60, height: 64)
      VStack(alignment: .leading, spacing: 6) {
        Text(mission.name).font(.system(.body, design: .rounded).weight(.medium))
        if let record {
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
              ForEach(0..<3) { index in
                Image(systemName: index < record.stars ? "star.fill" : "star")
              }
            }.font(.system(size: 11))
            Text("\(record.attempts) \(record.attempts == 1 ? "launch" : "launches")")
              .fixedSize(horizontal: false, vertical: true)
          }
          .font(.caption).foregroundStyle(Palette.copper)
        } else {
          Text(
            unlocked
              ? mission.subtitle
              : "Complete mission \(mission.number == "01" ? "01" : String(format: "%02d", mission.id)) to unlock"
          )
          .font(.caption).foregroundStyle(Palette.muted)
          .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 4)
      Image(systemName: unlocked ? "arrow.up.right" : "lock")
        .font(.caption).foregroundStyle(unlocked ? Palette.cyan : Palette.muted)
    }
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) { Rectangle().fill(Palette.muted.opacity(0.15)).frame(height: 1) }
  }
}

struct SettingsView: View {
  @Bindable var store: FlightStore
  @Environment(\.dismiss) private var dismiss
  @State private var confirmReset = false
  var body: some View {
    NavigationStack {
      List {
        Section("Flight instrument") {
          Text(
            "Aim a probe through gravitational fields. Collect every beacon before docking. Each flight uses the same physics as its preview."
          )
          Toggle("Tactile feedback", isOn: $store.archive.haptics)
            .onChange(of: store.archive.haptics) { _, _ in store.save() }
        }
        Section("Flight log") {
          LabeledContent("Missions completed", value: "\(store.completed) of 8")
          LabeledContent("Lifetime launches", value: "\(store.archive.launches)")
          Text(
            "Three stars for one launch, two for up to three, one for persevering. Your fewest launches are saved; ties favor faster flights."
          )
          Text(
            "Flight guide aligns a solvable course. Guided records are noted in mission results.")
        }
        Section("On this device") {
          Text(
            "Progress and preferences stay on this device. No accounts, network connection, tracking, or audio required."
          )
          Button("Erase flight log", role: .destructive) { confirmReset = true }
        }
        Section {
          Text("ORBIT FOUNDRY  /  1.0\nAn instrument for getting wonderfully lost.")
            .font(.footnote).foregroundStyle(Palette.muted)
        }
      }
      .scrollContentBackground(.hidden)
      .background(Palette.background)
      .navigationTitle("Flight settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .confirmationDialog(
        "Erase all mission progress and best scores?", isPresented: $confirmReset,
        titleVisibility: .visible
      ) {
        Button("Erase flight log", role: .destructive) { store.reset() }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This cannot be undone.")
      }
    }
  }
}
