import SwiftUI
import UIKit

private enum Panel {
  static let background = Color(red: 0.075, green: 0.082, blue: 0.09)
  static let surface = Color(red: 0.115, green: 0.125, blue: 0.135)
  static let ivory = Color(red: 0.94, green: 0.92, blue: 0.85)
  static let muted = Color(red: 0.59, green: 0.62, blue: 0.63)
  static let orange = Color(red: 1, green: 0.37, blue: 0.16)
}

extension Drum {
  var color: Color {
    switch self {
    case .kick: Color(red: 0.59, green: 0.86, blue: 0.73)
    case .snare: Color(red: 0.94, green: 0.64, blue: 0.68)
    case .hat: Color(red: 0.58, green: 0.76, blue: 0.96)
    case .clap: Color(red: 0.88, green: 0.77, blue: 0.54)
    }
  }
}

struct InstrumentView: View {
  @StateObject private var model = InstrumentModel()
  @Environment(\.scenePhase) private var scenePhase
  @State private var library = false
  @State private var mixer = false
  @State private var help = false
  @State private var clearConfirmation = false

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 19) {
          header
          display
          transport
          sequencer
          pads
          footer
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .frame(minHeight: geometry.size.height, alignment: .top)
      }
      .scrollIndicators(.hidden)
    }
    .background(Panel.background)
    .foregroundStyle(Panel.ivory)
    .preferredColorScheme(.dark)
    .sheet(isPresented: $library) { LibraryView(model: model) }
    .sheet(isPresented: $mixer) { mixerSheet }
    .sheet(isPresented: $help) { helpSheet }
    .sheet(
      isPresented: Binding(
        get: { model.exportURL != nil },
        set: { if !$0 { model.exportURL = nil } }
      )
    ) {
      if let url = model.exportURL { ShareSheet(url: url).presentationDetents([.medium, .large]) }
    }
    .alert(
      "Instrument notice",
      isPresented: Binding(
        get: { model.error != nil }, set: { if !$0 { model.error = nil } }
      )
    ) {
      Button("OK") { model.error = nil }
    } message: {
      Text(model.error ?? "")
    }
    .confirmationDialog("Clear all 16 steps on every track?", isPresented: $clearConfirmation) {
      Button("Clear pattern", role: .destructive) { model.clear() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Your saved patterns stay in the library. Undo restores this pattern.")
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { model.stop() }
    }
  }

  private var header: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 4) {
        Text("groovebox").font(.system(size: 31, weight: .heavy, design: .rounded))
          .tracking(-1.3)
        label("GB—01   /   POCKET RHYTHM", size: 9)
      }
      Spacer()
      Button {
        help = true
      } label: {
        Image(systemName: "waveform.path")
          .font(.system(size: 23, weight: .medium))
          .foregroundStyle(Panel.orange)
          .frame(width: 48, height: 48)
          .background(Panel.surface, in: RoundedRectangle(cornerRadius: 15))
          .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.08)))
      }.accessibilityLabel("Instrument guide")
    }
  }

  private var display: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        HStack(spacing: 6) {
          Circle().fill(model.playing ? Drum.kick.color : Panel.muted).frame(width: 5, height: 5)
          label(model.playing ? "LIVE SEQUENCE" : "PATTERN / 01", size: 9)
        }
        Spacer()
        label("16 STEPS · 4 VOICES", size: 9)
      }
      HStack(alignment: .firstTextBaseline) {
        Text(model.pattern.name)
          .font(.system(size: 21, weight: .medium, design: .rounded))
          .lineLimit(1).minimumScaleFactor(0.7)
        Spacer(minLength: 8)
        Text(String(format: "%02d", max(1, model.activeStep + 1)))
          .font(.system(size: 28, weight: .light, design: .monospaced))
          .foregroundStyle(Drum.kick.color)
          .contentTransition(.numericText())
      }
      HStack(spacing: 5) {
        ForEach(0..<16) { step in
          RoundedRectangle(cornerRadius: 2)
            .fill(model.activeStep == step ? Panel.orange : ledColor(step))
            .frame(height: 5)
            .shadow(color: model.activeStep == step ? Panel.orange.opacity(0.6) : .clear, radius: 5)
        }
      }.accessibilityLabel("Playback position").accessibilityValue("\(model.activeStep + 1) of 16")
    }
    .padding(17)
    .background(Color.black.opacity(0.33), in: RoundedRectangle(cornerRadius: 15))
    .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.09)))
  }

  private var transport: some View {
    HStack(spacing: 11) {
      Button {
        model.togglePlayback()
      } label: {
        HStack(spacing: 10) {
          Image(systemName: model.playing ? "stop.fill" : "play.fill").font(.system(size: 15))
          Text(model.playing ? "STOP" : "PLAY").font(
            .system(size: 12, weight: .heavy, design: .monospaced))
        }
        .foregroundStyle(Color.black.opacity(0.85))
        .frame(maxWidth: .infinity).frame(height: 57)
        .background(Panel.orange.gradient, in: RoundedRectangle(cornerRadius: 12))
      }.accessibilityLabel(model.playing ? "Stop playback" : "Play pattern")
        .accessibilityIdentifier("transport")
      HStack(spacing: 0) {
        Button {
          model.edit { $0.bpm = max(50, $0.bpm - 1) }
        } label: {
          Image(systemName: "minus").frame(width: 44, height: 57)
            .contentShape(Rectangle())
        }.accessibilityLabel("Decrease tempo")
        VStack(spacing: 2) {
          Text("\(Int(model.pattern.bpm))")
            .font(.system(size: 25, weight: .medium, design: .monospaced))
            .contentTransition(.numericText())
          label("BPM", size: 8)
        }.frame(width: 52)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Tempo").accessibilityValue(
            "\(Int(model.pattern.bpm)) beats per minute")
        Button {
          model.edit { $0.bpm = min(200, $0.bpm + 1) }
        } label: {
          Image(systemName: "plus").frame(width: 44, height: 57)
            .contentShape(Rectangle())
        }.accessibilityLabel("Increase tempo")
      }
      .background(Panel.surface, in: RoundedRectangle(cornerRadius: 12))
      Button {
        mixer = true
      } label: {
        Image(systemName: "slider.horizontal.3")
          .font(.system(size: 18)).frame(width: 48, height: 57)
          .background(Panel.surface, in: RoundedRectangle(cornerRadius: 12))
      }.accessibilityLabel("Mix and swing")
    }
    .buttonStyle(TactileButton())
  }

  private var sequencer: some View {
    VStack(spacing: 12) {
      HStack {
        label("01 / STEP SEQUENCER", size: 9)
        Spacer()
        Button {
          clearConfirmation = true
        } label: {
          Text("CLEAR").font(.system(size: 9, weight: .semibold, design: .monospaced))
            .foregroundStyle(Panel.muted).frame(minWidth: 44, minHeight: 25)
        }.accessibilityLabel("Clear pattern")
      }
      HStack(spacing: 7) {
        ForEach(Drum.allCases, id: \.rawValue) { drum in
          Button {
            model.selected = drum
          } label: {
            VStack(spacing: 7) {
              HStack(spacing: 4) {
                Circle().fill(drum.color.opacity(model.pattern.audible(drum.rawValue) ? 1 : 0.2))
                  .frame(width: 5, height: 5)
                Text(drum.name.uppercased())
                  .font(.system(size: 9, weight: .bold, design: .monospaced))
              }
              HStack(spacing: 1.5) {
                ForEach(0..<16) { step in
                  RoundedRectangle(cornerRadius: 0.5)
                    .fill(
                      model.pattern.steps[drum.rawValue][step]
                        ? drum.color : drum.color.opacity(0.1)
                    )
                    .frame(height: 7)
                }
              }
            }
            .padding(.horizontal, 7).frame(maxWidth: .infinity).frame(height: 49)
            .foregroundStyle(model.selected == drum ? drum.color : Panel.muted)
            .background(
              model.selected == drum ? drum.color.opacity(0.10) : Panel.surface,
              in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 9)
                .stroke(model.selected == drum ? drum.color.opacity(0.7) : .clear))
          }
          .accessibilityLabel("Select \(drum.name) track")
          .accessibilityValue(model.selected == drum ? "Selected" : "")
        }
      }
      HStack {
        label(model.selected.detail, size: 9)
        Spacer()
        toggle("MUTE", active: model.pattern.muted[model.selected.rawValue]) {
          model.edit { $0.muted[model.selected.rawValue].toggle() }
        }.accessibilityLabel("Mute \(model.selected.name)")
        toggle("SOLO", active: model.pattern.solo == model.selected.rawValue) {
          model.edit {
            $0.solo = $0.solo == model.selected.rawValue ? nil : model.selected.rawValue
          }
        }.accessibilityLabel("Solo \(model.selected.name)")
      }.frame(height: 25)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 7)
      {
        ForEach(0..<16) { step in
          let on = model.pattern.steps[model.selected.rawValue][step]
          Button {
            model.toggleStep(step)
          } label: {
            VStack(spacing: 5) {
              Capsule().fill(on ? Color.black.opacity(0.45) : .white.opacity(0.12))
                .frame(width: 12, height: 2)
              Text(String(format: "%02d", step + 1))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .frame(maxWidth: .infinity).frame(height: 43)
            .foregroundStyle(on ? Panel.background : Panel.muted)
            .background(
              on ? model.selected.color : Panel.surface, in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 7)
                .stroke(
                  model.activeStep == step
                    ? Panel.ivory : .white.opacity(step % 4 == 0 ? 0.16 : 0.04),
                  lineWidth: model.activeStep == step ? 2 : 1))
          }
          .accessibilityLabel("\(model.selected.name) step \(step + 1)")
          .accessibilityValue(on ? "On" : "Off")
          .accessibilityIdentifier("step-\(step + 1)")
        }
      }.buttonStyle(TactileButton())
    }
  }

  private var pads: some View {
    VStack(spacing: 12) {
      HStack {
        label("02 / LIVE PADS", size: 9)
        Spacer()
        label("TAP TO AUDITION", size: 8)
      }
      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9
      ) {
        ForEach(Drum.allCases, id: \.rawValue) { drum in
          Button {
            model.hit(drum)
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 7) {
                Text(String(format: "%02d", drum.rawValue + 1))
                  .font(.system(size: 8, weight: .medium, design: .monospaced))
                  .foregroundStyle(drum.color.opacity(0.6))
                Text(drum.name.uppercased())
                  .font(.system(size: 15, weight: .heavy, design: .rounded))
              }
              Spacer()
              PadArt(drum: drum).frame(width: 42, height: 42).opacity(0.85)
            }
            .padding(.horizontal, 17).frame(height: 78)
            .foregroundStyle(drum.color)
            .background(
              LinearGradient(
                colors: [
                  drum.color.opacity(model.flashed == drum ? 0.42 : 0.16),
                  drum.color.opacity(0.055),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing),
              in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(drum.color.opacity(0.29)))
            .overlay(alignment: .bottom) {
              Capsule().fill(drum.color.opacity(model.flashed == drum ? 1 : 0.5))
                .frame(width: 28, height: 2).padding(.bottom, 8)
            }
          }.accessibilityLabel("Play \(drum.name) pad")
            .accessibilityHint("Auditions this sound without changing the sequence.")
        }
      }.buttonStyle(TactileButton())
    }
  }

  private var footer: some View {
    VStack(spacing: 13) {
      HStack(spacing: 9) {
        footerButton("Patterns", symbol: "square.stack.3d.up") { library = true }
        footerButton("Undo", symbol: "arrow.uturn.backward") { model.undo() }
          .disabled(model.history.isEmpty).opacity(model.history.isEmpty ? 0.35 : 1)
        footerButton("WAV", symbol: "square.and.arrow.up") { model.export() }
          .accessibilityLabel("Export WAV")
      }
      Text(model.notice).font(.system(size: 8, weight: .medium, design: .monospaced))
        .tracking(1).foregroundStyle(Panel.muted).lineLimit(1).minimumScaleFactor(0.6)
    }
  }

  private var mixerSheet: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 28) {
        Text("Shape the pocket.").font(.system(size: 29, weight: .bold, design: .rounded))
        Text("Swing delays every second sixteenth note. Each pair keeps its original length.")
          .foregroundStyle(Panel.muted)
        VStack(alignment: .leading) {
          HStack {
            Text("SWING")
            Spacer()
            Text("\(Int(model.pattern.swing * 100))%")
          }
          .font(.system(.subheadline, design: .monospaced))
          Slider(
            value: Binding(
              get: { model.pattern.swing },
              set: { value in
                model.edit { $0.swing = value }
              }), in: 0...0.5, step: 0.01
          ).tint(Drum.kick.color)
            .accessibilityLabel("Swing")
        }
        VStack(alignment: .leading) {
          HStack {
            Text("MASTER")
            Spacer()
            Text("\(Int(model.pattern.volume * 100))%")
          }
          .font(.system(.subheadline, design: .monospaced))
          Slider(
            value: Binding(
              get: { model.pattern.volume },
              set: { value in
                model.edit { $0.volume = value }
              }), in: 0...1, step: 0.01
          ).tint(Panel.orange)
            .accessibilityLabel("Master volume")
        }
        Text(
          "Live changes take effect on the audio sample clock. Pad auditions bypass track mute and solo."
        )
        .font(.footnote).foregroundStyle(Panel.muted)
        Spacer()
      }.padding(24).background(Panel.background)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) { Button("Done") { mixer = false } }
        }
    }.presentationDetents([.large])
  }

  private var helpSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Text("Make room for rhythm.")
            .font(.system(size: 32, weight: .bold, design: .rounded))
          guide(
            "01", "Build a pattern",
            "Select a colored track, then tap its 16 numbered steps. Bright steps play; dark steps rest."
          )
          guide(
            "02", "Find your sound",
            "The four pads synthesize kick, snare, metallic hi-hat and clap locally. Tap to audition; pads do not record steps."
          )
          guide(
            "03", "Move the beat",
            "Press Play. Change BPM, mute or solo a track, and adjust swing in the mixer. Stop clears active sound immediately."
          )
          guide(
            "04", "Keep a take",
            "Changes autosave. Patterns holds factory presets and your named snapshots. Undo reverses edits, loads and Clear."
          )
          guide(
            "05", "Take it with you",
            "WAV renders two bars plus a 0.55-second natural tail at 48 kHz, 16-bit mono. Save or share the real audio file."
          )
        }.padding(24)
      }.background(Panel.background)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { help = false } } }
    }
  }

  private func guide(_ number: String, _ title: String, _ text: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("\(number) / \(title.uppercased())").font(.system(.caption, design: .monospaced))
        .foregroundStyle(Panel.orange)
      Text(text).font(.subheadline).foregroundStyle(Panel.muted)
    }
  }

  private func label(_ text: String, size: CGFloat) -> some View {
    Text(text).font(.system(size: size, weight: .semibold, design: .monospaced))
      .tracking(0.7).foregroundStyle(Panel.muted)
  }

  private func toggle(_ text: String, active: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(text).font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(active ? Panel.background : Panel.muted)
        .frame(width: 48, height: 28)
        .background(active ? model.selected.color : Panel.surface, in: Capsule())
    }.accessibilityValue(active ? "On" : "Off")
  }

  private func footerButton(_ title: String, symbol: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .frame(maxWidth: .infinity).frame(height: 40)
        .background(Panel.surface, in: RoundedRectangle(cornerRadius: 10))
    }
  }

  private func ledColor(_ step: Int) -> Color {
    Drum.allCases.contains {
      model.pattern.steps[$0.rawValue][step] && model.pattern.audible($0.rawValue)
    }
      ? Drum.kick.color.opacity(0.35) : .white.opacity(0.08)
  }
}

private struct PadArt: View {
  let drum: Drum
  var body: some View {
    Canvas { context, size in
      switch drum {
      case .kick:
        for inset in stride(from: 3.0, through: 15.0, by: 6) {
          context.stroke(
            Path(
              ellipseIn: CGRect(
                x: inset, y: inset,
                width: size.width - inset * 2, height: size.height - inset * 2)),
            with: .color(drum.color), lineWidth: 1.3)
        }
      case .snare:
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 21))
        for index in 1...16 {
          let amplitude = sin(Double(index) / 16 * .pi) * 16
          path.addLine(
            to: CGPoint(
              x: Double(index) * 2.6,
              y: 21 + (index.isMultiple(of: 2) ? amplitude : -amplitude)))
        }
        context.stroke(path, with: .color(drum.color), lineWidth: 1.3)
      case .hat, .clap:
        for index in 0..<5 {
          var path = Path()
          let x = Double(index) * 7 + 4
          path.move(to: CGPoint(x: x, y: drum == .hat ? 11 : 30))
          path.addLine(to: CGPoint(x: x + (drum == .hat ? 0 : 10), y: drum == .hat ? 31 : 11))
          context.stroke(path, with: .color(drum.color), lineWidth: 2)
        }
      }
    }.accessibilityHidden(true)
  }
}

private struct TactileButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.scaleEffect(configuration.isPressed ? 0.955 : 1)
      .brightness(configuration.isPressed ? 0.1 : 0)
      .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
  }
}

private struct LibraryView: View {
  @ObservedObject var model: InstrumentModel
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""

  var body: some View {
    NavigationStack {
      List {
        Section {
          HStack {
            TextField("Name this pattern", text: $name)
              .accessibilityIdentifier("pattern-name")
              .onChange(of: name) { _, value in name = String(value.prefix(40)) }
            Button("Save") {
              model.save(name: name)
              name = ""
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
              .tint(Panel.orange).accessibilityLabel("Save named pattern")
          }
        } header: {
          Text("Capture the current pattern")
        } footer: {
          Text("Your working pattern autosaves. Save a named snapshot to return to it later.")
        }
        Section("Your patterns · \(model.saved.count)") {
          if model.saved.isEmpty {
            Text("A good groove deserves a name. Save your first take above.")
              .font(.subheadline).foregroundStyle(Panel.muted)
          }
          ForEach(model.saved) { pattern in
            patternRow(pattern)
              .swipeActions {
                Button("Delete", role: .destructive) { model.delete(pattern.id) }
              }
          }
        }
        Section("Factory / starting points") {
          ForEach(Pattern.presets) { pattern in patternRow(pattern) }
        }
      }
      .scrollContentBackground(.hidden).background(Panel.background)
      .navigationTitle("Patterns")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }.tint(Panel.ivory)
  }

  private func patternRow(_ pattern: Pattern) -> some View {
    Button {
      model.load(pattern)
      dismiss()
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 7) {
          Text(pattern.name).font(.system(.body, design: .rounded, weight: .semibold))
          Text("\(Int(pattern.bpm)) BPM  /  \(Int(pattern.swing * 100))% SWING")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(Panel.muted)
        }
        Spacer()
        Image(systemName: "arrow.up.right").foregroundStyle(Drum.kick.color)
      }.padding(.vertical, 7)
    }.accessibilityLabel("Load \(pattern.name)")
  }
}

private struct ShareSheet: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
