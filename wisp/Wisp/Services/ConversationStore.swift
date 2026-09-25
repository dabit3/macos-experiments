import Foundation

/// Disk persistence for the *kept* conversations only.
/// Ephemeral chats live in memory and are never handed to this type.
struct ConversationStore {
    private let directory: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appending(path: "Kept", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func loadAll() -> [Conversation] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> Conversation? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                guard var c = try? decoder.decode(Conversation.self, from: data) else { return nil }
                // A reply that was mid-stream when the app died can never finish.
                for i in c.messages.indices { c.messages[i].isStreaming = false }
                return c
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ conversation: Conversation) {
        guard let data = try? encoder.encode(conversation) else { return }
        try? data.write(to: url(for: conversation.id), options: [.atomic, .completeFileProtection])
    }

    func delete(id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }
}
