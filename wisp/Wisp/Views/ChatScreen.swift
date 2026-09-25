import SwiftUI

struct ChatScreen: View {
    @Environment(AppState.self) private var app
    @State private var chat = ChatController()
    @State private var draft = ""
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var burning = false
    @State private var confirmDiscard = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StatusStrip(chat: chat)
                Divider().overlay(Color.ink.opacity(0.2))
                MessageList(chat: chat, burning: burning)
                Composer(text: $draft, isStreaming: chat.isStreaming, focused: $composerFocused) {
                    chat.send(draft, app: app)
                    draft = ""
                } onStop: {
                    chat.stop()
                }
            }
            .background(Color.paper)
            .foregroundStyle(Color.ink)
            .toolbarBackground(Color.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 2) {
                        Button {
                            showHistory = true
                        } label: {
                            Image(systemName: "archivebox")
                        }
                        .accessibilityLabel("Kept chats")
                        .accessibilityIdentifier("historyButton")

                        Button(action: startNewChat) {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("New chat")
                        .accessibilityIdentifier("newChatButton")
                    }
                }
                ToolbarItem(placement: .principal) {
                    ModelMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 2) {
                        KeepToggle()
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("settingsButton")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("This chat is ephemeral.", isPresented: $confirmDiscard) {
                Button("Let it go") { burnAndReset() }
                Button("Keep it, then start new") {
                    chat.stop()
                    app.setKept(true)
                    app.newChat()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Start a new one and this transcript is gone for good.")
            }
            .onChange(of: app.current.id) { chat.stop() }
            .sensoryFeedback(.selection, trigger: app.isKept)
            .sensoryFeedback(.impact(weight: .light), trigger: app.current.messages.count) { old, new in new > old }
        }
    }

    private func startNewChat() {
        if app.current.isEmpty { return }
        if app.isKept {
            chat.stop()
            app.newChat()
        } else {
            confirmDiscard = true
        }
    }

    /// Ephemeral chats don't just disappear: they visibly dissolve.
    private func burnAndReset() {
        chat.stop()
        withAnimation(.easeIn(duration: 0.45)) { burning = true }
        Task {
            try? await Task.sleep(for: .milliseconds(480))
            app.newChat()
            burning = false
        }
    }
}

// MARK: - Status strip

/// A one-line ticker under the nav bar: persistence state on the left, spend on the right.
private struct StatusStrip: View {
    @Environment(AppState.self) private var app
    var chat: ChatController

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(app.isKept ? Color.ink : Color.clear)
                .overlay(Circle().strokeBorder(Color.ink, lineWidth: 1))
                .frame(width: 7, height: 7)
            Text(app.isKept ? "KEPT" : "EPHEMERAL")
                .accessibilityIdentifier("persistenceLabel")
            if !app.isKept {
                Text("· \(app.settings.burnAfterLeaving.statusText)")
                    .foregroundStyle(Color.ink.opacity(0.45))
            }
            Spacer()
            if app.settings.showCost {
                let usage = app.current.totalUsage
                if usage.total > 0 {
                    Text("\(usage.total.formatted()) tok · \(Money.format(app.currentModel.cost(for: usage)))")
                        .foregroundStyle(Color.ink.opacity(0.6))
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("sessionCost")
                }
            }
        }
        .font(.monoCaption)
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .animation(.easeOut(duration: 0.2), value: app.isKept)
    }
}

// MARK: - Model menu

private struct ModelMenu: View {
    @Environment(AppState.self) private var app

    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 5) {
                Text(app.currentModel.displayName)
                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.6)
            }
            .foregroundStyle(Color.ink)
        }
        .accessibilityIdentifier("modelMenu")
        .sheet(isPresented: $showPicker) {
            ModelPickerSheet()
                .presentationDetents([.medium])
                .presentationBackground(Color.paper)
        }
    }
}

private struct ModelPickerSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("MODEL")
                    .font(.monoCaption)
                    .foregroundStyle(Color.ink.opacity(0.5))
                Spacer()
                Button("Done") { dismiss() }
                    .font(.mono.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 10)

            ForEach(app.models) { m in
                let selected = m.id == app.current.modelID
                Button {
                    app.current.modelID = m.id
                    app.persistCurrentIfKept()
                    dismiss()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 15))
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.displayName)
                                .font(.body.weight(selected ? .semibold : .regular))
                            Text("\(Self.ctx(m.contextLength)) ctx · \(Money.perMillion(m.promptPrice)) in / \(Money.perMillion(m.completionPrice)) out per 1M tok")
                                .font(.monoCaption)
                                .foregroundStyle(Color.ink.opacity(0.55))
                            HStack(spacing: 6) {
                                if m.supportsVision { Tag("vision") }
                                if m.supportsReasoning { Tag("reasoning") }
                                Tag(m.id)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("model-\(m.id)")
                .accessibilityAddTraits(selected ? .isSelected : [])
                Divider().overlay(Color.ink.opacity(0.15)).padding(.leading, 20)
            }
            Spacer()
        }
        .foregroundStyle(Color.ink)
        .background(Color.paper)
    }

    static func ctx(_ n: Int) -> String {
        n >= 1_000_000 ? "\(n / 1_000_000)M" : "\(n / 1024)K"
    }
}

private struct Tag: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 9, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .hairline(opacity: 0.4, radius: 2)
            .foregroundStyle(Color.ink.opacity(0.7))
    }
}

// MARK: - Keep toggle

private struct KeepToggle: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Button {
            withAnimation(.snappy) { app.setKept(!app.isKept) }
        } label: {
            Image(systemName: app.isKept ? "bookmark.fill" : "bookmark")
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(app.isKept ? "Stop keeping this chat" : "Keep this chat")
        .accessibilityIdentifier("keepToggle")
    }
}

enum Money {
    static func format(_ usd: Double) -> String {
        if usd == 0 { return "$0" }
        if usd < 0.01 { return String(format: "$%.4f", usd) }
        return String(format: "$%.2f", usd)
    }
    static func perMillion(_ perToken: Double) -> String {
        let v = perToken * 1_000_000
        return v == v.rounded() ? String(format: "$%.0f", v) : String(format: "$%.2f", v)
    }
}
