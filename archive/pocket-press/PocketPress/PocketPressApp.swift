import SwiftUI

@main
struct PocketPressApp: App {
    @StateObject private var store = PressStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(store)
                .tint(PressStyle.cobalt)
                .font(.custom("AvenirNext-Regular", size: 15))
                .preferredColorScheme(.light)
                .alert(
                    "A small interruption",
                    isPresented: Binding(
                        get: { store.error != nil },
                        set: { if !$0 { store.error = nil } }
                    )
                ) {
                    Button("OK") { store.error = nil }
                } message: {
                    Text(store.error ?? "")
                }
        }
    }
}

enum PressStyle {
    static let paper = Color(uiColor: UIColor(hex: 0xF4F1EA))
    static let ink = Color(uiColor: UIColor(hex: 0x23251F))
    static let muted = Color(uiColor: UIColor(hex: 0x707168))
    static let cobalt = Color(uiColor: UIColor(hex: 0x2448D8))
    static let line = Color(uiColor: UIColor(hex: 0xD8D8CD))

    static func serif(_ size: CGFloat) -> Font { .custom("Georgia", size: size) }
    static func sans(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "AvenirNext-DemiBold" : "AvenirNext-Regular", size: size)
    }
}

struct Eyebrow: View {
    var text: String
    var color: Color = PressStyle.cobalt

    var body: some View {
        Text(text.uppercased()).font(PressStyle.sans(10, bold: true))
            .tracking(2).foregroundStyle(color)
    }
}

struct PressButton: View {
    var title: String
    var symbol: String = "arrow.up.right"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(PressStyle.sans(15, bold: true))
                Spacer()
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white).padding(.horizontal, 20).frame(minHeight: 54)
            .background(PressStyle.cobalt, in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain)
    }
}

struct CircleButton: View {
    var symbol: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.65), in: Circle())
                .overlay(Circle().stroke(PressStyle.line, lineWidth: 0.6))
        }
        .buttonStyle(.plain).foregroundStyle(PressStyle.ink)
        .accessibilityLabel(label)
    }
}

struct PageArtwork: View {
    let page: MagazinePage
    let theme: PressTheme
    let index: Int

    var body: some View {
        Image(uiImage: PageRenderer.preview(page, theme: theme, index: index))
            .resizable().aspectRatio(420.0 / 594.0, contentMode: .fit)
            .accessibilityLabel("Page \(index + 1), \(page.kind.title): \(page.title)")
    }
}

struct LibraryView: View {
    @EnvironmentObject private var store: PressStore
    @State private var path: [UUID] = []
    @State private var showTemplate = false
    @State private var deleting: Magazine?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .top) {
                        Text("pocket\npress.").font(PressStyle.serif(31)).lineSpacing(-8)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Eyebrow(text: "Independent")
                            Eyebrow(text: "by nature")
                            Rectangle().fill(PressStyle.cobalt).frame(width: 36, height: 3)
                        }.padding(.top, 9)
                    }.padding(.top, 10)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Good places.\nGreat stories.").font(PressStyle.serif(38))
                            .tracking(-1.7).lineSpacing(-3)
                        Text("Your travels, in print. A little magazine\nfor the things you want to keep.")
                            .font(PressStyle.sans(14)).foregroundStyle(PressStyle.muted).lineSpacing(3)
                    }
                    PressButton(title: "Make a new issue", symbol: "plus") { showTemplate = true }
                        .disabled(store.storageUnavailable)
                    HStack {
                        Eyebrow(text: "On your shelf", color: PressStyle.ink)
                        Spacer()
                        Text(String(format: "%02d ISSUES", store.library.issues.count))
                            .font(PressStyle.sans(10, bold: true)).tracking(1).foregroundStyle(
                                PressStyle.muted)
                    }.padding(.top, 3)
                    if store.library.issues.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text(store.storageUnavailable ? "Your library is safe." : "A clean slate.")
                                .font(PressStyle.serif(28))
                            Text(
                                store.storageUnavailable
                                    ? "We couldn’t read your saved library. Its original file is preserved in Files → Pocket Press → PocketPress."
                                    : "Every good issue starts with a place. Choose the coastal template to begin."
                            )
                            .foregroundStyle(PressStyle.muted)
                            if store.canUndo {
                                Button("Undo deletion", action: store.undo).frame(minHeight: 44)
                            }
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                    }
                    ForEach(store.library.issues) { issue in
                        VStack(alignment: .leading, spacing: 14) {
                            NavigationLink(value: issue.id) {
                                if let page = issue.pages.first {
                                    PageArtwork(page: page, theme: issue.theme, index: 0)
                                        .frame(maxWidth: .infinity)
                                        .padding(22)
                                        .background(Color(uiColor: UIColor(hex: 0xE2E4DC)))
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                        .overlay(alignment: .topTrailing) {
                                            Text("OPEN ISSUE ↗").font(PressStyle.sans(9, bold: true))
                                                .tracking(1).padding(9).background(PressStyle.paper)
                                                .padding(10)
                                        }
                                }
                            }.buttonStyle(.plain).accessibilityLabel("Open \(issue.title)")
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(issue.title).font(PressStyle.serif(23))
                                    Text("\(issue.pages.count) pages  ·  \(issue.theme.title)")
                                        .font(PressStyle.sans(12)).foregroundStyle(PressStyle.muted)
                                }
                                Spacer()
                                Menu {
                                    Button("Delete issue", role: .destructive) { deleting = issue }
                                    if store.canUndo { Button("Undo last change", action: store.undo) }
                                } label: {
                                    Image(systemName: "ellipsis").frame(width: 44, height: 44)
                                }.accessibilityLabel("Issue options")
                            }
                        }.padding(.bottom, 12)
                    }
                    HStack {
                        Rectangle().frame(height: 1)
                        Text("MADE TO BE KEPT").font(PressStyle.sans(9, bold: true)).tracking(2)
                            .fixedSize()
                        Rectangle().frame(height: 1)
                    }.foregroundStyle(PressStyle.muted).padding(.vertical, 16)
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }
            .background(PressStyle.paper).foregroundStyle(PressStyle.ink)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in EditorView(issueID: id) }
            .sheet(isPresented: $showTemplate) {
                TemplateView {
                    if let id = store.create() {
                        showTemplate = false
                        path.append(id)
                    }
                }
            }
            .confirmationDialog(
                "Delete this issue?",
                isPresented: Binding(
                    get: { deleting != nil }, set: { if !$0 { deleting = nil } }
                ), titleVisibility: .visible
            ) {
                Button("Delete issue", role: .destructive) {
                    if let deleting { store.delete(deleting.id) }
                    deleting = nil
                }
            } message: {
                Text("You can undo this from an issue’s options during this session.")
            }
        }
    }
}

struct TemplateView: View {
    @Environment(\.dismiss) private var dismiss
    var create: () -> Void
    private let issue = Magazine.coastal()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Eyebrow(text: "Start with a place")
                    Text("A story, already\nin the making.").font(PressStyle.serif(34)).tracking(-1)
                    HStack(alignment: .center, spacing: -20) {
                        PageArtwork(page: issue.pages[2], theme: .riviera, index: 2)
                            .rotationEffect(.degrees(-7)).padding(.leading, 10)
                        PageArtwork(page: issue.pages[0], theme: .riviera, index: 0)
                            .rotationEffect(.degrees(6)).padding(.trailing, 10)
                    }.padding(.vertical, 18)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coastal journal").font(PressStyle.serif(26))
                        Text(
                            "Four considered layouts. Sun-washed photography.\nYour own words, wherever the day takes you."
                        )
                        .font(PressStyle.sans(14)).foregroundStyle(PressStyle.muted).lineSpacing(3)
                        Eyebrow(text: "Cover  /  Photo essay  /  Story  /  Notes")
                            .padding(.top, 10)
                    }
                    PressButton(title: "Use this template", symbol: "arrow.right", action: create)
                    Text("Everything is editable. Everything stays on your iPhone.")
                        .font(PressStyle.sans(11)).foregroundStyle(PressStyle.muted)
                }.padding(24)
            }.background(PressStyle.paper)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) { Eyebrow(text: "New issue", color: PressStyle.ink) }
                    ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
                }
        }
    }
}
