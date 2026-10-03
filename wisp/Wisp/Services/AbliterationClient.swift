import Foundation

/// Thin client for the OpenAI-compatible Abliteration API (`https://api.abliteration.ai/v1`).
struct AbliterationClient {
    static let baseURL = URL(string: "https://api.abliteration.ai/v1")!

    var apiKey: String
    var session: URLSession = Self.ephemeralSession

    /// No disk cache, cookie store or credential store: nothing about the traffic outlives the process.
    static let ephemeralSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    enum ClientError: LocalizedError {
        case unauthorized
        case http(Int, String)
        case malformed

        var errorDescription: String? {
            switch self {
            case .unauthorized: return "That key was rejected (401). Check it and try again."
            case .http(let code, let body):
                let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "HTTP \(code)" : "HTTP \(code): \(trimmed.prefix(240))"
            case .malformed: return "Unexpected response from server."
            }
        }
    }

    // MARK: - Models

    func listModels() async throws -> [ModelInfo] {
        var req = request(path: "models")
        req.httpMethod = "GET"
        let (data, response) = try await session.data(for: req)
        try check(response, data: data)
        let list = try JSONDecoder().decode(ModelListResponse.self, from: data)
        return list.data.map { m in
            ModelInfo(
                id: m.id,
                displayName: m.display_name ?? m.name ?? m.id,
                contextLength: m.context_length ?? 0,
                inputModalities: m.input_modalities ?? ["text"],
                supportedFeatures: m.supported_features ?? [],
                promptPrice: Double(m.pricing?.prompt ?? "") ?? 0,
                completionPrice: Double(m.pricing?.completion ?? "") ?? 0,
                cachedPromptPrice: Double(m.pricing?.input_cache_read ?? "") ?? 0
            )
        }
    }

    // MARK: - Streaming chat

    enum StreamEvent {
        case reasoning(String)
        case content(String)
        case usage(Usage)
        case done
    }

    struct ChatOptions {
        var model: String
        var temperature: Double
        var systemPrompt: String
    }

    func streamChat(messages: [ChatMessage], options: ChatOptions) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var req = request(path: "chat/completions")
                    req.httpMethod = "POST"
                    req.timeoutInterval = 300

                    var wire: [[String: Any]] = []
                    let system = options.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !system.isEmpty {
                        wire.append(["role": "system", "content": system])
                    }
                    for m in messages where m.error == nil && !(m.role == .assistant && m.content.isEmpty) {
                        wire.append(["role": m.role.rawValue, "content": m.content])
                    }

                    let body: [String: Any] = [
                        "model": options.model,
                        "messages": wire,
                        "temperature": options.temperature,
                        "stream": true,
                        "stream_options": ["include_usage": true],
                    ]
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else { throw ClientError.malformed }
                    if http.statusCode != 200 {
                        var collected = Data()
                        for try await b in bytes { collected.append(b) }
                        if http.statusCode == 401 { throw ClientError.unauthorized }
                        throw ClientError.http(http.statusCode, Self.errorMessage(from: collected))
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(ChatChunk.self, from: data)
                        else { continue }

                        if let choice = chunk.choices?.first {
                            if let r = choice.delta?.reasoning ?? choice.delta?.reasoning_content, !r.isEmpty {
                                continuation.yield(.reasoning(r))
                            }
                            if let c = choice.delta?.content, !c.isEmpty {
                                continuation.yield(.content(c))
                            }
                        }
                        if let u = chunk.usage {
                            continuation.yield(.usage(Usage(
                                promptTokens: u.prompt_tokens ?? 0,
                                completionTokens: u.completion_tokens ?? 0,
                                cachedTokens: u.prompt_tokens_details?.cached_tokens ?? 0
                            )))
                        }
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Helpers

    private func request(path: String) -> URLRequest {
        var req = URLRequest(url: Self.baseURL.appending(path: path))
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("wisp-ios/1.0", forHTTPHeaderField: "User-Agent")
        return req
    }

    private func check(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ClientError.malformed }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw ClientError.unauthorized
        default: throw ClientError.http(http.statusCode, Self.errorMessage(from: data))
        }
    }

    private static func errorMessage(from data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let err = obj["error"] as? [String: Any], let msg = err["message"] as? String { return msg }
            if let msg = obj["message"] as? String { return msg }
            if let msg = obj["error"] as? String { return msg }
        }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Wire types

private struct ModelListResponse: Decodable {
    struct Pricing: Decodable {
        var prompt: String?
        var completion: String?
        var input_cache_read: String?
    }
    struct Model: Decodable {
        var id: String
        var name: String?
        var display_name: String?
        var context_length: Int?
        var input_modalities: [String]?
        var supported_features: [String]?
        var pricing: Pricing?
    }
    var data: [Model]
}

private struct ChatChunk: Decodable {
    struct Delta: Decodable {
        var content: String?
        var reasoning: String?
        var reasoning_content: String?
    }
    struct Choice: Decodable {
        var delta: Delta?
        var finish_reason: String?
    }
    struct UsageWire: Decodable {
        struct Details: Decodable { var cached_tokens: Int? }
        var prompt_tokens: Int?
        var completion_tokens: Int?
        var prompt_tokens_details: Details?
    }
    var choices: [Choice]?
    var usage: UsageWire?
}
