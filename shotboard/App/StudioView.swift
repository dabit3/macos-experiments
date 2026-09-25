import SwiftUI
import UniformTypeIdentifiers

struct StudioView: View {
  @EnvironmentObject private var store: StudioStore
  @State private var guide = CompositionGuide.none
  @State private var ink = InkColor.graphite
  @State private var thick = false
  @State private var showLibrary = false
  @State private var showScene = false
  @State private var showTitle = false
  @State private var presenting = false
  @State private var clearConfirm = false
  @State private var deleteConfirm = false
  @State private var pdf: ExportedPDF?
  @State private var inspector = true

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.width < 1100
      VStack(spacing: 0) {
        topBar
        Rectangle().fill(Color.white.opacity(0.09)).frame(height: 1)
        HStack(spacing: 0) {
          if !compact { sidebar.frame(width: 204) }
          VStack(spacing: 0) {
            editor
            filmstrip
          }
          if inspector {
            InspectorView().frame(width: compact ? 235 : 268)
              .background(Palette.panel)
          }
        }
        footer
      }
      .background(Palette.background)
      .foregroundStyle(Palette.ivory)
    }
    .sheet(isPresented: $showLibrary) { ProjectLibrary() }
    .sheet(isPresented: $showScene) { SceneSheet() }
    .sheet(isPresented: $showTitle) { ProjectTitleSheet() }
    .fullScreenCover(item: $pdf) { export in PDFPreview(export: export) }
    .fullScreenCover(isPresented: $presenting) { PresentationView(project: store.project) }
    .confirmationDialog(
      "Clear all artwork in this frame?", isPresented: $clearConfirm, titleVisibility: .visible
    ) {
      Button("Clear frame", role: .destructive) { store.editShot { $0.strokes = [] } }
    } message: {
      Text("You can restore it with Undo.")
    }
    .confirmationDialog("Delete this shot?", isPresented: $deleteConfirm, titleVisibility: .visible)
    {
      Button("Delete shot", role: .destructive) { store.deleteShot() }
    } message: {
      Text("Your other shots stay in order. Undo restores the deleted shot.")
    }
    .alert(
      "Unable to complete action",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
  }

  private var topBar: some View {
    HStack(spacing: 22) {
      Button {
        showLibrary = true
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "square.stack.3d.up.fill").font(.system(size: 24)).foregroundStyle(
            Palette.yellow)
          Text("SHOTBOARD").font(.system(size: 19, weight: .heavy, design: .rounded)).tracking(2)
        }
      }.buttonStyle(.plain).accessibilityLabel("Project library")
      Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 30)
      Button {
        showTitle = true
      } label: {
        HStack(spacing: 10) {
          Text(store.project.title).font(.system(size: 17, weight: .medium)).lineLimit(1)
          Image(systemName: "chevron.down").font(.system(size: 10))
        }
      }.buttonStyle(.plain).accessibilityLabel("Edit film title")
      Spacer(minLength: 0)
      Button {
        exportPDF()
      } label: {
        Label("Export PDF", systemImage: "square.and.arrow.up").font(
          .system(size: 14, weight: .semibold))
      }.buttonStyle(StudioButton())
      Button {
        presenting = true
      } label: {
        Label("Present", systemImage: "play.fill").font(.system(size: 14, weight: .bold))
      }.buttonStyle(StudioButton(accent: true))
    }.padding(.horizontal, 24).frame(height: 78)
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      eyebrow("PRODUCTION / 001").padding(.bottom, 18)
      Text(store.project.title).font(.system(size: 30, weight: .regular, design: .serif))
        .lineSpacing(1).padding(.bottom, 12)
      Text(store.project.subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted)
        .lineSpacing(5).padding(.bottom, 30)
      HStack {
        eyebrow("SCENES")
        Spacer()
        Text(String(format: "%02d", store.project.scenes.count)).font(
          .system(size: 11, design: .monospaced)
        ).foregroundStyle(Palette.muted)
      }
      .padding(.bottom, 14)
      ScrollView {
        VStack(spacing: 8) {
          ForEach(Array(store.project.scenes.enumerated()), id: \.element.id) { index, scene in
            Button {
              if let first = store.project.shots.first(where: { $0.sceneID == scene.id }) {
                store.selectedID = first.id
              }
            } label: {
              HStack(alignment: .top, spacing: 10) {
                Text(String(format: "%02d", index + 1)).font(
                  .system(size: 11, weight: .semibold, design: .monospaced)
                )
                .foregroundStyle(store.scene.id == scene.id ? Palette.yellow : Palette.muted)
                VStack(alignment: .leading, spacing: 6) {
                  Text(scene.title).font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.leading)
                  Text("\(store.project.shots.filter { $0.sceneID == scene.id }.count) shots")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
              }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(store.scene.id == scene.id ? Palette.elevated : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain).accessibilityLabel("Scene \(index + 1): \(scene.title)")
          }
        }
      }
      Button {
        showScene = true
      } label: {
        Label("Add scene", systemImage: "plus").font(.system(size: 12, weight: .semibold))
      }
      .buttonStyle(StudioButton()).padding(.top, 14)
      Spacer(minLength: 22)
      Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1).padding(.bottom, 20)
      eyebrow("ESTIMATED RUNTIME")
      Text(store.project.runtimeLabel).font(.system(size: 36, weight: .light, design: .monospaced))
        .padding(.top, 7)
      Text("\(store.project.shots.count) frames · \(store.project.scenes.count) scenes")
        .font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.top, 5)
    }.padding(22).frame(maxHeight: .infinity).background(Palette.panel.opacity(0.55))
  }

  private var editor: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 9) {
          HStack(spacing: 8) {
            eyebrow(store.scene.location)
            Text("/").foregroundStyle(Palette.muted.opacity(0.4))
            eyebrow(store.scene.title.uppercased())
          }
          Text(store.shot.title).font(.system(size: 27, weight: .regular, design: .serif))
            .lineLimit(1)
        }
        Spacer()
        Text(String(format: "%02d", store.selectedIndex + 1))
          .font(.system(size: 36, weight: .light, design: .monospaced)).foregroundStyle(
            Palette.yellow)
      }.padding(.bottom, 22)
      GeometryReader { size in
        let width = min(size.size.width, (size.size.height - 24) * store.shot.ratio.value)
        VStack(spacing: 9) {
          InkCanvas(shot: store.shot, guide: guide, ink: ink, width: thick ? 0.012 : 0.004) {
            stroke in
            store.editShot { $0.strokes.append(stroke) }
          }
          .frame(width: max(width, 1), height: max(width / store.shot.ratio.value, 1))
          .overlay(alignment: .topLeading) {
            if store.shot.strokes.isEmpty {
              Text("Draw your opening idea").font(.system(size: 13, design: .serif))
                .foregroundStyle(Color.black.opacity(0.3)).padding(20).allowsHitTesting(false)
            }
          }
          .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
          HStack {
            Text("SHOT \(String(format: "%02d", store.selectedIndex + 1))")
            Spacer()
            Text("\(store.shot.ratio.rawValue)  ·  \(store.shot.size.rawValue.uppercased())")
          }.font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(1.5).foregroundStyle(Palette.muted).frame(width: max(width, 1))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      drawingToolbar.padding(.top, 18)
    }.padding(26).frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var drawingToolbar: some View {
    HStack(spacing: 9) {
      Image(systemName: "pencil.tip").foregroundStyle(Palette.yellow).padding(.trailing, 4)
      ForEach([InkColor.graphite, .yellow, .ivory], id: \.self) { color in
        Button {
          ink = color
        } label: {
          Circle().fill(Color(uiColor: color.uiColor)).frame(width: 23, height: 23)
            .padding(5).overlay(
              Circle().stroke(ink == color ? Palette.yellow : .clear, lineWidth: 1))
        }.buttonStyle(.plain).accessibilityLabel("\(color.rawValue.capitalized) ink")
      }
      Button {
        thick.toggle()
      } label: {
        Image(systemName: thick ? "lineweight" : "pencil.line").frame(width: 33, height: 36)
      }.buttonStyle(.plain).accessibilityLabel(thick ? "Use fine pen" : "Use broad pen")
      Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1, height: 24).padding(
        .horizontal, 4)
      Menu {
        ForEach(CompositionGuide.allCases, id: \.self) { value in
          Button(value.rawValue) { guide = value }
        }
      } label: {
        Image(systemName: guide == .none ? "viewfinder" : "grid").frame(width: 36, height: 38)
          .foregroundStyle(guide == .none ? Palette.ivory : Palette.yellow)
      }.accessibilityLabel("Composition guides")
      Menu {
        ForEach(FrameRatio.allCases, id: \.self) { ratio in
          Button(ratio.rawValue) { store.editShot { $0.ratio = ratio } }
        }
      } label: {
        Text(store.shot.ratio.rawValue).font(
          .system(size: 11, weight: .semibold, design: .monospaced)
        )
        .frame(minWidth: 55, minHeight: 38)
      }.accessibilityLabel("Frame aspect ratio")
      Spacer(minLength: 0)
      Button {
        store.undo()
      } label: {
        Image(systemName: "arrow.uturn.backward").frame(width: 34, height: 38)
      }
      .buttonStyle(.plain).disabled(store.history.isEmpty).accessibilityLabel("Undo")
      .keyboardShortcut("z", modifiers: .command)
      Menu {
        Button("Clear artwork", role: .destructive) { clearConfirm = true }
        Button("Delete shot", role: .destructive) { deleteConfirm = true }.disabled(
          store.project.shots.count == 1)
        Button(inspector ? "Hide shot details" : "Show shot details") { inspector.toggle() }
        Button("Add scene") { showScene = true }
      } label: {
        Image(systemName: "ellipsis").frame(width: 34, height: 38)
      }
      .accessibilityLabel("Frame actions")
    }.padding(.horizontal, 10).padding(.vertical, 5).background(Palette.elevated.opacity(0.55))
      .clipShape(RoundedRectangle(cornerRadius: 9))
  }

  private var filmstrip: some View {
    VStack(spacing: 14) {
      HStack {
        eyebrow("THE SEQUENCE")
        Text("·  \(store.project.shots.count) SHOTS").font(.system(size: 10, design: .monospaced))
          .foregroundStyle(Palette.muted)
        Spacer()
        Button {
          store.edit { $0.moveShot(store.selectedID, by: -1) }
        } label: {
          Image(systemName: "arrow.left").frame(width: 32, height: 32)
        }.disabled(store.selectedIndex == 0).accessibilityLabel("Move shot earlier")
        Button {
          store.edit { $0.moveShot(store.selectedID, by: 1) }
        } label: {
          Image(systemName: "arrow.right").frame(width: 32, height: 32)
        }.disabled(store.selectedIndex == store.project.shots.count - 1).accessibilityLabel(
          "Move shot later")
        Button {
          store.addShot()
        } label: {
          Label("Add shot", systemImage: "plus").font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(StudioButton(accent: true)).accessibilityIdentifier("addShot")
      }
      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(Array(store.project.shots.enumerated()), id: \.element.id) { index, shot in
              Button {
                store.selectedID = shot.id
              } label: {
                VStack(alignment: .leading, spacing: 8) {
                  ZStack(alignment: .bottomLeading) {
                    InkThumbnail(shot: shot).frame(width: 151, height: 74).clipped()
                    Text(String(format: "%02d", index + 1))
                      .font(.system(size: 10, weight: .bold, design: .monospaced))
                      .foregroundStyle(Color.black).padding(.horizontal, 6).padding(.vertical, 4)
                      .background(store.selectedID == shot.id ? Palette.yellow : Palette.ivory)
                  }
                  HStack(spacing: 4) {
                    Text(shot.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 1)
                    Text("\(shot.duration)s").font(.system(size: 10, design: .monospaced))
                      .foregroundStyle(Palette.muted)
                  }.frame(width: 151)
                }.contentShape(Rectangle()).padding(7)
                  .background(store.selectedID == shot.id ? Palette.elevated : .clear)
                  .overlay(
                    RoundedRectangle(cornerRadius: 6).stroke(
                      store.selectedID == shot.id ? Palette.yellow : Color.white.opacity(0.12),
                      lineWidth: 1))
              }.buttonStyle(.plain).id(shot.id).accessibilityLabel(
                "Shot \(index + 1): \(shot.title)")
            }
          }.padding(2)
        }.onChange(of: store.selectedID) { _, id in
          withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .center) }
        }
      }
    }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 20)
      .background(Palette.panel.opacity(0.65))
  }

  private var footer: some View {
    HStack {
      Circle().fill(store.saved ? Palette.yellow : .red).frame(width: 5, height: 5)
      Text(store.saved ? "All changes saved on this iPad" : "Changes not saved").font(
        .system(size: 10))
      Spacer()
      Text("A FILM STARTS WITH A FRAME.").font(.system(size: 9, design: .monospaced)).tracking(2)
    }.foregroundStyle(Palette.muted).padding(.horizontal, 25).frame(height: 30)
  }

  private func exportPDF() {
    do { pdf = ExportedPDF(url: try StoryboardPDF.export(store.project)) } catch {
      store.error = error.localizedDescription
    }
  }
}

func eyebrow(_ text: String) -> some View {
  Text(text).font(.system(size: 10, weight: .semibold, design: .monospaced))
    .tracking(1.3).foregroundStyle(Palette.muted)
}

struct StudioButton: ButtonStyle {
  var accent = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(accent ? Palette.background : Palette.ivory)
      .padding(.horizontal, 15).frame(minHeight: 40)
      .background(accent ? Palette.yellow : Palette.elevated)
      .clipShape(RoundedRectangle(cornerRadius: 7))
      .opacity(configuration.isPressed ? 0.65 : 1)
  }
}

struct InspectorView: View {
  @EnvironmentObject private var store: StudioStore
  @State private var title = ""
  @State private var notes = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 23) {
        HStack {
          eyebrow("SHOT DETAILS")
          Spacer()
          Image(systemName: "slider.horizontal.3").foregroundStyle(Palette.muted).font(
            .system(size: 13))
        }
        VStack(alignment: .leading, spacing: 10) {
          eyebrow("FRAME TITLE")
          TextField("Give this shot a title", text: $title, axis: .vertical)
            .font(.system(size: 19, design: .serif)).lineLimit(1...3)
            .accessibilityIdentifier("shotTitle")
            .onChange(of: title) { _, value in
              let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
              if !trimmed.isEmpty && trimmed != store.shot.title {
                store.editShot { $0.title = String(trimmed.prefix(100)) }
              }
            }
        }
        divider
        VStack(alignment: .leading, spacing: 10) {
          eyebrow("SHOT SIZE")
          Picker(
            "Shot size",
            selection: Binding(
              get: { store.shot.size }, set: { value in store.editShot { $0.size = value } })
          ) {
            ForEach(ShotSize.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }.pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            .padding(6).background(Palette.elevated).clipShape(RoundedRectangle(cornerRadius: 7))
        }
        VStack(alignment: .leading, spacing: 10) {
          eyebrow("CAMERA MOVEMENT")
          Picker(
            "Camera movement",
            selection: Binding(
              get: { store.shot.movement }, set: { value in store.editShot { $0.movement = value } }
            )
          ) {
            ForEach(CameraMove.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }.pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            .padding(6).background(Palette.elevated).clipShape(RoundedRectangle(cornerRadius: 7))
        }
        VStack(alignment: .leading, spacing: 11) {
          eyebrow("DURATION")
          HStack {
            Button {
              store.editShot { $0.duration = max(1, $0.duration - 1) }
            } label: {
              Image(systemName: "minus").frame(width: 40, height: 42)
            }.disabled(store.shot.duration == 1).accessibilityLabel("Decrease duration")
            Spacer()
            Text("\(store.shot.duration)").font(
              .system(size: 26, weight: .light, design: .monospaced))
            Text("sec").font(.system(size: 11)).foregroundStyle(Palette.muted)
            Spacer()
            Button {
              store.editShot { $0.duration = min(120, $0.duration + 1) }
            } label: {
              Image(systemName: "plus").frame(width: 40, height: 42)
            }.disabled(store.shot.duration == 120).accessibilityLabel("Increase duration")
          }.background(Palette.elevated).clipShape(RoundedRectangle(cornerRadius: 7))
        }
        divider
        VStack(alignment: .leading, spacing: 11) {
          eyebrow("DIRECTOR'S NOTES")
          TextEditor(text: $notes).font(.system(size: 13)).lineSpacing(5)
            .scrollContentBackground(.hidden).frame(minHeight: 120)
            .accessibilityIdentifier("directorNotes")
            .onChange(of: notes) { _, value in
              if value != store.shot.notes {
                store.editShot { $0.notes = String(value.prefix(1000)) }
              }
            }
        }
        Text("Sketch with your finger, Pencil or mouse. Your frames stay editable.")
          .font(.system(size: 11)).lineSpacing(4).foregroundStyle(Palette.muted)
      }.padding(23)
    }
    .onAppear { sync() }
    .onChange(of: store.selectedID) { _, _ in sync() }
    .onChange(of: store.project) { _, _ in
      if title != store.shot.title && !title.isEmpty { title = store.shot.title }
      if notes != store.shot.notes { notes = store.shot.notes }
    }
  }

  private var divider: some View { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
  private func sync() {
    title = store.shot.title
    notes = store.shot.notes
  }
}
