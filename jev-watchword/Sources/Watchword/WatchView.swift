import AppKit
import SwiftUI
import WatchwordCore

private let ink = Color(red: 0.10, green: 0.16, blue: 0.18)
private let paper = Color(red: 0.96, green: 0.96, blue: 0.93)
private let accent = Color(red: 0.77, green: 0.91, blue: 0.45)
private let muted = Color(red: 0.40, green: 0.46, blue: 0.46)

struct WatchView: View {
  @StateObject private var model = WatchModel()

  var body: some View {
    HStack(spacing: 0) {
      sidebar
      VStack(alignment: .leading, spacing: 19) {
        header
        configuration
        HStack(alignment: .top, spacing: 16) {
          evidence
          verdict
        }
        footer
      }
      .padding(28)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(paper)
    }
    .foregroundStyle(ink)
    .frame(minWidth: 1100, minHeight: 750)
    .preferredColorScheme(.light)
    .task {
      model.refresh()
      let args = CommandLine.arguments
      if let index = args.firstIndex(of: "--showcase"), args.indices.contains(index + 1) {
        await model.startShowcase(folderURL: URL(fileURLWithPath: args[index + 1]))
      }
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 28) {
      HStack(spacing: 10) {
        Image(systemName: "waveform.path").font(.system(size: 26, weight: .medium)).foregroundStyle(
          accent)
        Text("watchword").font(.system(size: 23, weight: .semibold, design: .rounded)).tracking(
          -0.8)
      }
      VStack(alignment: .leading, spacing: 6) {
        Text("YOUR ATTENTION,\nGIVEN BACK.").font(.system(size: 11, weight: .semibold)).tracking(
          1.8)
        Text("A semantic wait-until\nfor your Mac.").font(.system(size: 14)).foregroundStyle(
          .white.opacity(0.6)
        ).lineSpacing(4)
      }
      VStack(alignment: .leading, spacing: 16) {
        rail("01", "Choose a window", complete: !model.selectedID.isEmpty)
        rail("02", "Describe “done”", complete: !model.condition.isEmpty)
        rail("03", "Get back to work", complete: model.active || model.phase == .fired)
      }
      Divider().overlay(.white.opacity(0.1))
      HStack {
        Circle().fill(model.active ? accent : .white.opacity(0.4)).frame(width: 7, height: 7)
        Text(model.active ? "LIVE OBSERVATION" : "ONE WATCH AT A TIME")
          .font(.system(size: 10, weight: .semibold)).tracking(1)
      }
      Text("Only your selected window.\nOnly your chosen follow-up.\nAlways fresh evidence.")
        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55)).lineSpacing(6)
      Spacer()
      Button {
        model.openFixture()
      } label: {
        Label("Open Terminal demo", systemImage: "terminal").font(
          .system(size: 12, weight: .medium)
        )
        .padding(.vertical, 9).frame(maxWidth: .infinity)
      }
      .buttonStyle(.plain).background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
      Text("Synthetic export · real Terminal\nArm during the 25-second lead-in.")
        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45)).lineSpacing(3)
      HStack(spacing: 6) {
        Image(systemName: "bolt.fill").foregroundStyle(accent)
        Text("Decisions by Jev").font(.system(size: 12, weight: .medium))
      }
    }
    .padding(24).frame(width: 230).frame(maxHeight: .infinity)
    .foregroundStyle(.white).background(ink)
  }

  private func rail(_ number: String, _ text: String, complete: Bool) -> some View {
    HStack(spacing: 10) {
      Text(number).font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(complete ? ink : .white.opacity(0.5))
        .frame(width: 24, height: 24).background(
          complete ? accent : .white.opacity(0.1), in: Circle())
      Text(text).font(.system(size: 12, weight: .medium))
    }
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Stop checking. Start knowing.").font(.system(size: 28, weight: .semibold)).tracking(
          -0.9)
        Text("When the meaning changes, your Mac makes the next move.")
          .font(.system(size: 13)).foregroundStyle(muted)
      }
      Spacer()
      Text(
        model.active
          ? "WATCH IS LIVE" : model.phase == .fired ? "FOLLOW-UP SENT" : "READY WHEN YOU ARE"
      )
      .font(.system(size: 9, weight: .bold)).tracking(1)
      .padding(.horizontal, 11).padding(.vertical, 8)
      .background(accent.opacity(0.65), in: Capsule())
    }
  }

  private var configuration: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack {
        sectionLabel("WATCH THIS WINDOW")
        Spacer()
        Button("Refresh", systemImage: "arrow.clockwise") { model.refresh() }.font(
          .system(size: 11)
        )
        .disabled(model.active)
      }
      if !model.permission {
        Button("Grant Accessibility access") { NativeAccess.requestPermission() }
      }
      Picker("Window", selection: $model.selectedID) {
        Text("Choose a window…").tag("")
        ForEach(model.windows) { Text($0.label).tag($0.id) }
      }.labelsHidden().disabled(model.active)
      sectionLabel("WAIT UNTIL")
      TextField("Describe the condition that matters…", text: $model.condition, axis: .vertical)
        .font(.system(size: 18, weight: .medium)).lineLimit(2...3)
        .textFieldStyle(.plain).padding(13)
        .background(paper, in: RoundedRectangle(cornerRadius: 9))
        .disabled(model.active)
      HStack(spacing: 12) {
        Picker("Then", selection: $model.followUp) {
          ForEach(FollowUp.allCases) { Text($0.rawValue).tag($0) }
        }.frame(width: 205).disabled(model.active)
        if model.followUp == .reveal {
          Button {
            model.chooseFolder()
          } label: {
            Label(model.folder?.url.lastPathComponent ?? "Choose folder…", systemImage: "folder")
              .lineLimit(1)
          }.disabled(model.active)
        } else if model.followUp == .raise {
          Picker("Raise", selection: $model.actionWindowID) {
            ForEach(model.windows) { Text($0.label).tag($0.id) }
          }.labelsHidden().disabled(model.active)
        }
        Spacer(minLength: 0)
        Picker("Limit", selection: $model.limit) {
          Text("2 min").tag(2)
          Text("5 min").tag(5)
          Text("15 min").tag(15)
        }.frame(width: 120).disabled(model.active)
        Button {
          if model.active { model.cancel() } else { model.arm() }
        } label: {
          Label(
            model.active ? "Cancel" : "Arm watch",
            systemImage: model.active ? "stop.fill" : "play.fill"
          )
          .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 13).padding(.vertical, 9)
        }.buttonStyle(.plain).background(ink, in: Capsule()).foregroundStyle(.white)
          .disabled(!model.keyAvailable && !model.active)
      }
      if let error = model.error {
        Text(error).font(.system(size: 11)).foregroundStyle(.red).textSelection(.enabled)
      } else {
        Text(
          model.keyAvailable
            ? "Selected-window AX text is sent to TypeSafe when you arm. No screenshots or other windows are sent."
            : "API key missing. Launch from a shell with TYPESAFE_API_KEY or JEV_API_KEY."
        )
        .font(.system(size: 10)).foregroundStyle(muted)
      }
    }
    .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(ink.opacity(0.07)))
  }

  private var evidence: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        sectionLabel("WINDOW EVIDENCE")
        Spacer()
        if model.evaluating { ProgressView().controlSize(.small) }
        Toggle("Baseline", isOn: $model.showBaseline).toggleStyle(.checkbox).font(.system(size: 10))
      }
      ScrollView {
        Text(
          model.showBaseline
            ? (model.baselineText.isEmpty ? "Captured when you arm." : model.baselineText)
            : (model.evidence?.text
              ?? "Live, selectable text from the chosen window appears here.\n\nNo hidden process signals. No screenshot guessing.")
        )
        .font(.system(size: 12, design: .monospaced))
        .lineSpacing(5).textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
      }
      .frame(height: 166).background(ink, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(
        .white.opacity(0.88))
      HStack {
        sectionLabel("OBSERVATIONS")
        Spacer()
        Text("Newest first").font(.system(size: 10)).foregroundStyle(muted)
      }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(model.observations) { observation in
            Button {
              model.selectedObservation = observation.id
              model.showBaseline = false
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(observation.at, style: .time).font(
                  .system(size: 10, weight: .semibold, design: .monospaced))
                Text(
                  observation.signals.map {
                    $0.confirmed ? "Confirmed" : $0.failed >= 0.85 ? "Failure" : "Waiting"
                  } ?? "Baseline"
                )
                .font(.system(size: 10))
              }.padding(8)
                .background(
                  model.evidence?.id == observation.id ? accent.opacity(0.55) : ink.opacity(0.04),
                  in: RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain)
          }
        }
      }.frame(height: 47)
      if let observation = model.evidence, !model.showBaseline {
        Text(observation.reason)
          .font(.system(size: 10)).foregroundStyle(muted)
          .fixedSize(horizontal: false, vertical: true)
        if let duration = observation.duration {
          Text("\(Int(duration)) ms · selected observation")
            .font(.system(size: 9, design: .monospaced)).foregroundStyle(muted)
        }
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }

  private var verdict: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack {
        sectionLabel("THE DECISION")
        Spacer()
        Text("\(model.confirmations)/2").font(.system(size: 11, weight: .bold, design: .monospaced))
          .foregroundStyle(muted)
      }
      Text(model.active || !model.observations.isEmpty ? model.phase.rawValue : "Standing by")
        .font(.system(size: 23, weight: .semibold)).tracking(-0.6)
      Text(model.reason).font(.system(size: 12)).foregroundStyle(muted).lineSpacing(3).fixedSize(
        horizontal: false, vertical: true)
      Divider()
      signal(
        "Condition met", value: model.evidence?.signals?.satisfied,
        color: Color(red: 0.3, green: 0.5, blue: 0.22))
      signal("Failed / cancelled", value: model.evidence?.signals?.failed, color: .orange)
      signal("Insufficient evidence", value: model.evidence?.signals?.insufficient, color: muted)
      Text("Noul = P(yes). Signals are independent.\nExplanations are rules written in code.")
        .font(.system(size: 9)).foregroundStyle(muted).lineSpacing(3)
      if !model.actionReceipt.isEmpty {
        Text(model.actionReceipt).font(.system(size: 11, weight: .medium)).padding(9)
          .background(accent.opacity(0.45), in: RoundedRectangle(cornerRadius: 7))
      }
    }.padding(17).frame(width: 262, alignment: .leading)
      .background(.white, in: RoundedRectangle(cornerRadius: 12))
  }

  private var footer: some View {
    HStack(spacing: 18) {
      Label(model.modelID, systemImage: "cpu")
      Text("\(model.requests) requests")
      Text(model.latency > 0 ? "\(Int(model.latency)) ms last inference" : "Latency measured live")
      Spacer()
      Text(
        model.active || model.elapsed > 0
          ? "\(Int(model.elapsed))s elapsed" : "Fresh → confirm → act once")
    }.font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text).font(.system(size: 9, weight: .bold)).tracking(1.3).foregroundStyle(muted)
  }

  private func signal(_ label: String, value: Double?, color: Color) -> some View {
    VStack(spacing: 4) {
      HStack {
        Text(label).font(.system(size: 11))
        Spacer()
        Text(value.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
      }
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(ink.opacity(0.07))
          Capsule().fill(color).frame(width: geometry.size.width * (value ?? 0))
        }
      }.frame(height: 4)
    }
  }
}
