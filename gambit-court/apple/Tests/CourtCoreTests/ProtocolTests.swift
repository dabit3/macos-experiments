@testable import CourtCore
import XCTest

final class ProtocolTests: XCTestCase {
    func testClocksExtrapolateFreezeAndClamp() throws {
        let data = Data(#"{"whiteMs":1800000,"blackMs":210000,"running":"w","asOfServerMs":1000,"frozen":false}"#.utf8)
        let clock = try JSONDecoder().decode(ClockState.self, from: data)
        XCTAssertEqual(ClockState.format(clock.remaining(.white, serverNowMs: 3500)), "29:57")
        XCTAssertEqual(clock.remaining(.black, serverNowMs: 90000), 210_000)
        XCTAssertEqual(clock.remaining(.white, serverNowMs: 5_000_000), 0)
        let frozen = try JSONDecoder().decode(ClockState.self, from: Data(String(decoding: data, as: UTF8.self).replacingOccurrences(of: "false", with: "true").utf8))
        XCTAssertEqual(frozen.remaining(.white, serverNowMs: 5_000_000), 1_800_000)
        XCTAssertEqual(ClockState.format(-5), "0:00.0")
        XCTAssertEqual(ClockState.format(19400), "0:19.4")
        XCTAssertEqual(ClockState.format(3_661_000), "1:01:01")
    }

    func testWirePayloadsAndErrors() throws {
        var create = ClientMessage(.createRoom)
        create.timeControl = .standard; create.side = .black; create.botLevel = 2; create.isPublic = false
        let encoded = try JSONEncoder().encode(create)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: encoded)
        XCTAssertEqual(decoded.type.rawValue, "create_room")
        XCTAssertEqual(decoded.side?.rawValue, "black")
        XCTAssertEqual(decoded.timeControl?.initialMs, 300_000)
        XCTAssertNil(decoded.asSpectator)
        let error = try JSONDecoder().decode(ServerMessage.self, from: Data(#"{"type":"error","code":"not_allowed","message":"Already connected","fatal":true}"#.utf8))
        guard case let .error(payload) = error else { return XCTFail("Expected typed error") }
        XCTAssertTrue(payload.fatal == true)
        XCTAssertEqual(payload.code, "not_allowed")
        XCTAssertThrowsError(try JSONDecoder().decode(ServerMessage.self, from: Data(#"{"type":"room_state","room":{}}"#.utf8)))
    }

    @MainActor
    func testEndpointValidation() {
        XCTAssertNotNil(CourtConnection.endpoint("ws://127.0.0.1:8765/ws"))
        XCTAssertNotNil(CourtConnection.endpoint("wss://chess.example/ws"))
        for url in ["https://example.com", "ws://", "ws://user:password@host/ws", "file:///board", "ws://host/ws#fragment"] {
            XCTAssertNil(CourtConnection.endpoint(url))
        }
    }

    @MainActor
    func testSnapshotSequenceAndInvalidFENDoNotOverwritePosition() throws {
        func snapshot(_ seq: Int, fen: String) throws -> ServerMessage {
            try JSONDecoder().decode(ServerMessage.self, from: Data("""
            {"type":"room_state","room":{
              "code":"ABC123","seq":\(seq),"status":"playing",
              "timeControl":{"initialMs":300000,"incrementMs":3000},
              "white":{"clientId":"test","name":"Ada","platform":"macos","connected":true,"isBot":false},
              "spectators":[],"startFen":"\(Position.startFen)","fen":"\(fen)","moves":[],
              "turn":"w","clocks":{"whiteMs":300000,"blackMs":300000,"asOfServerMs":1000,"frozen":false},
              "offers":{},"isPublic":true
            }}
            """.utf8))
        }
        let store = CourtStore(clientId: "test", endpoint: "ws://localhost:8765/ws", platform: "test")
        let after = try Position.initial.applying(XCTUnwrap(Move(uci: "e2e4")))
        try store.receive(snapshot(7, fen: after.fen))
        try store.receive(snapshot(6, fen: Position.startFen))
        XCTAssertEqual(store.room?.seq, 7)
        XCTAssertEqual(store.position.fen, after.fen)
        try store.receive(snapshot(8, fen: "invalid"))
        XCTAssertEqual(store.room?.seq, 7)
        XCTAssertEqual(store.position.fen, after.fen)
        XCTAssertNotNil(store.notice)
    }
}
