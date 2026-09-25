import SwiftUI
import UIKit

@main
struct FrameForgeApp: App {
  @StateObject private var store = StudioStore()
  @Environment(\.scenePhase) private var scenePhase
  var body: some Scene {
    WindowGroup {
      StudioView(store: store)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
          if phase != .active {
            store.stop()
            store.save(announce: false)
          }
        }
    }
  }
}

enum Desk {
  static let background = Color(hex: "211E2B")
  static let panel = Color(hex: "2C2738")
  static let raised = Color(hex: "393244")
  static let muted = Color(hex: "B7ADBF")
  static let coral = Color(hex: "F38D7C")
  static let lavender = Color(hex: "BCB8EA")
  static let paper = Color(hex: "F7F0E3")
}

struct StudioView: View {
  @ObservedObject var store: StudioStore
  @State private var libraryOpen = false
  @State private var renameOpen = false
  @State private var projectName = ""
  @State private var helpOpen = false
  @State private var shareOpen = false

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        header
        Rectangle().fill(.white.opacity(0.07)).frame(height: 1)
        HStack(spacing: 0) {
          toolRail
          VStack(spacing: 14) {
            stageHeading
            GeometryReader { area in
              let width = min(area.size.width - 38, (area.size.height - 20) * 800 / 520)
              DrawingStage(store: store)
                .frame(width: max(1, width), height: max(1, width * 520 / 800))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.2)))
                .shadow(color: .black.opacity(0.25), radius: 20, y: 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            stageFooter
          }
          .padding(.vertical, 18)
          .background {
            Canvas { context, size in
              for x in stride(from: 12.0, to: size.width, by: 22) {
                for y in stride(from: 12.0, to: size.height, by: 22) {
                  context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(0.08)))
                }
              }
            }
          }
          inspector.frame(width: 248)
        }
        timeline.frame(height: geometry.size.height > 800 ? 206 : 185)
      }
      .background(Desk.background)
      .foregroundStyle(Desk.paper)
    }
    .overlay(alignment: .top) {
      if let notice = store.notice {
        Label(notice, systemImage: "checkmark.circle.fill")
          .font(.system(size: 14, weight: .medium))
          .padding(.horizontal, 20).padding(.vertical, 12)
          .background(Desk.raised, in: Capsule())
          .shadow(radius: 12).padding(.top, 86)
          .allowsHitTesting(false)
      }
    }
    .sheet(isPresented: $libraryOpen) { library }
    .sheet(isPresented: $helpOpen) { help }
    .sheet(
      isPresented: Binding(
        get: { store.exportURL != nil },
        set: { if !$0 { store.exportURL = nil } }
      )
    ) { exportResult }
    .alert("Name your loop", isPresented: $renameOpen) {
      TextField("Project name", text: $projectName)
      Button("Cancel", role: .cancel) {}
      Button("Save name") {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { store.edit { $0.name = String(trimmed.prefix(60)) } }
      }
    }
    .alert(
      "Something needs attention",
      isPresented: Binding(
        get: { store.error != nil }, set: { if !$0 { store.error = nil } }
      )
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
  }

  private var header: some View {
    HStack(spacing: 16) {
      HStack(spacing: 10) {
        ZStack {
          RoundedRectangle(cornerRadius: 10).fill(Desk.coral).frame(width: 38, height: 38)
          Image(systemName: "square.stack.3d.up.fill")
            .font(.system(size: 19, weight: .semibold)).foregroundStyle(Desk.background)
        }
        VStack(alignment: .leading, spacing: 1) {
          Text("FRAME FORGE").font(.system(size: 15, weight: .heavy, design: .rounded))
            .tracking(2)
          Text("A LITTLE MOTION, BY HAND").font(.system(size: 8, weight: .medium))
            .tracking(1.6).foregroundStyle(Desk.muted)
        }
      }
      Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 30).padding(.horizontal, 6)
      Button {
        projectName = store.project.name
        renameOpen = true
      } label: {
        HStack(spacing: 10) {
          VStack(alignment: .leading, spacing: 4) {
            Text(store.project.name).font(.system(size: 18, weight: .semibold))
            Text("LOCAL PROJECT  /  AUTO-SAVED").font(.system(size: 9, weight: .medium))
              .tracking(1.3).foregroundStyle(Desk.muted)
          }
          Image(systemName: "pencil").font(.system(size: 12)).foregroundStyle(Desk.muted)
        }
      }.buttonStyle(.plain).accessibilityLabel("Rename project")
      Spacer(minLength: 10)
      Button {
        store.stop()
        libraryOpen = true
      } label: {
        Label("Studio", systemImage: "square.grid.2x2").font(.system(size: 13, weight: .medium))
      }.buttonStyle(DeskButtonStyle())
      Button {
        store.save()
      } label: {
        Text("Save").font(.system(size: 13, weight: .semibold))
      }.buttonStyle(DeskButtonStyle()).keyboardShortcut("s", modifiers: .command)
      Button {
        store.exportGIF()
      } label: {
        Label(store.exporting ? "Exporting…" : "Export GIF", systemImage: "arrow.up.right")
          .font(.system(size: 13, weight: .bold))
      }.buttonStyle(DeskButtonStyle(accent: true)).disabled(store.exporting)
    }.padding(.horizontal, 24).frame(height: 83)
  }

  private var toolRail: some View {
    VStack(spacing: 13) {
      railButton("Brush", symbol: "paintbrush.pointed.fill", active: !store.eraser) {
        store.eraser = false
      }
      railButton("Eraser", symbol: "eraser.fill", active: store.eraser) { store.eraser = true }
      Rectangle().fill(.white.opacity(0.1)).frame(width: 30, height: 1).padding(.vertical, 6)
      railButton("Undo", symbol: "arrow.uturn.backward") { store.undo() }
        .disabled(store.history.past.isEmpty).opacity(store.history.past.isEmpty ? 0.35 : 1)
        .keyboardShortcut("z", modifiers: .command)
      railButton("Redo", symbol: "arrow.uturn.forward") { store.redo() }
        .disabled(store.history.future.isEmpty).opacity(store.history.future.isEmpty ? 0.35 : 1)
        .keyboardShortcut("z", modifiers: [.command, .shift])
      Spacer()
      Circle().fill(Color(hex: store.color)).frame(width: 29, height: 29)
        .overlay(Circle().stroke(Desk.paper.opacity(0.75), lineWidth: 2))
        .accessibilityLabel("Current ink color")
      railButton("Guide", symbol: "questionmark") {
        store.stop()
        helpOpen = true
      }
    }.padding(.top, 25).padding(.bottom, 19).frame(width: 83).background(Desk.panel)
  }

  private func railButton(
    _ name: String, symbol: String, active: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 7) {
        Image(systemName: symbol).font(.system(size: 20, weight: .medium)).frame(height: 23)
        Text(name).font(.system(size: 9, weight: .medium))
      }.frame(width: 60, height: 61)
        .background(
          active ? Desk.coral.opacity(0.16) : .clear,
          in: RoundedRectangle(cornerRadius: 12)
        )
        .foregroundStyle(active ? Desk.coral : Desk.muted)
    }.buttonStyle(.plain).accessibilityLabel(name)
  }

  private var stageHeading: some View {
    HStack {
      HStack(spacing: 7) {
        Circle().fill(store.playing ? Desk.coral : Desk.lavender).frame(width: 6, height: 6)
        Text(store.playing ? "LOOP PREVIEW" : "ANIMATION DESK")
          .font(.system(size: 9, weight: .semibold)).tracking(1.7)
      }
      Spacer()
      Text("800 × 520").font(.system(size: 10, design: .monospaced))
      Text("•").padding(.horizontal, 2)
      Text("WARM PAPER").font(.system(size: 9, weight: .medium)).tracking(1)
    }.foregroundStyle(Desk.muted).padding(.horizontal, 25)
  }

  private var stageFooter: some View {
    HStack {
      Image(systemName: store.playing ? "play.circle" : "hand.draw")
      Text(store.playing ? "Playing your hand-made loop" : "Make a mark. Make it move.")
        .font(.system(size: 11))
      Spacer()
      if store.onionSkin && !store.playing {
        Text(store.selection == 0 ? "Onion skin · first frame" : "Previous frame · 18%")
          .font(.system(size: 10)).foregroundStyle(Desk.lavender)
      }
    }.foregroundStyle(Desk.muted).padding(.horizontal, 25)
  }

  private var inspector: some View {
    VStack(alignment: .leading, spacing: 19) {
      sectionLabel("YOUR TOOLKIT")
      HStack {
        Image(systemName: store.eraser ? "eraser.fill" : "paintbrush.pointed.fill")
          .font(.system(size: 20)).foregroundStyle(Desk.coral)
        VStack(alignment: .leading, spacing: 4) {
          Text(store.eraser ? "Soft eraser" : "Studio brush")
            .font(.system(size: 15, weight: .semibold))
          Text(store.eraser ? "Clear a little space" : "Round · smooth · opaque")
            .font(.system(size: 10)).foregroundStyle(Desk.muted)
        }
      }
      VStack(alignment: .leading, spacing: 9) {
        HStack {
          Text("Size").font(.system(size: 12))
          Spacer()
          Text("\(Int(store.brushSize * (store.eraser ? 4 : 1))) px")
            .font(.system(size: 11, design: .monospaced)).foregroundStyle(Desk.muted)
        }
        Slider(value: $store.brushSize, in: 2...20, step: 1).tint(Desk.coral)
          .accessibilityLabel("Brush size")
        ZStack {
          RoundedRectangle(cornerRadius: 10).fill(Desk.background)
          Capsule().fill(store.eraser ? Desk.paper : Color(hex: store.color))
            .frame(width: 98, height: min(28, store.brushSize * (store.eraser ? 2 : 1)))
        }.frame(height: 45)
      }
      VStack(alignment: .leading, spacing: 12) {
        sectionLabel("PAPER & PIGMENT")
        let colors = [
          ("493446", "Aubergine"), ("ED7969", "Coral"), ("E5AD53", "Ochre"),
          ("8EADB0", "Sage"), ("B8B9EC", "Lilac"), ("F7F0E3", "Paper"),
        ]
        HStack(spacing: 8) {
          ForEach(colors, id: \.0) { hex, name in
            Button {
              store.color = hex
              store.eraser = false
            } label: {
              Circle().fill(Color(hex: hex)).frame(width: 22, height: 22)
                .padding(3)
                .overlay(
                  Circle().stroke(
                    store.color == hex ? Desk.paper : .clear, lineWidth: 1.5))
            }.buttonStyle(.plain).accessibilityLabel("\(name) ink")
          }
        }
      }
      Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
      VStack(alignment: .leading, spacing: 11) {
        Toggle(isOn: $store.onionSkin) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Onion skin").font(.system(size: 13, weight: .medium))
            Text("Trace the in-between").font(.system(size: 9)).foregroundStyle(Desk.muted)
          }
        }.tint(Desk.lavender).accessibilityIdentifier("onion-skin")
        HStack {
          Text("Frame rate").font(.system(size: 12))
          Spacer()
          Text("\(store.project.fps) fps")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(Desk.coral)
        }
        HStack(spacing: 12) {
          miniButton("Decrease FPS", symbol: "minus") {
            store.edit { $0.fps -= 1 }
          }.disabled(store.project.fps <= 1)
          Text(store.project.fps < 10 ? "Hand-drawn" : "Smooth motion")
            .font(.system(size: 10)).foregroundStyle(Desk.muted)
            .frame(maxWidth: .infinity)
          miniButton("Increase FPS", symbol: "plus") {
            store.edit { $0.fps += 1 }
          }.disabled(store.project.fps >= 24)
        }
      }
      Spacer(minLength: 0)
      HStack(alignment: .top, spacing: 9) {
        Image(systemName: "sparkle").foregroundStyle(Desk.coral)
        Text("Small changes.\nWonderful motion.")
          .font(.system(size: 12, weight: .medium, design: .serif))
          .lineSpacing(4).foregroundStyle(Desk.muted)
      }
    }.padding(19).frame(maxHeight: .infinity).background(Desk.panel)
  }

  private var timeline: some View {
    VStack(spacing: 15) {
      HStack(spacing: 15) {
        Button {
          store.togglePlayback()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: store.playing ? "pause.fill" : "play.fill")
            Text(store.playing ? "Pause" : "Play loop")
          }.font(.system(size: 12, weight: .bold))
            .frame(width: 114, height: 38)
            .background(Desk.coral, in: RoundedRectangle(cornerRadius: 9))
            .foregroundStyle(Desk.background)
        }.buttonStyle(.plain).keyboardShortcut(.space, modifiers: [])
        Text(String(format: "%02d", store.selection + 1))
          .font(.system(size: 18, weight: .semibold, design: .monospaced))
          .foregroundStyle(Desk.coral)
        Text("/ \(String(format: "%02d", store.project.frames.count)) FRAMES")
          .font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(Desk.muted)
        Text(
          String(format: "%.2fs", Double(store.project.frames.count) / Double(store.project.fps))
        )
        .font(.system(size: 11, design: .monospaced)).foregroundStyle(Desk.muted)
        Spacer()
        miniButton("Move frame left", symbol: "arrow.left") { store.moveFrame(-1) }
          .disabled(store.selection == 0)
        miniButton("Move frame right", symbol: "arrow.right") { store.moveFrame(1) }
          .disabled(store.selection == store.project.frames.count - 1)
        Button {
          store.duplicateFrame()
        } label: {
          Label("Duplicate", systemImage: "square.on.square")
            .font(.system(size: 11, weight: .medium))
        }.buttonStyle(DeskButtonStyle())
          .disabled(store.project.frames.count >= AnimationProject.maximumFrames)
        miniButton("Delete frame", symbol: "trash") { store.deleteFrame() }
          .disabled(store.project.frames.count <= 1)
        Button {
          store.addFrame()
        } label: {
          Label("Add frame", systemImage: "plus").font(.system(size: 11, weight: .semibold))
        }.buttonStyle(DeskButtonStyle())
          .disabled(store.project.frames.count >= AnimationProject.maximumFrames)
      }
      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(Array(store.project.frames.enumerated()), id: \.element.id) { index, frame in
              Button {
                store.select(index)
              } label: {
                VStack(spacing: 6) {
                  Image(uiImage: ArtworkRenderer.image(frame, width: 150))
                    .resizable().aspectRatio(800 / 520, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding(3)
                    .overlay(
                      RoundedRectangle(cornerRadius: 8).stroke(
                        store.selection == index ? Desk.coral : .white.opacity(0.08),
                        lineWidth: store.selection == index ? 2 : 1))
                  HStack {
                    Text(String(format: "%02d", index + 1))
                    Spacer()
                    if store.selection == index {
                      Capsule().fill(Desk.coral).frame(width: 17, height: 3)
                    } else {
                      Text("\(frame.strokes.count) marks").font(.system(size: 8))
                    }
                  }.font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(store.selection == index ? Desk.coral : Desk.muted)
                }.frame(width: 123)
              }.buttonStyle(.plain).id(frame.id)
                .accessibilityLabel("Frame \(index + 1), \(frame.strokes.count) marks")
                .accessibilityIdentifier("frame-\(index + 1)")
            }
          }.padding(.horizontal, 2)
        }
        .onChange(of: store.selection) { _, _ in
          withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(store.currentFrame.id, anchor: .center)
          }
        }
      }
    }.padding(.horizontal, 24).padding(.vertical, 17).background(Desk.panel)
      .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.1)).frame(height: 1) }
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text).font(.system(size: 9, weight: .semibold)).tracking(1.7).foregroundStyle(Desk.muted)
  }

  private func miniButton(_ name: String, symbol: String, action: @escaping () -> Void) -> some View
  {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 13, weight: .medium))
        .frame(width: 36, height: 36).background(Desk.raised, in: RoundedRectangle(cornerRadius: 8))
    }.buttonStyle(.plain).accessibilityLabel(name)
  }

  private var library: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 23) {
          Text("Good things start\none frame at a time.")
            .font(.system(size: 32, weight: .medium, design: .serif))
          HStack {
            Button("New blank loop", systemImage: "plus") {
              store.open(.blank())
              libraryOpen = false
            }.buttonStyle(DeskButtonStyle(accent: true))
            Button("New sample", systemImage: "sparkles") {
              store.open(SampleAnimation.make())
              libraryOpen = false
            }.buttonStyle(DeskButtonStyle())
          }
          sectionLabel("SAVED IN YOUR STUDIO")
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 20) {
            ForEach(store.savedProjects) { project in
              Button {
                store.open(project)
                libraryOpen = false
              } label: {
                VStack(alignment: .leading, spacing: 10) {
                  Image(uiImage: ArtworkRenderer.image(project.frames[0], width: 360))
                    .resizable().aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                  Text(project.name).font(.system(size: 17, weight: .semibold))
                  Text("\(project.frames.count) frames  ·  \(project.fps) fps")
                    .font(.system(size: 12)).foregroundStyle(Desk.muted)
                }.padding(12).background(Desk.panel, in: RoundedRectangle(cornerRadius: 16))
              }.buttonStyle(.plain).accessibilityLabel("Open \(project.name)")
            }
          }
        }.padding(28)
      }.background(Desk.background).navigationTitle("Your studio")
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { libraryOpen = false }
          }
        }
    }.tint(Desk.coral).presentationDetents([.large])
  }

  private var help: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 23) {
          Text("A tiny guide to\nbringing drawings to life.")
            .font(.system(size: 31, weight: .medium, design: .serif))
          guideStep(
            "01", "Draw a pose",
            "Use your finger or Pencil on the warm paper. Pick a pigment and adjust your brush size."
          )
          guideStep(
            "02", "Find the next moment",
            "Duplicate a frame, erase a detail and redraw it. Onion skin shows the previous frame at 18% opacity."
          )
          guideStep(
            "03", "Give it a little rhythm",
            "Play your loop and tune the frame rate. Move frames with the arrows; undo restores each edit."
          )
          guideStep(
            "04", "Send it into the world",
            "Every edit saves locally. Export creates a real 800 × 520 looping GIF, ready to share or save to Files."
          )
          Text("⌘Z Undo    ⇧⌘Z Redo    ⌘S Save    Space Play / pause")
            .font(.system(size: 11, design: .monospaced)).foregroundStyle(Desk.muted)
        }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
      }.background(Desk.background).navigationTitle("Field notes")
        .toolbar {
          ToolbarItem(placement: .confirmationAction) { Button("Done") { helpOpen = false } }
        }
    }.tint(Desk.coral)
  }

  private func guideStep(_ number: String, _ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 17) {
      Text(number).font(.system(size: 15, design: .monospaced)).foregroundStyle(Desk.coral)
      VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.system(size: 17, weight: .semibold))
        Text(detail).font(.system(size: 14)).foregroundStyle(Desk.muted).lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var exportResult: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 23) {
          Image(systemName: "checkmark.seal.fill").font(.system(size: 38)).foregroundStyle(
            Desk.coral)
          Text("A little loop, ready to go.")
            .font(.system(size: 29, weight: .medium, design: .serif))
          Image(uiImage: ArtworkRenderer.image(store.project.frames[0], width: 600))
            .resizable().aspectRatio(contentMode: .fit).clipShape(
              RoundedRectangle(cornerRadius: 12)
            )
            .frame(maxHeight: 240)
            .padding(.horizontal, 15)
          Text("\(store.project.frames.count) frames  /  \(store.project.fps) fps  /  800 × 520")
            .font(.system(size: 13, design: .monospaced)).foregroundStyle(Desk.muted)
          Text("Animated GIF · loops forever\nSaved in Frame Forge / Exports")
            .font(.system(size: 13)).multilineTextAlignment(.center).lineSpacing(5)
            .foregroundStyle(Desk.muted)
          Button {
            shareOpen = true
          } label: {
            Label("Share GIF", systemImage: "square.and.arrow.up")
              .font(.system(size: 15, weight: .semibold))
          }.buttonStyle(DeskButtonStyle(accent: true))
        }.padding(28).frame(maxWidth: .infinity)
      }.background(Desk.background).navigationTitle("Export complete")
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { store.exportURL = nil }
          }
        }
        .sheet(isPresented: $shareOpen) {
          if let url = store.exportURL { ActivitySheet(url: url) }
        }
    }.tint(Desk.coral)
  }
}

struct DeskButtonStyle: ButtonStyle {
  var accent = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.padding(.horizontal, 14).frame(height: 38)
      .foregroundStyle(accent ? Desk.background : Desk.paper)
      .background(accent ? Desk.coral : Desk.raised, in: RoundedRectangle(cornerRadius: 9))
      .opacity(configuration.isPressed ? 0.65 : 1)
  }
}

struct ActivitySheet: UIViewControllerRepresentable {
  let url: URL
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [url], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
