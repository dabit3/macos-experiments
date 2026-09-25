import SwiftUI
import UIKit

private enum Palette {
  static let ink = Color(red: 0.17, green: 0.21, blue: 0.20)
  static let muted = Color(red: 0.41, green: 0.44, blue: 0.42)
  static let paper = Color(red: 0.94, green: 0.94, blue: 0.90)
  static let coral = Color(red: 0.82, green: 0.36, blue: 0.25)
  static func panel(_ module: Module) -> Color {
    switch module {
    case .oscillator: Color(red: 0.97, green: 0.77, blue: 0.65)
    case .filter: Color(red: 0.77, green: 0.83, blue: 0.66)
    case .envelope: Color(red: 0.77, green: 0.77, blue: 0.89)
    case .output: Color(red: 0.74, green: 0.84, blue: 0.85)
    }
  }
  static func cable(_ module: Module) -> Color {
    switch module {
    case .oscillator: Color(red: 0.88, green: 0.36, blue: 0.21)
    case .filter: Color(red: 0.33, green: 0.53, blue: 0.32)
    case .envelope: Color(red: 0.49, green: 0.43, blue: 0.72)
    case .output: Color(red: 0.28, green: 0.50, blue: 0.57)
    }
  }
}

struct InstrumentView: View {
  @ObservedObject var store: InstrumentStore
  @State private var showLibrary = false
  @State private var showSave = false
  @State private var showGuide = false
  @State private var patchName = ""

  var body: some View {
    GeometryReader { proxy in
      let scale = min(proxy.size.width / 1180, proxy.size.height / 820)
      ZStack {
        Palette.paper
        Canvas { context, size in
          for x in stride(from: 0.0, through: size.width, by: 18) {
            for y in stride(from: 0.0, through: size.height, by: 18) {
              context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                with: .color(Palette.ink.opacity(0.05)))
            }
          }
        }
        instrument
          .frame(width: 1180, height: 820)
          .scaleEffect(scale)
          .frame(width: proxy.size.width, height: proxy.size.height)
      }
    }
    .ignoresSafeArea()
    .foregroundStyle(Palette.ink)
    .sheet(isPresented: $showLibrary) { library }
    .sheet(isPresented: $showSave) { saveSheet }
    .sheet(isPresented: $showGuide) { guide }
    .sheet(
      isPresented: Binding(
        get: { store.shareURL != nil },
        set: { if !$0 { store.shareURL = nil } })
    ) {
      if let url = store.shareURL { ShareSheet(url: url) }
    }
  }

  private var instrument: some View {
    VStack(spacing: 12) {
      header
      HStack(alignment: .lastTextBaseline) {
        VStack(alignment: .leading, spacing: 5) {
          Text("THE PATCH TABLE").font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(2.5).foregroundStyle(Palette.muted)
          Text(store.patch.name).font(.system(size: 27, weight: .medium, design: .serif))
        }
        Spacer()
        Label(
          store.patch.signalPath.isEmpty
            ? "Awaiting a connection" : "A little circuit, a lot of possibility",
          systemImage: store.patch.signalPath.isEmpty
            ? "circle.dashed" : "point.3.connected.trianglepath.dotted"
        )
        .font(.system(size: 12)).foregroundStyle(Palette.muted)
      }
      .frame(height: 49)
      patchBoard
      connectionStrip
      HStack(spacing: 18) {
        keyboard.frame(width: 652)
        scope
      }.frame(height: 181)
      footer
    }
    .padding(.horizontal, 34)
    .padding(.vertical, 26)
  }

  private var header: some View {
    HStack(spacing: 13) {
      ZStack {
        RoundedRectangle(cornerRadius: 13).fill(Palette.ink).frame(width: 49, height: 49)
        Path { path in
          path.move(to: CGPoint(x: 10, y: 29))
          path.addCurve(
            to: CGPoint(x: 37, y: 18),
            control1: CGPoint(x: 29, y: 47), control2: CGPoint(x: 17, y: 1))
        }
        .stroke(Palette.panel(.oscillator), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .frame(width: 49, height: 49)
      }
      VStack(alignment: .leading, spacing: 1) {
        Text("patchwork").font(.system(size: 32, weight: .semibold, design: .rounded)).tracking(
          -1.8)
        Text("SMALL CIRCUITS. HAPPY ACCIDENTS.").font(
          .system(size: 8, weight: .bold, design: .monospaced)
        )
        .tracking(1.8).foregroundStyle(Palette.muted)
      }
      Spacer()
      action("Guide", icon: "questionmark.circle") { showGuide = true }
      action("Library", icon: "square.stack") { showLibrary = true }
      action("Save patch", icon: "square.and.arrow.down") {
        patchName = store.patch.name
        showSave = true
      }
      Button {
        store.export()
      } label: {
        Label("Export WAV", systemImage: "waveform")
          .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 17).frame(height: 43)
          .foregroundStyle(.white).background(Palette.ink, in: Capsule())
      }
      .accessibilityIdentifier("exportWAV")
    }
    .frame(height: 65)
    .padding(.bottom, 6)
    .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink.opacity(0.13)).frame(height: 1) }
  }

  private func action(_ title: String, icon: String, perform: @escaping () -> Void) -> some View {
    Button(action: perform) {
      Label(title, systemImage: icon).font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 13).frame(height: 43)
        .background(.white.opacity(0.55), in: Capsule())
        .overlay(Capsule().stroke(Palette.ink.opacity(0.12), lineWidth: 1))
    }.buttonStyle(.plain).accessibilityIdentifier(title)
  }

  private var patchBoard: some View {
    ZStack(alignment: .topLeading) {
      HStack(spacing: 16) {
        ForEach(Array(Module.allCases.enumerated()), id: \.element) { index, module in
          modulePanel(module, index: index)
        }
      }
      Canvas { context, _ in
        for (index, cable) in store.patch.cables.enumerated() {
          let start = portPosition(cable.source, input: false)
          let end = portPosition(cable.destination, input: true)
          var path = Path()
          path.move(to: start)
          let sag = max(start.y, end.y) + 70 + CGFloat(index * 7)
          path.addCurve(
            to: end, control1: CGPoint(x: start.x, y: sag), control2: CGPoint(x: end.x, y: sag))
          context.stroke(
            path.offsetBy(dx: 0, dy: 4), with: .color(.black.opacity(0.12)),
            style: StrokeStyle(lineWidth: 9, lineCap: .round))
          context.stroke(
            path, with: .color(Palette.cable(cable.source)),
            style: StrokeStyle(lineWidth: 7, lineCap: .round))
          context.stroke(
            path.offsetBy(dx: 0, dy: -1), with: .color(.white.opacity(0.35)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
      }
      .allowsHitTesting(false)
      HStack(spacing: 16) {
        ForEach(Module.allCases) { module in
          HStack {
            if module != .oscillator {
              socket(module, input: true)
            } else {
              Color.clear.frame(width: 64, height: 44)
            }
            Spacer()
            if module != .output {
              socket(module, input: false)
            } else {
              Color.clear.frame(width: 64, height: 44)
            }
          }
          .padding(.horizontal, 22).frame(width: 266)
        }
      }.offset(y: 267)
    }
    .frame(height: 352)
  }

  private func portPosition(_ module: Module, input: Bool) -> CGPoint {
    let index = Module.allCases.firstIndex(of: module) ?? 0
    return CGPoint(x: CGFloat(index) * 282 + (input ? 54 : 212), y: 289)
  }

  private func modulePanel(_ module: Module, index: Int) -> some View {
    VStack(spacing: 0) {
      HStack {
        Text("0\(index + 1) / \(module.short)").font(
          .system(size: 10, weight: .bold, design: .monospaced)
        ).tracking(1)
        Spacer()
        screw
      }
      .padding(.bottom, 8)
      HStack {
        Text(module.title).font(.system(size: 24, weight: .medium, design: .serif))
        Spacer()
        moduleGlyph(module).frame(width: 36, height: 22)
      }
      .padding(.bottom, 12)
      knob(module)
      Text(valueLabel(module))
        .font(.system(size: 20, weight: .medium, design: .monospaced))
        .monospacedDigit().padding(.top, 5)
      parameterSlider(module).padding(.horizontal, 13).padding(.top, 4)
      if module == .oscillator {
        HStack(spacing: 4) {
          ForEach(WaveShape.allCases, id: \.self) { shape in
            Button {
              store.setShape(shape)
            } label: {
              Text(shape.rawValue.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity).frame(height: 26)
                .background(store.patch.shape == shape ? Palette.ink : .clear, in: Capsule())
                .foregroundStyle(store.patch.shape == shape ? .white : Palette.ink)
            }
            .accessibilityLabel("\(shape.rawValue) waveform")
          }
        }.padding(.top, 3)
      } else {
        HStack(spacing: 5) {
          Circle().fill(Palette.ink.opacity(0.45)).frame(width: 4, height: 4)
          Text(
            module == .filter
              ? "TWO-POLE · 12 dB / OCT"
              : module == .envelope ? "PLUCK DECAY · HOLD BYPASS" : "STEREO · SOFT START"
          )
          .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.6)
        }.frame(height: 29)
      }
      Spacer()
    }
    .padding(20)
    .frame(width: 266, height: 319)
    .background {
      RoundedRectangle(cornerRadius: 12).fill(
        LinearGradient(
          colors: [Palette.panel(module).opacity(0.90), Palette.panel(module)],
          startPoint: .topLeading, endPoint: .bottomTrailing))
      RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.55), lineWidth: 1)
    }
    .shadow(color: Palette.ink.opacity(0.12), radius: 4, y: 4)
  }

  private var screw: some View {
    ZStack {
      Circle().fill(Palette.ink.opacity(0.12)).frame(width: 9, height: 9)
      Rectangle().fill(Palette.ink.opacity(0.35)).frame(width: 5, height: 1).rotationEffect(
        .degrees(-35))
    }
  }

  private func moduleGlyph(_ module: Module) -> some View {
    Canvas { context, size in
      var path = Path()
      for i in 0...40 {
        let t = Double(i) / 40
        let y: Double
        switch module {
        case .oscillator: y = 0.5 + sin(t * 2 * .pi) * 0.35
        case .filter: y = 0.15 + pow(t, 3) * 0.75
        case .envelope: y = t < 0.2 ? 0.85 - t * 3.5 : 0.15 + (1 - exp(-(t - 0.2) * 3)) * 0.8
        case .output: y = 0.5 + sin(t * 6 * .pi) * sin(t * .pi) * 0.4
        }
        let point = CGPoint(x: t * size.width, y: y * size.height)
        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
      }
      context.stroke(
        path, with: .color(Palette.ink.opacity(0.7)),
        style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }
  }

  private func knob(_ module: Module) -> some View {
    ZStack {
      ForEach(0..<25) { tick in
        Rectangle().fill(Palette.ink.opacity(tick % 6 == 0 ? 0.65 : 0.24))
          .frame(width: 1.3, height: tick % 6 == 0 ? 6 : 3)
          .offset(y: -47).rotationEffect(.degrees(Double(tick) * 11.25 - 135))
      }
      Circle().fill(.black.opacity(0.12)).frame(width: 73, height: 73).offset(y: 4)
      Circle().fill(
        LinearGradient(
          colors: [Color(white: 0.33), Palette.ink, Color(white: 0.12)], startPoint: .topLeading,
          endPoint: .bottomTrailing)
      )
      .frame(width: 72, height: 72).shadow(color: .black.opacity(0.2), radius: 3, y: 2)
      Circle().stroke(.white.opacity(0.15), lineWidth: 1).frame(width: 66, height: 66)
      Capsule().fill(Color(white: 0.95)).frame(width: 3, height: 16)
        .offset(y: -24).rotationEffect(.degrees(parameterNormalized(module) * 270 - 135))
    }
    .frame(height: 98)
    .accessibilityHidden(true)
  }

  private func valueLabel(_ module: Module) -> String {
    switch module {
    case .oscillator: "\(Int(store.patch.frequency)) Hz"
    case .filter:
      store.patch.cutoff >= 1000
        ? String(format: "%.2f kHz", store.patch.cutoff / 1000) : "\(Int(store.patch.cutoff)) Hz"
    case .envelope: String(format: "%.2f s", store.patch.decay)
    case .output: "\(Int(store.patch.volume * 100)) %"
    }
  }

  private func parameterNormalized(_ module: Module) -> Double {
    switch module {
    case .oscillator: log(store.patch.frequency / 40) / log(25)
    case .filter: log(store.patch.cutoff / 80) / log(150)
    case .envelope: (store.patch.decay - 0.1) / 2.9
    case .output: store.patch.volume / 0.8
    }
  }

  private func parameterSlider(_ module: Module) -> some View {
    Slider(
      value: Binding(
        get: { parameterNormalized(module) },
        set: { value in
          switch module {
          case .oscillator: store.setParameter(\.frequency, 40 * pow(25, value))
          case .filter: store.setParameter(\.cutoff, 80 * pow(150, value))
          case .envelope: store.setParameter(\.decay, 0.1 + value * 2.9)
          case .output: store.setParameter(\.volume, value * 0.8)
          }
        }),
      in: 0...1,
      onEditingChanged: { editing in
        if editing { store.checkpoint() } else { store.finishParameter() }
      }
    )
    .tint(Palette.ink.opacity(0.7))
    .accessibilityLabel(
      module == .oscillator
        ? "Frequency" : module == .filter ? "Cutoff" : module == .envelope ? "Decay" : "Volume"
    )
    .accessibilityValue(valueLabel(module))
    .accessibilityIdentifier("\(module.rawValue)Slider")
    .frame(height: 23)
  }

  private func socket(_ module: Module, input: Bool) -> some View {
    let selected = !input && store.selectedPort == module
    let connected = store.patch.cables.contains {
      input ? $0.destination == module : $0.source == module
    }
    return Button {
      store.port(module, input: input)
    } label: {
      ZStack {
        ZStack {
          Circle().fill(Color(white: 0.84)).frame(width: 29, height: 29)
            .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.5))
          Circle().fill(Palette.ink).frame(width: 21, height: 21)
          Circle().fill(connected ? Palette.cable(module) : Color(white: 0.07)).frame(
            width: 11, height: 11)
          if selected { Circle().stroke(Palette.coral, lineWidth: 3).frame(width: 37, height: 37) }
        }
        Text(input ? "IN" : "OUT").font(.system(size: 8, weight: .heavy, design: .monospaced))
          .offset(x: 28)
      }
      .frame(width: 64, height: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(module.title) \(input ? "input" : "output") socket")
    .accessibilityIdentifier("\(module.rawValue)-\(input ? "in" : "out")")
  }

  private var connectionStrip: some View {
    HStack(spacing: 8) {
      Text("PATCH BAY").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.6)
        .foregroundStyle(Palette.muted).padding(.trailing, 5)
      if store.patch.cables.isEmpty {
        Text("Tap an OUT socket, then an IN.").font(.system(size: 12)).foregroundStyle(
          Palette.muted)
      }
      ForEach(store.patch.cables) { cable in
        Button {
          store.remove(cable)
        } label: {
          HStack(spacing: 6) {
            Circle().fill(Palette.cable(cable.source)).frame(width: 6, height: 6)
            Text("\(cable.source.short) → \(cable.destination.short)")
              .font(.system(size: 9, weight: .bold, design: .monospaced))
            Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
          }
          .padding(.horizontal, 11).frame(height: 32).background(
            .white.opacity(0.65), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(cable.source.title) to \(cable.destination.title) cable")
      }
      Spacer(minLength: 0)
      Button {
        store.undo()
      } label: {
        Label("Undo", systemImage: "arrow.uturn.backward").font(.system(size: 11))
          .frame(height: 36)
      }.disabled(store.undoHistory.isEmpty).padding(.horizontal, 6)
      Button {
        store.load(.blank)
      } label: {
        Label("Clear", systemImage: "minus.circle").font(.system(size: 11))
          .frame(height: 36)
      }
    }.frame(height: 36)
  }

  private var keyboard: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack {
        Text("PLAY A LITTLE").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(
          1.8)
        Text("C3 — C4").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
        Spacer()
        Button {
          store.toggleHold()
        } label: {
          HStack(spacing: 7) {
            Circle().fill(store.hold ? Palette.coral : Palette.muted.opacity(0.4)).frame(
              width: 7, height: 7)
            Text(store.hold ? "HOLD ON" : "HOLD").font(
              .system(size: 9, weight: .bold, design: .monospaced))
          }.padding(.horizontal, 12).frame(height: 28)
            .background(
              store.hold ? Palette.panel(.oscillator) : Color.white.opacity(0.7), in: Capsule())
        }.accessibilityLabel(store.hold ? "Release hold" : "Hold note")
      }
      PianoKeyboard(active: store.activeNote, play: store.note)
    }
    .padding(18)
    .background(Color(red: 0.88, green: 0.89, blue: 0.85), in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.8), lineWidth: 1))
  }

  private var scope: some View {
    VStack(spacing: 10) {
      HStack {
        HStack(spacing: 7) {
          Circle().fill(
            store.telemetry.rms > 0.0001 ? Color(red: 0.78, green: 0.89, blue: 0.50) : .gray
          )
          .frame(width: 5, height: 5)
          Text("LIVE SCOPE").tracking(1.8)
        }
        Spacer()
        Text(
          store.telemetry.rms > 0.00001
            ? String(format: "%.1f dB", 20 * log10(store.telemetry.rms)) : "−∞ dB"
        )
        .monospacedDigit()
      }.font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundStyle(Color(white: 0.75))
      Canvas { context, size in
        var grid = Path()
        for x in stride(from: 0.0, through: size.width, by: size.width / 8) {
          grid.move(to: CGPoint(x: x, y: 0))
          grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: 0.0, through: size.height, by: size.height / 4) {
          grid.move(to: CGPoint(x: 0, y: y))
          grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(grid, with: .color(.white.opacity(0.065)), lineWidth: 0.5)
        let samples = store.telemetry.samples
        var wave = Path()
        for index in samples.indices {
          let point = CGPoint(
            x: Double(index) / Double(max(1, samples.count - 1)) * size.width,
            y: size.height / 2 - Double(samples[index]) / scopePeak * size.height * 0.43)
          if index == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
        }
        let color = Color(red: 0.82, green: 0.93, blue: 0.57)
        context.stroke(wave, with: .color(color.opacity(0.1)), lineWidth: 7)
        context.stroke(wave, with: .color(color), lineWidth: 1.5)
      }
      .clipped()
      .accessibilityLabel("Live waveform, RMS \(store.telemetry.rms)")
      HStack {
        Text(String(format: "POST OUT / AUTO ±%.2f FS", scopePeak))
        Spacer()
        Text("\(store.telemetry.frames / 1000)k frames").monospacedDigit()
      }.font(.system(size: 8, design: .monospaced)).foregroundStyle(.white.opacity(0.45))
    }
    .padding(17)
    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 14))
  }

  private var scopePeak: Double {
    max(0.1, store.telemetry.samples.reduce(0) { max($0, Double(abs($1))) })
  }

  private var footer: some View {
    HStack(spacing: 7) {
      Image(systemName: store.isError ? "exclamationmark.circle" : "smallcircle.filled.circle")
        .foregroundStyle(store.isError ? Palette.coral : Palette.muted)
      Text(store.notice).lineLimit(2)
        .foregroundStyle(store.isError ? Palette.coral : Palette.muted)
        .accessibilityIdentifier("patchNotice")
      Spacer(minLength: 4)
      Text(store.engineReady ? "ENGINE ON  /  V1.0" : "ENGINE PAUSED  /  V1.0")
        .font(.system(size: 8, design: .monospaced)).tracking(1)
    }
    .font(.system(size: 11))
    .frame(height: 26)
  }

  private var library: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("Find your next happy accident.")
            .font(.system(size: 31, weight: .medium, design: .serif)).padding(.top, 8)
          Text("FOUR STARTING POINTS").font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(2)
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(Array(Patch.presets.enumerated()), id: \.offset) { index, patch in
              patchTile(patch, color: Palette.panel(Module.allCases[index]))
            }
          }
          Text("YOUR PATCHES").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(
            2)
          if store.saved.isEmpty {
            Text("Your collection starts here. Save a circuit and it will be waiting for you.")
              .font(.system(size: 15)).foregroundStyle(Palette.muted).padding(.bottom, 20)
          } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
              ForEach(store.saved) { patch in patchTile(patch, color: Color.white) }
            }
          }
        }.padding(28)
      }
      .background(Palette.paper)
      .navigationTitle("Patch library").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { showLibrary = false } }
      }
    }
    .tint(Palette.ink)
  }

  private func patchTile(_ patch: Patch, color: Color) -> some View {
    Button {
      store.load(patch)
      showLibrary = false
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text(patch.shape.rawValue.uppercased()).tracking(1.5)
          Spacer()
          Image(systemName: "arrow.up.right")
        }.font(.system(size: 10, weight: .bold, design: .monospaced))
        Text(patch.name).font(.system(size: 23, weight: .medium, design: .serif))
        Text(patch.subtitle).font(.system(size: 12)).frame(height: 32, alignment: .topLeading)
        Text(
          patch.cables.isEmpty
            ? "NO CABLES · YOUR RULES" : "\(patch.cables.count) CABLES · \(Int(patch.frequency)) Hz"
        )
        .font(.system(size: 9, weight: .medium, design: .monospaced)).opacity(0.65)
      }
      .foregroundStyle(Palette.ink)
      .padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(color, in: RoundedRectangle(cornerRadius: 15))
    }.buttonStyle(.plain)
  }

  private var saveSheet: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 20) {
        Text("Give this circuit a home.").font(.system(size: 31, weight: .medium, design: .serif))
        Text(
          "Save the cables, tuning and character. Your last working circuit also saves automatically."
        )
        .foregroundStyle(Palette.muted)
        TextField("Patch name", text: $patchName)
          .textFieldStyle(.roundedBorder).accessibilityIdentifier("patchName")
        Text("Use 1–40 characters. An existing name updates that saved patch.")
          .font(.system(size: 12)).foregroundStyle(Palette.muted)
        if store.isError {
          Text(store.notice).font(.system(size: 12)).foregroundStyle(Palette.coral)
        }
        Button {
          if store.save(name: patchName) { showSave = false }
        } label: {
          Text("Save to library").fontWeight(.semibold).frame(maxWidth: .infinity).padding()
            .foregroundStyle(.white).background(Palette.ink, in: RoundedRectangle(cornerRadius: 12))
        }
        Spacer()
      }.padding(30).background(Palette.paper)
        .navigationTitle("Save patch").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showSave = false } }
        }
    }.tint(Palette.ink).presentationDetents([.medium, .large])
  }

  private var guide: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 22) {
        Text("Follow the sound.").font(.system(size: 36, weight: .medium, design: .serif))
        ForEach(
          [
            (
              "01", "Make a connection",
              "Tap an OUT socket, then an IN. Try OSC → VCF → OUT. One cable per input; feedback loops are blocked."
            ),
            (
              "02", "Give it a voice",
              "Tap the keys for notes. Turn on Hold for a continuous tone, then slide frequency or cutoff. The knobs follow your sliders."
            ),
            (
              "03", "Shape the moment",
              "Route through the Envelope for a decaying pluck. Hold bypasses decay. The scope shows actual samples from the audio callback."
            ),
            (
              "04", "Keep the good accidents",
              "Remove cables in the patch bay. Undo recovers your last edit. Save a named patch or export a three-second held WAV."
            ),
          ], id: \.0
        ) { item in
          HStack(alignment: .top, spacing: 18) {
            Text(item.0).font(.system(size: 12, weight: .bold, design: .monospaced))
              .foregroundStyle(Palette.coral)
            VStack(alignment: .leading, spacing: 6) {
              Text(item.1).font(.system(size: 19, weight: .semibold))
              Text(item.2).font(.system(size: 14)).foregroundStyle(Palette.muted)
            }
          }
        }
        Spacer()
      }.padding(32).background(Palette.paper)
        .navigationTitle("A small field guide").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) { Button("Done") { showGuide = false } }
        }
    }.tint(Palette.ink)
  }
}

private struct PianoKeyboard: View {
  let active: String
  let play: (String, Double) -> Void
  private let white = [
    ("C", 48), ("D", 50), ("E", 52), ("F", 53), ("G", 55), ("A", 57), ("B", 59), ("C↑", 60),
  ]
  private let black = [("C♯", 49, 0), ("D♯", 51, 1), ("F♯", 54, 3), ("G♯", 56, 4), ("A♯", 58, 5)]

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width / 8
      ZStack(alignment: .topLeading) {
        HStack(spacing: 4) {
          ForEach(white, id: \.1) { note in
            Button {
              play(note.0, frequency(note.1))
            } label: {
              VStack {
                Spacer()
                Text(note.0).font(.system(size: 10, weight: .medium, design: .monospaced))
                  .foregroundStyle(Palette.muted).padding(.bottom, 10)
              }
              .frame(maxWidth: .infinity).frame(height: 98)
              .background(
                active == note.0
                  ? Palette.panel(.oscillator) : Color(red: 0.99, green: 0.98, blue: 0.95),
                in: UnevenRoundedRectangle(bottomLeadingRadius: 7, bottomTrailingRadius: 7)
              )
              .shadow(color: .black.opacity(0.10), radius: 0, y: 3)
            }.buttonStyle(.plain).accessibilityLabel("Play \(note.0)")
          }
        }
        ForEach(black, id: \.1) { note in
          Button {
            play(note.0, frequency(note.1))
          } label: {
            RoundedRectangle(cornerRadius: 5)
              .fill(active == note.0 ? Palette.coral : Palette.ink)
              .frame(width: 37, height: 59)
              .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.05)).frame(
                  width: 28, height: 8
                ).padding(.bottom, 5)
              }
              .shadow(color: .black.opacity(0.2), radius: 2, y: 3)
          }
          .buttonStyle(.plain).offset(x: CGFloat(note.2 + 1) * width - 20)
          .accessibilityLabel("Play \(note.0)")
        }
      }
    }.frame(height: 101)
  }

  private func frequency(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }
}

private struct ShareSheet: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
