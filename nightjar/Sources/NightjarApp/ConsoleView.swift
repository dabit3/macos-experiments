import AppKit
import NightjarCore
import SwiftUI

private enum Desk {
  static let background = Color(red: 0.055, green: 0.064, blue: 0.08)
  static let panel = Color(red: 0.083, green: 0.095, blue: 0.116)
  static let raised = Color(red: 0.12, green: 0.137, blue: 0.16)
  static let line = Color.white.opacity(0.085)
  static let muted = Color(red: 0.57, green: 0.62, blue: 0.69)
  static let amber = Color(red: 1, green: 0.7, blue: 0.4)
}

struct ConsoleView: View {
  @ObservedObject var store: ShowStore
  @State private var confirmReset = false

  var body: some View {
    VStack(spacing: 0) {
      header
      Rectangle().fill(Desk.line).frame(height: 1)
      HStack(spacing: 0) {
        VStack(spacing: 0) {
          stageToolbar
          ZStack(alignment: .bottomLeading) {
            StageView(store: store)
            VStack(alignment: .leading, spacing: 5) {
              Text(store.isAiming ? "CLICK THE STAGE TO AIM" : "SCENIC STUDY  /  NO. 01")
                .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(2)
              Text(store.isAiming ? "Choose a point on the floor" : "Portal & plinths")
                .font(.system(size: 14, weight: .light))
            }
            .foregroundStyle(store.isAiming ? Desk.amber : Color.white.opacity(0.7))
            .padding(18)
            .allowsHitTesting(false)
          }
          .frame(minHeight: 265)
          fixtureStrip
        }
        Rectangle().fill(Desk.line).frame(width: 1)
        inspector.frame(width: 294)
      }
      Rectangle().fill(Desk.line).frame(height: 1)
      cueDeck
      Rectangle().fill(Desk.line).frame(height: 1)
      footer
    }
    .background(Desk.background)
    .frame(minWidth: 1180, minHeight: 790)
    .tint(Desk.amber)
    .alert(
      "Nightjar couldn't complete that action",
      isPresented: Binding(
        get: { store.error != nil },
        set: { if !$0 { store.error = nil } }
      )
    ) {
      Button("OK", role: .cancel) { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .confirmationDialog("Restore the sample show?", isPresented: $confirmReset) {
      Button("Restore Sample") { store.reset() }
    } message: {
      Text("Your current show can be recovered with Undo. Saved show files are not changed.")
    }
  }

  private var header: some View {
    HStack(spacing: 20) {
      HStack(spacing: 11) {
        Image(systemName: "light.beacon.min.fill")
          .font(.system(size: 25, weight: .light)).foregroundStyle(Desk.amber)
        VStack(alignment: .leading, spacing: 2) {
          Text("nightjar").font(.system(size: 27, weight: .semibold, design: .serif)).tracking(-1)
          Text("VIRTUAL LIGHTING STUDIO").font(.system(size: 8, weight: .medium)).tracking(2.2)
            .foregroundStyle(Desk.muted)
        }
      }
      Rectangle().fill(Desk.line).frame(width: 1, height: 33)
      VStack(alignment: .leading, spacing: 3) {
        Text("SHOW FILE").font(.system(size: 8, weight: .semibold)).tracking(1.6).foregroundStyle(
          Desk.muted)
        TextField("Show title", text: Binding(get: { store.show.name }, set: store.renameShow))
          .textFieldStyle(.plain).font(.system(size: 14, weight: .medium))
          .accessibilityIdentifier("show-title").frame(maxWidth: 280, alignment: .leading)
      }
      Spacer(minLength: 12)
      utilityButton("Undo", symbol: "arrow.uturn.backward", action: store.undo)
        .disabled(!store.canUndo || store.locked)
      utilityButton("Open", symbol: "folder", action: store.openShow)
      utilityButton("Save", symbol: "square.and.arrow.down", action: { store.saveShow() })
      utilityButton("Cue sheet", symbol: "arrow.up.document", action: store.exportCueSheet)
      Menu {
        Button("Save Show As…") { store.saveShow(forcePanel: true) }
        Button("Restore Sample Show…") { confirmReset = true }
      } label: {
        Image(systemName: "ellipsis").frame(width: 26, height: 30)
      }
      .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("More show actions")
    }
    .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 17)
  }

  private var stageToolbar: some View {
    HStack(spacing: 10) {
      Circle().fill(store.playing ? Color.green : Desk.amber).frame(width: 5, height: 5)
      Text(store.locked ? "CUE PLAYBACK" : "LIVE PREVIEW")
        .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.8)
      Spacer()
      HStack(spacing: 2) {
        ForEach(StageCamera.allCases, id: \.self) { camera in
          Button {
            store.camera = camera
          } label: {
            Text(camera.rawValue).font(.system(size: 10, weight: .medium))
              .padding(.horizontal, 12).padding(.vertical, 6)
              .background(
                store.camera == camera ? Desk.raised : .clear, in: RoundedRectangle(cornerRadius: 5)
              )
          }
          .buttonStyle(.plain).foregroundStyle(store.camera == camera ? .white : Desk.muted)
          .accessibilityLabel("\(camera.rawValue) camera")
        }
      }
      .padding(3).background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 7))
      Button {
        store.showHaze.toggle()
      } label: {
        Label("Haze", systemImage: "cloud.fog").font(.system(size: 10, weight: .medium))
          .foregroundStyle(store.showHaze ? Desk.amber : Desk.muted).frame(width: 67, height: 28)
      }
      .buttonStyle(.plain).accessibilityLabel(store.showHaze ? "Disable haze" : "Enable haze")
    }
    .padding(.horizontal, 18).frame(height: 48).background(Desk.background)
  }

  private var fixtureStrip: some View {
    HStack(spacing: 7) {
      ForEach(store.show.live) { fixture in
        Button {
          store.selectedFixture = fixture.id
        } label: {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text(String(format: "%02d", fixture.id + 1))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Desk.muted)
              Spacer(minLength: 4)
              Circle().fill(fixture.color.swiftColor).frame(width: 7, height: 7)
                .shadow(color: fixture.color.swiftColor.opacity(0.5), radius: 4)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
              Text(fixture.name).font(.system(size: 10, weight: .medium)).lineLimit(1)
              Spacer(minLength: 0)
              Text("\(Int(fixture.intensity * 100))")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(Desk.muted)
            }
            GeometryReader { geometry in
              Capsule().fill(Desk.line)
                .overlay(alignment: .leading) {
                  Capsule().fill(fixture.color.swiftColor.opacity(0.85))
                    .frame(width: geometry.size.width * fixture.intensity)
                }
            }.frame(height: 2)
          }
          .padding(11)
          .background(
            store.selectedFixture == fixture.id ? Desk.raised : Desk.panel,
            in: RoundedRectangle(cornerRadius: 8)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(
                store.selectedFixture == fixture.id
                  ? fixture.color.swiftColor.opacity(0.65) : Desk.line)
          }
        }
        .buttonStyle(.plain).accessibilityLabel("Select fixture \(fixture.id + 1), \(fixture.name)")
        .accessibilityIdentifier("fixture-\(fixture.id + 1)")
      }
    }
    .padding(13).background(Desk.background)
  }

  private var inspector: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 5) {
            eyebrow("FIXTURE  /  \(String(format: "%02d", store.selectedFixture + 1))")
            Text(store.fixture.name).font(.system(size: 22, weight: .medium, design: .serif))
          }
          Spacer()
          RoundedRectangle(cornerRadius: 8).fill(store.fixture.color.swiftColor.gradient)
            .frame(width: 34, height: 34)
            .overlay { Image(systemName: "light.max").foregroundStyle(Color.black.opacity(0.6)) }
        }
        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .firstTextBaseline) {
            eyebrow("INTENSITY")
            Spacer()
            Text("\(Int((store.fixture.intensity * 100).rounded()))")
              .font(.system(size: 34, weight: .light, design: .monospaced))
            Text("%").font(.system(size: 13)).foregroundStyle(Desk.muted)
          }
          Slider(value: fixtureBinding("intensity", \.intensity), in: 0...1)
            .accessibilityLabel("Intensity").accessibilityIdentifier("intensity-slider")
            .tint(store.fixture.color.swiftColor)
          HStack {
            Text("BLACKOUT")
            Spacer()
            Text("FULL")
          }
          .font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(Desk.muted)
        }
        divider
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            eyebrow("COLOR GEL")
            Spacer()
            Text(store.fixture.color.hex).font(.system(size: 9, design: .monospaced))
              .foregroundStyle(Desk.muted)
          }
          HStack(spacing: 7) {
            swatch("Amber", .amber)
            swatch("Cyan", .cyan)
            swatch("Violet", .violet)
            swatch("Rose", .rose)
            swatch("Mint", .mint)
            swatch("Frost", .frost)
          }
          ColorPicker(
            "Custom color",
            selection: Binding(
              get: { store.fixture.color.swiftColor },
              set: { value in
                guard let rgb = NSColor(value).usingColorSpace(.sRGB) else { return }
                store.editFixture("color") {
                  $0.color = LightColor(
                    Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent))
                }
              }
            ), supportsOpacity: false
          )
          .font(.system(size: 10)).foregroundStyle(Desk.muted)
        }
        divider
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            eyebrow("FOCUS & BEAM")
            Spacer()
            Button {
              store.isAiming.toggle()
            } label: {
              Label(store.isAiming ? "Cancel aim" : "Aim on stage", systemImage: "scope")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(Desk.amber)
            }
            .buttonStyle(.plain).accessibilityIdentifier("aim-on-stage")
          }
          fader("Aim X", value: fixtureBinding("aim-x", \.target.x), range: -6...6, unit: "m")
          fader("Aim depth", value: fixtureBinding("aim-z", \.target.z), range: -3.5...4, unit: "m")
          fader("Aim height", value: fixtureBinding("aim-y", \.target.y), range: 0...2.5, unit: "m")
          fader("Beam", value: fixtureBinding("beam", \.beam), range: 10...70, unit: "°")
        }
        DisclosureGroup {
          VStack(spacing: 12) {
            fader(
              "Position X", value: fixtureBinding("position-x", \.position.x), range: -6...6,
              unit: "m")
            fader(
              "Rig height", value: fixtureBinding("position-y", \.position.y), range: 3...8,
              unit: "m")
            fader(
              "Position depth", value: fixtureBinding("position-z", \.position.z), range: -4...5,
              unit: "m")
          }.padding(.top, 12)
        } label: {
          eyebrow("RIG POSITION")
        }
        .tint(Desk.muted)
        if store.locked {
          Text("Stop playback to edit this fixture.").font(.system(size: 10)).foregroundStyle(
            Desk.amber)
        }
      }
      .padding(21).disabled(store.locked)
    }
    .background(Desk.panel)
  }

  private var cueDeck: some View {
    VStack(spacing: 13) {
      HStack(spacing: 13) {
        VStack(alignment: .leading, spacing: 4) {
          Text("The cue stack").font(.system(size: 20, weight: .medium, design: .serif))
          Text("\(store.show.cues.count) LOOKS  ·  \(Int(store.totalDuration))s RUN TIME")
            .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.2)
            .foregroundStyle(Desk.muted)
        }
        Spacer()
        if let clock = store.clock {
          Text("\(clock.phase.rawValue.uppercased())  \(Int(clock.totalProgress * 100))%")
            .font(.system(size: 10, design: .monospaced)).foregroundStyle(Desk.amber)
            .frame(width: 90, alignment: .trailing)
        } else {
          Text(store.liveIsRecorded ? "LOOK RECORDED" : "LIVE EDIT")
            .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1)
            .foregroundStyle(store.liveIsRecorded ? Desk.muted : Desk.amber)
        }
        Button(action: store.togglePlayback) {
          Label(
            store.playing ? "Pause" : (store.clock != nil ? "Resume" : "Play cues"),
            systemImage: store.playing ? "pause.fill" : "play.fill"
          )
          .font(.system(size: 11, weight: .semibold)).frame(width: 92, height: 32)
        }
        .buttonStyle(DeskButton(accent: true)).disabled(store.show.cues.isEmpty)
        .accessibilityIdentifier("play-cues")
        Button(action: store.stop) {
          Image(systemName: "stop.fill").font(.system(size: 11)).frame(width: 32, height: 32)
        }
        .buttonStyle(DeskButton()).disabled(!store.locked).accessibilityLabel("Stop playback")
        Rectangle().fill(Desk.line).frame(width: 1, height: 24)
        Button(action: store.recordCue) {
          Label("Record look", systemImage: "record.circle").font(
            .system(size: 11, weight: .medium)
          )
          .frame(width: 112, height: 32)
        }
        .buttonStyle(DeskButton()).disabled(store.locked || store.show.cues.count >= 100)
        .accessibilityIdentifier("record-look")
      }
      if store.show.cues.isEmpty {
        HStack {
          Image(systemName: "light.min").font(.system(size: 24)).foregroundStyle(Desk.amber)
          VStack(alignment: .leading, spacing: 6) {
            Text("An empty stage. A thousand possibilities.").font(
              .system(size: 16, design: .serif))
            Text("Shape the light above, then Record look to begin your sequence.")
              .font(.system(size: 11)).foregroundStyle(Desk.muted)
          }
          Spacer()
        }
        .padding(20).frame(height: 91).background(Desk.panel, in: RoundedRectangle(cornerRadius: 8))
      } else {
        ScrollViewReader { proxy in
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
              ForEach(Array(store.show.cues.enumerated()), id: \.element.id) { index, cue in
                cueCard(cue, index: index).id(cue.id)
              }
            }
          }
          .onChange(of: store.selectedCue) { _, id in
            if let id {
              withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(id, anchor: .center) }
            }
          }
        }
      }
      cueEditor
    }
    .padding(.horizontal, 22).padding(.vertical, 18).background(Desk.background)
  }

  private func cueCard(_ cue: Cue, index: Int) -> some View {
    let selected = store.selectedCue == cue.id
    return Button {
      store.selectCue(cue.id)
    } label: {
      HStack(alignment: .top, spacing: 12) {
        VStack(spacing: 4) {
          Text(String(format: "%02d", index + 1))
            .font(.system(size: 19, weight: .light, design: .monospaced))
          RoundedRectangle(cornerRadius: 1).fill(selected ? Desk.amber : Desk.line).frame(
            width: 20, height: 2)
        }
        .foregroundStyle(selected ? Desk.amber : Desk.muted)
        VStack(alignment: .leading, spacing: 10) {
          Text(cue.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
          HStack(spacing: 4) {
            ForEach(cue.fixtures) { fixture in
              RoundedRectangle(cornerRadius: 2)
                .fill(fixture.color.swiftColor.opacity(0.35 + fixture.intensity * 0.65))
                .frame(height: 7)
            }
          }
          Text("\(cue.fade, specifier: "%.1f")s fade   /   \(cue.hold, specifier: "%.1f")s hold")
            .font(.system(size: 9, design: .monospaced)).foregroundStyle(Desk.muted)
        }
      }
      .padding(14).frame(width: 252, height: 91, alignment: .leading)
      .background(selected ? Desk.raised : Desk.panel, in: RoundedRectangle(cornerRadius: 8))
      .overlay {
        RoundedRectangle(cornerRadius: 8).strokeBorder(
          selected ? Desk.amber.opacity(0.75) : Desk.line)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Cue \(index + 1), \(cue.name)")
  }

  private var cueEditor: some View {
    HStack(spacing: 12) {
      Image(systemName: "slider.horizontal.3").font(.system(size: 12)).foregroundStyle(Desk.muted)
      TextField(
        "Cue name",
        text: Binding(
          get: { store.cue?.name ?? "" },
          set: { store.editCue(name: $0) }
        )
      )
      .textFieldStyle(.plain).font(.system(size: 11, weight: .medium))
      .padding(8).frame(width: 194)
      .background(Desk.panel, in: RoundedRectangle(cornerRadius: 5))
      .accessibilityIdentifier("cue-name")
      timingEditor(
        "Fade",
        value: Binding(
          get: { store.cue?.fade ?? 3 }, set: { store.editCue(fade: $0) }
        ), range: 0.2...30)
      timingEditor(
        "Hold",
        value: Binding(
          get: { store.cue?.hold ?? 2 }, set: { store.editCue(hold: $0) }
        ), range: 0...60)
      Spacer(minLength: 0)
      utilityButton("Update cue", symbol: "arrow.triangle.2.circlepath", action: store.updateCue)
        .help("Replace the selected cue with the live stage look")
      Button {
        store.moveCue(-1)
      } label: {
        Image(systemName: "arrow.left").frame(width: 26, height: 27)
      }
      .buttonStyle(DeskButton()).accessibilityLabel("Move cue earlier")
      .disabled(store.cueIndex == 0)
      Button {
        store.moveCue(1)
      } label: {
        Image(systemName: "arrow.right").frame(width: 26, height: 27)
      }
      .buttonStyle(DeskButton()).accessibilityLabel("Move cue later")
      .disabled(store.cueIndex == store.show.cues.count - 1)
      Button(action: store.deleteCue) {
        Image(systemName: "trash").frame(width: 26, height: 27)
      }
      .buttonStyle(DeskButton()).accessibilityLabel("Delete cue")
    }
    .disabled(store.cue == nil || store.locked)
  }

  private var footer: some View {
    HStack(spacing: 7) {
      Circle().fill(Color(red: 0.45, green: 0.74, blue: 0.6)).frame(width: 4, height: 4)
      Text(store.status).font(.system(size: 10)).lineLimit(1)
      Spacer()
      Text("LOCAL AUTOSAVE  ·  VIRTUAL STAGE ONLY")
        .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1)
    }
    .foregroundStyle(Desk.muted).padding(.horizontal, 22).frame(height: 29)
  }

  private var divider: some View { Rectangle().fill(Desk.line).frame(height: 1) }

  private func eyebrow(_ text: String) -> some View {
    Text(text).font(.system(size: 9, weight: .semibold, design: .monospaced))
      .tracking(1.3).foregroundStyle(Desk.muted)
  }

  private func utilityButton(_ title: String, symbol: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Label(title, systemImage: symbol).font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 10).frame(height: 30)
    }
    .buttonStyle(DeskButton())
  }

  private func fixtureBinding(_ key: String, _ path: WritableKeyPath<Fixture, Double>) -> Binding<
    Double
  > {
    Binding(
      get: { store.fixture[keyPath: path] },
      set: { value in
        store.editFixture(key) { $0[keyPath: path] = value }
      })
  }

  private func fader(
    _ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String
  ) -> some View {
    VStack(spacing: 5) {
      HStack {
        Text(title).font(.system(size: 10)).foregroundStyle(Desk.muted)
        Spacer()
        Text("\(value.wrappedValue, specifier: "%.1f")\(unit)")
          .font(.system(size: 10, design: .monospaced))
      }
      Slider(value: value, in: range).accessibilityLabel(title).tint(Desk.muted)
    }
  }

  private func swatch(_ name: String, _ color: LightColor) -> some View {
    Button {
      store.editFixture("color") { $0.color = color }
    } label: {
      RoundedRectangle(cornerRadius: 5).fill(color.swiftColor.gradient)
        .frame(height: 27)
        .overlay {
          if store.fixture.color == color {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
              .foregroundStyle(Color.black.opacity(0.75))
          }
        }
    }
    .buttonStyle(.plain).accessibilityLabel("\(name) gel").help(name)
  }

  private func timingEditor(_ title: String, value: Binding<Double>, range: ClosedRange<Double>)
    -> some View
  {
    HStack(spacing: 5) {
      Text(title).font(.system(size: 10)).foregroundStyle(Desk.muted)
      TextField(title, value: value, format: .number.precision(.fractionLength(1)))
        .textFieldStyle(.plain).multilineTextAlignment(.trailing)
        .font(.system(size: 11, design: .monospaced)).frame(width: 33)
        .accessibilityLabel("\(title) seconds")
      Text("s").font(.system(size: 10)).foregroundStyle(Desk.muted)
      Stepper(title, value: value, in: range, step: 0.5).labelsHidden()
        .accessibilityLabel("Adjust \(title.lowercased())")
    }
    .padding(.horizontal, 7).frame(height: 29).background(
      Desk.panel, in: RoundedRectangle(cornerRadius: 5))
  }
}

private struct DeskButton: ButtonStyle {
  var accent = false
  @Environment(\.isEnabled) private var enabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(accent ? Desk.background : Color.white.opacity(0.86))
      .background(
        accent
          ? Desk.amber.opacity(configuration.isPressed ? 0.75 : 1)
          : (configuration.isPressed ? Desk.raised : Desk.panel),
        in: RoundedRectangle(cornerRadius: 6)
      )
      .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(accent ? .clear : Desk.line) }
      .opacity(enabled ? 1 : 0.32)
  }
}
