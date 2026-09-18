import AppKit
import StageCore
import SwiftUI

private let ink = Color(red: 0.075, green: 0.16, blue: 0.18)
private let muted = Color(red: 0.38, green: 0.45, blue: 0.45)
private let accent = Color(red: 0.13, green: 0.43, blue: 0.34)
private let paper = Color(red: 0.96, green: 0.97, blue: 0.94)

struct StageView: View {
  @ObservedObject var model: StageModel
  var body: some View {
    HStack(spacing: 0) {
      sidebar.frame(width: 264)
      Rectangle().fill(ink.opacity(0.1)).frame(width: 1)
      VStack(alignment: .leading, spacing: 0) {
        header
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            scope
            if !model.selectedRows.isEmpty { results }
            if let row = model.rows.first(where: { $0.id == model.focused }) { inspector(row) }
            if model.rows.isEmpty { emptyState }
          }.padding(24)
        }
        footer
      }
      .background(Color.white)
    }
    .foregroundStyle(ink)
    .background(paper)
    .frame(minWidth: 1000, minHeight: 700)
    .preferredColorScheme(.light)
    .font(.system(size: 13))
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 9) {
        Image(systemName: "rectangle.on.rectangle.slash")
          .font(.system(size: 22, weight: .light)).foregroundStyle(accent)
        Text("ShareStage").font(.system(size: 21, weight: .semibold))
      }
      Text("THE RIGHT WINDOWS.\nTHE RIGHT AUDIENCE.")
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .tracking(1.8).foregroundStyle(muted).lineSpacing(4)
      Divider()
      VStack(alignment: .leading, spacing: 10) {
        eyebrow("01  SET THE ROOM")
        Text("Who’s watching?").font(.system(size: 22, weight: .medium, design: .serif))
        HStack(spacing: 5) {
          Button("Customer") { model.audience = StageModel.externalAudience }
          Button("Internal team") { model.audience = StageModel.internalAudience }
        }.buttonStyle(.bordered).controlSize(.small)
        TextEditor(text: $model.audience)
          .font(.system(size: 13)).lineSpacing(4)
          .scrollContentBackground(.hidden)
          .padding(9).background(.white)
          .clipShape(RoundedRectangle(cornerRadius: 9))
          .overlay(RoundedRectangle(cornerRadius: 9).stroke(ink.opacity(0.1)))
          .frame(height: 182)
        Text("Audience, purpose, and what must stay off stage.")
          .font(.system(size: 11)).foregroundStyle(muted)
      }
      VStack(alignment: .leading, spacing: 10) {
        eyebrow("02  CHOOSE THE SCOPE")
        Picker("App", selection: $model.appPID) {
          Text("Choose an app…").tag(pid_t(0))
          ForEach(model.apps) { app in Text(app.name).tag(app.id) }
        }.labelsHidden()
        HStack {
          Button("Add windows", action: model.loadWindows).disabled(model.appPID == 0 || model.busy)
          Button {
            model.refreshApps()
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .help("Refresh running apps")
        }.buttonStyle(.bordered).controlSize(.small)
        Button("Select TextEdit demo windows", action: model.selectDemoWindows)
          .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(accent)
        if !model.trusted {
          Button("Grant Accessibility…") { AXReader.requestPermission() }
            .buttonStyle(.borderedProminent).tint(accent)
          Text("System Settings → Privacy & Security → Accessibility → ShareStage")
            .font(.system(size: 10)).foregroundStyle(muted)
        }
      }
      Spacer(minLength: 0)
      VStack(alignment: .leading, spacing: 8) {
        Label("Your scope. Your control.", systemImage: "hand.raised")
          .font(.system(size: 11, weight: .semibold))
        Text(
          "Only selected windows’ accessible text goes to Jev. No screenshots, OCR, or background crawling."
        )
        .font(.system(size: 11)).foregroundStyle(muted).lineSpacing(3)
        Button("Clear scope & discard evidence", action: model.clearScope)
          .font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(accent)
      }
    }.padding(23)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          eyebrow("DESKTOP PREFLIGHT")
          Text("Make room for the moment.")
            .font(.system(size: 29, weight: .medium, design: .serif))
        }
        Spacer()
        Text(model.coverCount > 0 ? "●  STAGING LIVE" : "●  READY TO STAGE")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .foregroundStyle(accent).padding(9)
          .background(accent.opacity(0.08)).clipShape(Capsule())
      }
      HStack(spacing: 10) {
        Button(action: model.analyze) {
          HStack {
            Image(systemName: model.busy ? "hourglass" : "sparkle")
            Text(model.busy ? "Reading the room…" : "Analyze selected")
          }.padding(.vertical, 4)
        }.buttonStyle(.borderedProminent).tint(accent)
          .disabled(model.busy || model.selectedRows.isEmpty || model.audience.isEmpty)
        Button("Cover suggested (\(model.suggestedCount))", action: model.stageSuggested)
          .disabled(model.busy || model.suggestedCount == 0).buttonStyle(.bordered)
        Spacer()
        Button("Restore all", action: model.restore)
          .buttonStyle(.bordered).keyboardShortcut("r", modifiers: [.command, .shift])
      }
    }.padding(24).background(paper.opacity(0.7))
  }

  private var scope: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        eyebrow("WINDOWS IN SCOPE")
        Spacer()
        Text("\(model.selectedRows.count) selected / \(model.rows.count) observed")
          .font(.system(size: 11)).foregroundStyle(muted)
      }
      if !model.rows.isEmpty {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
          ForEach(model.rows) { row in
            Toggle(isOn: Binding(get: { row.selected }, set: { model.select(row.id, value: $0) })) {
              VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle(row)).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(row.target.appName).font(.system(size: 10)).foregroundStyle(muted)
              }
            }.toggleStyle(.checkbox).tint(accent).disabled(model.busy)
              .padding(10).frame(maxWidth: .infinity, alignment: .leading)
              .background(paper).clipShape(RoundedRectangle(cornerRadius: 7))
          }
        }
      }
    }
  }

  private var results: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 8) {
        counter("KEEP", count: model.keepCount, color: accent)
        counter(
          "COVER",
          count: model.selectedRows.filter { $0.verdict(audience: model.audience) == .cover }.count,
          color: .brown)
        counter("REVIEW", count: model.reviewCount, color: .orange)
      }
      ForEach([Verdict.cover, .review, .keep], id: \.self) { verdict in
        let rows = model.selectedRows.filter { $0.verdict(audience: model.audience) == verdict }
          .sorted {
            ($0.judgment?.response.answers.relevance.score ?? -1)
              > ($1.judgment?.response.answers.relevance.score ?? -1)
          }
        if !rows.isEmpty {
          VStack(alignment: .leading, spacing: 7) {
            HStack {
              Text(verdict.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5)
              Text(groupSubtitle(verdict)).font(.system(size: 10)).foregroundStyle(muted)
            }
            ForEach(rows) { row in resultCard(row, verdict: verdict) }
          }
        }
      }
    }
  }

  private func resultCard(_ row: WindowRow, verdict: Verdict) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 9) {
        Image(systemName: row.covered ? "rectangle.slash.fill" : "macwindow")
          .foregroundStyle(verdict == .keep ? accent : .brown)
        Button {
          model.focused = row.id
        } label: {
          Text(displayTitle(row)).font(.system(size: 13, weight: .semibold)).lineLimit(1)
        }.buttonStyle(.plain)
        Spacer()
        if let judgment = row.judgment {
          Text("MISMATCH \(Int(judgment.response.answers.mismatch.noul * 100))%")
            .font(.system(size: 9, design: .monospaced)).foregroundStyle(muted)
        }
        Button(row.covered ? "Reveal" : "Cover") {
          if row.covered { model.reveal(row.id) } else { model.cover(row.id) }
        }.buttonStyle(.bordered).controlSize(.small).disabled(model.busy)
      }
      if let evidence = row.evidence, !evidence.text.isEmpty {
        Text("“\(evidence.text.prefix(180))”")
          .font(.system(size: 11)).foregroundStyle(muted).lineLimit(2).textSelection(.enabled)
      }
      HStack {
        Text(row.covered ? "Opaque native panel · tracking position" : row.note)
          .font(.system(size: 10)).foregroundStyle(row.covered ? accent : muted).lineLimit(1)
        Spacer()
        Button("Inspect evidence") { model.focused = row.id }
          .font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(accent)
      }
    }.padding(12)
      .background(row.covered ? accent.opacity(0.05) : paper.opacity(0.6))
      .clipShape(RoundedRectangle(cornerRadius: 9))
      .overlay(
        RoundedRectangle(cornerRadius: 9).stroke(
          row.covered ? accent.opacity(0.35) : ink.opacity(0.08)))
  }

  private func inspector(_ row: WindowRow) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        eyebrow("EVIDENCE / \(displayTitle(row).uppercased())")
        Spacer()
        Button {
          model.focused = nil
        } label: {
          Image(systemName: "xmark")
        }.buttonStyle(.plain)
      }
      if let a = row.judgment?.response.answers {
        HStack(spacing: 16) {
          metric("Task relevance", value: String(format: "%.2f / 2", a.relevance.score))
          metric("Audience mismatch", value: String(format: "%.1f%%", a.mismatch.noul * 100))
          metric("Policy conflict", value: String(format: "%.1f%%", a.policyConflict.noul * 100))
        }
        Text(
          "Relevance concentration \(String(format: "%.2f", a.relevance.confidence)) · P(0/1/2): "
            + (0...2).map { String(format: "%.2f", a.relevance.probabilities[String($0)] ?? 0) }
            .joined(separator: " / ")
        )
        .font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
      }
      Text(row.evidence?.text ?? "No text read yet.").font(.system(size: 12))
        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
      Text(
        "Verbatim AX evidence. Labels and excerpts are deterministic; Jev does not generate explanations. Concentration is not correctness. Noul near 50% means uncertain."
      )
      .font(.system(size: 10)).foregroundStyle(muted)
    }.padding(16).background(paper).clipShape(RoundedRectangle(cornerRadius: 9))
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 16) {
      Image(systemName: "rectangle.3.group").font(.system(size: 45, weight: .ultraLight))
        .foregroundStyle(accent)
      Text("Same desktop.\nDifferent room.")
        .font(.system(size: 35, weight: .regular, design: .serif))
      Text(
        "A public roadmap belongs in a customer demo.\nThe negotiating room next door probably doesn’t."
      )
      .font(.system(size: 14)).foregroundStyle(muted).lineSpacing(5)
      Text("Choose TextEdit and add windows, or run the included demo scenario.")
        .font(.system(size: 11)).foregroundStyle(muted)
    }.padding(.vertical, 35)
  }

  private var footer: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        if model.busy { ProgressView().controlSize(.mini) }
        Text(model.activity).font(.system(size: 11)).lineLimit(2)
        Spacer()
        Text("\(model.requests) req · \(Int(model.elapsed)) ms")
          .font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
      }
      HStack {
        Text(model.modelID).font(.system(size: 10, design: .monospaced))
        Text("•  Desktop staging only. Direct window/app capture may bypass covers.")
          .font(.system(size: 10))
      }.foregroundStyle(muted)
    }.padding(.horizontal, 24).padding(.vertical, 13)
      .background(paper)
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2)
      .foregroundStyle(muted)
  }
  private func metric(_ title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(.system(size: 10)).foregroundStyle(muted)
      Text(value).font(.system(size: 17, weight: .medium, design: .monospaced))
    }
  }
  private func counter(_ label: String, count: Int, color: Color) -> some View {
    HStack(spacing: 8) {
      Text("\(count)").font(.system(size: 24, weight: .medium, design: .serif))
      Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
    }.foregroundStyle(color).padding(.vertical, 10).frame(maxWidth: .infinity)
      .background(color.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 7))
  }
  private func displayTitle(_ row: WindowRow) -> String {
    row.evidence?.title.replacingOccurrences(of: "ShareStage — ", with: "")
      ?? row.target.title.replacingOccurrences(of: "ShareStage — ", with: "")
  }
  private func groupSubtitle(_ verdict: Verdict) -> String {
    switch verdict {
    case .keep: return "Relevant, low mismatch · still use your judgment"
    case .cover: return "Off audience or off topic · ranked by relevance"
    case .review: return "Uncertain, unreadable, changed, or not analyzed"
    }
  }
}
