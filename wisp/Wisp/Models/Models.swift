import Foundation
import SwiftUI

enum Role: String, Codable {
    case system, user, assistant
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var role: Role
    var content: String
    var reasoning: String = ""
    var usage: Usage? = nil
    var modelID: String? = nil
    var isStreaming = false
    var error: String? = nil
    var createdAt = Date()
}

struct Usage: Codable, Equatable {
    var promptTokens: Int
    var completionTokens: Int
    var cachedTokens: Int = 0

    var total: Int { promptTokens + completionTokens }
}

struct Conversation: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String = ""
    var messages: [ChatMessage] = []
    var modelID: String
    var systemPrompt: String = ""
    var createdAt = Date()
    var updatedAt = Date()

    var isEmpty: Bool { messages.isEmpty }

    var displayTitle: String {
        if !title.isEmpty { return title }
        if let first = messages.first(where: { $0.role == .user }) {
            let line = first.content
                .split(whereSeparator: \.isNewline)
                .first.map(String.init) ?? first.content
            return String(line.prefix(60))
        }
        return "Untitled"
    }

    var totalUsage: Usage {
        messages.compactMap(\.usage).reduce(Usage(promptTokens: 0, completionTokens: 0)) {
            Usage(promptTokens: $0.promptTokens + $1.promptTokens,
                  completionTokens: $0.completionTokens + $1.completionTokens,
                  cachedTokens: $0.cachedTokens + $1.cachedTokens)
        }
    }
}

/// A model advertised by `GET /v1/models`.
struct ModelInfo: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var displayName: String
    var contextLength: Int
    var inputModalities: [String]
    var supportedFeatures: [String]
    /// USD per token
    var promptPrice: Double
    var completionPrice: Double
    var cachedPromptPrice: Double

    var supportsVision: Bool { inputModalities.contains("image") }
    var supportsReasoning: Bool { supportedFeatures.contains("reasoning") }

    func cost(for usage: Usage) -> Double {
        let uncached = max(0, usage.promptTokens - usage.cachedTokens)
        return Double(uncached) * promptPrice
            + Double(usage.cachedTokens) * cachedPromptPrice
            + Double(usage.completionTokens) * completionPrice
    }

    static let fallback: [ModelInfo] = [
        ModelInfo(id: "abliterated-model", displayName: "Abliterated Model", contextLength: 262_144,
                  inputModalities: ["text", "image"], supportedFeatures: ["reasoning", "tools"],
                  promptPrice: 1e-6, completionPrice: 3e-6, cachedPromptPrice: 1e-7),
        ModelInfo(id: "abliterated-model-large", displayName: "Abliterated Large", contextLength: 1_048_576,
                  inputModalities: ["text"], supportedFeatures: ["reasoning", "tools"],
                  promptPrice: 3e-6, completionPrice: 5e-6, cachedPromptPrice: 3e-7),
        ModelInfo(id: "abliterated-model-large-v2", displayName: "Abliterated Large v2", contextLength: 1_048_576,
                  inputModalities: ["text"], supportedFeatures: ["reasoning", "tools"],
                  promptPrice: 3e-6, completionPrice: 5e-6, cachedPromptPrice: 3e-7),
    ]
}

enum Appearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
}

/// How long an ephemeral chat survives after the app leaves the foreground.
enum BurnDelay: Int, Codable, CaseIterable, Identifiable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case never = -1

    var id: Int { rawValue }

    var seconds: TimeInterval? { self == .never ? nil : TimeInterval(rawValue) }

    var label: String {
        switch self {
        case .immediately: return "Now"
        case .oneMinute: return "1 min"
        case .fiveMinutes: return "5 min"
        case .never: return "Never"
        }
    }

    var statusText: String {
        switch self {
        case .immediately: return "gone when you leave"
        case .oneMinute: return "gone 1m after you leave"
        case .fiveMinutes: return "gone 5m after you leave"
        case .never: return "gone when you start another"
        }
    }
}

struct Settings: Codable, Equatable {
    /// Wisp is ephemeral by default: nothing is written to disk unless the user opts in.
    var keepChatsByDefault = false
    var defaultModelID = "abliterated-model"
    var systemPrompt = ""
    var temperature: Double = 0.7
    var showReasoning = true
    var showCost = true
    var appearance: Appearance = .system
    var burnAfterLeaving: BurnDelay = .fiveMinutes

    init() {}

    /// Tolerates settings saved by older builds that lack newer keys.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        keepChatsByDefault = try c.decodeIfPresent(Bool.self, forKey: .keepChatsByDefault) ?? d.keepChatsByDefault
        defaultModelID = try c.decodeIfPresent(String.self, forKey: .defaultModelID) ?? d.defaultModelID
        systemPrompt = try c.decodeIfPresent(String.self, forKey: .systemPrompt) ?? d.systemPrompt
        temperature = try c.decodeIfPresent(Double.self, forKey: .temperature) ?? d.temperature
        showReasoning = try c.decodeIfPresent(Bool.self, forKey: .showReasoning) ?? d.showReasoning
        showCost = try c.decodeIfPresent(Bool.self, forKey: .showCost) ?? d.showCost
        appearance = try c.decodeIfPresent(Appearance.self, forKey: .appearance) ?? d.appearance
        burnAfterLeaving = try c.decodeIfPresent(BurnDelay.self, forKey: .burnAfterLeaving) ?? d.burnAfterLeaving
    }
}

extension Appearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
