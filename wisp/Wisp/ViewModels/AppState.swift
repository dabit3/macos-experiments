import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    // MARK: Key
    private(set) var apiKey: String?
    var hasKey: Bool { apiKey != nil }
    /// True if the Keychain refused the write (e.g. an unsigned build). The key then lives in memory only.
    private(set) var keychainUnavailable = false

    // MARK: Models
    var models: [ModelInfo] = ModelInfo.fallback
    var modelsLoaded = false

    // MARK: Settings
    var settings: Settings {
        didSet { persistSettings() }
    }

    // MARK: Conversations
    /// The chat currently on screen. Ephemeral unless `isKept` is true.
    var current: Conversation
    var isKept: Bool
    /// Only kept conversations are ever written to disk.
    private(set) var kept: [Conversation] = []

    /// Set when an ephemeral chat was burned while the app was away; cleared on the next send.
    var burnedWhileAway = false
    private var backgroundedAt: Date?

    private let store = ConversationStore()
    private static let settingsKey = "wisp.settings"

    init() {
        let s: Settings
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            s = decoded
        } else {
            s = Settings()
        }
        settings = s
        apiKey = KeychainStore.readAPIKey()
        current = Conversation(modelID: s.defaultModelID, systemPrompt: s.systemPrompt)
        isKept = s.keepChatsByDefault
        kept = store.loadAll()
        if apiKey != nil {
            Task { await refreshModels() }
        }
    }

    var client: AbliterationClient? {
        apiKey.map { AbliterationClient(apiKey: $0) }
    }

    func model(withID id: String) -> ModelInfo? {
        models.first { $0.id == id }
    }

    var currentModel: ModelInfo {
        model(withID: current.modelID) ?? models.first ?? ModelInfo.fallback[0]
    }

    // MARK: - Key management

    /// Validates the key against `/v1/models` before storing it.
    func connect(apiKey raw: String) async throws {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let client = AbliterationClient(apiKey: key)
        let fetched = try await client.listModels()
        keychainUnavailable = !KeychainStore.writeAPIKey(key)
        apiKey = key
        if !fetched.isEmpty {
            models = fetched
            modelsLoaded = true
        }
        if model(withID: settings.defaultModelID) == nil, let first = models.first {
            settings.defaultModelID = first.id
            current.modelID = first.id
        }
    }

    func forgetKey() {
        KeychainStore.deleteAPIKey()
        apiKey = nil
        modelsLoaded = false
        newChat()
    }

    func refreshModels() async {
        guard let client else { return }
        if let fetched = try? await client.listModels(), !fetched.isEmpty {
            models = fetched
            modelsLoaded = true
        }
    }

    // MARK: - Conversation lifecycle

    /// Discards the current chat (unless kept) and starts fresh.
    func sceneDidEnterBackground() {
        backgroundedAt = Date()
        if settings.burnAfterLeaving == .immediately { burnIfEphemeral() }
    }

    func sceneDidBecomeActive() {
        defer { backgroundedAt = nil }
        guard let since = backgroundedAt, let limit = settings.burnAfterLeaving.seconds else { return }
        if Date().timeIntervalSince(since) >= limit { burnIfEphemeral() }
    }

    private func burnIfEphemeral() {
        guard !isKept, !current.isEmpty else { return }
        newChat()
        burnedWhileAway = true
    }

    func newChat() {
        settleStreaming()
        current = Conversation(modelID: settings.defaultModelID, systemPrompt: settings.systemPrompt)
        isKept = settings.keepChatsByDefault
    }

    func open(_ conversation: Conversation) {
        settleStreaming()
        current = conversation
        isKept = true
    }

    /// Freezes an in-flight reply before `current` is replaced, so a kept copy never shows a live cursor.
    private func settleStreaming() {
        guard current.messages.contains(where: \.isStreaming) else { return }
        current.messages.removeAll { $0.isStreaming && $0.content.isEmpty && $0.reasoning.isEmpty }
        for i in current.messages.indices { current.messages[i].isStreaming = false }
        persistCurrentIfKept()
    }

    func setKept(_ keep: Bool) {
        isKept = keep
        if keep {
            persistCurrentIfKept()
        } else {
            store.delete(id: current.id)
            kept.removeAll { $0.id == current.id }
        }
    }

    /// Called after every change to `current`. No-op for ephemeral chats.
    func persistCurrentIfKept() {
        guard isKept, !current.isEmpty else { return }
        current.updatedAt = Date()
        store.save(current)
        if let i = kept.firstIndex(where: { $0.id == current.id }) {
            kept[i] = current
        } else {
            kept.insert(current, at: 0)
        }
        kept.sort { $0.updatedAt > $1.updatedAt }
    }

    func deleteKept(id: UUID) {
        store.delete(id: id)
        kept.removeAll { $0.id == id }
        if current.id == id { newChat() }
    }

    func deleteAllKept() {
        store.deleteAll()
        kept = []
        if isKept { newChat() }
    }

    // MARK: - Settings

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }
}
