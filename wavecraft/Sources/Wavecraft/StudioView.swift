import AppKit
import SwiftUI
import WavecraftCore

enum Palette {
  static let background = Color(red: 0.075, green: 0.082, blue: 0.087)
  static let panel = Color(red: 0.10, green: 0.11, blue: 0.115)
  static let raised = Color(red: 0.145, green: 0.155, blue: 0.16)
  static let line = Color.white.opacity(0.09)
  static let text = Color(red: 0.92, green: 0.91, blue: 0.87)
  static let muted = Color(red: 0.56, green: 0.59, blue: 0.59)
  static let mint = Color(red: 0.53, green: 0.89, blue: 0.74)
  static let coral = Color(red: 0.96, green: 0.55, blue: 0.43)
}

struct StudioView: View {
  @ObservedObject var model: StudioModel
  @State private var startText = "0.000"
  @State private var endText = "0.000"
  private let clock = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: 0) {
      topbar
      Rectangle().fill(Palette.line).frame(height: 1)
      HStack(spacing: 0) {
        library.frame(width: 202)
        Rectangle().fill(Palette.line).frame(width: 1)
        workspace.frame(maxWidth: .infinity, maxHeight: .infinity)
        Rectangle().fill(Palette.line).frame(width: 1)
        inspector.frame(width: 234)
      }
      footer
    }
    .background(Palette.background)
    .foregroundStyle(Palette.text)
    .buttonStyle(.plain)
    .onReceive(clock) { _ in model.tick() }
    .onAppear { syncFields() }
    .onChange(of: model.start) { syncFields() }
    .onChange(of: model.end) { syncFields() }
    .alert(
      "Let's fix that",
      isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })
    ) {
      Button("OK") { model.error = nil }
    } message: {
      Text(model.error ?? "")
    }
  }

  private func syncFields() {
    startText = String(format: "%.3f", model.start)
    endText = String(format: "%.3f", model.end)
  }

  private var topbar: some View {
    HStack(spacing: 12) {
      HStack(alignment: .center, spacing: 3) {
        ForEach(0..<7) { i in
          Capsule().fill(Palette.mint).frame(
            width: 3, height: CGFloat([9, 19, 27, 15, 32, 22, 10][i]))
        }
      }.frame(width: 36)
      Text("wavecraft").font(.system(size: 22, weight: .semibold, design: .rounded)).tracking(-0.7)
      Rectangle().fill(Palette.line).frame(width: 1, height: 24).padding(.horizontal, 12)
      Text("A SMALL STUDIO FOR SOUND").font(.system(size: 9, weight: .medium)).tracking(2.3)
        .foregroundStyle(Palette.muted)
      Spacer()
      tool("Open audio", icon: "arrow.down.doc", action: model.importAudio)
      Button(action: model.exportAudio) {
        HStack(spacing: 9) {
          Text("Export WAV").font(.system(size: 12, weight: .semibold))
          Image(systemName: "arrow.up.right")
        }
        .foregroundStyle(Palette.background).padding(.horizontal, 18).frame(height: 36)
        .background(Palette.mint, in: RoundedRectangle(cornerRadius: 6))
      }.accessibilityIdentifier("exportWAV")
    }
    .padding(.leading, 24).padding(.trailing, 22).padding(.top, 25).padding(.bottom, 18)
    .background(Palette.panel)
  }

  private var library: some View {
    VStack(alignment: .leading, spacing: 0) {
      eyebrow("SOUND LIBRARY")
      HStack(alignment: .firstTextBaseline) {
        Text("Start with a spark.").font(.system(size: 16, weight: .medium))
        Spacer()
      }.padding(.top, 11).padding(.bottom, 24)
      ForEach(SampleKind.allCases, id: \.self) { kind in
        Button {
          model.loadSample(kind)
        } label: {
          VStack(alignment: .leading, spacing: 11) {
            HStack {
              Text(kind.number).font(.system(size: 10, design: .monospaced)).foregroundStyle(
                Palette.muted)
              Spacer()
              Image(systemName: "arrow.up.right").font(.system(size: 10))
            }
            MiniWave(kind: kind).frame(height: 34)
            Text(kind.rawValue).font(.system(size: 13, weight: .semibold))
            Text(kind.subtitle).font(.system(size: 9)).foregroundStyle(Palette.muted).lineLimit(1)
          }
          .padding(13)
          .background(
            model.audio.name == kind.rawValue ? Palette.raised : Palette.panel,
            in: RoundedRectangle(cornerRadius: 8)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(
              model.audio.name == kind.rawValue ? Palette.mint.opacity(0.45) : Palette.line,
              lineWidth: 1))
        }
        .accessibilityLabel("Load " + kind.rawValue)
        .padding(.bottom, 12)
      }
      Spacer(minLength: 16)
      Rectangle().fill(Palette.line).frame(height: 1)
      Text("MADE TO BE MADE YOURS").font(.system(size: 8, weight: .medium)).tracking(1.4)
        .foregroundStyle(Palette.muted).padding(.top, 18)
      Text("Three original sounds.\nInfinite small discoveries.")
        .font(.system(size: 11)).lineSpacing(4).foregroundStyle(Palette.muted).padding(.top, 9)
    }.padding(18).background(Palette.panel)
  }

  private var workspace: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          eyebrow("THE WORKBENCH")
          Text(model.audio.name).font(.system(size: 28, weight: .medium)).tracking(-0.8)
            .lineLimit(1).truncationMode(.middle)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 7) {
          Text("LOCAL SESSION").font(.system(size: 8, weight: .medium)).tracking(1.5)
            .foregroundStyle(Palette.muted)
          HStack(spacing: 5) {
            Circle().fill(Palette.mint).frame(width: 5, height: 5)
            Text("Autosaved").font(.system(size: 10)).foregroundStyle(Palette.mint)
          }
        }.padding(.top, 4)
      }.padding(.bottom, 24)
      HStack(spacing: 8) {
        Button {
          model.seek(0)
        } label: {
          Image(systemName: "backward.end.fill").frame(width: 30, height: 34)
        }.accessibilityLabel("Return to start")
        Button {
          model.togglePlayback()
        } label: {
          Image(systemName: model.playing ? "stop.fill" : "play.fill")
            .font(.system(size: 13)).foregroundStyle(Palette.background)
            .frame(width: 44, height: 36).background(
              Palette.mint, in: RoundedRectangle(cornerRadius: 6))
        }.accessibilityLabel(model.playing ? "Stop playback" : "Play audio")
        Text(time(model.playhead)).font(.system(size: 18, weight: .medium, design: .monospaced))
          .padding(.leading, 8)
        Text("/ " + time(model.audio.duration)).font(.system(size: 10, design: .monospaced))
          .foregroundStyle(Palette.muted)
        Spacer(minLength: 4)
        Button {
          model.zoom = max(1, model.zoom / 2)
        } label: {
          Image(systemName: "minus.magnifyingglass").frame(width: 27, height: 34)
        }.disabled(model.zoom == 1).accessibilityLabel("Zoom out")
        Text("\(Int(model.zoom))×").font(.system(size: 10, design: .monospaced)).foregroundStyle(
          Palette.muted)
        Button {
          model.zoom = min(8, model.zoom * 2)
        } label: {
          Image(systemName: "plus.magnifyingglass").frame(width: 27, height: 34)
        }.disabled(model.zoom == 8).accessibilityLabel("Zoom in")
      }.padding(.bottom, 17)
      waveform
      HStack {
        HStack(spacing: 5) {
          Image(systemName: "cursorarrow.motionlines")
          Text("Drag to select · click to seek")
        }
        Spacer()
        Text(
          "\(model.audio.channels.count == 2 ? "STEREO" : "MONO")  /  \(Int(model.audio.sampleRate)) Hz"
        )
        .font(.system(size: 9, design: .monospaced))
      }
      .font(.system(size: 10)).foregroundStyle(Palette.muted).padding(.top, 11).padding(.bottom, 22)
      selectionBar
      Spacer(minLength: 16)
      HStack {
        eyebrow("RECENT MOVES")
        Spacer()
        tool(
          "Undo", icon: "arrow.uturn.backward", enabled: !model.undoStack.isEmpty,
          action: model.undo)
        tool(
          "Redo", icon: "arrow.uturn.forward", enabled: !model.redoStack.isEmpty, action: model.redo
        )
      }
      HStack(spacing: 8) {
        Circle().fill(Palette.mint.opacity(0.8)).frame(width: 5, height: 5)
        Text(model.history.last ?? "Session opened").font(.system(size: 11))
        Spacer()
        Text("\(model.undoStack.count) / 20 steps").font(.system(size: 9, design: .monospaced))
          .foregroundStyle(Palette.muted)
      }
      .padding(13).background(Palette.panel, in: RoundedRectangle(cornerRadius: 6)).padding(
        .top, 10)
    }.padding(26)
  }

  private var waveform: some View {
    GeometryReader { geometry in
      ScrollView(.horizontal) {
        WaveformView(
          bins: model.bins, duration: model.audio.duration,
          start: model.start, end: model.end, playhead: model.playhead,
          onSelect: { a, b, done in model.select(a, b, save: done) },
          onSeek: model.seek
        )
        .frame(width: max(1, geometry.size.width) * model.zoom, height: geometry.size.height - 10)
      }
      .scrollIndicators(model.zoom > 1 ? .visible : .hidden)
    }
    .frame(minHeight: 220, idealHeight: 300, maxHeight: 350)
    .background(Color(red: 0.062, green: 0.07, blue: 0.073), in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line, lineWidth: 1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private var selectionBar: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        eyebrow("SELECTION")
        Spacer()
        Button("Select all", action: model.selectAll).font(.system(size: 10))
          .foregroundStyle(Palette.mint).accessibilityIdentifier("selectAll")
        Text(" / ").foregroundStyle(Palette.muted)
        Button("Clear") { model.select(0, 0) }.font(.system(size: 10)).foregroundStyle(
          Palette.muted)
      }
      HStack(spacing: 14) {
        timeField("IN", value: $startText)
        Text("—").foregroundStyle(Palette.muted)
        timeField("OUT", value: $endText)
        Button {
          model.setSelection(startText: startText, endText: endText)
        } label: {
          Image(systemName: "checkmark").frame(width: 28, height: 32)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: 4))
        }.accessibilityLabel("Apply precise selection")
        Spacer(minLength: 0)
        VStack(alignment: .trailing, spacing: 6) {
          Text("LENGTH").font(.system(size: 8, weight: .medium)).tracking(1.3).foregroundStyle(
            Palette.muted)
          Text(String(format: "%.3f s", model.selectionDuration))
            .font(.system(size: 14, design: .monospaced)).foregroundStyle(Palette.mint)
        }
      }
    }.padding(16).background(Palette.panel, in: RoundedRectangle(cornerRadius: 8))
  }

  private func timeField(_ label: String, value: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.system(size: 8, weight: .medium)).tracking(1.3).foregroundStyle(
        Palette.muted)
      TextField(label, text: value).textFieldStyle(.plain)
        .font(.system(size: 13, design: .monospaced)).frame(width: 68)
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(Palette.background, in: RoundedRectangle(cornerRadius: 3))
        .accessibilityLabel(label == "IN" ? "Selection start seconds" : "Selection end seconds")
        .onSubmit { model.setSelection(startText: startText, endText: endText) }
    }
  }

  private var inspector: some View {
    VStack(alignment: .leading, spacing: 0) {
      eyebrow("SHAPE YOUR SOUND")
      Text("Small moves.\nBig difference.").font(.system(size: 20, weight: .medium)).tracking(-0.3)
        .lineSpacing(2).padding(.top, 12).padding(.bottom, 22)
      action(
        "Audition range", subtitle: "Listen to the selection", icon: "headphones",
        enabled: model.hasSelection
      ) { model.togglePlayback(selection: true) }
      action(
        "Trim to selection", subtitle: "Keep only what matters", icon: "crop",
        enabled: model.hasSelection, action: model.trim)
      Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 18)
      eyebrow("ENVELOPE")
      HStack(spacing: 8) {
        effect("Fade in", icon: "line.diagonal", action: model.fadeIn)
        effect("Fade out", icon: "line.diagonal", mirrored: true, action: model.fadeOut)
      }.padding(.top, 13)
      Text("Linear fades across the selected range.")
        .font(.system(size: 10)).foregroundStyle(Palette.muted).lineSpacing(3).padding(.top, 11)
      Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 18)
      HStack {
        eyebrow("GAIN")
        Spacer()
        Text(String(format: "%+.1f dB", model.gainDB))
          .font(.system(size: 13, design: .monospaced)).foregroundStyle(Palette.coral)
      }
      Slider(value: $model.gainDB, in: -24...24, step: 0.5).tint(Palette.coral)
        .accessibilityLabel("Gain decibels").padding(.top, 10)
      HStack {
        Text("−24 dB")
        Spacer()
        Text("+24 dB")
      }.font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
      Button(action: model.applyGain) {
        Text("Apply gain").font(.system(size: 11, weight: .medium)).frame(maxWidth: .infinity)
          .frame(height: 33).background(Palette.raised, in: RoundedRectangle(cornerRadius: 5))
      }.disabled(!model.hasSelection).opacity(model.hasSelection ? 1 : 0.4).padding(.top, 12)
      Spacer(minLength: 16)
      analysis
    }.padding(20).background(Palette.panel)
  }

  private var analysis: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Circle().fill(model.clipped > 0 ? Palette.coral : Palette.mint).frame(width: 6, height: 6)
        Text(model.clipped > 0 ? "CLIPPING DETECTED" : "HEALTHY HEADROOM")
          .font(.system(size: 8, weight: .semibold)).tracking(1)
          .foregroundStyle(model.clipped > 0 ? Palette.coral : Palette.mint)
      }
      GeometryReader { geo in
        HStack(spacing: 2) {
          ForEach(0..<24) { i in
            RoundedRectangle(cornerRadius: 1)
              .fill(
                Double(i) / 24 < Double(model.peak)
                  ? (i > 20 ? Palette.coral : Palette.mint) : Palette.line
              )
              .frame(width: max(1, (geo.size.width - 46) / 24))
          }
        }
      }.frame(height: 13)
      HStack {
        metric("PEAK", value: db(Double(model.peak)))
        Spacer()
        metric("RMS", value: db(model.rms))
      }
      if model.clipped > 0 {
        Text("\(model.clipped) samples over 0 dBFS.\nUndo or reduce gain before export.")
          .font(.system(size: 9)).foregroundStyle(Palette.coral).lineSpacing(3)
      } else {
        Text("Measured from the edited samples.")
          .font(.system(size: 9)).foregroundStyle(Palette.muted)
      }
    }.padding(13).background(Palette.background, in: RoundedRectangle(cornerRadius: 7))
  }

  private var footer: some View {
    HStack(spacing: 8) {
      Image(systemName: "waveform").foregroundStyle(Palette.mint)
      Text(model.notice).lineLimit(1)
      Spacer()
      if let url = model.lastExport {
        Button("Reveal export") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
          .foregroundStyle(Palette.mint)
      }
      Text("16-BIT WAV EXPORT").font(.system(size: 8, design: .monospaced)).tracking(1.2)
        .foregroundStyle(Palette.muted)
    }.font(.system(size: 10)).padding(.horizontal, 24).frame(height: 36)
      .background(Palette.raised.opacity(0.5))
  }

  private func action(
    _ title: String, subtitle: String, icon: String, enabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Palette.mint).frame(
          width: 21)
        VStack(alignment: .leading, spacing: 5) {
          Text(title).font(.system(size: 12, weight: .medium))
          Text(subtitle).font(.system(size: 9)).foregroundStyle(Palette.muted)
        }
        Spacer(minLength: 0)
      }.padding(.vertical, 10)
    }.disabled(!enabled).opacity(enabled ? 1 : 0.4).accessibilityLabel(title)
  }

  private func effect(
    _ title: String, icon: String, mirrored: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 9) {
        Image(systemName: icon).font(.system(size: 21)).scaleEffect(x: mirrored ? -1 : 1, y: 1)
          .foregroundStyle(Palette.mint)
        Text(title).font(.system(size: 10, weight: .medium))
      }.frame(maxWidth: .infinity).frame(height: 65)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 6))
    }.disabled(!model.hasSelection).opacity(model.hasSelection ? 1 : 0.4)
  }

  private func tool(
    _ title: String, icon: String, enabled: Bool = true,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(title, systemImage: icon).font(.system(size: 11)).padding(.horizontal, 9).frame(
        height: 32)
    }.disabled(!enabled).opacity(enabled ? 1 : 0.35)
  }

  private func metric(_ title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.system(size: 8)).tracking(1).foregroundStyle(Palette.muted)
      Text(value).font(.system(size: 12, design: .monospaced))
    }
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text).font(.system(size: 8, weight: .semibold)).tracking(1.8).foregroundStyle(
      Palette.muted)
  }

  private func time(_ value: Double) -> String {
    let milliseconds = Int(value * 1000)
    return String(
      format: "%02d:%02d.%03d", milliseconds / 60000, milliseconds / 1000 % 60, milliseconds % 1000)
  }

  private func db(_ value: Double) -> String {
    value > 0 ? String(format: "%.1f dB", 20 * log10(value)) : "−∞ dB"
  }
}

struct MiniWave: View {
  let kind: SampleKind
  var body: some View {
    Canvas { context, size in
      var path = Path()
      for index in 0..<48 {
        let x = Double(index) / 47
        let envelope: Double
        switch kind {
        case .tide: envelope = 0.2 + 0.8 * exp(-x.truncatingRemainder(dividingBy: 0.25) * 16)
        case .glass: envelope = exp(-x * 3)
        case .orbit: envelope = sin(x * .pi) * (0.55 + abs(sin(x * 22)) * 0.45)
        }
        let height = (0.18 + abs(sin(Double(index) * 2.7)) * 0.82) * envelope * size.height
        path.move(to: CGPoint(x: x * size.width, y: (size.height - height) / 2))
        path.addLine(to: CGPoint(x: x * size.width, y: (size.height + height) / 2))
      }
      context.stroke(
        path, with: .color(kind == .glass ? Palette.coral : Palette.mint.opacity(0.85)),
        lineWidth: 1.5)
    }.accessibilityHidden(true)
  }
}

struct WaveformView: View {
  let bins: [[PeakBin]]
  let duration: Double
  let start: Double
  let end: Double
  let playhead: Double
  let onSelect: (Double, Double, Bool) -> Void
  let onSeek: (Double) -> Void

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        Canvas { context, size in
          let ruler = 32.0
          let trackHeight = (size.height - ruler) / Double(max(1, bins.count))
          let divisions = max(4, Int(size.width / 90))
          for i in 0...divisions {
            let x = Double(i) / Double(divisions) * size.width
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(Palette.line), lineWidth: 0.5)
            if i < divisions {
              context.draw(
                Text(String(format: "%.2f", Double(i) / Double(divisions) * duration))
                  .font(.system(size: 9, design: .monospaced)).foregroundColor(Palette.muted),
                at: CGPoint(x: x + 9, y: 15), anchor: .leading)
            }
            for j in 1..<4 {
              let minor = x + Double(j) / 4 * size.width / Double(divisions)
              var tick = Path()
              tick.move(to: CGPoint(x: minor, y: ruler - 5))
              tick.addLine(to: CGPoint(x: minor, y: ruler))
              context.stroke(tick, with: .color(Palette.muted.opacity(0.35)), lineWidth: 0.5)
            }
          }
          for (channel, values) in bins.enumerated() {
            let center = ruler + trackHeight * (Double(channel) + 0.5)
            let amplitude = trackHeight * 0.40
            var centerLine = Path()
            centerLine.move(to: CGPoint(x: 0, y: center))
            centerLine.addLine(to: CGPoint(x: size.width, y: center))
            context.stroke(centerLine, with: .color(Palette.muted.opacity(0.3)), lineWidth: 0.5)
            var wave = Path()
            for (i, bin) in values.enumerated() {
              let point = CGPoint(
                x: Double(i) / Double(max(1, values.count - 1)) * size.width,
                y: center - Double(min(1, max(-1, bin.high))) * amplitude)
              if i == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
            }
            for (i, bin) in values.enumerated().reversed() {
              wave.addLine(
                to: CGPoint(
                  x: Double(i) / Double(max(1, values.count - 1)) * size.width,
                  y: center - Double(min(1, max(-1, bin.low))) * amplitude))
            }
            wave.closeSubpath()
            let color = channel == 0 ? Palette.mint : Palette.coral
            context.fill(
              wave,
              with: .linearGradient(
                Gradient(colors: [color, color.opacity(0.5)]),
                startPoint: CGPoint(x: 0, y: center - amplitude),
                endPoint: CGPoint(x: 0, y: center + amplitude)))
            context.draw(
              Text(channel == 0 ? "L" : "R").font(.system(size: 8, weight: .semibold))
                .foregroundColor(Palette.muted),
              at: CGPoint(x: 12, y: ruler + trackHeight * Double(channel) + 12))
          }
        }
        if end > start {
          let x = start / duration * geometry.size.width
          let width = (end - start) / duration * geometry.size.width
          Rectangle().fill(Palette.mint.opacity(0.075))
            .frame(width: max(1, width), height: geometry.size.height).offset(x: x)
          Rectangle().fill(Palette.mint).frame(width: 1).offset(x: x)
          Rectangle().fill(Palette.mint).frame(width: 1).offset(x: x + width - 1)
          RoundedRectangle(cornerRadius: 2).fill(Palette.mint).frame(width: 5, height: 14).offset(
            x: x)
          RoundedRectangle(cornerRadius: 2).fill(Palette.mint).frame(width: 5, height: 14).offset(
            x: x + width - 5)
        }
        Rectangle().fill(Palette.text.opacity(0.9)).frame(width: 1)
          .offset(x: min(geometry.size.width - 1, playhead / duration * geometry.size.width))
        Path { path in
          let x = min(geometry.size.width - 1, playhead / duration * geometry.size.width)
          path.move(to: CGPoint(x: x - 5, y: 0))
          path.addLine(to: CGPoint(x: x + 5, y: 0))
          path.addLine(to: CGPoint(x: x, y: 7))
          path.closeSubpath()
        }.fill(Palette.text)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { drag in
            if abs(drag.translation.width) > 3 {
              onSelect(
                drag.startLocation.x / geometry.size.width * duration,
                drag.location.x / geometry.size.width * duration, false)
            }
          }
          .onEnded { drag in
            if abs(drag.translation.width) > 3 {
              onSelect(
                drag.startLocation.x / geometry.size.width * duration,
                drag.location.x / geometry.size.width * duration, true)
            } else {
              onSeek(drag.location.x / geometry.size.width * duration)
            }
          }
      )
      .accessibilityLabel("Audio waveform. Drag horizontally to select; click to seek.")
      .accessibilityIdentifier("audioWaveform")
    }
  }
}
