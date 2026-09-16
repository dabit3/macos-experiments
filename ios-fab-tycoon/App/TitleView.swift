import SwiftUI

struct TitleView: View {
  @ObservedObject var store: GameStore
  @State private var pulse = false
  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(spacing: 16) {
          HStack {
            Text("STUDIO / 01").font(.system(size: 11, weight: .bold, design: .monospaced))
              .foregroundStyle(Theme.green)
            Spacer()
            Button {
              store.showingSettings = true
            } label: {
              Image(systemName: "gearshape.fill").font(.title3)
            }.accessibilityLabel("Settings")
          }
          .foregroundStyle(Theme.muted)
          Spacer(minLength: 16)
          Text("FAB TYCOON").font(
            .system(size: min(52, proxy.size.width * 0.14), weight: .black, design: .rounded)
          )
          .tracking(-2).foregroundStyle(Theme.lime).neonGlow(10)
          Text("FROM GARAGE TO GIGAFAB.").font(
            .system(size: 12, weight: .bold, design: .monospaced)
          ).tracking(2).foregroundStyle(Theme.muted)
          WaferArt().padding(.vertical, 9)
          VStack(spacing: 5) {
            Text("BUILD THE SILICON EMPIRE").font(
              .system(size: 13, weight: .bold, design: .monospaced)
            ).foregroundStyle(Theme.green)
            Text("Tap. Research. Scale. Ride the AI wave.").font(.subheadline).foregroundStyle(
              Theme.muted)
          }
          Button {
            store.start()
          } label: {
            HStack {
              Image(systemName: "power")
              Text(store.hasSave ? "RESUME FAB" : "POWER ON")
            }
            .font(.system(size: 17, weight: .black, design: .rounded)).frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Theme.green).foregroundStyle(.black).clipShape(
              RoundedRectangle(cornerRadius: 12)
            ).neonGlow(9)
          }
          .scaleEffect(pulse ? 1.015 : 1)
          .accessibilityLabel("Power on")
          if store.hasSave {
            Text(
              "GEN \(store.engine.state.generation)  ·  \(NumberFormat.formatCash(store.engine.state.lifetimeCash)) LIFETIME"
            )
            .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(
              Theme.muted)
          }
          HStack(spacing: 22) {
            Label("NO ACCOUNTS", systemImage: "lock.open.fill")
            Label("OFFLINE SAFE", systemImage: "bolt.fill")
            Label("100% ORIGINAL", systemImage: "sparkles")
          }.font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
      }
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
    }
  }
}
