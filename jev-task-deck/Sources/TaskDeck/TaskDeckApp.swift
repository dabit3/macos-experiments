import AppKit
import SwiftUI
import TaskDeckCore

@main
struct TaskDeckApp: App {
  @StateObject private var model = DeckModel()
  init() {
    if CommandLine.arguments.contains("--eval") || CommandLine.arguments.contains("--native-smoke")
    {
      CommandRunner.start()
    }
  }
  var body: some Scene {
    WindowGroup("TaskDeck") {
      DeckView(model: model)
        .disabled(model.acting)
        .frame(minWidth: 1000, minHeight: 710)
        .task {
          NSApplication.shared.setActivationPolicy(.regular)
          NSApplication.shared.activate(ignoringOtherApps: true)
          if CommandLine.arguments.contains("--showcase") {
            await model.openDemo()
          }
        }
    }
    .defaultSize(width: 1080, height: 770)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(after: .undoRedo) {
        Button("Undo desktop arrangement") { model.undo() }
          .keyboardShortcut("z").disabled(!model.canUndo)
      }
    }
  }
}

@MainActor
final class DeckModel: ObservableObject {
  @Published var goal = "Bring back the Atlas launch review"
  @Published var windows: [WindowEvidence] = []
  @Published var judgments: [UUID: Judgment] = [:]
  @Published var failures: [UUID: String] = [:]
  @Published var selected: Set<UUID> = []
  @Published var permitted: Set<String> = []
  @Published var apps: [NSRunningApplication] = []
  @Published var busy = false
  @Published var acting = false
  @Published var status = "Choose apps to include, then find your task."
  @Published var activity: [String] = []
  @Published var elapsed = 0.0
  @Published var requests = 0
  @Published var modelName = "Jev · ready"
  @Published var canUndo = false
  @Published var showScope = false
  @Published var showEvidence: UUID?
  let native = NativeWindows()
  private let jev = JevClient()
  private var work: Task<Void, Never>?
  private var generation = UUID()
  private var hasSearched = false

  init() { refreshApps() }
  var sorted: [WindowEvidence] {
    windows.sorted {
      let left = judgments[$0.id]?.rank ?? -1
      let right = judgments[$1.id]?.rank ?? -1
      return left == right ? $0.title < $1.title : left > right
    }
  }
  func refreshApps() { apps = native.availableApps() }
  func setScope(_ bundle: String, included: Bool) {
    work?.cancel()
    generation = UUID()
    busy = false
    windows = []
    judgments = [:]
    selected = []
    if included { permitted.insert(bundle) } else { permitted.remove(bundle) }
    status = "App scope changed. Submit your task to capture fresh evidence."
  }
  func changedGoal() {
    work?.cancel()
    generation = UUID()
    selected = []
    judgments = [:]
    failures = [:]
    busy = false
    status = "Task changed. Refreshing decisions…"
    guard hasSearched else { return }
    work = Task {
      do {
        try await Task.sleep(nanoseconds: 600_000_000)
        if !Task.isCancelled { search() }
      } catch {}
    }
  }
  func search() {
    guard !acting else { return }
    work?.cancel()
    let run = UUID()
    generation = run
    busy = false
    selected = []
    let intent = goal.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !intent.isEmpty, intent.count <= 600 else {
      status = "Enter a task between 1 and 600 characters."
      return
    }
    guard !permitted.isEmpty else {
      showScope = true
      return
    }
    do { windows = try native.capture(bundleIDs: permitted) } catch {
      status = error.localizedDescription
      return
    }
    judgments = [:]
    failures = [:]
    selected = []
    requests = 0
    elapsed = 0
    activity = native.notices
    hasSearched = true
    guard !windows.isEmpty else {
      status = "No supported windows in the selected apps."
      return
    }
    busy = true
    status = "Reading \(windows.count) windows against your task…"
    let snapshots = windows
    let start = Date()
    work = Task {
      await withTaskGroup(of: (UUID, Result<Judgment, Error>).self) { group in
        var next = 0
        func enqueue(_ window: WindowEvidence) {
          group.addTask { [jev] in
            do {
              return (
                window.id,
                .success(try await jev.evaluate(EvaluationState(goal: intent, window: window)))
              )
            } catch { return (window.id, .failure(error)) }
          }
        }
        for _ in 0..<min(4, snapshots.count) {
          enqueue(snapshots[next])
          next += 1
        }
        for await (id, result) in group {
          guard generation == run, !Task.isCancelled else {
            group.cancelAll()
            return
          }
          switch result {
          case .success(let judgment):
            judgments[id] = judgment
            modelName = judgment.model
            requests += judgment.requests
          case .failure(let error): failures[id] = error.localizedDescription
          }
          elapsed = Date().timeIntervalSince(start)
          status = "Judged \(judgments.count + failures.count) / \(snapshots.count) windows"
          if next < snapshots.count {
            enqueue(snapshots[next])
            next += 1
          }
        }
      }
      guard generation == run, !Task.isCancelled else { return }
      selected = Set(sorted.filter { judgments[$0.id]?.selected == true }.prefix(4).map(\.id))
      busy = false
      status =
        selected.isEmpty
        ? "No confident match. Review evidence or try another task."
        : "\(selected.count) windows ready. Review the set, then compose."
      if !failures.isEmpty { status += " \(failures.count) requests failed." }
    }
  }
  func toggle(_ id: UUID) {
    if selected.contains(id) {
      selected.remove(id)
    } else if selected.count < 4, judgments[id] != nil {
      selected.insert(id)
    }
  }
  func compose() {
    guard !acting, !busy else { return }
    acting = true
    status = "Composing selected windows…"
    let ids = sorted.filter { selected.contains($0.id) }.map(\.id)
    Task {
      defer {
        acting = false
        canUndo = native.canUndo
      }
      do {
        activity = try await native.arrange(ids: ids)
        status = "Window actions finished. Review activity; Undo restores the observed state."
      } catch { status = error.localizedDescription }
    }
  }
  func undo() {
    guard !acting, native.canUndo else { return }
    acting = true
    status = "Restoring previous window state…"
    Task {
      activity = await native.undo()
      canUndo = native.canUndo
      acting = false
      status =
        canUndo
        ? "Some windows could not restore; see activity and retry."
        : "Undo finished. See per-window readback below."
    }
  }
  func openDemo() async {
    do {
      try await Fixtures.open()
      permitted.insert("com.apple.TextEdit")
      refreshApps()
      search()
    } catch { status = error.localizedDescription }
  }
}

struct DeckView: View {
  @ObservedObject var model: DeckModel
  private let ink = Color(red: 0.07, green: 0.10, blue: 0.14)
  private let mint = Color(red: 0.70, green: 0.94, blue: 0.79)
  private let paper = Color(red: 0.96, green: 0.97, blue: 0.96)

  var body: some View {
    HStack(spacing: 0) {
      sidebar
      VStack(alignment: .leading, spacing: 0) {
        header
        Divider()
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Text("YOUR WORKING SET").font(.system(size: 11, weight: .bold, design: .monospaced))
              Spacer()
              Text("\(model.windows.count) observed · \(model.selected.count) selected")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if model.windows.isEmpty {
              emptyState
            } else {
              LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(model.sorted) { window in card(window) }
              }
            }
            if !model.activity.isEmpty {
              VStack(alignment: .leading, spacing: 5) {
                Text("NATIVE ACTIVITY").font(.system(size: 10, weight: .bold, design: .monospaced))
                ForEach(Array(model.activity.enumerated()), id: \.offset) { _, line in
                  Text(line).font(.system(size: 11)).foregroundStyle(.secondary)
                }
              }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            }
          }.padding(24)
        }
        footer
      }.background(paper).foregroundStyle(ink)
    }
    .background(ink)
    .preferredColorScheme(.light)
    .sheet(isPresented: $model.showScope) { scope }
    .onChange(of: model.goal) { _, _ in model.changedGoal() }
    .sheet(
      item: Binding(
        get: { model.windows.first { $0.id == model.showEvidence } },
        set: { model.showEvidence = $0?.id })
    ) { window in
      VStack(alignment: .leading, spacing: 16) {
        Text(window.title).font(.title2.bold())
        Text(
          "\(window.app) · observed \(window.capturedAt.formatted(date: .omitted, time: .standard))"
        )
        .foregroundStyle(.secondary)
        Text("Verbatim accessibility evidence • at most 4,000 characters")
          .font(.caption)
        ScrollView {
          Text(
            window.document + "\n\n"
              + (window.text.isEmpty ? "No text exposed by this app." : window.text)
          )
          .font(.system(size: 13, design: .monospaced)).textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        Button("Done") { model.showEvidence = nil }.keyboardShortcut(.defaultAction)
      }.padding(26).frame(width: 660, height: 480)
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        Image(systemName: "rectangle.3.group.fill").font(.system(size: 25)).foregroundStyle(mint)
        Text("TaskDeck").font(.system(size: 23, weight: .semibold))
      }.padding(.top, 38)
      Text("A desktop for your intent.").font(.system(size: 12)).foregroundStyle(
        .white.opacity(0.5)
      )
      .padding(.top, 10)
      Rectangle().fill(.white.opacity(0.12)).frame(height: 1).padding(.vertical, 28)
      Text("PICK UP A THREAD").font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(.white.opacity(0.4)).padding(.bottom, 18)
      thread(
        "Atlas launch", subtitle: "Decisions, risks, run of show", icon: "paperplane",
        goal: "Bring back the Atlas launch review")
      thread(
        "Expense close", subtitle: "Reconcile September 2026", icon: "creditcard",
        goal: "Show what I need to reconcile September 2026 expenses, excluding personal purchases")
      thread(
        "Hiring loop", subtitle: "Maya Chen · platform role", icon: "person.crop.rectangle",
        goal: "Prepare Maya Chen's platform engineering interview debrief")
      Spacer()
      VStack(alignment: .leading, spacing: 12) {
        Label("Real windows. Live Jev.", systemImage: "circle.fill")
          .font(.system(size: 11, weight: .medium)).foregroundStyle(mint)
        Text("You choose the apps.\nJev judges the evidence.\nYou compose the desktop.")
          .font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)).lineSpacing(5)
        Button {
          Task { await model.openDemo() }
        } label: {
          Label("Open demo desktop", systemImage: "play.fill")
            .font(.system(size: 12, weight: .semibold)).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }.buttonStyle(.plain).background(
          .white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
        Text("Opens 8 synthetic TextEdit documents.").font(.system(size: 9)).foregroundStyle(
          .white.opacity(0.35))
      }.padding(.bottom, 26)
    }.padding(.horizontal, 23).frame(width: 235).foregroundStyle(.white)
  }
  private func thread(_ title: String, subtitle: String, icon: String, goal: String) -> some View {
    Button {
      model.goal = goal
    } label: {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: icon).font(.system(size: 16)).frame(width: 20).padding(.top, 2)
        VStack(alignment: .leading, spacing: 5) {
          Text(title).font(.system(size: 13, weight: .semibold))
          Text(subtitle).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
        }
        Spacer(minLength: 0)
      }.padding(.vertical, 15)
    }.buttonStyle(.plain)
  }
  private var header: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack {
        Text("LESS HUNTING. MORE DOING.").font(
          .system(size: 10, weight: .bold, design: .monospaced)
        )
        .foregroundStyle(.secondary)
        Spacer()
        Button {
          model.refreshApps()
          model.showScope = true
        } label: {
          Label("\(model.permitted.count) apps in scope", systemImage: "slider.horizontal.3")
            .font(.system(size: 11))
        }.buttonStyle(.plain)
      }
      Text("What are you getting back to?").font(.system(size: 27, weight: .semibold))
      HStack(spacing: 14) {
        Image(systemName: "sparkle").font(.system(size: 22)).foregroundStyle(Color.teal)
        TextField("Describe the task, not the window title", text: $model.goal)
          .textFieldStyle(.plain).font(.system(size: 15)).onSubmit { model.search() }
        Button(action: model.search) {
          Image(systemName: "arrow.right").font(.system(size: 16, weight: .semibold))
            .frame(width: 36, height: 36).background(ink, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
        }.buttonStyle(.plain).help("Capture permitted windows and ask Jev")
      }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(.black.opacity(0.1)))
      HStack(spacing: 8) {
        if model.busy {
          ProgressView().controlSize(.small)
        } else {
          Circle().fill(model.judgments.isEmpty ? Color.gray : Color.teal).frame(
            width: 6, height: 6)
        }
        Text(model.status).font(.system(size: 11)).lineLimit(2)
        Spacer(minLength: 0)
      }.frame(minHeight: 28)
    }.padding(24).padding(.top, 15)
  }
  private func card(_ window: WindowEvidence) -> some View {
    let judgment = model.judgments[window.id]
    let chosen = model.selected.contains(window.id)
    return VStack(alignment: .leading, spacing: 11) {
      HStack {
        Image(
          nsImage: NSWorkspace.shared.icon(
            forFile: NSWorkspace.shared.urlForApplication(
              withBundleIdentifier: window.bundleID)?.path ?? "")
        )
        .resizable().frame(width: 22, height: 22)
        Text(window.app).font(.system(size: 11)).foregroundStyle(.secondary)
        Spacer()
        Button {
          model.toggle(window.id)
        } label: {
          Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 20)).foregroundStyle(chosen ? Color.teal : Color.gray.opacity(0.4))
        }.buttonStyle(.plain).disabled(judgment == nil || model.busy)
      }
      Text(window.title.isEmpty ? "Untitled window" : window.title)
        .font(.system(size: 14, weight: .semibold)).lineLimit(1)
      Text(
        window.text.isEmpty
          ? "No body text exposed. Inspect metadata before selecting." : window.text
      )
      .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(3)
      .frame(height: 43, alignment: .top).frame(maxWidth: .infinity, alignment: .leading)
      if let judgment {
        HStack(spacing: 7) {
          Text(judgment.label).font(.system(size: 10, weight: .semibold))
            .foregroundStyle(judgment.contradiction >= 0.65 ? Color.orange : Color.teal)
          Spacer()
          Text(String(format: "%.1f / 3", judgment.relevance))
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            Capsule().fill(.black.opacity(0.06))
            Capsule().fill(chosen ? Color.teal : Color.gray.opacity(0.4))
              .frame(width: geometry.size.width * judgment.relevance / 3)
          }
        }.frame(height: 3)
        HStack {
          Text(
            String(
              format: "P(conflict) %.0f%% · concentration %.0f%%",
              judgment.contradiction * 100, judgment.confidence * 100)
          )
          .font(.system(size: 9)).foregroundStyle(.secondary)
          Spacer(minLength: 0)
          Button("Evidence") { model.showEvidence = window.id }
            .buttonStyle(.plain).font(.system(size: 10, weight: .medium)).foregroundStyle(.teal)
        }
      } else {
        Text(model.failures[window.id] ?? "Waiting for live judgment…")
          .font(.system(size: 10)).foregroundStyle(
            model.failures[window.id] == nil ? .secondary : Color.red
          )
          .lineLimit(3).frame(height: 36)
      }
    }.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12).stroke(
          chosen ? Color.teal.opacity(0.5) : .black.opacity(0.07), lineWidth: 1))
  }
  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 16) {
      Image(systemName: "rectangle.3.group").font(.system(size: 40, weight: .light))
        .foregroundStyle(.teal)
      Text("Your next task is already open.").font(.title2.weight(.medium))
      Text(
        "Find the right windows by what they contain—even when the titles are misleading. Review the evidence, compose up to four windows, and undo the layout in one click."
      )
      .font(.system(size: 14)).foregroundStyle(.secondary).lineSpacing(5)
      Button("Choose apps to include") { model.showScope = true }.buttonStyle(.borderedProminent)
        .tint(.teal)
    }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
      .background(.white, in: RoundedRectangle(cornerRadius: 16))
  }
  private var footer: some View {
    VStack(spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(model.modelName).font(.system(size: 11, weight: .semibold, design: .monospaced))
          Text(
            "\(model.requests) requests · \(String(format: "%.2f", model.elapsed))s batch · max 4 in flight"
          )
          .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        Spacer()
        Button("Undo layout", action: model.undo).disabled(!model.canUndo).buttonStyle(.bordered)
        Button(action: model.compose) {
          Label("Compose \(model.selected.count) windows", systemImage: "rectangle.split.2x2")
            .padding(.horizontal, 6).padding(.vertical, 5)
        }.buttonStyle(.borderedProminent).tint(ink)
          .disabled(model.selected.isEmpty || model.busy || model.canUndo)
      }
      HStack {
        Text("One desktop · no closing documents · no Space switching")
        Spacer()
        Text("Scores are judgments, not guarantees")
      }.font(.system(size: 9)).foregroundStyle(.secondary)
    }.padding(.horizontal, 24).padding(.vertical, 17).background(.white)
  }
  private var scope: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Choose the apps Jev may read").font(.title2.bold())
      Text(
        "Only checked apps are captured. Titles, document URLs and up to 4,000 characters of accessibility text per window are sent to TypeSafe when you search. No screenshots, files, password fields or home-folder crawling."
      )
      .font(.system(size: 13)).foregroundStyle(.secondary)
      if !model.native.trusted {
        Button("Grant Accessibility in System Settings") { model.native.requestPermission() }
      }
      ScrollView {
        ForEach(model.apps, id: \.processIdentifier) { app in
          if let bundle = app.bundleIdentifier {
            Toggle(
              app.localizedName ?? bundle,
              isOn: Binding(
                get: { model.permitted.contains(bundle) },
                set: {
                  model.setScope(bundle, included: $0)
                })
            )
            .padding(.vertical, 5)
          }
        }
      }
      Text(
        "Apps can omit text or reject resizing. Full-screen windows are skipped. Accessibility permission stays in macOS; this scope is kept only for this session."
      )
      .font(.caption).foregroundStyle(.secondary)
      HStack {
        Button("Refresh app list", action: model.refreshApps)
        Spacer()
        Button("Done") { model.showScope = false }.keyboardShortcut(.defaultAction)
      }
    }.padding(28).frame(width: 550, height: 470)
  }
}
