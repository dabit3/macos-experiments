import SwiftUI

struct AchievementsView: View {
  @ObservedObject var store: GameStore
  var body: some View {
    VStack(spacing: 12) {
      SectionHeader(eyebrow: "MILESTONES", title: "Awards")
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
        ForEach(Balance.achievements) { achievement in
          let unlocked = store.engine.state.unlockedAchievements.contains(achievement.id)
          VStack(alignment: .leading, spacing: 8) {
            Image(systemName: unlocked ? "rosette" : "lock.fill").font(.title2).foregroundStyle(
              unlocked ? Theme.lime : Theme.muted)
            Text(achievement.title).font(.headline).foregroundStyle(unlocked ? .white : Theme.muted)
            Text(achievement.detail).font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
          }.frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading).padding(12)
            .background(
              Theme.panel.opacity(unlocked ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 13)
            ).overlay(
              RoundedRectangle(cornerRadius: 13).stroke(
                unlocked ? Theme.green.opacity(0.5) : .clear, lineWidth: 1))
        }
      }
    }
  }
}

struct ToastView: View {
  @ObservedObject var store: GameStore
  var body: some View {
    VStack(spacing: 8) {
      ForEach(store.toasts) { toast in
        VStack(alignment: .leading, spacing: 3) {
          Text(toast.title).font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(toast.dramatic ? .black : Theme.green)
          Text(toast.detail).font(.headline)
        }.padding(13).frame(maxWidth: .infinity, alignment: .leading).background(
          toast.dramatic ? Theme.green : Theme.panel2,
          in: RoundedRectangle(cornerRadius: toast.dramatic ? 0 : 12)
        ).overlay(
          RoundedRectangle(cornerRadius: 12).stroke(Theme.green, lineWidth: toast.dramatic ? 2 : 1)
        ).neonGlow(toast.dramatic ? 12 : 4)
      }
      Spacer()
    }.padding(.horizontal, 0).padding(.top, 8).animation(.spring(), value: store.toasts.map(\.id))
  }
}
