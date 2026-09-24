import SwiftUI

struct MessageList: View {
    @Environment(AppState.self) private var app
    var chat: ChatController
    var burning: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if app.current.isEmpty {
                    EmptyState()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                } else {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(app.current.messages) { message in
                            MessageRow(message: message, chat: chat)
                                .id(message.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .blur(radius: burning ? 14 : 0)
            .opacity(burning ? 0 : 1)
            .scaleEffect(burning ? 1.03 : 1)
            .onChange(of: app.current.messages.last?.content) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: app.current.messages.count) {
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }
}

private struct EmptyState: View {
    @Environment(AppState.self) private var app
    var body: some View {
        VStack(spacing: 18) {
            WispMark(size: 40).opacity(0.7)
            Text(app.isKept
                 ? "This chat will be kept.\nIt's saved on this device as you go."
                 : "This chat is ephemeral.\nClose it and it's gone.")
                .multilineTextAlignment(.center)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Color.ink.opacity(0.5))
            if app.burnedWhileAway {
                Text("Your last chat burned while you were away.")
                    .font(.monoCaption)
                    .foregroundStyle(Color.ink.opacity(0.6))
                    .accessibilityIdentifier("burnedNotice")
            }
            if !app.isKept {
                Label("Tap to keep it", systemImage: "bookmark")
                    .font(.monoCaption)
                    .foregroundStyle(Color.ink.opacity(0.35))
            }
        }
        .padding(.horizontal, 40)
    }
}

struct MessageRow: View {
    @Environment(AppState.self) private var app
    let message: ChatMessage
    var chat: ChatController
    @State private var showReasoning = false

    var body: some View {
        switch message.role {
        case .user: userRow
        case .assistant: assistantRow
        case .system: EmptyView()
        }
    }

    private var userRow: some View {
        HStack {
            Spacer(minLength: 48)
            Text(message.content)
                .font(.body)
                .foregroundStyle(Color.paper)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.ink, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .textSelection(.enabled)
                .contextMenu { copyButton(message.content) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You: \(message.content)")
    }

    private var assistantRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !message.reasoning.isEmpty && app.settings.showReasoning {
                ReasoningDisclosure(text: message.reasoning, live: message.isStreaming && message.content.isEmpty, expanded: $showReasoning)
            }

            if message.content.isEmpty && message.isStreaming && message.reasoning.isEmpty {
                Cursor()
            } else if !message.content.isEmpty {
                let segments = Markdown.segments(message.content)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { i, segment in
                        let isLast = i == segments.count - 1
                        switch segment {
                        case .prose(let text):
                            HStack(alignment: .bottom, spacing: 0) {
                                Text(Markdown.inline(text))
                                    .font(.body)
                                    .textSelection(.enabled)
                                if isLast && message.isStreaming { Cursor().padding(.leading, 2) }
                            }
                        case .code(let lang, let body):
                            CodeBlock(language: lang, code: body)
                            if isLast && message.isStreaming { Cursor() }
                        }
                    }
                }
                .contextMenu {
                    copyButton(message.content)
                    if isLastMessage && !chat.isStreaming {
                        Button { chat.retryLast(app: app) } label: {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }

            if let error = message.error {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error)
                        .font(.mono)
                    Button("Retry") { chat.retryLast(app: app) }
                        .font(.mono.weight(.semibold))
                        .disabled(chat.isStreaming)
                }
                .padding(12)
                .hairline(opacity: 1)
            }

            if !message.isStreaming, message.error == nil {
                footer
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("assistantMessage")
    }

    private var isLastMessage: Bool { app.current.messages.last?.id == message.id }

    private var footer: some View {
        Text(footerParts.joined(separator: " · "))
            .font(.monoCaption)
            .foregroundStyle(Color.ink.opacity(0.4))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footerParts: [String] {
        var parts: [String] = []
        if let usage = message.usage {
            parts.append("\(usage.completionTokens) out")
            parts.append("\(usage.promptTokens) in")
            if app.settings.showCost, let m = message.modelID.flatMap(app.model(withID:)) {
                parts.append(Money.format(m.cost(for: usage)))
            }
        }
        if let id = message.modelID { parts.append(id) }
        return parts
    }

    private func copyButton(_ text: String) -> some View {
        Button {
            Clipboard.copy(text)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
    }
}

private struct ReasoningDisclosure: View {
    let text: String
    let live: Bool
    @Binding var expanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(live ? "thinking" : "thought")
                    if live { Cursor(small: true) }
                }
                .font(.monoCaption)
                .foregroundStyle(Color.ink.opacity(0.55))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("reasoningToggle")

            if expanded {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Color.ink.opacity(0.6))
                    .textSelection(.enabled)
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.ink.opacity(0.25)).frame(width: 1)
                    }
            }
        }
    }
}

/// A fenced code block: monospaced, horizontally scrollable, one-tap copy.
private struct CodeBlock: View {
    let language: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "code" : language)
                Spacer()
                Button {
                    Clipboard.copy(code)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("copyCode")
            }
            .font(.monoCaption)
            .foregroundStyle(Color.ink.opacity(0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            Rectangle().fill(Color.ink.opacity(0.15)).frame(height: 1)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(12)
            }
        }
        .hairline(opacity: 0.3)
        .sensoryFeedback(.success, trigger: copied) { _, new in new }
    }
}

enum Markdown {
    enum Segment {
        case prose(String)
        case code(language: String, body: String)
    }

    /// Splits a reply into prose and ``` fenced blocks. An unterminated fence (mid-stream) is treated as code.
    static func segments(_ text: String) -> [Segment] {
        var out: [Segment] = []
        var buffer: [Substring] = []
        var inCode = false
        var language = ""

        func flush() {
            let joined = buffer.joined(separator: "\n")
            if inCode {
                out.append(.code(language: language, body: joined))
            } else {
                let trimmed = joined.trimmingCharacters(in: .newlines)
                if !trimmed.trimmingCharacters(in: .whitespaces).isEmpty { out.append(.prose(trimmed)) }
            }
            buffer = []
        }

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") {
                flush()
                inCode.toggle()
                if inCode { language = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
            } else {
                buffer.append(line)
            }
        }
        flush()
        return out
    }

    /// Inline markdown only; model output is never interpreted as a localization key or format string.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

/// A blinking block cursor: the only "typing indicator" a monochrome terminal needs.
struct Cursor: View {
    var small = false
    @State private var on = true
    var body: some View {
        Rectangle()
            .fill(Color.ink)
            .frame(width: small ? 5 : 8, height: small ? 9 : 16)
            .opacity(on ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { on = false }
            }
            .accessibilityHidden(true)
    }
}
