import MarginCore
import SwiftUI

enum Theme {
  static let linen = Color(red: 0.95, green: 0.94, blue: 0.91)
  static let paper = Color(red: 0.995, green: 0.990, blue: 0.977)
  static let ink = Color(red: 0.19, green: 0.18, blue: 0.16)
  static let muted = Color(red: 0.46, green: 0.44, blue: 0.40)
  static let wine = Color(red: 0.43, green: 0.17, blue: 0.21)
  static let rule = Color(red: 0.84, green: 0.82, blue: 0.77)
}

struct ContentView: View {
  @ObservedObject var workspace: Workspace

  var body: some View {
    VStack(spacing: 0) {
      topBar
      Rectangle().fill(Theme.rule).frame(height: 1)
      HStack(spacing: 0) {
        library.frame(width: 232)
        Rectangle().fill(Theme.rule).frame(width: 1)
        reader.frame(minWidth: 420, maxWidth: .infinity)
        Rectangle().fill(Theme.rule).frame(width: 1)
        writing.frame(minWidth: 375, maxWidth: .infinity)
      }
      bottomBar
    }
    .background(Theme.paper)
    .foregroundStyle(Theme.ink)
    .font(.system(size: 13))
    .frame(minWidth: 1120, minHeight: 730)
    .alert(
      "Unable to complete that action",
      isPresented: Binding(
        get: { workspace.errorMessage != nil },
        set: { if !$0 { workspace.errorMessage = nil } }
      )
    ) {
      Button("Keep working", role: .cancel) { workspace.errorMessage = nil }
    } message: {
      Text(workspace.errorMessage ?? "")
    }
    .confirmationDialog(
      "Restore the sample workspace?", isPresented: $workspace.showReset, titleVisibility: .visible
    ) {
      Button("Restore sample", role: .destructive, action: workspace.resetSample)
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This replaces the current draft and collection. Save a project first if you want to keep them."
      )
    }
  }

  private var topBar: some View {
    HStack(spacing: 0) {
      HStack(spacing: 9) {
        Text("m").font(.custom("Georgia-Italic", size: 26))
          .foregroundStyle(Theme.paper)
          .frame(width: 34, height: 34).background(
            Theme.wine, in: RoundedRectangle(cornerRadius: 7))
        Text("Margin").font(.custom("Georgia", size: 25))
      }
      .frame(width: 210, alignment: .leading)
      .padding(.leading, 22)
      Rectangle().fill(Theme.rule).frame(width: 1, height: 24)
      HStack(spacing: 9) {
        Text("WORKSPACE").font(.system(size: 10, weight: .semibold)).tracking(1.8)
          .foregroundStyle(Theme.muted)
        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(Theme.muted)
        Text("The attentive city").font(.system(size: 13, weight: .medium))
      }.padding(.leading, 24)
      Spacer()
      Button(action: workspace.openProject) { Label("Open", systemImage: "folder") }
        .buttonStyle(QuietButton())
      Button(action: workspace.saveProject) {
        Label("Save project", systemImage: "square.and.arrow.down")
      }
      .buttonStyle(QuietButton())
      Menu {
        Button("Export PDF…") { workspace.export(pdf: true) }
        Button("Export Markdown…") { workspace.export(pdf: false) }
      } label: {
        HStack(spacing: 8) {
          Text("Export")
          Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
        }.padding(.horizontal, 14).padding(.vertical, 9)
          .foregroundStyle(.white).background(Theme.wine, in: RoundedRectangle(cornerRadius: 6))
      }
      .menuStyle(.borderlessButton).fixedSize()
      .padding(.leading, 10)
      .accessibilityIdentifier("export-menu")
    }
    .padding(.trailing, 22).padding(.top, 27).padding(.bottom, 17)
    .background(Theme.paper)
  }

  private var library: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        eyebrow("YOUR LIBRARY")
        Spacer()
        Image(systemName: "books.vertical").foregroundStyle(Theme.muted)
      }.padding(.bottom, 18)
      VStack(alignment: .leading, spacing: 0) {
        coverArt.frame(height: 114)
        VStack(alignment: .leading, spacing: 7) {
          Text("The attentive city").font(.custom("Georgia", size: 17))
          Text("Margin Field Notes · 2026")
            .font(.system(size: 11)).foregroundStyle(Theme.muted)
          HStack(spacing: 5) {
            Image(systemName: "doc.text")
            Text("SOURCE PDF  ·  5 PAGES")
          }.font(.system(size: 9, weight: .medium)).tracking(0.8).foregroundStyle(Theme.wine)
            .padding(.top, 6)
        }.padding(14)
      }
      .background(Theme.paper, in: RoundedRectangle(cornerRadius: 7))
      .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.rule, lineWidth: 0.6))
      .padding(.bottom, 26)
      HStack {
        eyebrow("COLLECTED")
        Text(String(format: "%02d", workspace.project.excerpts.count))
          .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Theme.wine)
        Spacer()
        Button(action: workspace.undoClipping) { Image(systemName: "arrow.uturn.backward") }
          .buttonStyle(.plain).foregroundStyle(Theme.muted)
          .disabled(workspace.undoClippings.isEmpty)
          .help("Undo last collection change").accessibilityLabel("Undo collection change")
      }.padding(.bottom, 13)
      HStack(spacing: 7) {
        Image(systemName: "magnifyingglass").font(.system(size: 11))
        TextField("Find a passage…", text: $workspace.libraryQuery)
          .textFieldStyle(.plain).font(.system(size: 11))
          .accessibilityIdentifier("library-search")
      }
      .foregroundStyle(Theme.muted).padding(9)
      .background(Theme.paper.opacity(0.75), in: RoundedRectangle(cornerRadius: 5))
      .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.rule, lineWidth: 0.6))
      .padding(.bottom, 12)
      ScrollView {
        VStack(spacing: 10) {
          if workspace.project.excerpts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
              Image(systemName: "text.quote").font(.system(size: 22, weight: .light))
                .foregroundStyle(Theme.wine)
              Text("Keep what moves\nyour thinking.")
                .font(.custom("Georgia-Italic", size: 17)).lineSpacing(3)
              Text("Select a passage in the source,\nthen choose Collect selection.")
                .font(.system(size: 11)).lineSpacing(4).foregroundStyle(Theme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 16)
          } else if workspace.project.filteredExcerpts(workspace.libraryQuery).isEmpty {
            Text("No passages match.\nTry another word or page number.")
              .font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.vertical, 20)
          }
          ForEach(workspace.project.filteredExcerpts(workspace.libraryQuery)) { excerpt in
            excerptCard(excerpt)
          }
        }
      }
      Spacer(minLength: 12)
      Button {
        workspace.showReset = true
      } label: {
        Label("Restore sample", systemImage: "arrow.counterclockwise")
          .font(.system(size: 11))
      }.buttonStyle(.plain).foregroundStyle(Theme.muted).padding(.vertical, 5)
    }
    .padding(.horizontal, 20).padding(.top, 23).padding(.bottom, 15)
    .background(Theme.linen)
  }

  private var coverArt: some View {
    GeometryReader { geometry in
      ZStack {
        Color(red: 0.83, green: 0.81, blue: 0.74)
        Path { path in
          let w = geometry.size.width
          path.move(to: CGPoint(x: 0, y: 95))
          path.addLine(to: CGPoint(x: w, y: 34))
          path.move(to: CGPoint(x: 0, y: 72))
          path.addLine(to: CGPoint(x: w, y: 11))
          path.move(to: CGPoint(x: 36, y: 114))
          path.addLine(to: CGPoint(x: 100, y: 0))
          path.move(to: CGPoint(x: 75, y: 114))
          path.addLine(to: CGPoint(x: 139, y: 0))
        }.stroke(Theme.paper.opacity(0.65), lineWidth: 10)
        Circle().fill(Theme.wine).frame(width: 63, height: 63).offset(x: 39, y: 5)
        Circle().stroke(Theme.paper.opacity(0.75), lineWidth: 0.7).frame(width: 83, height: 83)
          .offset(x: 39, y: 5)
        Text("FIELD\nNOTES").font(.system(size: 9, weight: .semibold)).tracking(2)
          .lineSpacing(4).foregroundStyle(Theme.wine)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(14)
      }
    }.clipShape(UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7))
  }

  private func excerptCard(_ excerpt: Excerpt) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("p. \(excerpt.pageLabel)").font(.system(size: 10, weight: .semibold)).foregroundStyle(
          Theme.wine)
        Spacer()
        Button {
          workspace.remove(excerpt)
        } label: {
          Image(systemName: "xmark").font(.system(size: 10))
        }
        .buttonStyle(.plain).foregroundStyle(Theme.muted)
        .accessibilityLabel("Remove passage from page \(excerpt.pageLabel)")
      }
      Button {
        workspace.show(excerpt)
      } label: {
        Text("“\(excerpt.text)”").font(.custom("Georgia", size: 12)).lineSpacing(4)
          .lineLimit(5).frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(
            .leading)
      }.buttonStyle(.plain).help("Reveal passage in source")
      Button {
        workspace.insert(excerpt)
      } label: {
        HStack {
          Text("Insert citation")
          Spacer()
          Image(systemName: "arrow.up.right")
        }.font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.wine)
      }.buttonStyle(.plain).padding(.top, 3)
        .accessibilityLabel("Insert citation from page \(excerpt.pageLabel)")
    }
    .padding(12).background(Theme.paper, in: RoundedRectangle(cornerRadius: 5))
    .overlay(alignment: .leading) { Rectangle().fill(Theme.wine.opacity(0.8)).frame(width: 2) }
    .overlay(
      RoundedRectangle(cornerRadius: 5).stroke(
        workspace.activeExcerpt == excerpt.id ? Theme.wine.opacity(0.3) : Theme.rule.opacity(0.5),
        lineWidth: 0.6
      ))
  }

  private var reader: some View {
    VStack(spacing: 0) {
      HStack {
        eyebrow("SOURCE")
        Text("The attentive city").font(.custom("Georgia", size: 14)).padding(.leading, 7)
        Spacer()
        Text("PDF").font(.system(size: 9, weight: .semibold)).tracking(1)
          .foregroundStyle(Theme.muted).padding(.horizontal, 7).padding(.vertical, 4)
          .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.rule, lineWidth: 0.6))
      }.padding(.horizontal, 22).frame(height: 55)
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
        TextField("Search within source…", text: $workspace.searchQuery)
          .textFieldStyle(.plain).onSubmit(workspace.search)
          .accessibilityIdentifier("source-search")
        if workspace.hasSearched {
          Text(
            workspace.searchCount == 0
              ? "No matches" : "\(workspace.searchIndex + 1)/\(workspace.searchCount)"
          )
          .font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted)
          Button {
            workspace.showSearchResult(workspace.searchIndex - 1)
          } label: {
            Image(systemName: "chevron.up")
          }.buttonStyle(.plain).disabled(workspace.searchCount == 0).accessibilityLabel(
            "Previous match")
          Button {
            workspace.showSearchResult(workspace.searchIndex + 1)
          } label: {
            Image(systemName: "chevron.down")
          }.buttonStyle(.plain).disabled(workspace.searchCount == 0).accessibilityLabel(
            "Next match")
        }
        Button("Find", action: workspace.search).buttonStyle(.plain).foregroundStyle(Theme.wine)
      }
      .font(.system(size: 12)).padding(.horizontal, 12).frame(height: 35)
      .background(Theme.linen.opacity(0.65), in: RoundedRectangle(cornerRadius: 5))
      .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.rule.opacity(0.7), lineWidth: 0.5))
      .padding(.horizontal, 20).padding(.bottom, 14)
      SourceReader(workspace: workspace)
      HStack(spacing: 10) {
        Button {
          workspace.movePage(-1)
        } label: {
          Image(systemName: "chevron.left")
        }
        .disabled(workspace.currentPage <= 1).accessibilityLabel("Previous page")
        Text("\(workspace.currentPage) / 5")
          .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.muted)
        Button {
          workspace.movePage(1)
        } label: {
          Image(systemName: "chevron.right")
        }
        .disabled(workspace.currentPage >= 5).accessibilityLabel("Next page")
        Spacer()
        Button(action: workspace.capture) {
          Label("Collect selection", systemImage: "text.badge.plus")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 12).padding(.vertical, 9)
            .foregroundStyle(workspace.selectedText.isEmpty ? Theme.muted : Theme.wine)
            .background(
              Theme.wine.opacity(workspace.selectedText.isEmpty ? 0.04 : 0.09),
              in: RoundedRectangle(cornerRadius: 5))
        }
        .disabled(workspace.selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityIdentifier("collect-selection")
      }
      .buttonStyle(.plain).padding(.horizontal, 20).frame(height: 57)
    }
  }

  private var writing: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        eyebrow("DRAFT 01")
        Spacer()
        Circle().fill(Color(red: 0.39, green: 0.48, blue: 0.35)).frame(width: 5, height: 5)
        Text("LIVE DOCUMENT").font(.system(size: 9, weight: .medium)).tracking(1).foregroundStyle(
          Theme.muted)
      }.padding(.horizontal, 30).frame(height: 55)
      VStack(alignment: .leading, spacing: 17) {
        Text("RESEARCH BRIEF").font(.system(size: 9, weight: .semibold)).tracking(2.1)
          .foregroundStyle(Theme.wine)
        TextField("Untitled brief", text: $workspace.project.title, axis: .vertical)
          .font(.custom("Georgia", size: 31)).textFieldStyle(.plain).lineSpacing(4)
          .accessibilityLabel("Brief title")
        HStack(spacing: 8) {
          Text("WORDS & IDEAS")
          Rectangle().fill(Theme.rule).frame(width: 26, height: 1)
          Text("A working argument")
        }.font(.system(size: 9)).tracking(1).foregroundStyle(Theme.muted)
        Rectangle().fill(Theme.rule).frame(height: 1)
      }.padding(.horizontal, 30).padding(.top, 24).padding(.bottom, 4)
      DraftEditor(workspace: workspace)
      HStack {
        Text("\(workspace.project.wordCount) words")
          .font(.system(size: 11, design: .monospaced))
        Spacer()
        Text("Plain text · citation ready").font(.system(size: 10))
      }.foregroundStyle(Theme.muted).padding(.horizontal, 30).frame(height: 57)
    }
    .background(Theme.paper)
  }

  private var bottomBar: some View {
    HStack(spacing: 7) {
      Image(systemName: "checkmark.circle").foregroundStyle(Theme.muted)
      Text(workspace.status).lineLimit(1)
      Spacer()
      Text("READ  /  COLLECT  /  COMPOSE").font(.system(size: 9, weight: .medium)).tracking(1.6)
    }
    .font(.system(size: 10)).foregroundStyle(Theme.muted)
    .padding(.horizontal, 22).frame(height: 30)
    .background(Theme.linen)
    .overlay(alignment: .top) { Rectangle().fill(Theme.rule).frame(height: 1) }
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text).font(.system(size: 10, weight: .semibold)).tracking(1.6).foregroundStyle(Theme.muted)
  }
}

struct QuietButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12))
      .foregroundStyle(Theme.ink)
      .padding(.horizontal, 12).padding(.vertical, 9)
      .background(
        Theme.linen.opacity(configuration.isPressed ? 1 : 0), in: RoundedRectangle(cornerRadius: 5)
      )
      .contentShape(Rectangle())
  }
}
