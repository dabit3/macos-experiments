import SwiftUI

enum ToolTab: String, CaseIterable {
  case looks = "Looks"
  case adjust = "Adjust"
  case frame = "Frame"
  case recipes = "Recipes"

  var symbol: String {
    switch self {
    case .looks: "camera.filters"
    case .adjust: "slider.horizontal.3"
    case .frame: "crop.rotate"
    case .recipes: "bookmark"
    }
  }
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
    case .exposure: "Darker"
    case .contrast: "Softer"
    case .warmth: "Cooler"
    }
  }
  var upperLabel: String {
    switch self {
    case .exposure: "Brighter"
    case .contrast: "Stronger"
    case .warmth: "Warmer"
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
  @State private var exportFile: ExportFile?
  @State private var saved = false
  @ScaledMetric(relativeTo: .caption) private var filmWidth: CGFloat = 60

  init(negative: Negative) {
    self.negative = negative
    _room = StateObject(wrappedValue: Darkroom(settings: negative.settings))
  }

  private var edited: Bool { room.settings != EditSettings() }

  var body: some View {
    VStack(spacing: 0) {
      toolbar
      if typeSize.isAccessibilitySize {
        GeometryReader { geometry in
          ScrollView {
            VStack(spacing: 0) {
              photo(height: geometry.size.width * 1.1)
              tools
            }
          }
          .scrollIndicators(.visible)
        }
      } else {
        GeometryReader { geometry in
          photo(height: geometry.size.height)
        }
        tools
      }
    }
    .background(Palette.canvas)
    .foregroundStyle(Palette.ink)
    .task {
      do { await room.load(data: try library.data(for: negative)) } catch {
        room.error = error.localizedDescription
      }
    }
    .task(id: room.settings) {
      library.update(negative, settings: room.settings)
      saved = false
      await room.develop()
    }
    .sheet(isPresented: $showRecipes) {
      RecipeShelf(negative: negative) { recipe in
        room.apply(recipe)
        showRecipes = false
      }
    }
    .sheet(item: $exportFile) { file in ExportView(file: file) }
    .sheet(isPresented: $showSave) {
      RecipeNameSheet(title: "Save recipe", initialName: room.settings.film.title) { name in
        library.addRecipe(name: name, settings: room.settings)
        saved = true
      }
    }
    .sheet(isPresented: $showReset) {
      NoticeSheet(
        title: "Reset all edits?",
        detail: "The photo returns to its original look and framing. You can undo this.",
        actionTitle: "Reset"
      ) {
        room.edit { $0 = EditSettings() }
        comparing = false
      }
    }
    .sheet(
      isPresented: Binding(
        get: { room.error != nil || library.error != nil },
        set: {
          if !$0 {
            room.error = nil
            library.error = nil
          }
        })
    ) {
      NoticeSheet(
        title: "Something went wrong", detail: room.error ?? library.error ?? "",
        actionTitle: "OK"
      ) {
        room.error = nil
        library.error = nil
      }
    }
    .sensoryFeedback(.selection, trigger: room.settings.film)
    .sensoryFeedback(.selection, trigger: tab)
    .sensoryFeedback(.success, trigger: saved)
  }

  private var toolbar: some View {
    HStack(spacing: 0) {
      IconButton(symbol: "xmark", label: "Close photo", size: 17) { dismiss() }
      if !typeSize.isAccessibilitySize {
        Spacer(minLength: 0)
        VStack(spacing: 2) {
          Text(negative.title).font(TypeStyle.label).lineLimit(1)
          if room.outputSize != .zero {
            Text("\(Int(room.outputSize.width)) × \(Int(room.outputSize.height))")
              .font(TypeStyle.micro).foregroundStyle(Palette.muted).monospacedDigit()
          }
        }
        .accessibilityElement(children: .combine)
      }
      Spacer(minLength: 0)
      IconButton(symbol: "arrow.uturn.backward", label: "Undo", size: 17) { room.undo() }
        .disabled(!room.canUndo)
      IconButton(symbol: "arrow.uturn.forward", label: "Redo", size: 17) { room.redo() }
        .disabled(!room.canRedo)
      exportButton
    }
    .padding(.horizontal, 8).padding(.vertical, 4)
  }

  private var exportButton: some View {
    Button {
      Task {
        let directory = library.disk.directory.appendingPathComponent(
          "Exports", isDirectory: true)
        if let url = await room.export(directory: directory) { exportFile = ExportFile(url: url) }
      }
    } label: {
      Group {
        if room.exporting {
          ProgressView().tint(Palette.ink)
        } else {
          Image(systemName: "square.and.arrow.up").font(.system(size: 17, weight: .medium))
        }
      }
      .frame(width: 44, height: 44).contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(room.preview == nil || room.exporting)
    .opacity(room.preview == nil ? 0.4 : 1)
    .accessibilityLabel(room.exporting ? "Exporting" : "Export photo")
  }

  private func photo(height: CGFloat) -> some View {
    ZStack(alignment: .bottom) {
      Palette.canvas
      if let image = comparing ? room.original : room.preview {
        Image(uiImage: image).resizable().scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .accessibilityLabel(
            comparing ? "Original photo" : "Edited photo, \(room.settings.film.title) look")
      } else {
        ProgressView().tint(Palette.ink)
      }
      if comparing {
        Text("Original").font(TypeStyle.micro).foregroundStyle(Palette.background)
          .padding(.horizontal, 10).padding(.vertical, 6)
          .background(Palette.ink, in: Capsule()).padding(.bottom, 14)
          .accessibilityHidden(true)
      }
    }
    .frame(height: max(1, height))
    .contentShape(Rectangle())
    .onLongPressGesture(minimumDuration: 0.12, pressing: { comparing = $0 }, perform: {})
    .overlay(alignment: .bottomTrailing) { canvasControls }
    .overlay(alignment: .bottomLeading) {
      if typeSize.isAccessibilitySize { compareControl.padding(10) }
    }
  }

  private var canvasControls: some View {
    HStack(spacing: 8) {
      if edited {
        IconButton(
          symbol: "arrow.counterclockwise", label: "Reset all edits", size: 16, filled: true
        ) { showReset = true }
      }
      if !typeSize.isAccessibilitySize { compareControl }
    }
    .padding(10)
  }

  private var compareControl: some View {
    Image(systemName: comparing ? "circle.lefthalf.filled.inverse" : "circle.lefthalf.filled")
      .font(.system(size: 16, weight: .medium))
      .frame(width: 44, height: 44)
      .foregroundStyle(comparing ? Palette.background : Palette.ink)
      .background(comparing ? Palette.ink : Palette.control, in: Circle())
      .contentShape(Circle())
      .onLongPressGesture(minimumDuration: 0.01, pressing: { comparing = $0 }, perform: {})
      .accessibilityLabel("Compare with original")
      .accessibilityValue(comparing ? "Showing original" : "Showing edit")
      .accessibilityHint("Touch and hold to see the original. Double-tap to toggle.")
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { comparing.toggle() }
  }

  private var tools: some View {
    VStack(spacing: 0) {
      if typeSize.isAccessibilitySize {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
          ForEach(ToolTab.allCases, id: \.self) { tabButton($0) }
        }
        .padding(.horizontal, 12).padding(.top, 8)
      }
      Group {
        switch tab {
        case .looks: filmstrip
        case .adjust: adjustmentPanel
        case .frame: framePanel
        case .recipes: recipePanel
        }
      }
      .frame(height: typeSize.isAccessibilitySize ? nil : 176)
      .padding(.vertical, typeSize.isAccessibilitySize ? 16 : 0)
      if !typeSize.isAccessibilitySize {
        HStack(spacing: 0) {
          ForEach(ToolTab.allCases, id: \.self) { tabButton($0) }
        }
        .padding(.horizontal, 8).padding(.bottom, 2)
      }
    }
    .background(Palette.background.ignoresSafeArea(edges: .bottom))
  }

  private func tabButton(_ item: ToolTab) -> some View {
    let selected = tab == item
    return Button {
      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { tab = item }
    } label: {
      VStack(spacing: 5) {
        Image(systemName: item.symbol)
          .font(.system(size: 20, weight: selected ? .semibold : .regular))
          .frame(height: 24)
        Text(item.rawValue).font(TypeStyle.micro)
      }
      .frame(maxWidth: .infinity, minHeight: 56)
      .foregroundStyle(selected ? Palette.ink : Palette.muted)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var filmstrip: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 10) {
          ForEach(Film.allCases) { film in
            let selected = room.settings.film == film
            Button {
              room.edit { $0.film = film }
            } label: {
              VStack(spacing: 8) {
                Group {
                  if let image = room.films[film] {
                    Image(uiImage: image).resizable().scaledToFill()
                  } else {
                    Palette.panel
                  }
                }
                .frame(width: min(filmWidth, 84), height: min(filmWidth, 84) * 1.25).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                  RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Palette.ink : .clear, lineWidth: 2)
                }
                Text(film.title).font(TypeStyle.caption)
                  .fontWeight(selected ? .semibold : .regular)
                  .foregroundStyle(selected ? Palette.ink : Palette.muted)
              }
            }
            .buttonStyle(.plain).id(film)
            .accessibilityLabel("\(film.title) look")
            .accessibilityAddTraits(selected ? .isSelected : [])
          }
        }
        .padding(.horizontal, 16)
      }
      .onChange(of: room.settings.film) { _, film in
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
          proxy.scrollTo(film, anchor: .center)
        }
      }
      .onAppear { proxy.scrollTo(room.settings.film, anchor: .center) }
    }
    .frame(maxHeight: .infinity)
  }

  private var adjustmentPanel: some View {
    VStack(spacing: 6) {
      if typeSize.isAccessibilitySize {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
          ForEach(Adjustment.allCases, id: \.self) { adjustmentButton($0) }
        }
      } else {
        HStack(spacing: 2) {
          ForEach(Adjustment.allCases, id: \.self) { adjustmentButton($0) }
        }
        .padding(2)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      ZStack {
        Text(valueText).font(TypeStyle.value)
          .foregroundStyle(isNeutral ? Palette.ink : Palette.accent)
          .contentTransition(.numericText())
          .accessibilityHidden(true)
        if !isNeutral {
          HStack {
            Spacer()
            Button("Reset") { adjustmentBinding.wrappedValue = adjustment.neutral }
              .font(TypeStyle.label).foregroundStyle(Palette.muted).frame(minHeight: 44)
              .accessibilityLabel("Reset \(adjustment.rawValue.lowercased())")
          }
        }
      }
      .frame(minHeight: 40)
      VStack(spacing: 2) {
        AdjustmentSlider(
          value: adjustmentBinding, scale: SliderScale(range: adjustment.range),
          onEditingChanged: room.setAdjusting
        )
        .accessibilityLabel(adjustment.rawValue).accessibilityValue(valueText)
        HStack {
          Text(adjustment.lowerLabel)
          Spacer()
          Text(adjustment.upperLabel)
        }
        .font(TypeStyle.micro).foregroundStyle(Palette.muted).padding(.horizontal, 2)
      }
    }
    .padding(.horizontal, 20).padding(.top, 8)
  }

  private var isNeutral: Bool { adjustmentBinding.wrappedValue == adjustment.neutral }

  private func adjustmentButton(_ item: Adjustment) -> some View {
    let selected = adjustment == item
    return Button {
      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { adjustment = item }
    } label: {
      Text(item.rawValue).font(TypeStyle.label)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(selected ? Palette.ink : Palette.muted)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(
          selected ? Palette.control : .clear,
          in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
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
        room.edit {
          switch adjustment {
          case .exposure: $0.exposure = value
          case .contrast: $0.contrast = value
          case .warmth: $0.warmth = value
          }
        }
      })
  }

  private var valueText: String {
    switch adjustment {
    case .exposure: String(format: "%+.2f", room.settings.exposure)
    case .contrast: String(format: "%+.0f", (room.settings.contrast - 1) * 100)
    case .warmth: String(format: "%+.0f", room.settings.warmth * 100)
    }
  }

  private var framePanel: some View {
    let columns = typeSize.isAccessibilitySize ? 1 : 3
    return LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10
    ) {
      frameTile(
        symbol: "rectangle", title: "Original", selected: !room.settings.squareCrop,
        label: "Original ratio"
      ) { room.edit { $0.squareCrop = false } }
      frameTile(
        symbol: "square", title: "Square", selected: room.settings.squareCrop,
        label: "Square crop"
      ) { room.edit { $0.squareCrop = true } }
      frameTile(
        symbol: "rotate.right", title: "Rotate \(room.settings.quarterTurns * 90)°",
        selected: false,
        label: "Rotate 90 degrees, currently \(room.settings.quarterTurns * 90) degrees"
      ) { room.edit { $0.quarterTurns += 1 } }
    }
    .padding(.horizontal, 20).padding(.top, 12)
  }

  private func frameTile(
    symbol: String, title: String, selected: Bool, label: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: symbol).font(.system(size: 22, weight: .regular))
        Text(title).font(TypeStyle.label).monospacedDigit()
      }
      .foregroundStyle(selected ? Palette.background : Palette.ink)
      .frame(maxWidth: .infinity, minHeight: 88)
      .background(
        selected ? Palette.ink : Palette.panel,
        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var recipePanel: some View {
    VStack(spacing: 10) {
      Button {
        showSave = true
      } label: {
        Label(
          saved ? "Saved" : "Save this look as a recipe", systemImage: saved ? "checkmark" : "plus"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(PrimaryButton())
      .disabled(saved)
      Button {
        showRecipes = true
      } label: {
        HStack {
          Text("Apply a saved recipe")
          Spacer()
          Text("\(library.state.recipes.count)").foregroundStyle(Palette.muted).monospacedDigit()
        }
      }
      .buttonStyle(SecondaryButton())
    }
    .padding(.horizontal, 20).padding(.top, 16)
  }
}

private struct AdjustmentSlider: View {
  @Binding var value: Double
  let scale: SliderScale
  var onEditingChanged: (Bool) -> Void
  @GestureState private var pressed = false
  @State private var editing = false

  var body: some View {
    GeometryReader { geometry in
      let length = max(1, geometry.size.width - 28)
      let position = CGFloat(scale.fraction(for: value)) * length
      ZStack(alignment: .leading) {
        Capsule().fill(Palette.control).frame(height: 3).padding(.horizontal, 14)
        Rectangle().fill(Palette.muted).frame(width: 1, height: 11).offset(x: 14 + length / 2)
        Capsule().fill(Palette.accent)
          .frame(width: abs(position - length / 2), height: 3)
          .offset(x: 14 + min(position, length / 2))
        Circle().fill(Palette.ink).shadow(color: .black.opacity(0.4), radius: 3, y: 1)
          .frame(width: 22, height: 22)
          .frame(width: 28, height: 44)
          .offset(x: position)
      }
      .frame(height: 44)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .updating($pressed) { _, pressed, _ in pressed = true }
          .onChanged { gesture in
            if !editing {
              editing = true
              onEditingChanged(true)
            }
            value = scale.value(at: Double((gesture.location.x - 14) / length))
          }
          .onEnded { _ in finishEditing() }
      )
    }
    .frame(height: 44)
    .accessibilityElement(children: .ignore)
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: value = min(scale.range.upperBound, value + scale.step)
      case .decrement: value = max(scale.range.lowerBound, value - scale.step)
      @unknown default: break
      }
    }
    .onChange(of: pressed) { _, pressed in
      if !pressed { finishEditing() }
    }
    .onDisappear { finishEditing() }
  }

  private func finishEditing() {
    guard editing else { return }
    editing = false
    onEditingChanged(false)
  }
}
