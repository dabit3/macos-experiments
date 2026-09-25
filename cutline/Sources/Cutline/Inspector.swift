import AppKit
import SwiftUI

struct Inspector: View {
  @ObservedObject var editor: Editor
  @State private var start = 0.0
  @State private var end = 6.0
  @State private var title = ""
  @State private var subtitle = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 21) {
        sectionLabel("CLIP INSPECTOR")
        if let media = editor.selectedMedia {
          VStack(alignment: .leading, spacing: 6) {
            Text(media.name).font(.system(size: 17, weight: .medium, design: .serif))
            Text("SOURCE  \(String(format: "%.1fs", media.duration))  /  1280 × 720")
              .font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
          }
          HStack(spacing: 10) {
            trimField("IN", value: $start, maximum: media.duration)
            trimField("OUT", value: $end, maximum: media.duration)
          }
          Button {
            if let selected = editor.selected {
              editor.change { try $0.trim(selected, start: start, end: end) }
            }
          } label: {
            HStack {
              Image(systemName: "scissors")
              Text("Apply trim")
              Spacer()
              Text(String(format: "%.1fs", max(0, end - start))).foregroundStyle(Palette.muted)
            }.font(.system(size: 11, weight: .medium)).padding(11)
              .background(Palette.raised, in: RoundedRectangle(cornerRadius: 6))
          }.buttonStyle(.plain)
        } else {
          Text("Select a timeline clip to set its in and out points.")
            .font(.system(size: 12)).foregroundStyle(Palette.muted)
        }
        Rectangle().fill(Palette.line).frame(height: 1)
        HStack {
          sectionLabel("OPENING TITLE")
          Spacer()
          Toggle(
            "Opening title",
            isOn: Binding(
              get: { editor.project.titleEnabled },
              set: { enabled in editor.change { $0.titleEnabled = enabled } }
            )
          ).toggleStyle(.switch).labelsHidden().controlSize(.mini)
        }
        VStack(spacing: 8) {
          ForEach(TitleStyle.allCases, id: \.self) { style in
            Button {
              editor.change { $0.titleStyle = style }
            } label: {
              HStack(spacing: 14) {
                Text("Aa").font(
                  .system(
                    size: 24, weight: style == .postcard ? .bold : .regular,
                    design: style == .editorial ? .serif : .default)
                )
                .frame(width: 37)
                VStack(alignment: .leading, spacing: 4) {
                  Text(style.rawValue).font(.system(size: 11, weight: .medium))
                  Text(
                    style == .editorial
                      ? "Quiet, cinematic serif"
                      : style == .postcard ? "A bold note from afar" : "Less, but considered"
                  )
                  .font(.system(size: 9)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                if style == editor.project.titleStyle {
                  Circle().fill(Palette.cyan).frame(width: 5, height: 5)
                }
              }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(
                  style == editor.project.titleStyle
                    ? Palette.cyan.opacity(0.065) : Palette.raised.opacity(0.45),
                  in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 6).stroke(
                    style == editor.project.titleStyle ? Palette.cyan.opacity(0.6) : Palette.line,
                    lineWidth: 1))
            }.buttonStyle(.plain).accessibilityLabel("\(style.rawValue) title preset")
          }
        }
        VStack(alignment: .leading, spacing: 8) {
          sectionLabel("TITLE")
          TextEditor(text: $title).font(.system(size: 13, design: .serif))
            .scrollContentBackground(.hidden).frame(height: 51)
            .padding(8).background(Palette.base, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.line))
            .accessibilityLabel("Title text")
          sectionLabel("SUBTITLE")
          TextField("A note from the road", text: $subtitle)
            .textFieldStyle(.plain).font(.system(size: 10))
            .padding(10).background(Palette.base, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityLabel("Subtitle text")
          Button {
            editor.change {
              $0.title = String(title.prefix(120))
              $0.subtitle = String(subtitle.prefix(100))
            }
            editor.seek(min(1, editor.project.duration / 2))
          } label: {
            Text("Update title").font(.system(size: 11, weight: .medium))
              .frame(maxWidth: .infinity).padding(.vertical, 10)
              .background(Palette.raised, in: RoundedRectangle(cornerRadius: 5))
          }.buttonStyle(.plain)
          Text("Appears on the first clip, up to 4s.\nFades gently in and out.")
            .font(.system(size: 9)).lineSpacing(3).foregroundStyle(Palette.muted)
        }
      }.padding(21)
    }
    .scrollIndicators(.hidden).background(Palette.panel)
    .onAppear(perform: synchronize)
    .onChange(of: editor.selected) { _, _ in synchronizeTrim() }
    .onChange(of: editor.project) { _, _ in synchronize() }
  }

  func trimField(_ label: String, value: Binding<Double>, maximum: Double) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      Text(label).font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(
        Palette.muted)
      TrimInput(value: value, label: "\(label) seconds")
        .frame(height: 28)
      HStack {
        Button {
          value.wrappedValue = max(0, value.wrappedValue - 0.5)
        } label: {
          Image(systemName: "minus").frame(width: 30, height: 22)
        }.accessibilityLabel("Decrease \(label)")
        Spacer(minLength: 2)
        Button {
          value.wrappedValue = min(maximum, value.wrappedValue + 0.5)
        } label: {
          Image(systemName: "plus").frame(width: 30, height: 22)
        }.accessibilityLabel("Increase \(label)")
      }.buttonStyle(.plain).foregroundStyle(Palette.cyan)
    }.padding(10).background(Palette.base, in: RoundedRectangle(cornerRadius: 6))
  }

  func synchronizeTrim() {
    start = editor.selectedClip?.inPoint ?? 0
    end = editor.selectedClip?.outPoint ?? 6
  }

  func synchronize() {
    synchronizeTrim()
    title = editor.project.title
    subtitle = editor.project.subtitle
  }
}

struct TrimInput: NSViewRepresentable {
  @Binding var value: Double
  let label: String

  func makeCoordinator() -> Coordinator {
    Coordinator(value: $value)
  }

  func makeNSView(context: Context) -> NSTextField {
    let field = NSTextField()
    field.isBezeled = false
    field.isBordered = false
    field.drawsBackground = false
    field.font = .monospacedSystemFont(ofSize: 16, weight: .medium)
    field.textColor = .white
    field.focusRingType = .none
    field.cell?.usesSingleLineMode = true
    field.cell?.isScrollable = true
    field.delegate = context.coordinator
    field.setAccessibilityLabel(label)
    return field
  }

  func updateNSView(_ field: NSTextField, context: Context) {
    context.coordinator.value = $value
    let previous = context.coordinator.lastValue
    let unchanged = previous == value || (previous?.isNaN == true && value.isNaN)
    if !unchanged, value.isFinite {
      let text = String(format: "%.2f", locale: Locale.current, value)
      field.stringValue = text
      field.currentEditor()?.string = text
    }
    context.coordinator.lastValue = value
  }

  final class Coordinator: NSObject, NSTextFieldDelegate {
    var value: Binding<Double>
    var lastValue: Double?

    init(value: Binding<Double>) {
      self.value = value
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSTextField else { return }
      let normalized = field.stringValue.replacingOccurrences(
        of: Locale.current.decimalSeparator ?? ".", with: ".")
      let parsed = Double(normalized) ?? .nan
      lastValue = parsed
      value.wrappedValue = parsed
    }
  }
}
