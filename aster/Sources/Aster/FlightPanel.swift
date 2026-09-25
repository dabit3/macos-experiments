import AsterCore
import SwiftUI

struct FlightPanel: View {
  @Bindable var controller: MissionController

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 23) {
        objective
        divider
        maneuver
        divider
        flightPlan
        divider
        library
      }.padding(24)
    }.scrollIndicators(.hidden)
  }

  private var divider: some View { Rectangle().fill(Theme.line).frame(height: 1) }

  private var objective: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack {
        Eyebrow(text: "MISSION 01", color: Theme.cyan)
        Spacer()
        Text(controller.goalMet ? "COMPLETE" : "IN PROGRESS")
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .foregroundStyle(controller.goalMet ? Theme.green : Theme.muted)
      }
      Text("Raise the horizon").font(.system(size: 23, weight: .regular, design: .serif))
      Text("Guide your probe into a higher orbit.\nA precise push. A different perspective.")
        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("2,400").font(.system(size: 36, weight: .light, design: .monospaced))
        Text("km").font(.system(size: 13)).foregroundStyle(Theme.muted)
        Spacer()
        Image(systemName: controller.goalMet ? "checkmark.seal.fill" : "scope")
          .font(.system(size: 25, weight: .light))
          .foregroundStyle(controller.goalMet ? Theme.green : Theme.cyan)
      }
      HStack(spacing: 5) {
        Circle().fill(controller.goalMet ? Theme.green : Theme.cyan).frame(width: 5, height: 5)
        Text(
          controller.goalMet ? "Transfer corridor acquired" : "Target apoapsis · tolerance ±120 km"
        )
        .font(.system(size: 11)).foregroundStyle(controller.goalMet ? Theme.green : Theme.muted)
      }
      Text("Keep periapsis ≥300 km").font(.system(size: 10, design: .monospaced)).foregroundStyle(
        Theme.muted)
    }
  }

  private var maneuver: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack {
        Eyebrow(text: "MANEUVER DESIGN", color: Theme.amber)
        Spacer()
        Text("IMPULSE").font(.system(size: 9, design: .monospaced)).foregroundStyle(Theme.muted)
      }
      burnControl(
        "Prograde",
        value: Binding(
          get: { controller.mission.plannedPrograde }, set: { controller.setPlan(prograde: $0) }),
        range: -900...900, help: "Along velocity · negative is retrograde")
      burnControl(
        "Radial",
        value: Binding(
          get: { controller.mission.plannedRadial }, set: { controller.setPlan(radial: $0) }),
        range: -500...500, help: "Away from Earth · negative is inward")
      HStack {
        Text("After burn").font(.system(size: 11)).foregroundStyle(Theme.muted)
        Spacer()
        Text("Ap \(controller.plannedElements.apoapsis.map { number($0) } ?? "∞") km")
          .font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.cyan)
      }
      HStack {
        Text("Periapsis").font(.system(size: 11)).foregroundStyle(Theme.muted)
        Spacer()
        Text("\(number(controller.plannedElements.periapsis)) km")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(controller.plannedElements.periapsis < 0 ? Theme.amber : Theme.muted)
      }
      Button {
        controller.suggestedBurn()
      } label: {
        HStack {
          Image(systemName: "arrow.up.right")
          Text("Load departure recipe")
          Spacer()
          Text("+460")
        }
        .font(.system(size: 11)).foregroundStyle(Theme.amber)
      }.buttonStyle(.plain).padding(.vertical, 4).accessibilityIdentifier("loadRecipe")
      Button {
        controller.execute()
      } label: {
        HStack {
          Image(systemName: "flame")
          Text("Execute burn")
          Spacer()
          Text("\(number(controller.deltaV)) m/s").monospacedDigit()
        }.frame(maxWidth: .infinity).padding(.vertical, 3)
      }
      .buttonStyle(InstrumentButton(primary: true))
      .disabled(!controller.canBurn)
      .opacity(controller.canBurn ? 1 : 0.4)
      .accessibilityIdentifier("executeBurn")
    }
  }

  private func burnControl(
    _ title: String, value: Binding<Double>, range: ClosedRange<Double>, help: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        Text(title).font(.system(size: 12, weight: .medium))
        Spacer()
        TextField(title, value: value, format: .number.precision(.fractionLength(0)))
          .textFieldStyle(.plain).multilineTextAlignment(.trailing)
          .font(.system(size: 16, weight: .regular, design: .monospaced))
          .foregroundStyle(Theme.amber).frame(width: 63)
          .padding(5).background(Theme.background).clipShape(RoundedRectangle(cornerRadius: 4))
          .accessibilityIdentifier(title.lowercased() + "Input")
        Text("m/s").font(.system(size: 10)).foregroundStyle(Theme.muted)
      }
      Slider(value: value, in: range, step: 10).tint(Theme.amber).accessibilityLabel(
        "\(title) burn")
      Text(help).font(.system(size: 10)).foregroundStyle(Theme.muted)
    }
  }

  private var flightPlan: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Eyebrow(text: "FLIGHT LOG")
        Spacer()
        Text(String(format: "%02d", controller.mission.burns.count))
          .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.muted)
      }
      if let burn = controller.mission.burns.last {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "arrow.up.forward.circle").foregroundStyle(Theme.amber)
          VStack(alignment: .leading, spacing: 5) {
            Text("Maneuver \(controller.mission.burns.count)").font(
              .system(size: 12, weight: .medium))
            Text("P \(number(burn.prograde))  /  R \(number(burn.radial)) m/s")
              .font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted)
          }
          Spacer()
          Button {
            controller.undoBurn()
          } label: {
            Image(systemName: "arrow.uturn.backward").padding(8)
          }
          .buttonStyle(.plain).foregroundStyle(Theme.muted)
          .accessibilityLabel("Undo last burn").help("Restore the instant before this burn")
        }
      } else {
        Text("No maneuvers yet. The next move is yours.")
          .font(.system(size: 11)).foregroundStyle(Theme.muted)
      }
    }
  }

  private var library: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Eyebrow(text: "MISSION LIBRARY")
        Spacer()
        Menu {
          Button("Departure orbit · 450 km") { controller.reset() }
          Button("Survey orbit · eccentric") { controller.reset(survey: true) }
        } label: {
          Label("Reset", systemImage: "arrow.counterclockwise")
        }
        .menuStyle(.borderlessButton).fixedSize().font(.system(size: 11))
        .accessibilityIdentifier("resetMission")
      }
      Text(controller.mission.preset).font(.system(size: 11)).foregroundStyle(Theme.muted)
      Button {
        controller.reload()
      } label: {
        HStack {
          Image(systemName: "arrow.clockwise")
          Text("Reload saved mission")
          Spacer()
        }
      }
      .buttonStyle(InstrumentButton()).disabled(!controller.hasSavedMission)
      .opacity(controller.hasSavedMission ? 1 : 0.4)
      .accessibilityIdentifier("reloadMission")
    }
  }
}
