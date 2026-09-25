import Foundation

public actor WebSocketConnection {
  private let session: URLSession
  private let socket: URLSessionWebSocketTask
  public init(url: URL) {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 20
    config.timeoutIntervalForResource = 86_400
    session = URLSession(configuration: config)
    socket = session.webSocketTask(with: url)
    socket.maximumMessageSize = 1_048_576
    socket.resume()
  }
  public func send(_ command: Command) async throws {
    let data = try command.data()
    try await socket.send(.string(String(decoding: data, as: UTF8.self)))
  }
  public func receive() async throws -> ServerMessage {
    let frame = try await socket.receive()
    let data: Data
    switch frame {
    case .string(let text): data = Data(text.utf8)
    case .data(let bytes): data = bytes
    @unknown default: throw URLError(.cannotParseResponse)
    }
    return try JSONDecoder().decode(ServerMessage.self, from: data)
  }
  public func close() {
    socket.cancel(with: .goingAway, reason: nil)
    session.invalidateAndCancel()
  }
}
