import SwiftUI

private let ink = Color(red: 0.035, green: 0.038, blue: 0.036)
private let paper = Color(red: 0.95, green: 0.92, blue: 0.85)
private let amber = Color(red: 0.91, green: 0.66, blue: 0.33)
private let muted = Color(red: 0.59, green: 0.58, blue: 0.54)

private enum Tool: String, CaseIterable {
  case looks = "Looks"
  case light = "Light"
  case crop = "Crop"
  var icon: String {
    switch self {
    case .looks: "camera.filters"
    case .light: "slider.horizontal.3"
    case .crop: "crop.rotate"
    }
  }
}

private enum Tone: String, CaseIterable {
  case exposure = "Exposure"
  case contrast = "Contrast"
  case saturation = "Color"
  case warmth = "Warmth"
  var key: WritableKeyPath<Edit, Double> {
    switch self {
    case .exposure: \.exposure
    case .contrast: \.contrast
    case .saturation: \.saturation
    case .warmth: \.warmth
    }
  }
  var range: ClosedRange<Double> {
    switch self {
    case .exposure: -2...2
    case .contrast: 0.5...1.5
    case .saturation: 0...2
    case .warmth: -1...1
    }
  }
  func display(_ value: Double) -> String {
    switch self {
    case .exposure: String(format: "%+.2f EV", value)
    case .contrast, .saturation: String(format: "%.0f", value * 100)
    case .warmth: String(format: "%+.0f", value * 100)
    }
  }
}

struct DarkroomView: View {
  @StateObject private var store = EditorStore()
  @State private var tool: Tool = .looks
  @State private var tone: Tone = .exposure
  @State private var comparing = false
  @State private var resetting = false
  @State private var panStart: Edit?

  var body: some View {
    GeometryReader { geometry in
      ScrollView(.vertical) {
        VStack(spacing: 0) {
          header
          photoTitle
          canvas
            .frame(height: max(240, geometry.size.height - 405))
          photoStrip.padding(.top, 12).padding(.bottom, 10)
          toolPicker
          controls.frame(height: 121)
          footer
        }
        .frame(minHeight: geometry.size.height, alignment: .top)
      }
      .scrollIndicators(.hidden)
    }
    .background(ink)
    .foregroundStyle(paper)
    .tint(amber)
    .sheet(item: $store.exported) { ExportView(export: $0) }
    .alert(
      "Darkroom notice",
      isPresented: Binding(
        get: { store.error != nil }, set: { if !$0 { store.error = nil } }
      )
    ) {
      Button("Continue", role: .cancel) { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .confirmationDialog(
      "Return to the original negative?", isPresented: $resetting, titleVisibility: .visible
    ) {
      Button("Reset all edits", role: .destructive) { store.change { $0 = Edit() } }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("You can undo this. Your original photograph is always preserved.")
    }
  }

  private var header: some View {
    HStack(alignment: .center) {
      HStack(spacing: 8) {
        Image(systemName: "circle.lefthalf.filled")
          .foregroundStyle(amber).font(.system(size: 19, weight: .light))
        Text("afterglow").font(.system(size: 29, weight: .regular, design: .serif))
          .tracking(-1.3)
      }
      Spacer()
      Button(action: store.export) {
        HStack(spacing: 6) {
          if store.exporting {
            ProgressView().tint(ink)
          } else {
            Image(systemName: "arrow.up.right")
          }
          Text(store.exporting ? "Saving" : "Export")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(ink)
        .padding(.horizontal, 16).frame(height: 38)
        .background(amber, in: Capsule())
      }
      .disabled(store.exporting)
      .accessibilityIdentifier("export")
    }
    .padding(.horizontal, 22).frame(height: 52)
  }

  private var photoTitle: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 4) {
        Text(store.photo.title).font(.system(size: 18, weight: .regular, design: .serif))
        Text(store.photo.subtitle).font(.system(size: 8, weight: .medium))
          .tracking(2.1).foregroundStyle(muted)
      }
      Spacer()
      Text("\(store.photo.number) / 03").font(.system(size: 10, design: .monospaced))
        .foregroundStyle(muted)
    }
    .padding(.horizontal, 23).frame(height: 58)
  }

  private var canvas: some View {
    GeometryReader { geometry in
      ZStack {
        Color.black
        if let image = comparing ? store.photo.image : store.preview {
          Image(uiImage: image)
            .resizable().scaledToFit()
            .overlay {
              if tool == .crop && !comparing {
                GridOverlay().stroke(paper.opacity(0.35), lineWidth: 0.5)
                  .allowsHitTesting(false)
              }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .accessibilityLabel(comparing ? "Original photograph" : "Edited photograph")
        } else {
          ProgressView().tint(amber)
        }
        if tool == .crop && !comparing {
          VStack {
            Text("DRAG TO REFRAME").font(.system(size: 8, weight: .medium)).tracking(2)
              .padding(8).background(.black.opacity(0.65), in: Capsule())
            Spacer()
          }.padding(.top, 14).allowsHitTesting(false)
        }
        VStack {
          HStack {
            Text(comparing ? "ORIGINAL" : store.draft.look.rawValue.uppercased())
              .font(.system(size: 8, weight: .semibold)).tracking(1.5)
              .padding(.horizontal, 11).padding(.vertical, 7)
              .background(.black.opacity(0.55), in: Capsule())
            Spacer()
            if store.rendering { ProgressView().scaleEffect(0.7) }
          }
          Spacer()
          HStack {
            Spacer()
            Text(comparing ? "Original negative" : "Hold to compare")
              .font(.system(size: 10, weight: .medium))
              .padding(.horizontal, 12).padding(.vertical, 9)
              .background(.black.opacity(0.7), in: Capsule())
              .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5))
              .gesture(
                DragGesture(minimumDistance: 0)
                  .onChanged { _ in comparing = true }
                  .onEnded { _ in comparing = false }
              )
              .accessibilityLabel("Compare original")
              .accessibilityHint("Touch and hold to see the unedited original")
              .accessibilityAddTraits(.isButton)
              .accessibilityAction { comparing.toggle() }
              .accessibilityIdentifier("compare")
          }
        }.padding(15)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 8)
          .onChanged { value in
            guard tool == .crop else { return }
            if panStart == nil { panStart = store.draft }
            guard let start = panStart else { return }
            store.draft.panX = min(1, max(-1, start.panX - value.translation.width / 120))
            store.draft.panY = min(1, max(-1, start.panY + value.translation.height / 120))
            store.render()
          }
          .onEnded { _ in
            if panStart != nil { store.commit() }
            panStart = nil
          }
      )
    }
  }

  private var photoStrip: some View {
    HStack(spacing: 10) {
      ForEach(SamplePhoto.all) { photo in
        Button {
          store.select(photo)
        } label: {
          HStack(spacing: 8) {
            if let image = photo.image {
              Image(uiImage: image).resizable().scaledToFill()
                .frame(width: 37, height: 45).clipped()
            }
            VStack(alignment: .leading, spacing: 4) {
              Text(photo.number).font(.system(size: 10, design: .monospaced))
              Rectangle().fill(photo.id == store.photo.id ? amber : muted.opacity(0.3))
                .frame(width: 16, height: 1)
            }
            Spacer(minLength: 0)
          }
          .padding(5).frame(maxWidth: .infinity)
          .background(photo.id == store.photo.id ? Color.white.opacity(0.06) : .clear)
          .overlay(
            RoundedRectangle(cornerRadius: 3)
              .stroke(
                photo.id == store.photo.id ? amber.opacity(0.8) : .white.opacity(0.09), lineWidth: 1
              )
          )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(photo.title)")
        .accessibilityIdentifier("photo-\(photo.id)")
      }
    }.padding(.horizontal, 22)
  }

  private var toolPicker: some View {
    HStack(spacing: 0) {
      ForEach(Tool.allCases, id: \.self) { item in
        Button {
          tool = item
        } label: {
          VStack(spacing: 10) {
            HStack(spacing: 7) {
              Image(systemName: item.icon).font(.system(size: 12))
              Text(item.rawValue.uppercased()).font(.system(size: 10, weight: .medium))
                .tracking(1.6)
            }.foregroundStyle(tool == item ? paper : muted)
            Rectangle().fill(tool == item ? amber : .clear).frame(height: 1)
          }.padding(.top, 10).frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain).accessibilityIdentifier("tool-\(item.rawValue.lowercased())")
      }
    }
    .background(Color.white.opacity(0.025))
    .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5) }
  }

  @ViewBuilder private var controls: some View {
    switch tool {
    case .looks: looks
    case .light: light
    case .crop: crop
    }
  }

  private var looks: some View {
    VStack(spacing: 7) {
      HStack(spacing: 11) {
        ForEach(FilmLook.allCases, id: \.self) { look in
          Button {
            store.change { $0.look = look }
          } label: {
            VStack(spacing: 6) {
              Group {
                if let image = store.thumbnails[look] {
                  Image(uiImage: image).resizable().scaledToFill()
                } else {
                  Color.gray.opacity(0.2)
                }
              }
              .frame(height: 52).clipped()
              .overlay(alignment: .bottomTrailing) {
                if store.draft.look == look {
                  Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                    .foregroundStyle(ink).padding(4).background(amber, in: Circle()).padding(3)
                }
              }
              .overlay(Rectangle().stroke(store.draft.look == look ? amber : .clear, lineWidth: 1))
              Text(look.rawValue).font(.system(size: 9, weight: .medium))
                .foregroundStyle(store.draft.look == look ? amber : muted)
            }.frame(maxWidth: .infinity)
          }
          .buttonStyle(.plain).accessibilityLabel("\(look.rawValue) look")
          .accessibilityIdentifier("look-\(look.rawValue.lowercased())")
        }
      }
      Text(store.draft.look.note).font(.system(size: 9)).foregroundStyle(muted)
    }.padding(.horizontal, 23)
  }

  private var light: some View {
    VStack(spacing: 13) {
      HStack(spacing: 4) {
        ForEach(Tone.allCases, id: \.self) { value in
          Button {
            tone = value
          } label: {
            Text(value.rawValue).font(.system(size: 11, weight: .medium))
              .frame(maxWidth: .infinity).frame(height: 30)
              .background(tone == value ? paper.opacity(0.09) : .clear, in: Capsule())
              .foregroundStyle(tone == value ? paper : muted)
          }.buttonStyle(.plain)
        }
      }
      HStack(spacing: 13) {
        Image(systemName: tone == .exposure ? "sun.min" : "minus")
          .font(.system(size: 12)).foregroundStyle(muted)
        PrecisionSlider(
          value: Binding(
            get: { store.draft[keyPath: tone.key] },
            set: {
              store.draft[keyPath: tone.key] = $0
              store.render()
            }
          ), range: tone.range, onCommit: store.commit
        )
        .accessibilityLabel(tone.rawValue)
        .accessibilityValue(tone.display(store.draft[keyPath: tone.key]))
        .accessibilityIdentifier("tone-slider")
        Text(tone.display(store.draft[keyPath: tone.key]))
          .font(.system(size: 11, design: .monospaced)).foregroundStyle(amber)
          .frame(width: 68, alignment: .trailing)
      }
    }.padding(.horizontal, 23)
  }

  private var crop: some View {
    VStack(spacing: 10) {
      HStack(spacing: 8) {
        ForEach(CropFormat.allCases, id: \.self) { format in
          Button {
            store.change {
              $0.crop = format
              $0.panX = 0
              $0.panY = 0
            }
          } label: {
            Text(format.rawValue).font(.system(size: 11, weight: .medium))
              .frame(maxWidth: .infinity).frame(height: 34)
              .background(store.draft.crop == format ? amber : paper.opacity(0.06), in: Capsule())
              .foregroundStyle(store.draft.crop == format ? ink : paper)
          }.buttonStyle(.plain).accessibilityLabel("Crop \(format.rawValue)")
        }
        Button {
          store.change { $0.rotation = ($0.rotation + 1) % 4 }
        } label: {
          Image(systemName: "rotate.right").frame(width: 40, height: 36)
        }.accessibilityLabel("Rotate clockwise").accessibilityIdentifier("rotate")
      }
      HStack(spacing: 13) {
        Text("ZOOM").font(.system(size: 8, weight: .medium)).tracking(1.4).foregroundStyle(muted)
        PrecisionSlider(
          value: Binding(
            get: { store.draft.zoom },
            set: {
              store.draft.zoom = $0
              store.render()
            }),
          range: 1...2.5, onCommit: store.commit
        ).accessibilityLabel("Crop zoom")
        Text(String(format: "%.2f×", store.draft.zoom))
          .font(.system(size: 10, design: .monospaced)).foregroundStyle(amber)
      }
    }.padding(.horizontal, 23)
  }

  private var footer: some View {
    HStack(spacing: 5) {
      Circle().fill(store.status == "Save failed" ? .red : amber).frame(width: 4, height: 4)
      Text(store.status).font(.system(size: 9)).foregroundStyle(muted)
      Spacer()
      Button(action: store.undo) {
        Image(systemName: "arrow.uturn.backward").frame(width: 35, height: 40)
      }
      .disabled(!store.history.canUndo).accessibilityLabel("Undo").accessibilityIdentifier("undo")
      Button(action: store.redo) {
        Image(systemName: "arrow.uturn.forward").frame(width: 35, height: 40)
      }
      .disabled(!store.history.canRedo).accessibilityLabel("Redo").accessibilityIdentifier("redo")
      Rectangle().fill(muted.opacity(0.25)).frame(width: 1, height: 13).padding(.horizontal, 7)
      Button {
        resetting = true
      } label: {
        Text("Reset").font(.system(size: 10)).frame(height: 40)
      }.disabled(!store.isEdited).accessibilityIdentifier("reset")
    }
    .foregroundStyle(paper).padding(.horizontal, 23)
    .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5) }
  }
}

private struct PrecisionSlider: View {
  @Binding var value: Double
  let range: ClosedRange<Double>
  let onCommit: () -> Void

  private var fraction: Double {
    min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
  }

  var body: some View {
    GeometryReader { geometry in
      let width = max(1, geometry.size.width - 18)
      ZStack(alignment: .leading) {
        Capsule().fill(paper.opacity(0.1)).frame(height: 2)
        Capsule().fill(amber.opacity(0.6))
          .frame(width: width * fraction, height: 2).padding(.leading, 9)
        HStack(spacing: 0) {
          ForEach(0..<21) { index in
            Rectangle().fill(index == 10 ? paper.opacity(0.6) : muted.opacity(0.4))
              .frame(width: 1, height: index % 5 == 0 ? 15 : 7)
            if index != 20 { Spacer(minLength: 0) }
          }
        }.padding(.horizontal, 9)
        RoundedRectangle(cornerRadius: 5)
          .fill(paper)
          .frame(width: 18, height: 28)
          .overlay {
            RoundedRectangle(cornerRadius: 1).fill(ink.opacity(0.45))
              .frame(width: 2, height: 11)
          }
          .offset(x: width * fraction)
      }
      .frame(height: 44)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            let position = min(1, max(0, (gesture.location.x - 9) / width))
            value = range.lowerBound + position * (range.upperBound - range.lowerBound)
          }
          .onEnded { _ in onCommit() }
      )
    }
    .frame(height: 44)
    .accessibilityElement(children: .ignore)
    .accessibilityAdjustableAction { direction in
      let step = (range.upperBound - range.lowerBound) / 40
      switch direction {
      case .increment: value = min(range.upperBound, value + step)
      case .decrement: value = max(range.lowerBound, value - step)
      @unknown default: return
      }
      onCommit()
    }
  }
}

private struct GridOverlay: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.addRect(rect)
      for fraction in [1.0 / 3, 2.0 / 3] {
        path.move(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
      }
    }
  }
}

private struct ExportView: View {
  let export: ExportedPhoto
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    VStack(spacing: 18) {
      HStack {
        Text("A moment, made yours.").font(.system(size: 24, design: .serif))
        Spacer()
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark").font(.system(size: 13)).frame(width: 36, height: 36)
            .background(.white.opacity(0.08), in: Circle())
        }.accessibilityLabel("Close export")
      }
      Image(uiImage: export.image).resizable().scaledToFit().frame(maxHeight: 420)
      VStack(spacing: 8) {
        Label("Developed & saved", systemImage: "checkmark.circle")
          .font(.system(size: 15, weight: .medium)).foregroundStyle(amber)
        Text("JPEG  ·  \(export.width) × \(export.height)  ·  \(export.bytes / 1024) KB")
          .font(.system(size: 11, design: .monospaced)).foregroundStyle(muted)
        Text(
          "Your full-resolution edit is in Afterglow’s Exports folder.\nShare it or save a copy to Files."
        )
        .font(.system(size: 12)).foregroundStyle(muted)
        .multilineTextAlignment(.center).lineSpacing(4)
      }
      ShareLink(
        item: export.url, preview: SharePreview("Afterglow", image: Image(uiImage: export.image))
      ) {
        Label("Share image", systemImage: "square.and.arrow.up")
          .font(.system(size: 14, weight: .semibold)).foregroundStyle(ink)
          .frame(maxWidth: .infinity).frame(height: 50)
          .background(amber, in: Capsule())
      }.accessibilityIdentifier("share-export")
      Button("Back to the darkroom") { dismiss() }.font(.system(size: 12)).foregroundStyle(paper)
    }
    .padding(25).frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ink).foregroundStyle(paper)
    .presentationDragIndicator(.visible)
  }
}
