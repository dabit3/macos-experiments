import SwiftUI

enum ToolTab: String, CaseIterable {
  case looks = "Looks"
  case adjust = "Adjust"
  case frame = "Frame"
}

enum Adjustment: String, CaseIterable {
  case exposure = "Exposure"
  case contrast = "Contrast"
  case warmth = "Warmth"
  var range: ClosedRange<Double> {
    switch self {
    case .exposure: -2...2
    case .contrast: 0.5...1.5
    case .warmth: -1...1
    }
  }
  var neutral: Double { self == .contrast ? 1 : 0 }
  var lowerLabel: String {
    switch self {
    case .exposure: "−2 EV"
    case .contrast: "Softer"
    case .warmth: "Cool"
    }
  }
  var upperLabel: String {
    switch self {
    case .exposure: "+2 EV"
    case .contrast: "Deeper"
    case .warmth: "Warm"
    }
  }
}

struct EditorView: View {
  @EnvironmentObject private var library: LibraryStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @StateObject private var room: Darkroom
  let negative: Negative
  @State private var tab: ToolTab = .looks
  @State private var adjustment: Adjustment = .exposure
  @State private var comparing = false
  @State private var showReset = false
  @State private var showRecipes = false
  @State private var showSave = false
  @State private var recipeName = ""
  @State private var exportFile: ExportFile?
  @State private var saved = false

  init(negative: Negative) {
    self.negative = negative
    _room = StateObject(wrappedValue: Darkroom(settings: negative.settings))
  }

  var body: some View {
    VStack(spacing: 0) {
      toolbar
        .background(Palette.background)
      GeometryReader { geometry in
        ScrollView {
          VStack(spacing: 0) {
            photo(
              height: typeSize.isAccessibilitySize
                ? 180 : max(200, geometry.size.height - (tab == .adjust ? 410 : 365)))
            imageCaption
            tools
            footer
          }
          .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .clipped()
      }
    }
    .background(Palette.background)
    .foregroundStyle(Palette.silver)
    .task {
      do { await room.load(data: try library.data(for: negative)) } catch {
        room.error = error.localizedDescription
      }
    }
    .task(id: room.settings) {
      library.update(negative, settings: room.settings)
      await room.develop()
    }
    .sheet(isPresented: $showRecipes) {
      RecipeShelf(negative: negative) { recipe in
        room.apply(recipe)
        showRecipes = false
      }
    }
    .sheet(item: $exportFile) { file in
      ExportView(file: file, preview: room.preview, dimensions: room.outputSize)
    }
    .alert("Save a recipe", isPresented: $showSave) {
      TextField("Recipe name", text: $recipeName)
      Button("Cancel", role: .cancel) {}
      Button("Save") {
        library.addRecipe(name: recipeName, settings: room.settings)
        saved = true
      }
      .disabled(recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    } message: {
      Text(
        "Keep this look, exposure, contrast, and warmth for another photograph. Framing stays with this image."
      )
    }
    .confirmationDialog(
      "Return to the original?", isPresented: $showReset, titleVisibility: .visible
    ) {
      Button("Reset all edits", role: .destructive) {
        room.settings = EditSettings()
        comparing = false
      }
    } message: {
      Text(
        "The look, adjustments, rotation, and crop will be reset. Saved recipes stay in your collection."
      )
    }
    .alert(
      "Couldn’t complete that",
      isPresented: Binding(
        get: { room.error != nil }, set: { if !$0 { room.error = nil } })
    ) {
      Button("OK", role: .cancel) { room.error = nil }
    } message: {
      Text(room.error ?? "")
    }
    .sensoryFeedback(.selection, trigger: room.settings.film)
    .sensoryFeedback(.success, trigger: saved)
  }

  private var toolbar: some View {
    HStack {
      RoundControl(symbol: "chevron.left", label: "Back to library") { dismiss() }
      Spacer()
      VStack(spacing: 4) {
        Text("Darkroom").font(.system(.title3, design: .serif))
        Eyebrow(text: negative.title)
      }
      .lineLimit(1).minimumScaleFactor(0.75)
      Spacer()
      Button {
        Task {
          let directory = library.disk.directory.appendingPathComponent(
            "Exports", isDirectory: true)
          if let url = await room.export(directory: directory) { exportFile = ExportFile(url: url) }
        }
      } label: {
        Group {
          if room.exporting {
            ProgressView().tint(Palette.amber)
          } else {
            Image(systemName: "square.and.arrow.up").font(.system(size: 19))
          }
        }
        .frame(width: 46, height: 46).background(Palette.panel, in: Circle())
      }
      .disabled(room.preview == nil || room.exporting)
      .accessibilityLabel(room.exporting ? "Exporting" : "Export photograph")
    }
    .padding(.horizontal, 20).padding(.vertical, 12)
  }

  private func photo(height: CGFloat) -> some View {
    ZStack {
      Color.black.opacity(0.25)
      if let image = comparing ? room.original : room.preview {
        Image(uiImage: image).resizable().scaledToFit()
          .padding(8)
          .accessibilityLabel(
            comparing
              ? "Original photograph" : "Edited photograph, \(room.settings.film.title) look")
      } else {
        ProgressView("Developing…").tint(Palette.amber)
      }
      VStack {
        HStack {
          if comparing {
            Text("ORIGINAL").font(.system(.caption2, design: .monospaced)).tracking(2)
              .padding(9).background(.black.opacity(0.75))
          }
          Spacer()
          if room.rendering && room.preview != nil {
            ProgressView().tint(Palette.amber).padding(8).background(.black.opacity(0.6))
          }
        }
        Spacer()
      }
      .padding(14)
    }
    .frame(height: height)
    .contentShape(Rectangle())
    .onLongPressGesture(minimumDuration: 0.12, pressing: { comparing = $0 }) {}
    .overlay { Rectangle().stroke(Palette.line, lineWidth: 1) }
    .padding(.horizontal, 20)
  }

  private var imageCaption: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
      : AnyLayout(HStackLayout())
    return layout {
      Eyebrow(text: "\(Int(room.outputSize.width)) × \(Int(room.outputSize.height))")
      if !typeSize.isAccessibilitySize { Spacer() }
      Label(comparing ? "Original" : "Hold to compare", systemImage: "square.on.square")
        .font(.system(.caption, design: .monospaced)).fixedSize(horizontal: false, vertical: true)
    }
    .foregroundStyle(comparing ? Palette.amber : Palette.muted)
    .frame(minHeight: 46).contentShape(Rectangle())
    .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in comparing = pressing }) {}
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Compare with original")
    .accessibilityValue(comparing ? "Showing original" : "Showing edited photograph")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction { comparing.toggle() }
    .padding(.horizontal, 24)
    .padding(.vertical, typeSize.isAccessibilitySize ? 12 : 0)
  }

  private var tools: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ForEach(ToolTab.allCases, id: \.self) { item in
          Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { tab = item }
          } label: {
            VStack(spacing: 11) {
              Text(item.rawValue).font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
              Rectangle().fill(tab == item ? Palette.amber : .clear).frame(height: 2)
            }
            .foregroundStyle(tab == item ? Palette.amber : Palette.muted)
            .frame(maxWidth: .infinity).padding(.top, 14)
          }
          .accessibilityAddTraits(tab == item ? .isSelected : [])
        }
      }
      .padding(.horizontal, 24)
      Hairline()
      Group {
        switch tab {
        case .looks: filmstrip
        case .adjust: adjustmentPanel
        case .frame: framePanel
        }
      }
      .frame(minHeight: 164)
    }
  }

  private var filmstrip: some View {
    VStack(alignment: .leading, spacing: 12) {
      ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(Film.allCases) { film in
              Button {
                room.settings.film = film
              } label: {
                VStack(alignment: .leading, spacing: 6) {
                  ZStack(alignment: .topLeading) {
                    if let image = room.films[film] {
                      Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 68, height: 78).clipped()
                    } else {
                      Palette.panel.frame(width: 68, height: 78)
                    }
                    Text(film.code).font(.system(size: 8, design: .monospaced))
                      .padding(4).background(.black.opacity(0.5))
                  }
                  Text(film.title).font(.system(.caption, design: .monospaced))
                }
                .foregroundStyle(room.settings.film == film ? Palette.amber : Palette.muted)
                .padding(5)
                .overlay {
                  Rectangle().stroke(
                    room.settings.film == film ? Palette.amber : Palette.line, lineWidth: 1)
                }
              }
              .buttonStyle(.plain)
              .id(film)
              .accessibilityLabel("\(film.title) look")
              .accessibilityAddTraits(room.settings.film == film ? .isSelected : [])
            }
          }
          .padding(.horizontal, 24)
        }
        .onChange(of: room.settings.film) { _, film in
          withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            proxy.scrollTo(film, anchor: .center)
          }
        }
        .onAppear { proxy.scrollTo(room.settings.film, anchor: .center) }
      }
      Text(room.settings.film.note).font(.caption).foregroundStyle(Palette.muted)
        .padding(.horizontal, 24)
    }
    .padding(.vertical, 16)
  }

  private var adjustmentPanel: some View {
    VStack(spacing: 15) {
      if typeSize.isAccessibilitySize {
        Menu {
          Picker("Adjustment", selection: $adjustment) {
            ForEach(Adjustment.allCases, id: \.self) { item in
              Text(item.rawValue).tag(item)
            }
          }
        } label: {
          HStack {
            Text(adjustment.rawValue)
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
          }
          .font(.subheadline).foregroundStyle(Palette.silver)
          .padding(12).background(Palette.panel, in: RoundedRectangle(cornerRadius: 5))
        }
        .accessibilityLabel("Choose adjustment")
        .accessibilityValue(adjustment.rawValue)
      } else {
        HStack(spacing: 8) {
          ForEach(Adjustment.allCases, id: \.self) { item in
            Button {
              adjustment = item
            } label: {
              Text(item.rawValue).font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(adjustment == item ? Palette.panel : .clear, in: Capsule())
                .foregroundStyle(adjustment == item ? Palette.silver : Palette.muted)
            }
            .accessibilityAddTraits(adjustment == item ? .isSelected : [])
          }
        }
      }
      HStack {
        Button {
          adjustmentBinding.wrappedValue = adjustment.neutral
        } label: {
          Label("Neutral", systemImage: "arrow.uturn.backward")
            .font(.caption).frame(minHeight: 44)
        }
        .foregroundStyle(Palette.muted)
        .accessibilityLabel("Reset \(adjustment.rawValue.lowercased()) to neutral")
        Spacer()
        Text(valueText).font(.system(.subheadline, design: .monospaced)).foregroundStyle(
          Palette.amber)
      }
      ZStack {
        HStack {
          ForEach(0..<25) { index in
            Rectangle().fill(Palette.muted.opacity(0.45))
              .frame(width: 1, height: index.isMultiple(of: 6) ? 20 : 10)
            if index < 24 { Spacer(minLength: 0) }
          }
        }
        .padding(.horizontal, 3).offset(y: 12)
        Slider(value: adjustmentBinding, in: adjustment.range, step: 0.05)
          .tint(Palette.amber)
          .accessibilityLabel(adjustment.rawValue)
          .accessibilityValue(valueText)
      }
      .padding(.bottom, 8)
      HStack {
        Text(adjustment.lowerLabel)
        Spacer()
        Text(adjustment == .contrast ? "1.00" : "0")
          .foregroundStyle(Palette.amber)
        Spacer()
        Text(adjustment.upperLabel)
      }
      .font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.muted)
    }
    .padding(.horizontal, 24).padding(.vertical, 14)
  }

  private var adjustmentBinding: Binding<Double> {
    Binding(
      get: {
        switch adjustment {
        case .exposure: room.settings.exposure
        case .contrast: room.settings.contrast
        case .warmth: room.settings.warmth
        }
      },
      set: { value in
        switch adjustment {
        case .exposure: room.settings.exposure = value
        case .contrast: room.settings.contrast = value
        case .warmth: room.settings.warmth = value
        }
      })
  }

  private var valueText: String {
    switch adjustment {
    case .exposure: String(format: "%+.2f EV", room.settings.exposure)
    case .contrast: String(format: "%.2f×", room.settings.contrast)
    case .warmth: String(format: "%+.0f", room.settings.warmth * 100)
    }
  }

  private var framePanel: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
    return VStack(spacing: 17) {
      layout {
        frameButton("rotate.right", title: "Rotate 90°", active: false) {
          room.settings.quarterTurns = (room.settings.quarterTurns + 1) % 4
        }
        frameButton("rectangle", title: "Original ratio", active: !room.settings.squareCrop) {
          room.settings.squareCrop = false
        }
        frameButton("square", title: "Square", active: room.settings.squareCrop) {
          room.settings.squareCrop = true
        }
      }
      Text(
        "Rotation \(room.settings.quarterTurns * 90)° · \(room.settings.squareCrop ? "Centered square crop" : "Original proportions")"
      )
      .font(.caption).foregroundStyle(Palette.muted)
    }
    .padding(.horizontal, 24).padding(.vertical, 16)
  }

  private func frameButton(
    _ symbol: String, title: String, active: Bool, action: @escaping () -> Void
  ) -> some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 12))
    return Button(action: action) {
      layout {
        Image(systemName: symbol).font(.title2)
        Text(title).font(.caption).fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 12)
      .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? 64 : 86)
      .foregroundStyle(active ? Palette.amber : Palette.silver)
      .background(Palette.panel, in: RoundedRectangle(cornerRadius: 5))
    }
    .accessibilityAddTraits(active ? .isSelected : [])
  }

  private var footer: some View {
    let layout =
      typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
      : AnyLayout(HStackLayout(spacing: 4))
    return VStack(spacing: 0) {
      Hairline()
      layout {
        Button {
          showRecipes = true
        } label: {
          Label("Recipes", systemImage: "bookmark").font(.subheadline)
            .fixedSize(horizontal: false, vertical: true).frame(minHeight: 46)
        }
        if !typeSize.isAccessibilitySize { Spacer() }
        Button {
          recipeName = "\(room.settings.film.title) study"
          showSave = true
        } label: {
          Label("Save recipe", systemImage: "plus").font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 46)
        }
        if !typeSize.isAccessibilitySize { Spacer() }
        Button {
          showReset = true
        } label: {
          if typeSize.isAccessibilitySize {
            Label("Reset edits", systemImage: "arrow.counterclockwise")
              .font(.subheadline).frame(minHeight: 46)
          } else {
            Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 46)
          }
        }
        .accessibilityLabel("Reset edits")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(Palette.muted).padding(.horizontal, 24)
      Label(
        library.error == nil ? "Edits saved on this device" : "Edits could not be saved",
        systemImage: library.error == nil ? "checkmark" : "exclamationmark.circle"
      )
      .font(.caption2).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 24).padding(.bottom, 6)
    }
  }
}
