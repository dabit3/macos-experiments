import PDFKit
import SwiftUI

private enum StudioTab: String, CaseIterable {
    case studio = "Studio"
    case pages = "Pages"
    case read = "Read"
    var symbol: String {
        switch self {
        case .studio: "slider.horizontal.3"
        case .pages: "square.grid.2x2"
        case .read: "book"
        }
    }
}

struct EditorView: View {
    let issueID: UUID
    @EnvironmentObject private var store: PressStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab: StudioTab = .studio
    @State private var selectedPage = 0
    @State private var editing: MagazinePage?
    @State private var showAdd = false
    @State private var showThemes = false
    @State private var showReset = false
    @State private var exported: ExportedIssue?
    @State private var latestURL: URL?
    @State private var exporting = false

    var body: some View {
        Group {
            if let issue = store.issue(issueID) {
                VStack(spacing: 0) {
                    header(issue)
                    switch tab {
                    case .studio: studio(issue)
                    case .pages: pageList(issue)
                    case .read: reader(issue)
                    }
                    dock
                }
                .onChange(of: issue.pages.count) { _, count in
                    selectedPage = min(selectedPage, max(0, count - 1))
                }
                .sheet(item: $editing) { page in
                    PageEditView(page: page, theme: issue.theme, index: selectedPage) { changed in
                        store.update(issueID) { try $0.replace(changed) }
                    }
                }
                .sheet(isPresented: $showThemes) {
                    ThemePicker(selected: issue.theme) { theme in
                        store.update(issueID) { $0.theme = theme }
                    }.presentationDetents([.height(470)])
                }
                .sheet(isPresented: $showAdd) {
                    AddPageView { kind in
                        store.update(issueID) { magazine in _ = try magazine.add(kind) }
                        if let changed = store.issue(issueID) {
                            selectedPage = changed.pages.count - 1
                        }
                        showAdd = false
                        tab = .studio
                    }.presentationDetents([.height(510)])
                }
                .sheet(item: $exported) { export in PDFPreviewScreen(export: export) }
                .confirmationDialog(
                    "Start this issue over?", isPresented: $showReset, titleVisibility: .visible
                ) {
                    Button("Restore coastal template", role: .destructive) {
                        store.reset(issueID)
                        selectedPage = 0
                    }
                } message: {
                    Text("Your current edits can be recovered with Undo.")
                }
            } else {
                ContentUnavailableView(
                    "Issue not found", systemImage: "book.closed",
                    description: Text("Return to your shelf and choose another issue."))
                Button("Back to shelf") { dismiss() }
            }
        }
        .background(PressStyle.paper).foregroundStyle(PressStyle.ink)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func header(_ issue: Magazine) -> some View {
        HStack(spacing: 12) {
            CircleButton(symbol: "arrow.left", label: "Back to shelf") { dismiss() }
            Spacer()
            VStack(spacing: 4) {
                Eyebrow(text: "The editing room", color: PressStyle.ink)
                HStack(spacing: 4) {
                    Circle().fill(PressStyle.cobalt).frame(width: 4, height: 4)
                    Text("Saved on your iPhone").font(PressStyle.sans(10)).foregroundStyle(PressStyle.muted)
                }
            }
            Spacer()
            CircleButton(symbol: "arrow.uturn.backward", label: "Undo last change", action: store.undo)
                .disabled(!store.canUndo).opacity(store.canUndo ? 1 : 0.3)
        }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
    }

    private func studio(_ issue: Magazine) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Make it yours.").font(PressStyle.serif(30)).tracking(-0.9)
                        Spacer()
                        Menu {
                            Button("Restore template", systemImage: "arrow.counterclockwise") {
                                showReset = true
                            }
                            if let latestURL {
                                Button("Reopen last PDF", systemImage: "doc.richtext") {
                                    exported = ExportedIssue(url: latestURL, title: issue.title)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Magazine options")
                    }
                    Button {
                        editing = issue.pages[safeIndex(issue)]
                    } label: {
                        PageArtwork(
                            page: issue.pages[safeIndex(issue)], theme: issue.theme, index: safeIndex(issue)
                        )
                        .frame(
                            height: max(
                                210, min((geometry.size.width - 86) * 594 / 420, geometry.size.height - 242))
                        )
                        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
                        .padding(.horizontal, 21)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            Color(uiColor: UIColor(hex: 0xE0E3DA)),
                            in: RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain).accessibilityLabel("Edit current page")
                    HStack {
                        Eyebrow(
                            text:
                                "\(String(format: "%02d", safeIndex(issue) + 1)) / \(String(format: "%02d", issue.pages.count))",
                            color: PressStyle.ink)
                        Text(issue.pages[safeIndex(issue)].kind.title).font(PressStyle.sans(12))
                            .foregroundStyle(PressStyle.muted)
                        Spacer()
                        pageArrows(issue)
                    }
                    HStack(spacing: 10) {
                        Button {
                            editing = issue.pages[safeIndex(issue)]
                        } label: {
                            Label("Edit page", systemImage: "pencil")
                                .font(PressStyle.sans(14, bold: true)).frame(
                                    maxWidth: .infinity, minHeight: 50
                                )
                                .background(PressStyle.ink, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }.buttonStyle(.plain)
                        Button {
                            showThemes = true
                        } label: {
                            HStack(spacing: 8) {
                                Circle().fill(Color(uiColor: PrintPalette.forTheme(issue.theme).accent))
                                    .frame(width: 14, height: 14)
                                Text(issue.theme.title)
                            }.font(PressStyle.sans(14, bold: true)).frame(maxWidth: .infinity, minHeight: 50)
                                .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12).stroke(PressStyle.line, lineWidth: 1))
                        }.buttonStyle(.plain).accessibilityLabel("Choose theme")
                    }
                    HStack {
                        Image(systemName: "hand.tap").font(.system(size: 12))
                        Text("Tap the page to edit. Your layout takes care of itself.")
                            .font(PressStyle.sans(10))
                    }.foregroundStyle(PressStyle.muted).frame(maxWidth: .infinity)
                }.padding(.horizontal, 22).padding(.bottom, 18)
            }
        }
    }

    private func pageList(_ issue: Magazine) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("The running order.").font(PressStyle.serif(29)).tracking(-1)
                    Spacer()
                    Text("\(issue.pages.count)/24").font(PressStyle.sans(12)).foregroundStyle(
                        PressStyle.muted)
                }.padding(.top, 7)
                Text("Move a moment. Change the whole story.")
                    .font(PressStyle.sans(13)).foregroundStyle(PressStyle.muted)
                ForEach(Array(issue.pages.enumerated()), id: \.element.id) { index, page in
                    HStack(spacing: 15) {
                        Button {
                            selectedPage = index
                            tab = .studio
                        } label: {
                            PageArtwork(page: page, theme: issue.theme, index: index)
                                .frame(width: 88)
                                .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                        }.buttonStyle(.plain).accessibilityLabel("Select page \(index + 1)")
                        VStack(alignment: .leading, spacing: 7) {
                            Eyebrow(text: "\(String(format: "%02d", index + 1))  /  \(page.kind.title)")
                            Text(page.title.replacingOccurrences(of: "\n", with: " "))
                                .font(PressStyle.serif(18)).lineLimit(2)
                            if index == 0 {
                                Label("Cover stays first", systemImage: "lock")
                                    .font(PressStyle.sans(10)).foregroundStyle(PressStyle.muted)
                            } else {
                                HStack(spacing: 3) {
                                    Button {
                                        store.update(issueID) { $0.move(page.id, by: -1) }
                                    } label: {
                                        Image(systemName: "arrow.up").frame(width: 44, height: 40)
                                    }
                                    .disabled(index == 1).accessibilityLabel("Move page \(index + 1) up")
                                    Button {
                                        store.update(issueID) { $0.move(page.id, by: 1) }
                                    } label: {
                                        Image(systemName: "arrow.down").frame(width: 44, height: 40)
                                    }
                                    .disabled(index == issue.pages.count - 1)
                                    .accessibilityLabel("Move page \(index + 1) down")
                                    Spacer(minLength: 0)
                                    Button {
                                        store.update(issueID) { $0.remove(page.id) }
                                    } label: {
                                        Image(systemName: "minus.circle").frame(width: 40, height: 40)
                                    }
                                    .foregroundStyle(PressStyle.muted)
                                    .accessibilityLabel("Delete page \(index + 1)")
                                }.buttonStyle(.plain)
                            }
                        }
                    }.padding(14).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                }
                PressButton(title: "Add a page", symbol: "plus") { showAdd = true }
                    .disabled(issue.pages.count >= Magazine.maximumPages)
                Text("Deleted something? The undo arrow brings it back.")
                    .font(PressStyle.sans(11)).foregroundStyle(PressStyle.muted)
            }.padding(.horizontal, 22).padding(.bottom, 24)
        }
    }

    private func reader(_ issue: Magazine) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                HStack {
                    Eyebrow(text: "The finished feeling")
                    Spacer()
                    Text("\(safeIndex(issue) + 1) of \(issue.pages.count)").font(PressStyle.sans(12))
                }.padding(.horizontal, 24).padding(.top, 8)
                TabView(selection: $selectedPage) {
                    ForEach(Array(issue.pages.enumerated()), id: \.element.id) { index, page in
                        PageArtwork(page: page, theme: issue.theme, index: index)
                            .shadow(color: .black.opacity(0.17), radius: 10, x: 0, y: 6)
                            .padding(.horizontal, 25)
                            .padding(.vertical, 8)
                            .tag(index)
                    }
                }.tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(
                        height: min(geometry.size.height - 178, (geometry.size.width - 50) * 594 / 420 + 16)
                    )
                    .accessibilityLabel("Magazine preview")
                HStack {
                    Text("Swipe to turn the page").font(PressStyle.sans(11)).foregroundStyle(PressStyle.muted)
                    Spacer()
                    pageArrows(issue)
                }.padding(.horizontal, 24)
                PressButton(
                    title: exporting ? "Preparing your PDF…" : "Export print-ready PDF",
                    symbol: "arrow.up.doc"
                ) {
                    exporting = true
                    do {
                        let url = try PageRenderer.export(issue)
                        latestURL = url
                        exported = ExportedIssue(url: url, title: issue.title)
                    } catch { store.error = error.localizedDescription }
                    exporting = false
                }.padding(.horizontal, 22).disabled(exporting)
                Spacer(minLength: 0)
            }
        }
    }

    private func pageArrows(_ issue: Magazine) -> some View {
        HStack(spacing: 0) {
            Button {
                withAnimation { selectedPage = max(0, selectedPage - 1) }
            } label: {
                Image(systemName: "chevron.left").frame(width: 40, height: 38)
            }.disabled(selectedPage == 0).accessibilityLabel("Previous page")
            Button {
                withAnimation { selectedPage = min(issue.pages.count - 1, selectedPage + 1) }
            } label: {
                Image(systemName: "chevron.right").frame(width: 40, height: 38)
            }.disabled(selectedPage == issue.pages.count - 1).accessibilityLabel("Next page")
        }.font(.system(size: 13, weight: .medium)).buttonStyle(.plain)
    }

    private func safeIndex(_ issue: Magazine) -> Int { min(max(0, selectedPage), issue.pages.count - 1) }

    private var dock: some View {
        HStack(spacing: 8) {
            ForEach(StudioTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { tab = item }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: item.symbol).font(.system(size: 15))
                        Text(item.rawValue).font(PressStyle.sans(12, bold: true))
                    }.frame(maxWidth: .infinity, minHeight: 47)
                        .foregroundStyle(tab == item ? .white : PressStyle.muted)
                        .background(
                            tab == item ? PressStyle.ink : .clear,
                            in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).accessibilityLabel(item.rawValue)
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }.padding(6).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(PressStyle.line, lineWidth: 0.6))
            .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 6)
    }
}

struct AddPageView: View {
    @Environment(\.dismiss) private var dismiss
    var add: (PageKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Eyebrow(text: "Another little chapter")
                Spacer()
                CircleButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            Text("Give it a page.").font(PressStyle.serif(32))
            ForEach(PageKind.allCases.filter { $0 != .cover }) { kind in
                Button {
                    add(kind)
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: kind.symbol).font(.system(size: 22)).frame(width: 44)
                            .foregroundStyle(PressStyle.cobalt)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(kind.title).font(PressStyle.serif(22))
                            Text(kind.subtitle).font(PressStyle.sans(11)).foregroundStyle(PressStyle.muted)
                        }
                        Spacer()
                        Image(systemName: "plus").font(.system(size: 17))
                    }.padding(18).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 13))
                }.buttonStyle(.plain).accessibilityLabel("Add \(kind.title)")
            }
            Spacer(minLength: 0)
        }.padding(24).background(PressStyle.paper)
    }
}

struct ThemePicker: View {
    @Environment(\.dismiss) private var dismiss
    let selected: PressTheme
    var choose: (PressTheme) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Eyebrow(text: "The art direction")
                Spacer()
                CircleButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            Text("Set the mood.").font(PressStyle.serif(32))
            ForEach(PressTheme.allCases) { theme in
                let palette = PrintPalette.forTheme(theme)
                Button {
                    choose(theme)
                    dismiss()
                } label: {
                    HStack(spacing: 15) {
                        Text("Aa").font(.custom(palette.display, size: 27))
                            .foregroundStyle(Color(uiColor: palette.accent)).frame(width: 56, height: 56)
                            .background(Color(uiColor: palette.paper), in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(theme.title).font(PressStyle.sans(16, bold: true))
                            Text(theme.description).font(PressStyle.sans(10)).foregroundStyle(
                                PressStyle.muted)
                        }
                        Spacer()
                        Image(systemName: selected == theme ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(PressStyle.cobalt)
                    }.padding(10).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityLabel("\(theme.title) theme")
            }
            Spacer(minLength: 0)
        }.padding(24).background(PressStyle.paper)
    }
}
