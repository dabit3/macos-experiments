import SwiftUI

@main
struct SilverroomApp: App {
  @StateObject private var library = LibraryStore()

  var body: some Scene {
    WindowGroup {
      LibraryView()
        .environmentObject(library)
        .preferredColorScheme(.dark)
        .tint(Palette.ink)
    }
  }
}

enum Palette {
  static let background = Color(red: 0.055, green: 0.055, blue: 0.055)
  static let canvas = Color.black
  static let panel = Color(red: 0.125, green: 0.125, blue: 0.125)
  static let control = Color(red: 0.18, green: 0.18, blue: 0.18)
  static let ink = Color(red: 0.97, green: 0.97, blue: 0.96)
  static let muted = Color(red: 0.6, green: 0.6, blue: 0.59)
  static let accent = Color(red: 0.98, green: 0.72, blue: 0.3)
  static let line = Color.white.opacity(0.1)
}

enum TypeStyle {
  static let display = Font.system(.largeTitle, design: .default, weight: .bold)
  static let title = Font.system(.title2, weight: .semibold)
  static let heading = Font.system(.headline, weight: .semibold)
  static let body = Font.system(.body)
  static let label = Font.system(.subheadline, weight: .medium)
  static let caption = Font.system(.footnote)
  static let micro = Font.system(.caption2, weight: .medium)
  static let value = Font.system(.title, weight: .medium).monospacedDigit()
}

struct IconButton: View {
  let symbol: String
  let label: String
  var size: CGFloat = 20
  var filled = false
  var action: () -> Void
  @Environment(\.isEnabled) private var enabled

  var body: some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: size, weight: .medium))
        .frame(width: 44, height: 44)
        .background(filled ? Palette.control : .clear, in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(enabled ? Palette.ink : Palette.muted.opacity(0.4))
    .accessibilityLabel(label)
  }
}

struct PrimaryButton: ButtonStyle {
  @Environment(\.isEnabled) private var enabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(TypeStyle.heading)
      .foregroundStyle(Palette.background)
      .padding(.horizontal, 20)
      .frame(minHeight: 52)
      .background(
        Palette.ink.opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.3),
        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

struct SecondaryButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(TypeStyle.heading)
      .foregroundStyle(Palette.ink)
      .padding(.horizontal, 20)
      .frame(minHeight: 52)
      .background(
        Palette.control.opacity(configuration.isPressed ? 0.6 : 1),
        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

struct Hairline: View {
  var body: some View { Rectangle().fill(Palette.line).frame(height: 0.5) }
}

struct SheetHeader: View {
  let title: String
  var onClose: () -> Void

  var body: some View {
    ZStack {
      Text(title).font(TypeStyle.heading)
      HStack {
        Spacer()
        IconButton(symbol: "xmark", label: "Close", size: 15, filled: true, action: onClose)
          .scaleEffect(0.72)
      }
    }
    .foregroundStyle(Palette.ink)
    .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 6)
  }
}

struct NoticeSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  let title: String
  let detail: String
  let actionTitle: String
  var action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(TypeStyle.title).padding(.top, 28)
      Text(detail).font(TypeStyle.body).foregroundStyle(Palette.muted)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 24)
      Button {
        action()
        dismiss()
      } label: {
        Text(actionTitle).frame(maxWidth: .infinity)
      }
      .buttonStyle(PrimaryButton())
      Button {
        dismiss()
      } label: {
        Text("Cancel").frame(maxWidth: .infinity)
      }
      .buttonStyle(SecondaryButton())
    }
    .padding(.horizontal, 20).padding(.bottom, 12)
    .foregroundStyle(Palette.ink)
    .presentationBackground(Palette.background)
    .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
    .presentationDragIndicator(.visible)
  }
}

struct RecipeNameSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  @FocusState private var focused: Bool
  @State private var name: String
  @State private var confirmingDelete = false
  let title: String
  var onSave: (String) -> Void
  var onDelete: (() -> Void)?

  init(
    title: String, initialName: String, onSave: @escaping (String) -> Void,
    onDelete: (() -> Void)? = nil
  ) {
    self.title = title
    _name = State(initialValue: initialName)
    self.onSave = onSave
    self.onDelete = onDelete
  }

  var body: some View {
    VStack(spacing: 0) {
      SheetHeader(title: confirmingDelete ? "Delete recipe" : title) { dismiss() }
      ScrollView {
        form.padding(.horizontal, 20).padding(.top, 8)
      }
      .scrollDismissesKeyboard(.interactively)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      primaryAction.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
    }
    .foregroundStyle(Palette.ink)
    .presentationBackground(Palette.background)
    .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
    .presentationDragIndicator(.visible)
    .onAppear { focused = onDelete == nil }
  }

  @ViewBuilder private var primaryAction: some View {
    if confirmingDelete, let onDelete {
      Button {
        onDelete()
        dismiss()
      } label: {
        Text("Delete").frame(maxWidth: .infinity)
      }
      .buttonStyle(PrimaryButton())
    } else {
      Button {
        save()
      } label: {
        Text("Save").frame(maxWidth: .infinity)
      }
      .buttonStyle(PrimaryButton()).disabled(trimmedName.isEmpty)
    }
  }

  @ViewBuilder private var form: some View {
    VStack(alignment: .leading, spacing: 16) {
      if confirmingDelete {
        Text("Photos already using this recipe keep their edits.")
          .font(TypeStyle.body).foregroundStyle(Palette.muted)
        Button {
          confirmingDelete = false
        } label: {
          Text("Keep").frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButton())
      } else {
        TextField("Recipe name", text: $name)
          .font(TypeStyle.title).tint(Palette.accent)
          .padding(.horizontal, 16).frame(minHeight: 56)
          .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .focused($focused).submitLabel(.done)
          .onSubmit { save() }
        Text("Look, exposure, contrast and warmth are saved. Crop stays with each photo.")
          .font(TypeStyle.caption).foregroundStyle(Palette.muted)
        if onDelete != nil {
          Button("Delete recipe") {
            focused = false
            confirmingDelete = true
          }
          .font(TypeStyle.label).foregroundStyle(Palette.muted)
          .frame(maxWidth: .infinity, minHeight: 44)
        }
      }
    }
  }

  private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

  private func save() {
    guard !trimmedName.isEmpty else { return }
    onSave(trimmedName)
    dismiss()
  }
}
