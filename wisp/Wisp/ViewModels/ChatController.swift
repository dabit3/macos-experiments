import Foundation
import Observation

/// Drives one streaming turn at a time against `AppState.current`.
@MainActor
@Observable
final class ChatController {
    private(set) var isStreaming = false
    var lastError: String?
    private var task: Task<Void, Never>?

    func send(_ text: String, app: AppState) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isStreaming, let client = app.client else { return }

        lastError = nil
        app.burnedWhileAway = false
        let conversationID = app.current.id
        app.current.messages.append(ChatMessage(role: .user, content: prompt))
        var reply = ChatMessage(role: .assistant, content: "", modelID: app.current.modelID, isStreaming: true)
        let replyID = reply.id
        app.current.messages.append(reply)
        app.persistCurrentIfKept()
        isStreaming = true

        let history = app.current.messages.dropLast()
        let options = AbliterationClient.ChatOptions(
            model: app.current.modelID,
            temperature: app.settings.temperature,
            systemPrompt: app.current.systemPrompt
        )

        task = Task {
            defer {
                isStreaming = false
                task = nil
            }
            do {
                for try await event in client.streamChat(messages: Array(history), options: options) {
                    switch event {
                    case .reasoning(let r): reply.reasoning += r
                    case .content(let c): reply.content += c
                    case .usage(let u): reply.usage = u
                    case .done: break
                    }
                    app.update(messageID: replyID) { $0 = reply }
                }
                reply.isStreaming = false
                app.update(messageID: replyID) { $0 = reply }
            } catch {
                reply.isStreaming = false
                if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                    if reply.content.isEmpty && reply.reasoning.isEmpty {
                        app.current.messages.removeAll { $0.id == replyID }
                    } else {
                        app.update(messageID: replyID) { $0 = reply }
                    }
                } else {
                    reply.error = error.localizedDescription
                    lastError = error.localizedDescription
                    app.update(messageID: replyID) { $0 = reply }
                }
            }
            if app.current.id == conversationID { app.persistCurrentIfKept() }
        }
    }

    func stop() {
        task?.cancel()
    }

    /// Re-sends the last user turn, dropping the failed/previous assistant reply.
    func retryLast(app: AppState) {
        guard !isStreaming else { return }
        guard let lastUser = app.current.messages.last(where: { $0.role == .user }) else { return }
        if let idx = app.current.messages.lastIndex(where: { $0.id == lastUser.id }) {
            app.current.messages.removeSubrange(idx...)
        }
        send(lastUser.content, app: app)
    }
}

extension AppState {
    func update(messageID: UUID, _ mutate: (inout ChatMessage) -> Void) {
        guard let i = current.messages.firstIndex(where: { $0.id == messageID }) else { return }
        mutate(&current.messages[i])
    }
}
