import SwiftUI
import UIKit

struct SessionView: View {
  @EnvironmentObject private var store: CoachStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var confirmEnd = false
  @State private var confirmRestart = false
  var body: some View {
    Group {
      if let session = store.session {
        if session.finished {
          ResultView(record: session.record, routine: session.routine)
        } else {
          running(session)
        }
      }
    }
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    .confirmationDialog("End this session?", isPresented: $confirmEnd, titleVisibility: .visible) {
      Button("End and save effort", role: .destructive) { store.end() }
    }
    .confirmationDialog(
      "Restart from the beginning?", isPresented: $confirmRestart, titleVisibility: .visible
    ) {
      Button("Restart session", role: .destructive) {
        if let routine = store.session?.routine { store.start(routine) }
      }
    } message: {
      Text("This attempt will be discarded. Your saved history won’t change.")
    }
  }

  private func running(_ session: Session) -> some View {
    let accent = session.phase.kind == .work ? Palette.lime : Palette.rest
    return ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        HStack {
          CadenceMark().scaleEffect(0.8).frame(width: 32)
          Spacer()
          Eyebrow(text: session.routine.name).lineLimit(2)
          Spacer()
          Button {
            store.toggleMute()
          } label: {
            Image(systemName: store.muted ? "speaker.slash" : "speaker.wave.2")
              .font(.system(size: 20)).frame(width: 44, height: 44)
          }.accessibilityLabel(store.muted ? "Unmute cues" : "Mute cues")
        }.foregroundStyle(Palette.cream)
        HStack {
          Eyebrow(text: "Round \(session.round) / \(session.routine.rounds)")
          Spacer()
          Text("\(session.index + 1) OF \(session.phaseCount)").font(.caption.monospacedDigit())
        }.foregroundStyle(Palette.cream.opacity(0.6)).padding(.top, 20)
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 10) {
            Circle().fill(accent).frame(width: 8, height: 8)
            Eyebrow(
              text: session.paused
                ? "Paused / \(session.phase.kind.title)" : session.phase.kind.title)
          }.foregroundStyle(accent)
          Text(clock(session.remaining(at: store.now)))
            .instrumentDisplay(116).monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.5)
            .foregroundStyle(accent)
            .contentTransition(.numericText(countsDown: true))
            .accessibilityLabel("Time remaining")
            .accessibilityValue("\(session.remaining(at: store.now)) seconds")
          Text(session.phase.name).font(.title2.weight(.medium))
            .foregroundStyle(Palette.cream)
        }
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            Capsule().fill(Palette.cream.opacity(0.12))
            Capsule().fill(accent)
              .frame(
                width: max(
                  4,
                  geometry.size.width * session.elapsed(at: store.now)
                    / Double(session.phase.seconds)))
          }
        }.frame(height: 8).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 10) {
          let start = session.index / 24 * 24
          HStack(alignment: .bottom, spacing: 5) {
            ForEach(start..<min(session.phaseCount, start + 24), id: \.self) { index in
              let skipped = session.skippedIndices?.contains(index) == true
              RoundedRectangle(cornerRadius: 3)
                .fill(
                  skipped
                    ? .clear
                    : index == session.index
                      ? accent
                      : index < session.index ? accent.opacity(0.4) : Palette.cream.opacity(0.09)
                )
                .overlay {
                  if skipped {
                    RoundedRectangle(cornerRadius: 3)
                      .stroke(
                        Palette.cream.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [3]))
                  }
                }
                .frame(
                  height: session.routine.intervals[index % session.routine.intervals.count].kind
                    == .work ? 56 : 32)
            }
          }
          .frame(height: 60)
          if session.skippedPhases > 0 {
            Text("Dashed outline = skipped · \(session.skippedPhases)")
              .font(.caption).foregroundStyle(Palette.cream.opacity(0.6))
          }
        }.accessibilityElement(children: .ignore).accessibilityLabel(
          "Interval \(session.index + 1) of \(session.phaseCount). \(session.completedPhases) finished, \(session.skippedPhases) skipped."
        )
        AdaptiveRow {
          VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Up next").foregroundStyle(Palette.cream.opacity(0.5))
            Text(
              session.nextPhase.map { "\($0.kind.title) · \(clock($0.seconds))" }
                ?? "Session complete"
            )
            .font(.headline).foregroundStyle(Palette.cream)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 8) {
            Eyebrow(text: "Active time").foregroundStyle(Palette.cream.opacity(0.5))
            Text(clock(Int(session.totalActive(at: store.now))))
              .font(.system(.body, design: .monospaced)).foregroundStyle(Palette.cream)
              .accessibilityLabel("Active time \(Int(session.totalActive(at: store.now))) seconds")
          }
        }
        AdaptiveRow {
          Button("Restart") { confirmRestart = true }.frame(minWidth: 80, minHeight: 44)
          Spacer()
          Button("End session") { confirmEnd = true }.frame(minWidth: 100, minHeight: 44)
        }.font(.subheadline).foregroundStyle(Palette.cream.opacity(0.6))
      }.padding(28)
    }
    .background(Palette.ink.ignoresSafeArea())
    .safeAreaInset(edge: .bottom) {
      AdaptiveRow(spacing: 12) {
        Button {
          store.togglePause()
        } label: {
          Label(
            session.paused ? "Resume" : "Pause",
            systemImage: session.paused ? "play.fill" : "pause.fill"
          )
          .font(.headline).padding(.vertical, 16)
          .frame(maxWidth: .infinity, minHeight: 64)
          .background(accent).foregroundStyle(Palette.ink)
          .clipShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
        Button {
          store.skip()
        } label: {
          Label("Skip", systemImage: "forward.end.fill")
            .font(.headline).padding(.vertical, 16)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Palette.graphite).foregroundStyle(Palette.cream)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityLabel("Skip interval")
          .accessibilityHint("Advances to the next interval. Only time performed is saved.")
      }.padding(.horizontal, 28).padding(.vertical, 12).background(Palette.ink)
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: session.index)
    .preferredColorScheme(.dark)
  }
}

struct ResultView: View {
  @EnvironmentObject private var store: CoachStore
  let record: WorkoutRecord
  var routine: Routine?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        HStack {
          Eyebrow(text: "Session / saved")
          Spacer()
          CadenceMark(color: Palette.ink)
        }.padding(.top, 4)
        ZStack {
          Circle().stroke(Palette.ink.opacity(0.1), lineWidth: 1)
          Circle().trim(from: 0.03, to: 0.89).stroke(
            Palette.ink, style: StrokeStyle(lineWidth: 14, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
          CadenceMark(color: Palette.ink).scaleEffect(1.7)
        }.frame(width: 104, height: 104).padding(.vertical, 4)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 10) {
          Text(record.completed ? "Effort in.\nEnergy out." : "Every effort\ncounts.")
            .instrumentDisplay(46)
          Text(record.name).font(.title3).foregroundStyle(Palette.muted)
          Text(
            record.completed
              ? "You reached the end of your sequence." : "Ended early. Your effort is still saved."
          )
          .font(.subheadline).foregroundStyle(Palette.muted)
        }
        AdaptiveRow {
          Metric(value: clock(Int(record.activeSeconds.rounded(.down))), label: "ACTIVE TIME")
          Metric(value: clock(Int(record.workSeconds.rounded(.down))), label: "WORK TIME")
        }
        Divider()
        AdaptiveRow {
          Metric(
            value: "\(record.completedPhases)/\(record.totalPhases)", label: "FINISHED INTERVALS")
          Metric(value: "\(record.skippedPhases)", label: "SKIPPED")
        }
        Text("Paused time is excluded. Skipped intervals count only the time you spent in them.")
          .font(.footnote).foregroundStyle(Palette.muted)
      }.padding(28)
    }.background(Palette.cream.ignoresSafeArea()).foregroundStyle(Palette.ink)
      .safeAreaInset(edge: .bottom) {
        if let routine {
          VStack(spacing: 4) {
            ActionButton(title: "Done", symbol: "checkmark") { store.closeSession() }
            Button("Go again") { store.start(routine) }
              .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
          }
          .padding(.horizontal, 28).padding(.top, 12)
          .background(Palette.cream)
        }
      }
      .preferredColorScheme(.light)
  }
}
