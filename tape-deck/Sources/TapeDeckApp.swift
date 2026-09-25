import AVFoundation
import SwiftUI

@main
struct TapeDeckApp: App {
  @StateObject private var store = TapeStore()
  @Environment(\.scenePhase) private var phase

  var body: some Scene {
    WindowGroup {
      DeckView()
        .environmentObject(store)
        .preferredColorScheme(.light)
        .tint(Deck.red)
        .onChange(of: phase) { _, phase in
          if phase != .active { store.stop() }
        }
        .onReceive(
          NotificationCenter.default.publisher(
            for: AVAudioSession.interruptionNotification)
        ) { _ in store.stop() }
        .onReceive(
          NotificationCenter.default.publisher(
            for: AVAudioSession.routeChangeNotification)
        ) { notification in
          if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
            reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
          {
            store.stop()
          }
        }
    }
  }
}

struct DeckView: View {
  @EnvironmentObject private var store: TapeStore
  @State private var showingLibrary = false
  @State private var showingSave = false
  @State private var showingControls = false
  @State private var showingGuide = false
  @State private var confirmingClear = false
  @ScaledMetric(relativeTo: .body) private var padHeight = 48
  private let timer = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 10) {
          header
          CassetteView(playing: store.isPlaying, step: store.currentStep, level: store.level)
          patternTitle
          parameterControls
          sequencer
          deckStatus
        }
        .padding(.horizontal, 22)
        .padding(.top, 4)
        .padding(.bottom, 12)
      }
      transport
    }
    .background(Deck.bone)
    .onReceive(timer) { _ in store.tick() }
    .sheet(isPresented: $showingLibrary) { LibraryView() }
    .sheet(isPresented: $showingSave) { SaveTapeView() }
    .sheet(isPresented: $showingControls) { ParameterView() }
    .sheet(isPresented: $showingGuide) { GuideView() }
    .alert(
      "Clear all \(store.selectedDrum.name.lowercased()) steps?",
      isPresented: $confirmingClear
    ) {
      Button("Clear \(store.selectedDrum.name)", role: .destructive) { store.clearTrack() }
      Button("Cancel", role: .cancel) {}
    }
    .alert(
      "Tape Deck needs attention",
      isPresented: Binding(
        get: { store.errorMessage != nil },
        set: { if !$0 { store.errorMessage = nil } }
      )
    ) {
      Button("OK") { store.errorMessage = nil }
    } message: {
      Text(store.errorMessage ?? "")
    }
  }

  private var header: some View {
    HStack(alignment: .center) {
      HStack(spacing: 9) {
        VStack(spacing: 3) {
          ForEach(0..<3) { _ in Rectangle().fill(Deck.red).frame(width: 19, height: 4) }
        }
        Text("TAPE DECK")
          .font(.system(.title2, design: .rounded).weight(.black))
          .tracking(-0.8)
      }
      .accessibilityElement(children: .combine)
      Spacer(minLength: 8)
      Button {
        showingGuide = true
      } label: {
        Image(systemName: "info.circle")
          .font(.body)
          .frame(width: 44, height: 44)
      }
      .accessibilityLabel("How to play")
      Button {
        showingLibrary = true
      } label: {
        Image(systemName: "square.stack")
          .font(.system(size: 19, weight: .medium))
          .frame(width: 46, height: 44)
          .background(Deck.paper, in: RoundedRectangle(cornerRadius: 12))
          .overlay(RoundedRectangle(cornerRadius: 12).stroke(Deck.line))
      }
      .accessibilityLabel("Tape library")
    }
    .foregroundStyle(Deck.ink)
  }

  private var patternTitle: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 3) {
        Text(store.pattern.name).font(.system(.title2, design: .rounded).weight(.bold))
          .foregroundStyle(Deck.ink)
          .lineLimit(2)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Micro(text: store.isPlaying ? "PLAYING" : "STOPPED", color: Deck.red)
        Text(String(format: "%02d / 16", max(0, store.currentStep) + 1))
          .font(.system(.caption, design: .monospaced).weight(.medium))
          .foregroundStyle(Deck.muted).monospacedDigit()
          .accessibilityLabel("Step \(max(0, store.currentStep) + 1) of 16")
      }
    }
  }

  private var parameterControls: some View {
    HStack(spacing: 0) {
      parameter(
        name: "TEMPO", value: "\(Int(store.pattern.tempo))", unit: "BPM",
        fraction: (store.pattern.tempo - 60) / 120)
      Rectangle().fill(Deck.line).frame(width: 1, height: 40).padding(.horizontal, 12)
      parameter(
        name: "SWING", value: "\(Int((store.pattern.swing * 100).rounded()))", unit: "%",
        fraction: store.pattern.swing / 0.6)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(Deck.paper.opacity(0.7), in: RoundedRectangle(cornerRadius: 13))
    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Deck.line))
  }

  private func parameter(name: String, value: String, unit: String, fraction: Double) -> some View {
    Button {
      showingControls = true
    } label: {
      HStack(spacing: 8) {
        Knob(fraction: fraction)
        VStack(alignment: .leading, spacing: 1) {
          HStack(spacing: 3) {
            Micro(text: name)
            Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
              .foregroundStyle(Deck.muted)
          }
          HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value).font(.system(.title2, design: .monospaced).weight(.bold))
            Text(unit).font(.system(.caption2, design: .monospaced))
          }.foregroundStyle(Deck.ink).monospacedDigit()
        }
        Spacer(minLength: 0)
      }
    }
    .buttonStyle(HardwareButtonStyle())
    .accessibilityLabel("\(name.capitalized), \(value) \(unit)")
    .accessibilityHint("Opens tempo and swing controls")
  }

  private var sequencer: some View {
    VStack(spacing: 6) {
      HStack(spacing: 4) {
        ForEach(Drum.allCases) { drum in
          Button {
            store.selectedDrum = drum
            UISelectionFeedbackGenerator().selectionChanged()
          } label: {
            VStack(spacing: 4) {
              Text(drum.name.uppercased())
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
              Text(trackStatus(drum))
                .font(.system(.caption2, design: .monospaced).weight(.medium))
                .foregroundStyle(Deck.muted)
              Capsule().fill(store.selectedDrum == drum ? Deck.red : Deck.line)
                .frame(height: 3)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(store.selectedDrum == drum ? Deck.red : Deck.ink)
          }
          .accessibilityLabel("\(drum.name) track")
          .accessibilityValue(trackStatus(drum))
          .accessibilityAddTraits(store.selectedDrum == drum ? .isSelected : [])
        }
      }
      HStack(spacing: 8) {
        Micro(text: store.selectedDrum.name.uppercased() + " / 16")
        Spacer(minLength: 0)
        trackToggle(
          "MUTE", label: "Mute", enabled: store.pattern.muted[store.selectedDrum.rawValue]
        ) {
          store.edit { $0.muted[store.selectedDrum.rawValue].toggle() }
        }
        trackToggle(
          "SOLO", label: "Solo", enabled: store.pattern.soloed[store.selectedDrum.rawValue]
        ) {
          store.edit { $0.soloed[store.selectedDrum.rawValue].toggle() }
        }
        Button {
          confirmingClear = true
        } label: {
          Image(systemName: "eraser").font(.body).frame(width: 44, height: 44)
        }.accessibilityLabel("Clear \(store.selectedDrum.name) steps")
      }
      .foregroundStyle(Deck.muted)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8)
      {
        ForEach(0..<16) { step in pad(step) }
      }
    }
  }

  private func trackStatus(_ drum: Drum) -> String {
    let index = drum.rawValue
    if store.pattern.muted[index] {
      return store.pattern.soloed[index] ? "MUTE + SOLO" : "MUTED"
    }
    if store.pattern.soloed[index] { return "SOLO" }
    if store.pattern.activeMask & (1 << index) == 0 { return "HELD" }
    return "\(store.pattern.steps[index].filter { $0 }.count) HITS"
  }

  private var deckStatus: some View {
    VStack(spacing: 8) {
      Rectangle().fill(Deck.line).frame(height: 1)
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: store.notice == nil ? "internaldrive" : "checkmark.circle")
          .foregroundStyle(Deck.red)
        Text(store.notice ?? "Working copy · only on this iPhone")
          .foregroundStyle(Deck.muted)
        Spacer(minLength: 0)
      }
      .font(.footnote)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.updatesFrequently)
    }
    .padding(.top, 6)
  }

  private func trackToggle(
    _ title: String, label: String, enabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title).font(.system(.caption, design: .monospaced).weight(.bold))
        .padding(.horizontal, 10)
        .frame(minWidth: 54, minHeight: 36)
        .foregroundStyle(enabled ? Deck.paper : Deck.ink)
        .background(enabled ? Deck.red : Deck.paper, in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(enabled ? Deck.red : Deck.line))
        .frame(height: 44)
    }
    .accessibilityLabel("\(label) \(store.selectedDrum.name)")
    .accessibilityValue(enabled ? "On" : "Off")
  }

  private func pad(_ step: Int) -> some View {
    let enabled = store.pattern.steps[store.selectedDrum.rawValue][step]
    let current = store.currentStep == step
    return Button {
      store.toggleStep(step)
    } label: {
      HStack(alignment: .center) {
        Text(String(format: "%02d", step + 1))
          .font(.system(.caption, design: .monospaced).weight(.semibold))
        Spacer(minLength: 0)
        RoundedRectangle(cornerRadius: 2)
          .fill(enabled ? Deck.ink.opacity(0.8) : Color.white.opacity(0.13))
          .frame(width: 15, height: 4)
      }
      .foregroundStyle(enabled ? Deck.ink : Deck.paper.opacity(0.7))
      .padding(.horizontal, 13)
      .frame(maxWidth: .infinity, minHeight: padHeight)
      .background(
        LinearGradient(
          colors: enabled
            ? [Deck.amber, Color(red: 0.87, green: 0.55, blue: 0.22)]
            : [Color(white: 0.23), Deck.ink],
          startPoint: .top, endPoint: .bottom),
        in: RoundedRectangle(cornerRadius: 8)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(current ? Deck.red : .black.opacity(0.35), lineWidth: current ? 3 : 1)
      )
      .shadow(color: .black.opacity(0.15), radius: 0, y: 3)
    }
    .buttonStyle(HardwareButtonStyle())
    .accessibilityLabel("\(store.selectedDrum.name), step \(step + 1)")
    .accessibilityValue(enabled ? "On" : "Off")
    .accessibilityHint("Double tap to toggle this step")
  }

  private var transport: some View {
    HStack(spacing: 12) {
      Button {
        store.toggleTransport()
      } label: {
        HStack(spacing: 10) {
          Image(systemName: store.isPlaying ? "stop.fill" : "play.fill")
          Text(store.isPlaying ? "STOP" : "PLAY")
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .tracking(2)
          Spacer()
          Circle().fill(Deck.paper.opacity(0.45)).frame(width: 6, height: 6)
        }
        .padding(.horizontal, 21).frame(maxWidth: .infinity, minHeight: 54)
        .foregroundStyle(Deck.paper)
        .background(Deck.red, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: Deck.red.opacity(0.3), radius: 0, y: 3)
      }
      .accessibilityLabel(store.isPlaying ? "Stop playback" : "Play pattern")
      Button {
        showingSave = true
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "square.and.arrow.down")
          Text("SAVE").font(.system(.caption, design: .monospaced).weight(.bold))
        }
        .frame(minWidth: 108, minHeight: 54)
        .foregroundStyle(Deck.ink)
        .background(Deck.paper, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Deck.line))
        .shadow(color: .black.opacity(0.1), radius: 0, y: 3)
      }
      .accessibilityLabel("Save a copy")
    }
    .buttonStyle(HardwareButtonStyle())
    .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 10)
    .background(Deck.bone.shadow(color: .black.opacity(0.06), radius: 12, y: -5))
  }
}
