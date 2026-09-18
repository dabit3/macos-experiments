import AppKit
import Carbon
import MenuLensCore
import SwiftUI

@MainActor
final class LensModel: ObservableObject {
  @Published var goal = ""
  @Published var snapshot: MenuSnapshot?
  @Published var ranking: Ranking?
  @Published var selectedID: String?
  @Published var activity = "Choose an app. Say what you want to do."
  @Published var error = ""
  @Published var busy = false
  @Published var showIndex = false
  @Published var elapsed = 0
  let client = JevClient()
  var work: Task<Void, Never>?
  var generation = UUID()
  var lastTarget: NSRunningApplication?
  var showWindow: (() -> Void)?

  var selected: RankedCommand? { ranking?.commands.first { $0.id == selectedID } }

  func invalidate() {
    generation = UUID()
    work?.cancel()
    busy = false
    ranking = nil
    selectedID = nil
  }

  func capture(_ app: NSRunningApplication? = nil) {
    invalidate()
    error = ""
    guard let target = app ?? lastTarget else {
      error = "Switch to your document, then press Control–Option–Space."
      return
    }
    work = Task {
      target.activate()
      try? await Task.sleep(nanoseconds: 250_000_000)
      do {
        let captured = try NativeMenus.capture(target)
        snapshot = captured
        lastTarget = target
        activity =
          "\(captured.candidates.count) real menu commands captured • \(captured.candidates.filter(\.permitted).count) reversible commands supported"
      } catch {
        snapshot = nil
        self.error = error.localizedDescription
      }
      showWindow?()
    }
  }

  func captureApp(_ bundleID: String) {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    else {
      error = "Open this app and a document/window first, then capture."
      return
    }
    capture(app)
  }

  func search() {
    guard let snapshot else {
      error = "Capture a target application first."
      return
    }
    invalidate()
    error = ""
    busy = true
    elapsed = 0
    activity = "Jev is comparing intent with actual menu effects…"
    let token = generation
    let intent = goal
    work = Task {
      let clock = Task { @MainActor in
        while !Task.isCancelled {
          try? await Task.sleep(nanoseconds: 100_000_000)
          if !Task.isCancelled { elapsed += 100 }
        }
      }
      defer { clock.cancel() }
      do {
        let result = try await client.rank(
          goal: intent, context: snapshot.context, candidates: snapshot.candidates)
        guard generation == token, !Task.isCancelled else { return }
        ranking = result
        selectedID = result.routeID ?? result.commands.first?.id
        activity =
          result.routeID == nil
          ? "No clear enabled match. Refine the intent or change the target selection."
          : "Preview the exact command. You decide when it runs."
      } catch {
        guard generation == token, !Task.isCancelled else { return }
        self.error = error.localizedDescription
        activity = "No action taken"
      }
      if generation == token { busy = false }
    }
  }

  func execute() {
    guard let selected, let snapshot, let ranking, ranking.routeID != nil,
      selected.candidate.enabled, selected.candidate.permitted,
      selected.score >= 2.25, selected.confidence >= 0.5
    else { return }
    busy = true
    error = ""
    activity = "Rechecking target identity, selection and menu availability…"
    work = Task {
      do {
        activity = try await NativeMenus.execute(selected.candidate, snapshot: snapshot)
      } catch { self.error = error.localizedDescription }
      self.ranking = nil
      selectedID = nil
      busy = false
      showWindow?()
    }
  }

  func openSample() {
    guard let fixture = Bundle.main.url(forResource: "Dispatch", withExtension: "rtf") else {
      return
    }
    do {
      let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/MenuLens/Samples", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let destination = directory.appendingPathComponent(
        "Dispatch-\(Int(Date().timeIntervalSince1970)).rtf")
      try FileManager.default.copyItem(at: fixture, to: destination)
      NSWorkspace.shared.open(destination)
      activity = "Select a phrase in TextEdit, then press ⌃⌥Space."
    } catch { self.error = error.localizedDescription }
  }
}

@main
struct EntryPoint {
  static func main() {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = LensModel()
  var window: NSWindow!
  var hotKey: EventHotKeyRef?
  var statusItem: NSStatusItem?
  var observer: NSObjectProtocol?

  func applicationDidFinishLaunching(_ notification: Notification) {
    if CommandLine.arguments.count > 1 && CommandLine.arguments[1].hasPrefix("--")
      && CommandLine.arguments[1] != "--showcase"
    {
      NSApp.setActivationPolicy(.accessory)
      Task {
        let code = await CommandLineRunner.run(Array(CommandLine.arguments.dropFirst()))
        fflush(stdout)
        fflush(stderr)
        exit(code)
      }
      return
    }
    NSApp.setActivationPolicy(.regular)
    model.lastTarget = NSWorkspace.shared.frontmostApplication
    window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 940, height: 710),
      styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
      backing: .buffered, defer: false
    )
    window.title = "MenuLens"
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isReleasedWhenClosed = false
    window.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.067, blue: 0.09, alpha: 1)
    window.contentView = NSHostingView(rootView: LensView(model: model).preferredColorScheme(.dark))
    window.center()
    model.showWindow = { [weak self] in self?.show() }
    let mainMenu = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(
      withTitle: "Quit MenuLens", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
    )
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)
    let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(
      withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)
    NSApp.mainMenu = mainMenu
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.button?.image = NSImage(
      systemSymbolName: "command.circle", accessibilityDescription: "MenuLens")
    statusItem?.button?.target = self
    statusItem?.button?.action = #selector(summon)
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] note in
      guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
        app.processIdentifier != ProcessInfo.processInfo.processIdentifier
      else { return }
      MainActor.assumeIsolated { self?.model.lastTarget = app }
    }
    let pointer = Unmanaged.passUnretained(self).toOpaque()
    var specification = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, data in
        guard let data else { return noErr }
        let delegate = Unmanaged<AppDelegate>.fromOpaque(data).takeUnretainedValue()
        Task { @MainActor in delegate.summon() }
        return noErr
      }, 1, &specification, pointer, nil)
    let status = RegisterEventHotKey(
      UInt32(kVK_Space), UInt32(controlKey | optionKey),
      EventHotKeyID(signature: 0x4D4C_4E53, id: 1), GetApplicationEventTarget(), 0, &hotKey
    )
    if status != noErr {
      model.error = "Global shortcut unavailable. Use the menu bar icon to capture."
    }
    show()
    if CommandLine.arguments.contains("--showcase") {
      Task {
        do {
          let snapshot = try await CommandLineRunner.prepareTextEdit()
          model.snapshot = snapshot
          model.lastTarget = NSRunningApplication(processIdentifier: snapshot.pid)
          model.goal = "make these words all caps"
          show()
          model.search()
        } catch { model.error = error.localizedDescription }
      }
    }
  }

  func show() {
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc func summon() { model.capture() }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    show()
    return true
  }
}

struct LensView: View {
  @ObservedObject var model: LensModel
  private let mint = Color(red: 0.56, green: 0.91, blue: 0.77)

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .center) {
        ZStack {
          RoundedRectangle(cornerRadius: 13).fill(mint.opacity(0.14)).frame(width: 48, height: 48)
          Image(systemName: "command").font(.system(size: 27, weight: .medium)).foregroundStyle(
            mint)
        }
        VStack(alignment: .leading, spacing: 3) {
          Text("MenuLens").font(.system(size: 25, weight: .semibold, design: .rounded))
          Text("YOUR WORDS. THE APP’S REAL COMMANDS.")
            .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.8)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text("⌃ ⌥ SPACE").font(.system(size: 12, design: .monospaced))
          .padding(9).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
      }
      .padding(.top, 32).padding(.bottom, 22)

      HStack(spacing: 10) {
        Circle().fill(model.snapshot == nil ? .orange : mint).frame(width: 6, height: 6)
        Text(model.snapshot?.context.app ?? "No target captured").font(
          .system(size: 12, weight: .semibold))
        Text(model.snapshot?.context.window ?? "Focus an app and summon the lens")
          .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
        Spacer()
        Menu {
          Button("Capture TextEdit") { model.captureApp("com.apple.TextEdit") }
          Button("Capture Finder") { model.captureApp("com.apple.finder") }
          Button("Capture Safari") { model.captureApp("com.apple.Safari") }
          Divider()
          Button("Open TextEdit sample") { model.openSample() }
          Button("Enable Accessibility…") { NativeMenus.requestPermission() }
        } label: {
          Label("Target", systemImage: "scope")
        }
        Button {
          model.capture()
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .help("Recapture the last active app")
      }
      .padding(12).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))

      HStack(spacing: 12) {
        Image(systemName: "sparkle.magnifyingglass").font(.system(size: 23)).foregroundStyle(mint)
        TextField("What do you want to do?", text: $model.goal)
          .textFieldStyle(.plain).font(.system(size: 23, weight: .medium))
          .onSubmit { model.search() }
          .onChange(of: model.goal) { _, _ in model.invalidate() }
        Button(action: model.search) {
          Text("Find command").font(.system(size: 12, weight: .semibold)).padding(.vertical, 7)
        }
        .buttonStyle(.borderedProminent).tint(mint).foregroundStyle(.black)
        .disabled(model.snapshot == nil || model.busy || model.goal.isEmpty)
      }
      .padding(18).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(mint.opacity(0.23)))
      .padding(.top, 16)

      HStack(spacing: 8) {
        if model.busy { ProgressView().controlSize(.small) }
        Text(model.error.isEmpty ? model.activity : model.error)
          .font(.system(size: 11)).foregroundStyle(model.error.isEmpty ? .secondary : Color.orange)
          .lineLimit(2)
        Spacer()
        if model.busy { Text("\(model.elapsed) ms").monospacedDigit().font(.system(size: 11)) }
      }.frame(height: 42)

      HStack(alignment: .top, spacing: 18) {
        VStack(alignment: .leading, spacing: 9) {
          sectionLabel("01", "RANKED COMMANDS")
          if let ranking = model.ranking {
            ScrollView {
              VStack(spacing: 7) {
                ForEach(Array(ranking.commands.prefix(8).enumerated()), id: \.element.id) {
                  index, result in
                  commandRow(result, index: index)
                }
              }
            }
          } else {
            VStack(alignment: .leading, spacing: 20) {
              Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 37))
                .foregroundStyle(mint.opacity(0.7))
              Text("Know the outcome.\nSkip the menu hunt.").font(
                .system(size: 25, weight: .medium))
              Text(
                "“make these words all caps”\n“sort by when files changed”\n“show the navigation column”"
              )
              .font(.system(size: 14)).foregroundStyle(.secondary).lineSpacing(10)
              Button("Open a sample in TextEdit") { model.openSample() }
                .buttonStyle(.bordered)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
          }
        }.frame(maxWidth: .infinity)
        VStack(alignment: .leading, spacing: 13) {
          sectionLabel("02", "COMMAND PREVIEW")
          if let result = model.selected {
            VStack(alignment: .leading, spacing: 17) {
              Image(
                systemName: model.ranking?.routeID == nil
                  ? "questionmark.circle" : "cursorarrow.click"
              )
              .font(.system(size: 27)).foregroundStyle(mint)
              Text(result.candidate.title).font(.system(size: 23, weight: .semibold))
              Text(result.candidate.breadcrumb)
                .font(.system(size: 12)).foregroundStyle(mint).fixedSize(
                  horizontal: false, vertical: true)
              Divider()
              HStack {
                Text(result.candidate.enabled ? "Enabled" : "Disabled").foregroundStyle(
                  result.candidate.enabled ? mint : .orange)
                Spacer()
                Text(result.candidate.checked ? "✓ Checked" : result.candidate.shortcut)
              }.font(.system(size: 12, design: .monospaced))
              Text(
                String(
                  format: "%.2f / 3 relevance  ·  %.0f%% concentration", result.score,
                  result.confidence * 100)
              )
              .font(.system(size: 11)).foregroundStyle(.secondary)
              if let selection = model.snapshot?.context.selection, !selection.isEmpty {
                Text("SELECTED IN TARGET").font(.system(size: 9, weight: .semibold))
                  .foregroundStyle(.secondary)
                Text("“\(selection)”").font(.system(size: 13, design: .serif)).lineLimit(3)
                  .textSelection(.enabled)
              }
              Text(
                "Evidence is copied from macOS. Scores are Jev judgments, not proof of correctness."
              )
              .font(.system(size: 11)).foregroundStyle(.secondary)
              Button(action: model.execute) {
                HStack {
                  Text("Run this command")
                  Spacer()
                  Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 13, weight: .semibold)).padding(.vertical, 7)
              }
              .buttonStyle(.borderedProminent).tint(mint).foregroundStyle(.black)
              .disabled(
                model.busy || model.ranking?.routeID == nil || !result.candidate.enabled
                  || result.score < 2.25 || result.confidence < 0.5)
            }.padding(19).background(mint.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
          } else {
            VStack(alignment: .leading, spacing: 18) {
              Image(systemName: "checkmark.shield").font(.system(size: 27)).foregroundStyle(mint)
              Text("You stay in control.").font(.system(size: 18, weight: .medium))
              Text(
                "The lens reads live menu paths, availability and selection. Jev compares meanings. You preview and choose the exact native command."
              )
              .font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(5)
              Text("No generated scripts.\nNo blind clicks.\nNo silent execution.")
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(mint.opacity(0.8))
                .lineSpacing(7)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
              .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
          }
        }.frame(width: 330)
      }.frame(maxHeight: .infinity, alignment: .top)
      Divider().padding(.top, 12)
      HStack(spacing: 12) {
        Text("LIVE AX").foregroundStyle(mint)
        if let ranking = model.ranking {
          Text(ranking.model)
          Text(
            ranking.cached
              ? "memory cache • 0 requests"
              : "\(ranking.requests) requests • \(ranking.milliseconds) ms")
        } else {
          Text("Powered by Jev • text decisions, native actions")
        }
        Spacer()
        Button("\(model.snapshot?.candidates.count ?? 0) indexed ↗") { model.showIndex = true }
          .buttonStyle(.plain).foregroundStyle(mint)
      }.font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).padding(
        .vertical, 13)
      Text(
        "Sent on Find: intent, app/window title, up to 180 selected characters & supported menu paths."
      )
      .font(.system(size: 9)).foregroundStyle(.secondary).padding(.bottom, 12)
    }
    .padding(.horizontal, 26).background(Color(red: 0.055, green: 0.067, blue: 0.09))
    .sheet(isPresented: $model.showIndex) { indexView }
  }

  private func sectionLabel(_ number: String, _ title: String) -> some View {
    HStack(spacing: 8) {
      Text(number).foregroundStyle(mint)
      Text(title).foregroundStyle(.secondary).tracking(1.2)
    }.font(.system(size: 10, weight: .medium, design: .monospaced)).padding(.bottom, 3)
  }

  private func commandRow(_ result: RankedCommand, index: Int) -> some View {
    Button {
      model.selectedID = result.id
    } label: {
      HStack(spacing: 12) {
        Text(String(format: "%02d", index + 1)).font(.system(size: 11, design: .monospaced))
          .foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 5) {
          Text(result.candidate.title).font(.system(size: 14, weight: .medium))
          Text(result.candidate.path.dropLast().joined(separator: " › "))
            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text(String(format: "%.2f", result.score)).font(
            .system(size: 14, weight: .medium, design: .monospaced))
          Text(!result.candidate.enabled ? "DISABLED" : result.score < 2.25 ? "NEAR MISS" : "MATCH")
            .font(.system(size: 8, weight: .semibold)).foregroundStyle(
              result.score < 2.25 ? .secondary : mint)
        }
      }
      .padding(12).background(
        model.selectedID == result.id ? mint.opacity(0.12) : .white.opacity(0.035),
        in: RoundedRectangle(cornerRadius: 9)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 9).stroke(
          model.selectedID == result.id ? mint.opacity(0.35) : .clear))
    }.buttonStyle(.plain)
  }

  private var indexView: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Actual menu index").font(.title2.bold())
        Spacer()
        Button("Done") { model.showIndex = false }
      }
      Text(
        "All observed leaves are listed locally. Only reversible allowlisted commands are sent for ranking. English menu labels are required for execution."
      )
      .font(.callout).foregroundStyle(.secondary)
      if model.snapshot?.truncated == true {
        Text("Index incomplete: safety traversal limit reached.").foregroundStyle(.orange)
      }
      List(model.snapshot?.candidates ?? []) { candidate in
        HStack {
          Text(candidate.breadcrumb).textSelection(.enabled)
          Spacer()
          Text(!candidate.enabled ? "Disabled" : candidate.permitted ? "Supported" : "Preview only")
            .foregroundStyle(.secondary)
        }.font(.system(size: 12))
      }
    }.padding(24).frame(width: 760, height: 530)
  }
}
