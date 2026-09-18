import AppKit
import Carbon
import PasteCore
import SwiftUI

@MainActor
final class PilotModel: ObservableObject {
  @Published var source: SourceDocument?
  @Published var target: TargetSnapshot?
  @Published var result: Evaluation?
  @Published var intent = ""
  @Published var status = "Copy a brief. Capture once. Focus any field."
  @Published var busy = false
  @Published var selectedID: String?
  @Published var totalRequests = 0
  @Published var pastedCount = 0
  @Published var undoEdit: UndoEdit?
  @Published var activity: [String] = []
  @Published var showSource = false
  let client = JevClient()
  var pending: Task<Void, Never>?
  var generation = UUID()
  var reveal: (() -> Void)?

  var selected: Candidate? { source?.candidates.first { $0.id == selectedID } }
  var canPaste: Bool {
    !busy && target != nil && selectedID == result?.choice && result?.approved == true
  }
  var ranked: [Candidate] {
    (source?.candidates ?? []).sorted {
      (result?.probabilities[$0.id] ?? 0) > (result?.probabilities[$1.id] ?? 0)
    }
  }

  func log(_ message: String) {
    activity.insert(message, at: 0)
    activity = Array(activity.prefix(4))
  }

  func invalidate() {
    generation = UUID()
    pending?.cancel()
    busy = false
    result = nil
    selectedID = nil
  }

  func captureClipboard() {
    invalidate()
    target = nil
    undoEdit = nil
    do {
      guard let text = NSPasteboard.general.string(forType: .string) else {
        throw PilotError.message("Clipboard has no plain text.")
      }
      source = try SourceDocument(text)
      status = "Brief captured. Focus a destination, then ⌘⇧V."
      log("Captured \(source?.candidates.count ?? 0) exact spans · kept in memory")
    } catch {
      source = nil
      status = error.localizedDescription
    }
  }

  func captureTarget() {
    invalidate()
    undoEdit = nil
    do {
      target = try TargetSnapshot.capture(intent: intent)
      status = "Target pinned. Preview sends the brief + field labels to Jev."
      log("Pinned \(target?.context.app ?? "") · \(target?.context.title ?? "")")
    } catch {
      target = nil
      status = error.localizedDescription
    }
    reveal?()
  }

  func preview() {
    guard let source, let target else {
      status = "Capture a brief and focus a destination field first."
      return
    }
    invalidate()
    let token = generation
    busy = true
    status = "Jev is choosing an exact span and checking its business role…"
    let context = FieldContext(
      app: target.context.app, role: target.context.role, title: target.context.title,
      help: target.context.help, labels: target.context.labels, intent: intent)
    pending = Task {
      do {
        try target.validate()
        let evaluation = try await client.evaluate(source: source, target: context)
        guard token == generation, !Task.isCancelled else { return }
        try target.validate()
        result = evaluation
        selectedID = evaluation.choice == "none" ? nil : evaluation.choice
        totalRequests += evaluation.requests
        busy = false
        status =
          evaluation.approved
          ? "Ready for your review. Paste writes only the pinned field."
          : evaluation.choice == "none"
            ? "No exact match. Nothing will be pasted."
            : "Uncertain selection or role mismatch. Paste is disabled; clarify your intent."
        log(
          "\(evaluation.model) · \(evaluation.milliseconds) ms · \(evaluation.requests == 0 ? "memory cache" : "\(evaluation.requests) request(s)")"
        )
      } catch {
        guard token == generation else { return }
        busy = false
        status = error.localizedDescription
        log("Stopped · no field changed")
      }
    }
  }

  func paste() {
    guard canPaste, let source, let selected, let target else { return }
    busy = true
    pending = Task {
      do {
        let value = try source.exactText(selected)
        undoEdit = try await FieldAction.paste(value, into: target)
        pastedCount += 1
        status = "Inserted exact text. macOS readback verified."
        log("Verified insert into \(target.context.app)")
        result = nil
        self.target = nil
      } catch { status = error.localizedDescription }
      busy = false
    }
  }

  func undo() {
    guard let undoEdit, !busy else { return }
    busy = true
    pending = Task {
      do {
        try await FieldAction.undo(undoEdit)
        self.undoEdit = nil
        result = nil
        target = nil
        status = "Original field text restored and verified."
        log("Verified undo")
      } catch { status = error.localizedDescription }
      busy = false
    }
  }

  func copySelected() {
    guard let source, let selected, let value = try? source.exactText(selected) else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    status = "Exact span copied. Manual paste is your responsibility."
  }

  func loadFixture() {
    do {
      let text = try String(contentsOf: AppPaths.fixture)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(text, forType: .string)
      captureClipboard()
      log("Synthetic Northstar brief · explicit demo capture")
      let configuration = NSWorkspace.OpenConfiguration()
      NSWorkspace.shared.openApplication(at: AppPaths.form, configuration: configuration)
    } catch { status = error.localizedDescription }
  }
}

enum AppPaths {
  static var resources: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/Resources") }
  static var fixture: URL { resources.appendingPathComponent("vendor-brief.txt") }
  static var form: URL { resources.appendingPathComponent("VendorForm.app") }
}

private let ink = Color(red: 0.09, green: 0.10, blue: 0.15)
private let muted = Color(red: 0.58, green: 0.61, blue: 0.70)
private let mint = Color(red: 0.55, green: 0.94, blue: 0.77)

struct PilotView: View {
  @ObservedObject var model: PilotModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 11) {
        Image(systemName: "arrow.up.doc.on.clipboard").font(.system(size: 23, weight: .medium))
          .foregroundStyle(mint).frame(width: 44, height: 44)
          .background(mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
        VStack(alignment: .leading, spacing: 2) {
          Text("PastePilot").font(.system(size: 24, weight: .bold, design: .rounded))
          Text("THE RIGHT VALUE. THE RIGHT FIELD.").font(.system(size: 9, weight: .semibold))
            .tracking(1.5).foregroundStyle(muted)
        }
        Spacer()
        Text("JEV / LIVE").font(.system(size: 9, weight: .bold, design: .monospaced))
          .foregroundStyle(mint).padding(7).background(mint.opacity(0.09), in: Capsule())
      }
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          eyebrow("01  CAPTURE ONCE")
          Text(
            model.source == nil
              ? "Your clipboard, with context"
              : "\(model.source!.candidates.count) exact spans ready"
          )
          .font(.system(size: 14, weight: .semibold))
          Text(
            model.source == nil
              ? "Only text you explicitly capture is read."
              : "Brief stays in memory · \(model.pastedCount) verified inserts"
          )
          .font(.system(size: 11)).foregroundStyle(muted)
        }
        Spacer()
        Button("Capture  ⌘⇧C", action: model.captureClipboard).buttonStyle(.bordered)
      }.padding(14).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          eyebrow("02  PIN THE DESTINATION")
          Spacer()
          Text("Focus field → ⌘⇧V").font(.system(size: 11, design: .monospaced)).foregroundStyle(
            muted)
        }
        HStack(spacing: 9) {
          Image(systemName: model.target == nil ? "scope" : "pin.fill").foregroundStyle(mint)
          VStack(alignment: .leading, spacing: 3) {
            Text(
              model.target?.context.title.isEmpty == false
                ? model.target!.context.title : "No labeled field pinned"
            )
            .font(.system(size: 14, weight: .semibold)).lineLimit(2)
            Text(
              model.target.map { "\($0.context.app) · \($0.context.role)" }
                ?? "Works with real macOS Accessibility fields"
            )
            .font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
          }
        }
        TextField("Optional intent — e.g. billing email, not sales", text: $model.intent)
          .textFieldStyle(.plain).font(.system(size: 12)).padding(10)
          .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
          .onChange(of: model.intent) { model.invalidate() }
        HStack {
          Text("Preview sends this brief + field labels to TypeSafe.")
            .font(.system(size: 10)).foregroundStyle(muted)
          Spacer()
          Button(action: model.preview) {
            HStack {
              if model.busy { ProgressView().controlSize(.small) }
              Text("Preview")
            }
          }.buttonStyle(.bordered).disabled(
            model.busy || model.source == nil || model.target == nil)
        }
      }

      VStack(alignment: .leading, spacing: 11) {
        HStack {
          eyebrow("03  REVIEW EXACT TEXT")
          Spacer()
          if let result = model.result {
            Text(result.requests == 0 ? "CACHED" : "\(result.milliseconds) ms")
              .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(mint)
          }
        }
        Text(
          model.selected?.text
            ?? (model.result?.choice == "none"
              ? "No matching value" : "Less hunting.\nMore getting it right.")
        )
        .font(.system(size: model.selected == nil ? 25 : 21, weight: .medium, design: .rounded))
        .foregroundStyle(model.selected == nil ? Color.white.opacity(0.7) : .white)
        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).lineLimit(4)
        if let selected = model.selected {
          HStack(spacing: 12) {
            metric("CHOICE", model.result?.probabilities[selected.id])
            metric("ROLE MATCH", model.result?.roles[selected.id])
            Spacer()
            Text("VERBATIM").font(.system(size: 9, weight: .bold)).foregroundStyle(mint)
          }
          Text(selected.excerpt).font(.system(size: 11, design: .monospaced))
            .foregroundStyle(muted).lineLimit(4).textSelection(.enabled)
          Text("Source excerpt · probabilities are model judgments, not guarantees")
            .font(.system(size: 9)).foregroundStyle(muted)
        }
        HStack {
          Button(action: model.paste) {
            HStack {
              Image(systemName: "arrow.turn.down.right")
              Text("Paste exact value")
              Spacer()
              Text("↵")
            }
            .font(.system(size: 13, weight: .semibold)).padding(10).contentShape(Rectangle())
          }.buttonStyle(.plain).foregroundStyle(ink)
            .background(model.canPaste ? mint : muted, in: RoundedRectangle(cornerRadius: 8))
            .disabled(!model.canPaste)
          Button("Undo", action: model.undo).buttonStyle(.bordered).disabled(
            model.undoEdit == nil || model.busy)
        }
        Text(model.status).font(.system(size: 11)).foregroundStyle(
          model.result?.approved == false ? .orange : muted
        )
        .fixedSize(horizontal: false, vertical: true)
      }.padding(15).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))

      if model.result != nil {
        VStack(alignment: .leading, spacing: 5) {
          HStack {
            eyebrow("ALTERNATIVES · SAME CANDIDATE POOL")
            Spacer()
            Button("Copy selected", action: model.copySelected).buttonStyle(.plain).font(
              .system(size: 10)
            ).foregroundStyle(mint)
          }
          ScrollView {
            VStack(spacing: 2) {
              ForEach(model.ranked) { candidate in
                Button {
                  model.selectedID = candidate.id
                } label: {
                  HStack {
                    Image(
                      systemName: model.selectedID == candidate.id
                        ? "smallcircle.filled.circle" : "circle"
                    )
                    .foregroundStyle(mint)
                    Text(candidate.text.replacingOccurrences(of: "\n", with: " · ")).lineLimit(1)
                    Spacer()
                    Text("\(Int((model.result?.probabilities[candidate.id] ?? 0) * 100))%")
                      .foregroundStyle(muted).monospacedDigit()
                  }.font(.system(size: 11)).padding(.vertical, 4).contentShape(Rectangle())
                }.buttonStyle(.plain)
              }
            }
          }.frame(height: 73)
        }
      }
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(Array(model.activity.prefix(2).enumerated()), id: \.offset) { _, item in
            Text("· \(item)").font(.system(size: 9, design: .monospaced)).foregroundStyle(muted)
              .lineLimit(1)
          }
        }
        Spacer()
        Text("\(model.totalRequests) requests").font(.system(size: 9, design: .monospaced))
          .foregroundStyle(muted)
      }
      Divider().overlay(.white.opacity(0.05))
      HStack {
        Button("Try Northstar fixture", action: model.loadFixture)
        Button("Source") { model.showSource.toggle() }.disabled(model.source == nil)
        Spacer()
        Button("Permissions") {
          AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
          NSWorkspace.shared.open(
            URL(
              string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
      }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(muted)
    }
    .padding(22).frame(width: 508).background(ink).foregroundStyle(.white)
    .preferredColorScheme(.dark)
    .sheet(isPresented: $model.showSource) {
      VStack(alignment: .leading) {
        Text("Captured source · memory only").font(.headline)
        ScrollView {
          Text(model.source?.text ?? "").font(.system(size: 12, design: .monospaced)).textSelection(
            .enabled
          ).frame(maxWidth: .infinity, alignment: .leading)
        }
        Button("Close") { model.showSource = false }
      }.padding(24).frame(width: 550, height: 550)
    }
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text).font(.system(size: 9, weight: .bold)).tracking(1.2).foregroundStyle(muted)
  }
  private func metric(_ label: String, _ value: Double?) -> some View {
    HStack(spacing: 4) {
      Text(label).font(.system(size: 8, weight: .semibold)).foregroundStyle(muted)
      Text(value.map { "\(Int($0 * 100))%" } ?? "—").font(
        .system(size: 11, weight: .semibold, design: .monospaced)
      ).foregroundStyle(mint)
    }
  }
}

final class FloatingPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class Shortcuts {
  var references: [EventHotKeyRef?] = [nil, nil]
  var handler: EventHandlerRef?
  let model: PilotModel
  init(model: PilotModel) {
    self.model = model
    var type = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, context in
        guard let event, let context else { return OSStatus(eventNotHandledErr) }
        var id = EventHotKeyID()
        GetEventParameter(
          event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
          nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
        let shortcut = Unmanaged<Shortcuts>.fromOpaque(context).takeUnretainedValue()
        Task { @MainActor in
          if id.id == 1 {
            shortcut.model.captureTarget()
          } else {
            shortcut.model.captureClipboard()
            shortcut.model.reveal?()
          }
        }
        return noErr
      }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    for (index, key) in [kVK_ANSI_V, kVK_ANSI_C].enumerated() {
      let id = EventHotKeyID(signature: 0x5050_4C54, id: UInt32(index + 1))
      let result = RegisterEventHotKey(
        UInt32(key), UInt32(cmdKey | shiftKey), id,
        GetApplicationEventTarget(), 0, &references[index])
      if result != noErr {
        model.status = "Shortcut is already in use. Quit the conflicting app and relaunch."
      }
    }
  }
}
