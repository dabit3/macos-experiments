import SwiftUI

struct TitleOverlay: View {
  @ObservedObject var store: GameStore
  @State private var showingGuide = false

  var body: some View {
    VStack {
      HStack {
        Spacer()
        Button {
          store.toggleSound()
        } label: {
          Image(systemName: store.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            .font(.title3)
            .padding(12)
        }
        .accessibilityLabel("Toggle sound")
      }
      Spacer()
      Text("GPU RUSH")
        .font(.wordmark(58))
        .tracking(8)
        .foregroundStyle(Palette.green)
        .shadow(color: Palette.green.opacity(0.8), radius: 24)
      Text("AN RTX-INSPIRED PCB RUNNER")
        .font(.hud(12))
        .tracking(4)
        .foregroundStyle(Palette.steel)
        .padding(.top, 4)
      HStack(spacing: 10) {
        chip("BEST \(store.record.bestScore)", icon: "trophy.fill")
        chip("\(Int(store.record.bestDistance)) M", icon: "ruler.fill")
        if StreakTracker.isStreakAlive(store.record, on: Date(), calendar: .current),
          store.record.streakDays > 0
        {
          chip("\(store.record.streakDays)-DAY STREAK", icon: "flame.fill")
        }
      }
      .padding(.top, 18)
      Spacer()
      Button {
        store.startRun()
      } label: {
        Text("BOOT")
          .font(.wordmark(28))
          .tracking(6)
          .foregroundStyle(Palette.black)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 18)
          .background(Palette.green, in: RoundedRectangle(cornerRadius: 14))
          .shadow(color: Palette.green.opacity(0.7), radius: 20)
      }
      .accessibilityLabel("Boot a new run")
      .padding(.horizontal, 40)
      Button {
        showingGuide = true
      } label: {
        Text("HOW TO RUN")
          .font(.hud(14))
          .tracking(3)
          .foregroundStyle(Palette.green)
          .padding(.top, 18)
      }
      .accessibilityLabel("How to run")
      Text("Fan-made. Not affiliated with NVIDIA.")
        .font(.hud(10))
        .foregroundStyle(Palette.steel.opacity(0.7))
        .padding(.top, 30)
        .padding(.bottom, 26)
    }
    .sheet(isPresented: $showingGuide) { GuideView() }
  }

  private func chip(_ text: String, icon: String) -> some View {
    Label(text, systemImage: icon)
      .font(.digits(11))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Palette.charcoal, in: Capsule())
      .overlay(Capsule().stroke(Palette.green.opacity(0.4), lineWidth: 1))
  }
}

struct GuideView: View {
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        Label("Swipe left or right to change PCIe lanes.", systemImage: "arrow.left.arrow.right")
        Label("Swipe up or tap to jump over heat waves.", systemImage: "arrow.up")
        Label("Swipe down to slide under capacitor bars.", systemImage: "arrow.down")
        Label("Collect CUDA cores for score.", systemImage: "hexagon.fill")
        Label("Grab a DLSS orb for triple speed and double score.", systemImage: "circle.circle")
      }
      .navigationTitle("HOW TO RUN")
      .toolbar {
        Button("DONE") { dismiss() }
      }
    }
    .presentationDetents([.medium])
  }
}

struct HUDOverlay: View {
  @ObservedObject var store: GameStore

  var body: some View {
    VStack {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Text("\(store.score)")
            .font(.digits(30))
            .foregroundStyle(Palette.white)
          Text("\(Int(store.distance)) M")
            .font(.digits(13))
            .foregroundStyle(Palette.steel)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text("FPS \(store.fps)")
            .font(.digits(20))
            .foregroundStyle(Palette.green)
          Label("\(store.coins)", systemImage: "hexagon.fill")
            .font(.digits(14))
            .foregroundStyle(Palette.greenBright)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 14)
      if store.dlssActive {
        VStack(spacing: 4) {
          Text("DLSS 3\u{00D7} FRAME GEN")
            .font(.hud(11))
            .tracking(3)
            .foregroundStyle(Palette.greenBright)
          GeometryReader { geometry in
            Capsule()
              .fill(Palette.charcoal)
              .overlay(alignment: .leading) {
                Capsule()
                  .fill(Palette.greenBright)
                  .frame(width: geometry.size.width * store.dlssFraction)
              }
              .overlay(Capsule().stroke(Palette.green.opacity(0.6), lineWidth: 1))
          }
          .frame(width: 200, height: 8)
        }
        .padding(.top, 6)
      }
      Spacer()
      if let banner = store.banner {
        Text(banner)
          .font(.hud(15))
          .tracking(1)
          .foregroundStyle(Palette.greenBright)
          .padding(.horizontal, 18)
          .padding(.vertical, 8)
          .background(Palette.black.opacity(0.65), in: Capsule())
          .transition(.opacity)
          .padding(.bottom, 90)
      }
    }
    .animation(.easeInOut(duration: 0.25), value: store.banner)
  }
}

struct GameOverOverlay: View {
  @ObservedObject var store: GameStore

  private var headline: String {
    store.lastCrash == .heatWave ? "THERMAL THROTTLE" : "OUT OF VRAM"
  }

  var body: some View {
    ZStack {
      Palette.black.opacity(0.78).ignoresSafeArea()
      VStack(spacing: 14) {
        Text(headline)
          .font(.wordmark(38))
          .tracking(4)
          .foregroundStyle(store.lastCrash == .heatWave ? Palette.heat : Palette.cyan)
        Text(store.crashLine)
          .font(.hud(13))
          .foregroundStyle(Palette.steel)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 40)
        if store.newBest {
          Label("NEW BEST", systemImage: "sparkles")
            .font(.hud(13))
            .tracking(3)
            .foregroundStyle(Palette.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Palette.green, in: Capsule())
        }
        HStack(spacing: 26) {
          stat("SCORE", "\(store.score)")
          stat("DISTANCE", "\(Int(store.distance)) M")
          stat("CORES", "\(store.coins)")
        }
        .padding(.top, 8)
        if store.record.streakDays > 0 {
          Label(
            "\(store.record.streakDays)-DAY STREAK", systemImage: "flame.fill"
          )
          .font(.digits(12))
          .foregroundStyle(Palette.heat)
        }
        Button {
          store.startRun()
        } label: {
          Text("REBOOT")
            .font(.wordmark(24))
            .tracking(5)
            .foregroundStyle(Palette.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Palette.green, in: RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityLabel("Reboot and run again")
        .padding(.horizontal, 50)
        .padding(.top, 12)
        Button {
          store.toTitle()
        } label: {
          Text("TITLE")
            .font(.hud(14))
            .tracking(3)
            .foregroundStyle(Palette.green)
        }
        .accessibilityLabel("Back to title")
      }
    }
  }

  private func stat(_ label: String, _ value: String) -> some View {
    VStack(spacing: 4) {
      Text(value)
        .font(.digits(22))
        .foregroundStyle(Palette.white)
      Text(label)
        .font(.hud(10))
        .tracking(2)
        .foregroundStyle(Palette.steel)
    }
  }
}

struct PausedOverlay: View {
  @ObservedObject var store: GameStore
  var body: some View {
    ZStack {
      Palette.black.opacity(0.7).ignoresSafeArea()
      Button {
        store.resume()
      } label: {
        Text("TAP TO RESUME")
          .font(.wordmark(24))
          .tracking(4)
          .foregroundStyle(Palette.green)
          .padding(30)
      }
      .accessibilityLabel("Resume run")
    }
  }
}
