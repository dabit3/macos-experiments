import AsterCore
import Combine
import SwiftUI

struct MissionView: View {
  @Bindable var controller: MissionController
  @State private var showingGuide = false
  private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: 0) {
      header
      Rectangle().fill(Theme.line).frame(height: 1)
      HStack(spacing: 0) {
        VStack(spacing: 0) {
          OrbitCanvas(controller: controller)
          telemetry
          transport
        }
        Rectangle().fill(Theme.line).frame(width: 1)
        FlightPanel(controller: controller)
          .frame(width: 326)
          .background(Theme.panel)
      }
      statusBar
    }
    .background(Theme.background)
    .tint(Theme.cyan)
    .onReceive(timer) { _ in controller.tick() }
    .alert(
      "Flight notice",
      isPresented: Binding(
        get: { controller.error != nil }, set: { if !$0 { controller.error = nil } })
    ) {
      Button("OK") { controller.error = nil }
    } message: {
      Text(controller.error ?? "")
    }
    .sheet(isPresented: $showingGuide) { guide }
  }

  private var header: some View {
    HStack(spacing: 20) {
      HStack(spacing: 10) {
        Image(systemName: "sparkle").font(.system(size: 26, weight: .light)).foregroundStyle(
          Theme.cyan)
        Text("ASTER").font(.system(size: 22, weight: .medium)).tracking(6)
      }
      Rectangle().fill(Theme.line).frame(width: 1, height: 26)
      VStack(alignment: .leading, spacing: 4) {
        Eyebrow(text: "ORBITAL LABORATORY")
        Text("Earth system / Probe 01").font(.system(size: 12)).foregroundStyle(Theme.muted)
      }
      Spacer()
      Button {
        showingGuide = true
      } label: {
        Label("Flight guide", systemImage: "book.closed")
      }
      .buttonStyle(InstrumentButton())
      Button {
        controller.export()
      } label: {
        Label("Export", systemImage: "square.and.arrow.up")
      }
      .buttonStyle(InstrumentButton()).accessibilityIdentifier("exportTrajectory")
      Button {
        controller.save()
      } label: {
        Label("Save mission", systemImage: "tray.and.arrow.down")
      }
      .buttonStyle(InstrumentButton()).accessibilityIdentifier("saveMission")
    }
    .padding(.horizontal, 26).padding(.top, 32).padding(.bottom, 20)
  }

  private var telemetry: some View {
    HStack(spacing: 0) {
      metric("ALTITUDE", number(controller.state.altitude), "km", "Above mean radius")
      metric(
        "VELOCITY", number(controller.state.velocity.magnitude, digits: 3), "km/s", "Inertial speed"
      )
      metric("PERIAPSIS", number(controller.elements.periapsis), "km", "Closest approach")
      metric(
        "APOAPSIS", controller.elements.apoapsis.map { number($0) } ?? "Escape",
        controller.elements.apoapsis == nil ? "" : "km", "Farthest approach")
    }
    .padding(.vertical, 24)
    .background(Theme.panel.opacity(0.6))
    .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
  }

  private func metric(_ title: String, _ value: String, _ unit: String, _ note: String) -> some View
  {
    VStack(alignment: .leading, spacing: 9) {
      Eyebrow(text: title)
      HStack(alignment: .firstTextBaseline, spacing: 5) {
        Text(value).font(.system(size: 25, weight: .light, design: .monospaced)).foregroundStyle(
          .white)
        Text(unit).font(.system(size: 11)).foregroundStyle(Theme.muted)
      }
      Text(note).font(.system(size: 10)).foregroundStyle(Theme.muted)
    }
    .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 25)
  }

  private var transport: some View {
    HStack(spacing: 14) {
      Button {
        controller.togglePause()
      } label: {
        Image(systemName: controller.paused ? "play.fill" : "pause.fill")
          .frame(width: 18, height: 18)
      }
      .buttonStyle(InstrumentButton()).disabled(controller.state.impacted)
      .accessibilityLabel(controller.paused ? "Resume simulation" : "Pause simulation")
      .accessibilityIdentifier("playPause")
      VStack(alignment: .leading, spacing: 4) {
        Eyebrow(text: "MISSION ELAPSED")
        Text(elapsed).font(.system(size: 17, weight: .regular, design: .monospaced))
      }
      Spacer()
      Eyebrow(text: "TIME WARP")
      HStack(spacing: 4) {
        ForEach([1.0, 30, 120, 600], id: \.self) { warp in
          Button {
            controller.setWarp(warp)
          } label: {
            Text("\(Int(warp))×").font(.system(size: 12, weight: .medium, design: .monospaced))
              .frame(width: 48, height: 34)
              .foregroundStyle(controller.mission.warp == warp ? Theme.cyan : Theme.muted)
              .background(controller.mission.warp == warp ? Theme.cyan.opacity(0.12) : .clear)
              .clipShape(RoundedRectangle(cornerRadius: 5))
          }.buttonStyle(.plain).accessibilityLabel("Time warp \(Int(warp)) times")
        }
      }.padding(3).background(Theme.panel).clipShape(RoundedRectangle(cornerRadius: 7))
    }
    .padding(.horizontal, 25).padding(.vertical, 18)
  }

  private var elapsed: String {
    let seconds = Int(controller.state.time)
    return String(format: "T+ %02d:%02d:%02d", seconds / 3_600, (seconds / 60) % 60, seconds % 60)
  }

  private var statusBar: some View {
    HStack(spacing: 8) {
      Circle().fill(controller.state.impacted ? Theme.amber : Theme.green).frame(
        width: 5, height: 5)
      Text(controller.message).font(.system(size: 11)).lineLimit(1)
      Spacer()
      Text("2-BODY / VELOCITY VERLET").font(.system(size: 9, design: .monospaced)).tracking(1)
    }
    .foregroundStyle(Theme.muted).padding(.horizontal, 26).frame(height: 33)
    .background(Theme.panel)
    .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
  }

  private var guide: some View {
    VStack(alignment: .leading, spacing: 22) {
      Eyebrow(text: "ASTER / FLIGHT SCHOOL", color: Theme.cyan)
      Text("Your first orbital maneuver").font(.system(size: 30, weight: .light, design: .serif))
      Text("A small change in velocity can move your horizon by thousands of kilometers.")
        .foregroundStyle(Theme.muted)
      guideStep(
        "01", "Start at departure",
        "Reset → Departure orbit gives a circular orbit 450 km above Earth. Flight starts paused.")
      guideStep(
        "02", "Plan a transfer",
        "Load the +460 m/s recipe, or edit prograde and radial velocity. Cyan is the predicted orbit; the dashed ring marks the target altitude."
      )
      guideStep(
        "03", "Execute and coast",
        "Fire the burn. Aim for an apoapsis of 2,400 ±120 km and periapsis above 300 km. Resume at 600× to see your probe climb."
      )
      guideStep(
        "04", "Keep your discovery",
        "Save a checkpoint, reset, then reload. Export creates real numerical CSV samples. Undo restores the instant before your latest burn."
      )
      Text(
        "Educational model: planar Earth-only gravity, point spacecraft, instantaneous impulses. No atmosphere, fuel, finite thrust, other bodies, or real mission guidance. A prograde impulse follows velocity; radial points away from Earth."
      )
      .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
      Button("Ready for flight") { showingGuide = false }.buttonStyle(
        InstrumentButton(primary: true))
    }.padding(36).frame(width: 580).background(Theme.panel)
  }

  private func guideStep(_ index: String, _ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Text(index).font(.system(size: 17, design: .monospaced)).foregroundStyle(Theme.cyan)
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(.system(size: 14, weight: .semibold))
        Text(detail).font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
