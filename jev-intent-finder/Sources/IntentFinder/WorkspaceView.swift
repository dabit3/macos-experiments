import IntentCore
import SwiftUI

private let ink = Color(red: 0.10, green: 0.19, blue: 0.22)
private let teal = Color(red: 0.06, green: 0.44, blue: 0.39)
private let paper = Color(red: 0.97, green: 0.97, blue: 0.94)

struct WorkspaceView: View {
  @StateObject private var store = AppModel()
  var body: some View {
    HStack(spacing: 0) {
      sidebar
      VStack(spacing: 0) {
        searchHeader
        Divider()
        statusStrip
        Divider()
        HStack(spacing: 0) {
          resultPanel.frame(width: 365)
          Divider()
          evidence.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        Divider()
        footer
      }
      .background(paper)
    }
    .tint(teal)
    .foregroundStyle(ink)
    .onAppear {
      store.demo()
      if CommandLine.arguments.contains("--showcase") { store.search() }
    }
    .alert(
      "IntentFinder",
      isPresented: Binding(
        get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(spacing: 10) {
        Image(systemName: "viewfinder").font(.system(size: 27, weight: .medium))
        Text("Intent\nFinder").font(.system(size: 21, weight: .bold, design: .rounded))
      }
      .padding(.top, 22)
      Text("MEANING → FILE").font(.system(size: 10, weight: .semibold, design: .monospaced))
        .tracking(2).foregroundStyle(.white.opacity(0.55))
      Divider().overlay(.white.opacity(0.15))
      VStack(alignment: .leading, spacing: 12) {
        label("SEARCH SCOPE")
        Label(store.scope?.lastPathComponent ?? "No folder", systemImage: "folder.fill")
          .font(.system(size: 14, weight: .semibold))
        Text("\(store.documents.count) readable documents")
          .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
        sideButton("Choose folder…", icon: "folder.badge.plus", action: store.chooseFolder)
        sideButton("Use Finder window", icon: "macwindow", action: store.finderScope)
        sideButton("Demo vault", icon: "sparkles", action: store.demo)
      }
      Divider().overlay(.white.opacity(0.15))
      VStack(alignment: .leading, spacing: 12) {
        label("TRY AN INTENT")
        scenario("01", "The real agreement", "Signed. No-cause exit.", AppModel.signature)
        scenario(
          "02", "Customer workarounds", "Evidence, not planning.",
          "customer interviews that mention a workaround, excluding internal planning")
        scenario(
          "03", "Equipment receipts", "Purchases, not subscriptions.",
          "receipts for equipment, not subscriptions")
      }
      Spacer()
      VStack(alignment: .leading, spacing: 8) {
        Label("Paths stay on your Mac", systemImage: "lock.shield")
          .font(.system(size: 11, weight: .semibold))
        Text(
          "Search sends the intent and extracted document text to TypeSafe. Never filenames or folder paths."
        )
        .font(.system(size: 11)).lineSpacing(3).foregroundStyle(.white.opacity(0.58))
        Text("TXT · MD · RTF · PDF").font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(.white.opacity(0.45))
      }
    }
    .padding(22).frame(width: 210).frame(maxHeight: .infinity)
    .background(ink).foregroundStyle(.white)
  }

  private func label(_ text: String) -> some View {
    Text(text).font(.system(size: 10, weight: .semibold)).tracking(1.5)
      .foregroundStyle(.white.opacity(0.45))
  }

  private func sideButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View
  {
    Button(action: action) { Label(title, systemImage: icon).font(.system(size: 12)) }
      .buttonStyle(.plain).padding(.vertical, 3)
  }

  private func scenario(_ number: String, _ title: String, _ detail: String, _ query: String)
    -> some View
  {
    Button {
      store.query = query
      store.search()
    } label: {
      HStack(alignment: .top, spacing: 10) {
        Text(number).font(.system(size: 10, design: .monospaced))
          .foregroundStyle(Color.mint.opacity(0.7)).padding(.top, 3)
        VStack(alignment: .leading, spacing: 4) {
          Text(title).font(.system(size: 12, weight: .medium))
          Text(detail).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
    }.buttonStyle(.plain).padding(.vertical, 4)
  }

  private var searchHeader: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Find what you mean.").font(.system(size: 27, weight: .semibold, design: .serif))
        Spacer()
        Label("LIVE JEV", systemImage: "circle.fill")
          .font(.system(size: 10, weight: .bold, design: .monospaced))
          .foregroundStyle(teal).padding(8).background(teal.opacity(0.08), in: Capsule())
      }
      HStack(alignment: .center, spacing: 12) {
        Image(systemName: "magnifyingglass").font(.system(size: 19)).foregroundStyle(teal)
        TextField(
          "Describe the file, including what to exclude…", text: $store.query, axis: .vertical
        )
        .font(.system(size: 15)).textFieldStyle(.plain).lineLimit(2...3)
        .onSubmit { store.search() }
        Button(store.busy ? "Stop" : "Find") {
          if store.busy { store.cancel() } else { store.search() }
        }.buttonStyle(.borderedProminent).controlSize(.large)
      }
      .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(teal.opacity(0.25), lineWidth: 1))
      Text(
        "All eligible documents in scope. Meaning ranked separately from requirements and contradictions."
      )
      .font(.system(size: 11)).foregroundStyle(.secondary)
    }.padding(.horizontal, 26).padding(.top, 30).padding(.bottom, 18)
  }

  private var statusStrip: some View {
    HStack(spacing: 18) {
      if store.busy { ProgressView().controlSize(.small) }
      Text(
        store.busy
          ? "\(store.completed)/\(store.documents.count)" : "\(store.matches.count) matches"
      )
      .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(teal)
      Text(String(format: "%.2f s", store.elapsed)).font(.system(size: 12, design: .monospaced))
      Text("\(store.requests) HTTP requests").font(.system(size: 11)).foregroundStyle(.secondary)
      Spacer()
      Text(store.model).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
    }.padding(.horizontal, 26).padding(.vertical, 12)
  }

  private var resultPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("RESULTS").font(.system(size: 10, weight: .semibold)).tracking(1.5)
        Spacer()
        Picker("Ranking", selection: $store.baseline) {
          Text("Jev").tag(false)
          Text("Filename").tag(true)
        }.pickerStyle(.segmented).frame(width: 160)
      }.padding(18)
      if store.results.isEmpty {
        VStack(alignment: .leading, spacing: 16) {
          Image(systemName: "doc.text.magnifyingglass").font(.system(size: 40)).foregroundStyle(
            teal.opacity(0.5))
          Text("A filename is only a label.").font(.system(size: 20, design: .serif))
          Text("Search the demo vault to find an executed contract hiding behind scan_0042.pdf.")
            .font(.system(size: 13)).foregroundStyle(.secondary)
        }.padding(24)
        Spacer()
      } else {
        if store.baseline {
          Text("Local token overlap in filenames only.\nA reproducible baseline, not Spotlight.")
            .font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 18).padding(
              .bottom, 10)
        }
        List(selection: $store.selection) {
          ForEach(Array(store.displayed.enumerated()), id: \.element.id) { index, result in
            row(result, index: index).tag(result.id)
          }
        }.listStyle(.plain).scrollContentBackground(.hidden)
          .onKeyPress(.return) {
            if store.actionable { store.act("reveal") }
            return .handled
          }
      }
      HStack {
        Image(systemName: "command")
        Text("Click to inspect · ⌘ click to select several")
      }.font(.system(size: 10)).foregroundStyle(.secondary).padding(15)
    }
  }

  private func row(_ result: RankedDocument, index: Int) -> some View {
    HStack(alignment: .top, spacing: 11) {
      Text(String(format: "%02d", index + 1))
        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).padding(.top, 5)
      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Image(
            systemName: result.document.url.pathExtension == "pdf" ? "doc.richtext" : "doc.text"
          )
          .foregroundStyle(result.accepted ? teal : .secondary)
          Text(result.document.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
        }
        HStack {
          Text(result.status).font(.system(size: 10, weight: .medium))
            .foregroundStyle(result.accepted ? teal : .secondary)
          Spacer()
          if store.baseline {
            Text(
              "\(Documents.filenameOverlap(query: store.query, document: result.document)) tokens")
          } else if let judgment = result.judgment {
            Text(String(format: "%.0f%% fit", judgment.rank * 100))
          }
        }.font(.system(size: 10, design: .monospaced))
        Text(result.document.text.prefix(100)).font(.system(size: 10))
          .foregroundStyle(.secondary).lineLimit(2)
      }
    }.padding(.vertical, 9)
  }

  private var evidence: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let result = store.focused {
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("SOURCE EVIDENCE").font(.system(size: 10, weight: .semibold)).tracking(1.5)
            Spacer()
            Text(result.status).font(.system(size: 10, weight: .semibold))
              .foregroundStyle(result.accepted ? teal : .orange)
          }
          Text(result.document.name).font(.system(size: 23, weight: .medium, design: .serif))
            .textSelection(.enabled)
          Text(result.document.extraction).font(.system(size: 10)).foregroundStyle(.secondary)
          if let judgment = result.judgment {
            HStack(spacing: 16) {
              metric("RELEVANCE", String(format: "%.2f / 3", judgment.relevance))
              metric("REQUIREMENTS", String(format: "%.0f%% yes", judgment.requirements * 100))
              metric("CONTRADICTION", String(format: "%.0f%% yes", judgment.contradiction * 100))
            }.padding(.vertical, 8)
          }
          if let error = result.error {
            Text(error).font(.system(size: 12)).foregroundStyle(.red).textSelection(.enabled)
          }
        }.padding(22)
        Divider()
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            Text("VERBATIM EXTRACT · NOT MODEL-GENERATED")
              .font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(teal)
            Text(result.document.text).font(.system(size: 13)).lineSpacing(6).textSelection(
              .enabled
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            if let j = result.judgment {
              Text(
                String(
                  format:
                    "Score concentration %.2f · %.0f ms · %@\nConcentration describes the answer distribution, not correctness. Fit = relevance / 3 × requirements × (1 − contradiction).",
                  j.confidence, j.milliseconds, j.model)
              )
              .font(.system(size: 10)).foregroundStyle(.secondary)
            }
          }.padding(22)
        }
        Divider()
        HStack {
          Button("Reveal in Finder") { store.act("reveal") }.buttonStyle(.borderedProminent)
            .disabled(!store.actionable)
          Button("Quick Look") { store.act("preview") }.disabled(!store.actionable)
          Button("Open") { store.act("open") }.disabled(!store.actionable)
        }.controlSize(.small).padding(18)
      } else {
        Spacer()
        VStack(spacing: 14) {
          Image(systemName: "text.quote").font(.system(size: 42)).foregroundStyle(teal.opacity(0.3))
          Text("The proof stays beside the result.").font(.system(size: 20, design: .serif))
          Text("Select a document to inspect its actual text,\nrequirements and contradictions.")
            .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
        Spacer()
      }
    }.background(.white.opacity(0.65))
  }

  private func metric(_ name: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(name).font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary)
      Text(value).font(.system(size: 15, weight: .medium, design: .monospaced))
    }.frame(maxWidth: .infinity, alignment: .leading)
  }

  private var footer: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Circle().fill(store.busy ? Color.orange : teal).frame(width: 5, height: 5)
        Text(store.activity).font(.system(size: 10)).lineLimit(1)
        Spacer()
        Button("Select matches in Finder") { store.act("reveal", all: true) }
          .disabled(store.busy || store.matches.isEmpty).controlSize(.small)
      }
      if !store.finderSelection.isEmpty {
        Text(store.finderSelection).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
      }
      if !store.notices.isEmpty {
        DisclosureGroup("\(store.notices.count) extraction / scope notices") {
          ScrollView {
            Text(store.notices.joined(separator: "\n")).font(.system(size: 10)).textSelection(
              .enabled)
          }
          .frame(maxHeight: 80)
        }.font(.system(size: 10)).foregroundStyle(.orange)
      }
    }.padding(.horizontal, 20).padding(.vertical, 10)
  }
}
