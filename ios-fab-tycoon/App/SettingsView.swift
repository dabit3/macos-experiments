import SwiftUI

struct SettingsView: View {
  @ObservedObject var store: GameStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      Form {
        Section("PLAYBACK") {
          Toggle(
            "Sound",
            isOn: Binding(
              get: { store.engine.state.soundEnabled },
              set: { store.engine.state.soundEnabled = $0 }))
          Toggle(
            "Haptics",
            isOn: Binding(
              get: { store.engine.state.hapticsEnabled },
              set: { store.engine.state.hapticsEnabled = $0 }))
        }
        Section {
          Button("Reset save", role: .destructive) {
            store.reset()
            dismiss()
          }
        } footer: {
          Text("Fab Tycoon is local-first. No accounts, no tracking, no network.")
        }
      }.navigationTitle("Settings").toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
    }
  }
}

struct OfflineSheet: View {
  let report: OfflineReport
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "moon.stars.fill").font(.system(size: 42)).foregroundStyle(Theme.green)
        .neonGlow()
      Text("WHILE YOU WERE AWAY").font(.system(size: 13, weight: .black, design: .monospaced))
        .foregroundStyle(Theme.green)
      Text("\(duration(report.elapsed))").font(.system(size: 26, weight: .black, design: .rounded))
      Text("Your fabs kept the lights on.").foregroundStyle(Theme.muted)
      HStack(spacing: 10) {
        StatBox(label: "CASH EARNED", value: NumberFormat.formatCash(report.cash))
        StatBox(label: "GPUs SHIPPED", value: NumberFormat.format(report.gpus))
      }
      Button("BACK TO THE FLOOR") { dismiss() }.buttonStyle(.borderedProminent).tint(Theme.green)
        .foregroundStyle(.black)
    }.padding(26).presentationDetents([.medium]).presentationBackground(Theme.ink)
  }
  private func duration(_ seconds: TimeInterval) -> String {
    let h = Int(seconds) / 3600
    let m = (Int(seconds) % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
  }
}
