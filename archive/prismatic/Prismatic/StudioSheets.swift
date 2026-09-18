import SwiftUI

struct SheetHeading: View {
  var eyebrow: String
  var title: String
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 6) {
        Text(eyebrow).font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2)
          .foregroundStyle(Atelier.muted)
        Text(title).font(.system(.largeTitle, design: .serif))
      }
      Spacer()
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark").font(.system(size: 14, weight: .medium))
          .frame(width: 44, height: 44).background(Atelier.panel, in: Circle())
      }.accessibilityLabel("Close")
    }.padding(.top, 10)
  }
}

struct BrushSheet: View {
  @Bindable var studio: Studio
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(spacing: 10) {
          ForEach(Brush.allCases) { brush in
            Button {
              studio.settings.brush = brush
            } label: {
              let layout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(spacing: 20))
              layout {
                BrushPreview(
                  brush: brush, pigment: studio.settings.pigment, weight: studio.settings.width
                ).frame(
                  width: 80, height: 44)
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(brush.title).font(.headline)
                    Text(brush.subtitle).font(.caption).foregroundStyle(Atelier.muted)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                  Spacer(minLength: 0)
                  if studio.settings.brush == brush {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Atelier.ivory)
                  }
                }
              }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(Atelier.panel, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                  RoundedRectangle(cornerRadius: 20).stroke(
                    studio.settings.brush == brush ? Atelier.ivory.opacity(0.5) : .clear))
            }.buttonStyle(.plain).accessibilityAddTraits(
              studio.settings.brush == brush ? .isSelected : [])
          }
        }
        VStack(spacing: 10) {
          HStack {
            Text("Stroke weight").font(.subheadline)
            Spacer()
            Text(studio.settings.width, format: .number.precision(.fractionLength(1)))
              .font(.system(.subheadline, design: .monospaced))
          }
          Slider(value: $studio.settings.width, in: 0.8...7, step: 0.1).accessibilityLabel(
            "Stroke weight")
        }
        Text("Changes apply to your next stroke. Existing marks keep their character.")
          .font(.footnote).foregroundStyle(Atelier.muted)
      }.padding(24)
    }
    .background(Atelier.background).foregroundStyle(Atelier.ivory)
    .safeAreaInset(edge: .top) {
      SheetHeading(eyebrow: "THE TOOL CABINET", title: "A different feeling.")
        .padding(.horizontal, 24).padding(.bottom, 12).background(Atelier.background)
    }
    .presentationDetents([.height(580), .large]).presentationDragIndicator(.visible)
  }
}

struct SymmetrySheet: View {
  @Bindable var studio: Studio
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 25) {
        HStack(spacing: 24) {
          SymmetryDiagram(count: studio.settings.symmetry, mirror: studio.settings.mirror)
            .frame(width: 120, height: 120)
          VStack(alignment: .leading, spacing: 7) {
            Text("\(studio.settings.symmetry)").font(
              .system(size: 54, weight: .light, design: .serif))
            Text(studio.settings.mirror ? "axes · mirrored" : "axes · radial").font(.subheadline)
              .foregroundStyle(Atelier.muted)
          }
        }.frame(maxWidth: .infinity)
        VStack(spacing: 14) {
          Slider(
            value: Binding(
              get: { Double(studio.settings.symmetry) }, set: { studio.settings.symmetry = Int($0) }
            ), in: 1...24, step: 1
          )
          .accessibilityLabel("Symmetry axes").accessibilityValue("\(studio.settings.symmetry)")
          HStack {
            ForEach([4, 6, 8, 12, 16, 24], id: \.self) { count in
              Button {
                studio.settings.symmetry = count
              } label: {
                Text("\(count)").font(.subheadline.monospacedDigit())
                  .frame(maxWidth: .infinity).frame(height: 44)
                  .background(
                    studio.settings.symmetry == count ? Atelier.ivory : Atelier.panel, in: Capsule()
                  )
                  .foregroundStyle(
                    studio.settings.symmetry == count ? Atelier.background : Atelier.ivory)
              }.accessibilityLabel("\(count) axes")
            }
          }
        }
        Toggle("Mirror each stroke", isOn: $studio.settings.mirror).tint(
          Color(uiColor: UIColor(hex: "548B7C")))
        Toggle("Delicate axis guides", isOn: $studio.settings.guides).tint(
          Color(uiColor: UIColor(hex: "548B7C")))
        Text("New strokes use this symmetry. Your existing artwork stays exactly as you drew it.")
          .font(.footnote).foregroundStyle(Atelier.muted)
      }.padding(24)
    }
    .background(Atelier.background).foregroundStyle(Atelier.ivory)
    .safeAreaInset(edge: .top) {
      SheetHeading(eyebrow: "FIND YOUR RHYTHM", title: "One line, multiplied.")
        .padding(.horizontal, 24).padding(.bottom, 12).background(Atelier.background)
    }
    .presentationDetents([.height(590), .large]).presentationDragIndicator(.visible)
  }
}

struct SymmetryDiagram: View {
  var count: Int
  var mirror: Bool
  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      context.stroke(
        Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 5, dy: 5)),
        with: .color(Atelier.muted.opacity(0.3)), lineWidth: 0.5)
      for axis in 0..<count {
        var rotated = context
        rotated.translateBy(x: center.x, y: center.y)
        rotated.rotate(by: .degrees(Double(axis) * 360 / Double(count)))
        var path = Path()
        path.move(to: .zero)
        path.addQuadCurve(
          to: CGPoint(x: 0, y: -size.height * 0.44), control: CGPoint(x: 23, y: -size.height * 0.22)
        )
        rotated.stroke(path, with: .color(Color(uiColor: UIColor(hex: "83EAC3"))), lineWidth: 1)
        if mirror {
          rotated.scaleBy(x: -1, y: 1)
          rotated.stroke(path, with: .color(Atelier.ivory.opacity(0.5)), lineWidth: 0.6)
        }
      }
    }.accessibilityHidden(true)
  }
}

struct PigmentSheet: View {
  @Bindable var studio: Studio
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        ForEach(Palette.allCases) { palette in
          Button {
            studio.settings.palette = palette.rawValue
            studio.settings.pigment = palette.colors[1].hex
          } label: {
            VStack(alignment: .leading, spacing: 17) {
              HStack {
                Text(palette.title).font(.system(.title2, design: .serif))
                Spacer()
                if studio.settings.palette == palette.rawValue { Image(systemName: "checkmark") }
              }
              HStack(spacing: 0) {
                ForEach(palette.colors) { pigment in
                  Rectangle().fill(Color(uiColor: UIColor(hex: pigment.hex))).frame(height: 42)
                }
              }.clipShape(RoundedRectangle(cornerRadius: 10))
            }.padding(20).background(Atelier.panel, in: RoundedRectangle(cornerRadius: 20))
          }.buttonStyle(.plain).accessibilityLabel("\(palette.title) palette")
            .accessibilityAddTraits(studio.settings.palette == palette.rawValue ? .isSelected : [])
        }
      }.padding(24)
    }.background(Atelier.background).foregroundStyle(Atelier.ivory)
      .safeAreaInset(edge: .top) {
        SheetHeading(eyebrow: "THE PIGMENT LIBRARY", title: "Color, collected.")
          .padding(.horizontal, 24).padding(.bottom, 12).background(Atelier.background)
      }
      .presentationDetents([.height(590), .large]).presentationDragIndicator(.visible)
  }
}

struct GallerySheet: View {
  @Bindable var studio: Studio
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var pendingOpen: Artwork?
  @State private var pendingDelete: Artwork?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        Text("Saved pieces").font(.headline)
        if studio.gallery.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("Make something only you could.")
              .font(.system(.title2, design: .serif))
            Text(
              "Save a piece from the studio and it will live here. Everything stays on this device."
            )
            .font(.subheadline).foregroundStyle(Atelier.muted)
          }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(Atelier.panel, in: RoundedRectangle(cornerRadius: 20))
        } else {
          LazyVGrid(
            columns: Array(
              repeating: GridItem(.flexible()),
              count: dynamicTypeSize.isAccessibilitySize || studio.gallery.count == 1 ? 1 : 2),
            spacing: 24
          ) {
            ForEach(studio.gallery) { artwork in
              let layout =
                studio.gallery.count == 1 && !dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 18))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
              layout {
                Button {
                  requestOpen(artwork)
                } label: {
                  ArtThumbnail(artwork: artwork)
                    .frame(
                      maxWidth: studio.gallery.count == 1 && !dynamicTypeSize.isAccessibilitySize
                        ? 150 : .infinity
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Atelier.muted.opacity(0.15)))
                }.accessibilityLabel("Open \(artwork.title)")
                HStack(alignment: .top) {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(artwork.title).font(.subheadline.weight(.medium))
                    Text(
                      "\(artwork.strokes.count) \(artwork.strokes.count == 1 ? "stroke" : "strokes")"
                    ).font(.caption).foregroundStyle(
                      Atelier.muted)
                    if studio.gallery.count == 1 {
                      Button("Continue drawing") { requestOpen(artwork) }
                        .font(.caption.weight(.medium)).padding(.top, 8)
                        .frame(minHeight: 44).accessibilityLabel(
                          "Continue drawing \(artwork.title)")
                    }
                  }
                  Spacer(minLength: 0)
                  Button {
                    pendingDelete = artwork
                  } label: {
                    Image(systemName: "trash").font(.caption).frame(width: 44, height: 44)
                  }.accessibilityLabel("Delete \(artwork.title)")
                }
              }
            }
          }
        }
        VStack(alignment: .leading, spacing: 6) {
          Text("A place to begin").font(.system(.title2, design: .serif))
          Text("Editable samples · add your own mark").font(.subheadline).foregroundStyle(
            Atelier.muted)
        }.padding(.top, 8)
        LazyVGrid(
          columns: Array(
            repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
          spacing: 16
        ) {
          ForEach(Samples.all) { artwork in
            Button {
              requestOpen(artwork)
            } label: {
              VStack(alignment: .leading, spacing: 9) {
                ArtThumbnail(artwork: artwork).clipShape(RoundedRectangle(cornerRadius: 16))
                Text(artwork.title).font(.subheadline)
                Text("SAMPLE").font(.system(size: 9, design: .monospaced)).tracking(2)
                  .foregroundStyle(Atelier.muted)
              }
            }.buttonStyle(.plain).accessibilityLabel("Open \(artwork.title) editable sample")
          }
        }
        Text("No account. No cloud. Just you and your work.")
          .font(.footnote).foregroundStyle(Atelier.muted).padding(.top, 20)
      }.padding(24)
    }
    .background(Atelier.background).foregroundStyle(Atelier.ivory)
    .safeAreaInset(edge: .top) {
      SheetHeading(eyebrow: "YOUR PRIVATE COLLECTION", title: "The gallery.")
        .padding(.horizontal, 24).padding(.bottom, 12).background(Atelier.background)
    }
    .presentationDragIndicator(.visible)
    .alert(
      "Open this piece?",
      isPresented: Binding(get: { pendingOpen != nil }, set: { if !$0 { pendingOpen = nil } })
    ) {
      Button("Save current & open") {
        if let artwork = pendingOpen {
          studio.save(title: studio.current.title)
          studio.open(artwork)
          dismiss()
        }
      }
      Button("Open without saving", role: .destructive) {
        if let artwork = pendingOpen {
          studio.open(artwork)
          dismiss()
        }
      }
      Button("Cancel", role: .cancel) { pendingOpen = nil }
    } message: {
      Text("Save your current canvas first if you want to keep this version.")
    }
    .alert(
      "Delete saved artwork?",
      isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    ) {
      Button("Delete", role: .destructive) {
        if let artwork = pendingDelete { studio.delete(artwork) }
      }
      Button("Cancel", role: .cancel) { pendingDelete = nil }
    } message: {
      Text("This removes it from the gallery. Your current canvas is not affected.")
    }
  }

  private func requestOpen(_ artwork: Artwork) {
    if studio.current == artwork || studio.current.strokes.isEmpty {
      studio.open(artwork)
      dismiss()
    } else {
      pendingOpen = artwork
    }
  }
}
