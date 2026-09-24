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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var showingLibrary = false
  @State private var showingSave = false
  @State private var showingControls = false
  @State private var showingGuide = false
  @State private var confirmingClear = false
  @ScaledMetric(relativeTo: .body) private var padHeight = 44
  private let timer = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 14) {
          header
          display
          parameters
          tracks
          pads
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 16)
      }
      .overlay(alignment: .bottom) { notice }
      transport
    }
    .background(Deck.bone)
    .onReceive(timer) { _ in store.tick() }
    .sheet(isPresented: $showingLibrary) { LibraryView() }
    .sheet(isPresented: $showingSave) { SaveTapeView() }
    .sheet(isPresented: $showingControls) {
      ParameterView().presentationDetents([.medium, .large])
    }
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

  // MARK: Header

  private var header: some View {
    HStack(spacing: 8) {
      Text("Tape Deck")
        .font(.title3.weight(.bold))
        .foregroundStyle(Deck.ink)
      Spacer(minLength: 8)
      Button {
        showingGuide = true
      } label: {
        Image(systemName: "questionmark.circle")
          .font(.title3)
          .frame(width: 44, height: 44)
      }
      .accessibilityLabel("Help")
      Button {
        showingLibrary = true
      } label: {
        Label("Library", systemImage: "square.stack")
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 14)
          .frame(minHeight: 40)
          .background(Deck.paper, in: Capsule())
          .overlay(Capsule().stroke(Deck.line))
      }
      .accessibilityHint("Factory patterns and your saved tapes")
    }
    .foregroundStyle(Deck.ink)
    .buttonStyle(HardwareButtonStyle())
  }

  // MARK: Display

  private var display: some View {
    let reelAngle = reduceMotion ? 0 : Double(max(0, store.currentStep)) * 22.5
    return VStack(spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        Text(store.pattern.name)
          .font(.title2.weight(.semibold))
          .foregroundStyle(Deck.paper)
          .lineLimit(2)
        Spacer(minLength: 12)
        HStack(spacing: 6) {
          Circle()
            .fill(store.isPlaying ? Deck.red : Deck.bone.opacity(0.3))
            .frame(width: 8, height: 8)
          Text(
            store.isPlaying
              ? "Step \(String(format: "%02d", store.currentStep + 1))" : "Stopped"
          )
          .font(.subheadline.weight(.medium))
          .monospacedDigit()
          .foregroundStyle(Deck.bone.opacity(0.85))
        }
        .accessibilityElement(children: .combine)
      }
      HStack(spacing: 14) {
        Reel(angle: reelAngle).frame(width: 44, height: 44)
        VStack(spacing: 8) {
          stepLamps
          levelMeter
        }
        Reel(angle: reelAngle).frame(width: 44, height: 44)
      }
    }
    .padding(18)
    .background(Deck.ink, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  private var stepLamps: some View {
    HStack(spacing: 0) {
      ForEach(0..<16) { step in
        Capsule()
          .fill(
            store.currentStep == step
              ? Deck.amber : Deck.bone.opacity(step % 4 == 0 ? 0.35 : 0.14)
          )
          .frame(maxWidth: .infinity)
          .frame(height: 6)
          .padding(.trailing, step == 15 ? 0 : 3)
      }
    }
    .accessibilityHidden(true)
  }

  private var levelMeter: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(Deck.bone.opacity(0.12))
        Capsule()
          .fill(Deck.amber)
          .frame(width: proxy.size.width * CGFloat(min(1, store.level * 1.6)))
      }
    }
    .frame(height: 6)
    .accessibilityHidden(true)
  }

  // MARK: Tracks

  private var tracks: some View {
    VStack(spacing: 2) {
      ForEach(Drum.allCases) { drum in
        trackRow(drum)
      }
    }
  }

  private func trackRow(_ drum: Drum) -> some View {
    let index = drum.rawValue
    let selected = store.selectedDrum == drum
    let audible = store.pattern.activeMask & (1 << index) != 0
    return HStack(spacing: 10) {
      Button {
        store.selectedDrum = drum
        UISelectionFeedbackGenerator().selectionChanged()
      } label: {
        HStack(spacing: 12) {
          RoundedRectangle(cornerRadius: 2)
            .fill(selected ? Deck.red : Color.clear)
            .frame(width: 4, height: 24)
          Text(drum.name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(audible ? Deck.ink : Deck.muted)
            .frame(width: 52, alignment: .leading)
          StepStrip(
            steps: store.pattern.steps[index],
            currentStep: store.currentStep,
            on: audible ? Deck.ink : Deck.muted.opacity(0.45),
            off: Deck.ink.opacity(0.08),
            height: 14)
        }
        .frame(minHeight: 40)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(drum.name) track")
      .accessibilityValue(trackStatus(drum) + (selected ? ", selected" : ""))
      .accessibilityHint("Selects this track for editing")
      mixToggle("M", label: "Mute \(drum.name)", on: store.pattern.muted[index], color: Deck.red) {
        store.edit { $0.muted[index].toggle() }
      }
      mixToggle("S", label: "Solo \(drum.name)", on: store.pattern.soloed[index], color: Deck.amber)
      {
        store.edit { $0.soloed[index].toggle() }
      }
    }
    .padding(.trailing, 6)
    .background(
      selected ? Deck.paper : Color.clear,
      in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  private func mixToggle(
    _ symbol: String, label: String, on: Bool, color: Color, action: @escaping () -> Void
  ) -> some View {
    Button {
      action()
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    } label: {
      Text(symbol)
        .font(.footnote.weight(.bold))
        .frame(width: 34, height: 34)
        .foregroundStyle(on ? Deck.paper : Deck.muted)
        .background(
          on ? color : Deck.ink.opacity(0.06),
          in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(HardwareButtonStyle())
    .accessibilityLabel(label)
    .accessibilityValue(on ? "On" : "Off")
    .accessibilityAddTraits(on ? .isSelected : [])
  }

  private func trackStatus(_ drum: Drum) -> String {
    let index = drum.rawValue
    let hits = store.pattern.steps[index].filter { $0 }.count
    if store.pattern.muted[index] { return "muted" }
    if store.pattern.soloed[index] { return "solo, \(hits) hits" }
    if store.pattern.activeMask & (1 << index) == 0 { return "muted by solo" }
    return "\(hits) hits"
  }

  // MARK: Pads

  private var pads: some View {
    VStack(spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(store.selectedDrum.name)
          .font(.headline)
          .foregroundStyle(Deck.ink)
        Text(trackStatus(store.selectedDrum))
          .font(.subheadline)
          .foregroundStyle(Deck.muted)
        Spacer()
        Button("Clear") { confirmingClear = true }
          .font(.subheadline.weight(.semibold))
          .disabled(!store.pattern.steps[store.selectedDrum.rawValue].contains(true))
          .accessibilityLabel("Clear \(store.selectedDrum.name) steps")
      }
      .accessibilityElement(children: .contain)
      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
        spacing: 8
      ) {
        ForEach(0..<16) { step in
          pad(step)
        }
      }
    }
  }

  private func pad(_ step: Int) -> some View {
    let enabled = store.pattern.steps[store.selectedDrum.rawValue][step]
    let current = store.currentStep == step
    return Button {
      store.toggleStep(step)
    } label: {
      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(enabled ? Deck.amber : Deck.charcoal)
        Text("\(step + 1)")
          .font(.caption.weight(.semibold))
          .monospacedDigit()
          .foregroundStyle(enabled ? Deck.ink : Deck.bone.opacity(0.55))
          .padding(8)
      }
      .frame(maxWidth: .infinity, minHeight: padHeight)
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(Deck.red, lineWidth: current ? 3 : 0)
      )
    }
    .buttonStyle(HardwareButtonStyle())
    .accessibilityLabel("\(store.selectedDrum.name), step \(step + 1)")
    .accessibilityValue(enabled ? "On" : "Off")
    .accessibilityHint("Double tap to toggle this step")
  }

  // MARK: Parameters

  private var parameters: some View {
    HStack(spacing: 10) {
      stepper(
        "Tempo", value: "\(Int(store.pattern.tempo)) BPM",
        canDecrease: store.pattern.tempo > 60, canIncrease: store.pattern.tempo < 180,
        decrease: { store.nudgeTempo(-1) }, increase: { store.nudgeTempo(1) })
      stepper(
        "Swing", value: "\(Int((store.pattern.swing * 100).rounded()))% swing",
        canDecrease: store.pattern.swing > 0, canIncrease: store.pattern.swing < 0.6,
        decrease: { store.nudgeSwing(-0.02) }, increase: { store.nudgeSwing(0.02) })
    }
  }

  private func stepper(
    _ title: String, value: String, canDecrease: Bool, canIncrease: Bool,
    decrease: @escaping () -> Void, increase: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 0) {
        stepButton("minus", label: "Decrease \(title.lowercased())", enabled: canDecrease, decrease)
        Button {
          showingControls = true
        } label: {
          Text(value)
            .font(.body.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Deck.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityLabel("\(title), \(value)")
        .accessibilityHint("Opens sliders and tap tempo")
        stepButton("plus", label: "Increase \(title.lowercased())", enabled: canIncrease, increase)
      }
      .background(Deck.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Deck.line))
    }
    .buttonStyle(HardwareButtonStyle())
  }

  private func stepButton(
    _ symbol: String, label: String, enabled: Bool, _ action: @escaping () -> Void
  ) -> some View {
    Button {
      action()
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      Image(systemName: symbol)
        .font(.body.weight(.semibold))
        .frame(width: 44, height: 44)
        .foregroundStyle(enabled ? Deck.ink : Deck.line)
    }
    .disabled(!enabled)
    .accessibilityLabel(label)
  }

  // MARK: Transport

  private var transport: some View {
    HStack(spacing: 10) {
      Button {
        store.toggleTransport()
      } label: {
        Label(
          store.isPlaying ? "Stop" : "Play",
          systemImage: store.isPlaying ? "stop.fill" : "play.fill"
        )
        .font(.headline)
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(Deck.paper)
        .background(Deck.red, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .accessibilityLabel(store.isPlaying ? "Stop playback" : "Play pattern")
      Button {
        showingSave = true
      } label: {
        Label("Save", systemImage: "square.and.arrow.down")
          .font(.headline)
          .padding(.horizontal, 20)
          .frame(minHeight: 56)
          .foregroundStyle(Deck.ink)
          .background(Deck.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Deck.line))
      }
      .accessibilityLabel("Save a copy")
    }
    .buttonStyle(HardwareButtonStyle())
    .padding(.horizontal, 18)
    .padding(.top, 10)
    .padding(.bottom, 8)
    .background(Deck.bone.shadow(.drop(color: .black.opacity(0.06), radius: 10, y: -4)))
  }

  @ViewBuilder private var notice: some View {
    if let text = store.notice {
      Text(text)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Deck.paper)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Deck.ink, in: Capsule())
        .padding(.bottom, 10)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityAddTraits(.updatesFrequently)
    }
  }
}
