import SwiftUI

struct MixerView: View {
  @EnvironmentObject private var store: HushStore
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var sheet: HushSheet?
  @State private var showReset = false

  var body: some View {
    ZStack {
      HushStyle.ink.ignoresSafeArea()
      GeometryReader { geometry in
        VStack(spacing: 0) {
          ScrollView {
            VStack(spacing: 0) {
              header
              hero(
                height: typeSize.isAccessibilitySize
                  ? 260 : max(174, min(242, geometry.size.height - 550)))
              mixer(
                faderHeight: typeSize.isAccessibilitySize
                  ? 150 : min(138, max(112, geometry.size.height * 0.17)))
            }
            .padding(.bottom, 18)
          }
          .scrollIndicators(.visible)
          .clipped()
          playbackDock
        }
      }
    }
    .foregroundStyle(HushStyle.silver)
    .tint(HushStyle.lavender)
    .sheet(item: $sheet) { item in
      switch item {
      case .scenes: SceneLibrary()
      case .save: SaveSceneView()
      case .timer: TimerView()
      case .settings: SettingsView()
      }
    }
    .alert(
      "Audio unavailable",
      isPresented: Binding(
        get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("Retry") {
        store.error = nil
        store.play()
      }
      Button("Cancel", role: .cancel) { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .confirmationDialog(
      "Clear all four sound layers?", isPresented: $showReset, titleVisibility: .visible
    ) {
      Button("Clear mix", role: .destructive) { store.resetMix() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Your saved scenes will stay in your library.")
    }
  }

  private var header: some View {
    HStack(alignment: .center) {
      HStack(spacing: 6) {
        Image(systemName: "moonphase.waning.crescent")
          .font(.system(size: 17, weight: .light))
          .foregroundStyle(HushStyle.lavender)
        Text("hush").font(.system(size: 32, weight: .regular, design: .serif)).tracking(-1.5)
      }
      .accessibilityElement(children: .combine)
      Spacer()
      Button {
        sheet = .scenes
      } label: {
        Label("Scenes", systemImage: "square.stack.3d.up")
          .font(.subheadline.weight(.medium))
          .padding(.horizontal, 16).frame(minHeight: 44)
          .background(.white.opacity(0.055), in: Capsule())
          .overlay(Capsule().stroke(.white.opacity(0.08)))
      }
      Button {
        sheet = .settings
      } label: {
        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
      }.accessibilityLabel("Settings")
    }
    .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 8)
  }

  private func hero(height: CGFloat) -> some View {
    ZStack(alignment: .bottomLeading) {
      Landscape(mix: store.mix, animated: store.isPlaying)
        .frame(height: height)
      LinearGradient(colors: [.clear, HushStyle.ink], startPoint: .center, endPoint: .bottom)
      VStack(alignment: .leading, spacing: 10) {
        Text("A LITTLE LESS WORLD")
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .tracking(2.4).foregroundStyle(HushStyle.lavender)
        Text(store.preferences.sceneName)
          .font(.system(.largeTitle, design: .serif).weight(.regular))
          .tracking(-0.9)
        HStack(spacing: 7) {
          Circle().fill(store.isPlaying ? HushStyle.lavender : HushStyle.muted)
            .frame(width: 5, height: 5)
          Text(
            store.message
              ?? (store.isMuted
                ? "Muted · your mix is still here"
                : store.isPlaying ? "Here, for a while." : "Make room for quiet.")
          )
          .font(.subheadline).foregroundStyle(HushStyle.muted)
          .fixedSize(horizontal: false, vertical: true)
          if store.isEdited {
            Text("Edited").font(.caption)
              .padding(.horizontal, 8).padding(.vertical, 4)
              .background(.white.opacity(0.08), in: Capsule())
          }
        }
      }.padding(.horizontal, 28).padding(.bottom, 10)
    }
  }

  private func mixer(faderHeight: CGFloat) -> some View {
    VStack(spacing: 14) {
      HStack {
        Text("THE ELEMENTS")
          .font(.system(size: 11, weight: .medium, design: .monospaced)).tracking(1.8)
          .foregroundStyle(HushStyle.muted)
        Spacer()
        Button {
          showReset = true
        } label: {
          Text("Clear").font(.subheadline).frame(minWidth: 44, minHeight: 44)
            .foregroundStyle(HushStyle.muted)
        }.accessibilityLabel("Clear mix")
        Button {
          sheet = .save
        } label: {
          Label("Save", systemImage: "bookmark")
            .font(.subheadline).frame(minHeight: 44)
        }.accessibilityLabel("Save scene")
      }
      LazyVGrid(
        columns: Array(
          repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
          count: typeSize.isAccessibilitySize ? 2 : 4
        ),
        spacing: 26
      ) {
        ForEach(Layer.allCases) { layer in
          SoundFader(
            layer: layer,
            height: faderHeight,
            level: Binding(get: { store.mix.level(layer) }, set: { store.setLevel(layer, $0) }))
        }
      }
    }
    .padding(.horizontal, 28)
  }

  private var playbackDock: some View {
    VStack(spacing: 4) {
      HStack(spacing: 12) {
        Button {
          store.isMuted.toggle()
          store.haptic()
        } label: {
          Image(systemName: store.isMuted ? "speaker.slash" : "speaker.wave.2")
            .foregroundStyle(store.isMuted ? HushStyle.lavender : HushStyle.silver)
            .frame(width: 44, height: 44)
        }.accessibilityLabel(store.isMuted ? "Unmute all sounds" : "Mute all sounds")
        Slider(
          value: Binding(
            get: { store.mix.master },
            set: { store.preferences.mix.master = Mix.clamp($0) }
          )
        ).tint(HushStyle.lavender).accessibilityLabel("Master volume")
        Text("\(Int((store.mix.master * 100).rounded()))")
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(HushStyle.muted)
          .lineLimit(1).fixedSize(horizontal: true, vertical: false).frame(minWidth: 30)
      }
      let controls =
        typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
      controls {
        Button {
          sheet = .timer
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "moon.zzz")
            Text(store.timerLabel).monospacedDigit()
          }.font(.subheadline).frame(maxWidth: .infinity, minHeight: 52)
        }
        .foregroundStyle(store.countdown == nil ? HushStyle.silver : HushStyle.lavender)
        .background(.white.opacity(0.045), in: Capsule())
        .accessibilityLabel(
          store.countdown == nil ? "Sleep timer" : "Sleep timer, \(store.timerLabel) remaining")
        Button {
          store.togglePlayback()
        } label: {
          HStack(spacing: 9) {
            Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
            Text(store.isPlaying ? "Pause" : "Listen")
          }.font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .foregroundStyle(HushStyle.ink).background(HushStyle.lavender, in: Capsule())
        .accessibilityLabel(store.isPlaying ? "Pause soundscape" : "Listen to soundscape")
      }
      Group {
        if store.isPlaying {
          Button {
            if store.fadeStarted != nil { store.fadeStarted = nil } else { store.fadeOut() }
          } label: {
            Text(
              store.fadeStarted != nil
                ? "Cancel fade · keep listening"
                : store.isFading ? "Sleep timer · fading to quiet" : "Fade to quiet"
            )
            .font(.caption).foregroundStyle(HushStyle.muted).frame(minHeight: 34)
          }
          .disabled(store.isFading && store.fadeStarted == nil)
        } else {
          Text("OFFLINE SOUNDS · ORIGINAL BY NATURE")
            .font(.system(size: 9, design: .monospaced)).tracking(1.2)
            .foregroundStyle(HushStyle.muted).frame(minHeight: 34)
        }
      }
    }
    .padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 2)
    .background {
      HushStyle.ink.opacity(0.97).ignoresSafeArea(edges: .bottom)
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.09)).frame(height: 0.5) }
    }
  }
}

enum HushSheet: String, Identifiable {
  case scenes, save, timer, settings
  var id: String { rawValue }
}

struct SoundFader: View {
  let layer: Layer
  var height: CGFloat = 138
  @Binding var level: Double
  @EnvironmentObject private var store: HushStore

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: layer.symbol)
        .font(.system(size: 21, weight: .ultraLight))
        .foregroundStyle(level > 0 ? HushStyle.lavender : HushStyle.muted)
        .frame(height: 24).accessibilityHidden(true)
      GeometryReader { geometry in
        ZStack(alignment: .bottom) {
          Capsule().fill(.white.opacity(0.065))
          Capsule().fill(
            LinearGradient(
              colors: [HushStyle.lavender.opacity(0.12), HushStyle.lavender.opacity(0.45)],
              startPoint: .bottom, endPoint: .top)
          ).frame(height: max(0, geometry.size.height * level))
          ForEach(1..<5) { tick in
            Rectangle().fill(.white.opacity(0.12)).frame(width: 14, height: 1)
              .offset(y: -geometry.size.height * Double(tick) / 5)
          }
          Capsule().fill(level > 0 ? HushStyle.silver : HushStyle.muted)
            .frame(width: 26, height: 4)
            .shadow(color: HushStyle.lavender.opacity(0.5), radius: 10)
            .offset(y: -max(8, (geometry.size.height - 16) * level + 8))
        }
        .overlay(Capsule().stroke(.white.opacity(level > 0 ? 0.23 : 0.15), lineWidth: 1))
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              let position = 1 - (value.location.y - 8) / (geometry.size.height - 16)
              level = Mix.clamp((position * 100).rounded() / 100)
            }
            .onEnded { _ in store.haptic() }
        )
      }
      .frame(width: 48, height: height)
      .accessibilityElement()
      .accessibilityLabel("\(layer.title) volume")
      .accessibilityValue("\(Int((level * 100).rounded())) percent")
      .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment: level = Mix.clamp(level + 0.1)
        case .decrement: level = Mix.clamp(level - 0.1)
        @unknown default: break
        }
      }
      VStack(spacing: 4) {
        Text(layer.title).font(.footnote.weight(.medium)).lineLimit(2)
          .minimumScaleFactor(0.9).multilineTextAlignment(.center)
        Text(level > 0 ? "\(Int((level * 100).rounded()))%" : "OFF")
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .tracking(1).foregroundStyle(HushStyle.muted)
      }
    }.frame(maxWidth: .infinity)
  }
}
