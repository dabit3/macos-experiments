@testable import CourtCore
import XCTest

final class LiveProtocolTests: XCTestCase {
    @MainActor
    private func wait(seconds: Double = 12, file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(30))
        }
        XCTAssertTrue(condition(), "Timed out waiting for server state", file: file, line: line)
        if !condition() {
            throw URLError(.timedOut)
        }
    }

    @MainActor
    func testAuthoritativeMultiplayerReconnectOffersRematchAndBots() async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["GC_INTEGRATION_SERVER"] else {
            throw XCTSkip("Set GC_INTEGRATION_SERVER to run against the real Dart server.")
        }
        let prefix = UUID().uuidString.prefix(8)
        func store(_ suffix: String) -> CourtStore {
            CourtStore(clientId: "\(prefix)-\(suffix)", endpoint: endpoint, name: suffix, platform: "swift-test",
                       defaults: UserDefaults(suiteName: "gc-tests-\(prefix)-\(suffix)")!)
        }
        let white = store("white"), black = store("black"), spectator = store("spectator")
        defer { white.connection.stop(); black.connection.stop(); spectator.connection.stop() }
        white.connect(); black.connect(); spectator.connect()
        try await wait { white.ready && black.ready && spectator.ready }
        white.sidePreference = .white; white.create(isPublic: true)
        try await wait { white.room?.status == .waiting }
        let code = try XCTUnwrap(white.room?.code)
        spectator.join(code, spectate: true)
        black.join(code)
        try await wait { white.room?.status == .playing && black.room?.status == .playing && spectator.room?.status == .playing }
        XCTAssertNil(spectator.mySide)
        XCTAssertEqual(black.mySide, .black)
        let before = white.position.fen
        white.request(from: 12, to: 28)
        XCTAssertEqual(white.position.fen, before, "Client must wait for a server echo")
        try await wait { white.moves.count == 1 && black.moves.count == 1 && spectator.moves.count == 1 }
        XCTAssertEqual(white.position.fen, black.position.fen)
        white.request(from: 6, to: 21)
        XCTAssertEqual(white.premove?.uci, "g1f3")
        black.request(from: 52, to: 36)
        try await wait { white.moves.count == 3 && black.moves.count == 3 }
        XCTAssertNil(white.premove)
        white.action(.offerTakeback)
        try await wait { black.room?.offers.takeback == .white }
        black.action(.acceptTakeback)
        try await wait { white.moves.count < 3 && black.moves.count == white.moves.count }
        white.connection.stop()
        try await wait { black.room?.white?.connected == false }
        white.connect()
        try await wait { white.ready && white.room?.code == code && black.room?.white?.connected == true }
        XCTAssertEqual(white.room?.white?.clientId, white.clientId)
        white.action(.offerDraw)
        try await wait { black.room?.offers.draw == .white }
        black.action(.acceptDraw)
        try await wait { white.room?.result?.reason == .agreement && spectator.room?.result?.reason == .agreement }
        white.action(.offerRematch)
        try await wait { black.room?.offers.rematch == .white }
        black.action(.acceptRematch)
        try await wait { white.room?.code == code && black.room?.code == code && white.room?.status == .playing && white.mySide == .black }
        XCTAssertEqual(white.mySide, .black)
        white.action(.resign)
        try await wait { black.room?.result?.reason == .resignation }
        white.action(.leaveRoom)
        try await wait { white.room == nil && !white.busy }
        white.sidePreference = .black; white.botLevel = 1; white.create(bot: true, isPublic: false)
        try await wait(seconds: 20) { white.room?.white?.isBot == true && white.moves.count >= 1 }
        XCTAssertEqual(white.moves.first?.uci.count, 4)
        let duplicate = store("white")
        defer { duplicate.connection.stop() }
        duplicate.connect()
        try await wait { duplicate.ready && white.connection.phase == .offline }
        XCTAssertNotNil(white.connection.error)
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(white.connection.phase, .offline, "Fatal duplicate-session errors must stop reconnecting")
    }

    @MainActor
    func testOperaGameFourClientsAndPGNConverge() async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["GC_INTEGRATION_SERVER"] else {
            throw XCTSkip("Set GC_INTEGRATION_SERVER to run against the real Dart server.")
        }
        let prefix = UUID().uuidString.prefix(8)
        let clients = (0 ..< 4).map { index in
            CourtStore(clientId: "\(prefix)-opera-\(index)", endpoint: endpoint, name: "Opera \(index)", platform: "swift-test")
        }
        defer { clients.forEach { $0.connection.stop() } }
        clients.forEach { $0.connect() }
        try await wait { clients.allSatisfy(\.ready) }
        clients[0].sidePreference = .white
        clients[0].create()
        try await wait { clients[0].room != nil }
        let code = try XCTUnwrap(clients[0].room?.code)
        for index in 1 ..< 4 {
            clients[index].join(code, spectate: index > 1)
        }
        try await wait { clients.allSatisfy { $0.room?.status == .playing } }
        var invalid = ClientMessage(.move); invalid.uci = "e2e4"
        await clients[2].connection.send(invalid)
        try await wait { clients[2].notice != nil }
        XCTAssertEqual(clients[2].moves.count, 0)
        let script = """
        e2e4 e7e5 g1f3 d7d6 d2d4 c8g4 d4e5 g4f3 d1f3 d6e5 f1c4 g8f6 f3b3 d8e7
        b1c3 c7c6 c1g5 b7b5 c3b5 c6b5 c4b5 b8d7 e1c1 a8d8 d1d7 d8d7 h1d1 e7e6
        b5d7 f6d7 b3b8 d7b8 d1d8
        """.split(whereSeparator: \.isWhitespace)
        let expectedSAN = "e4 e5 Nf3 d6 d4 Bg4 dxe5 Bxf3 Qxf3 dxe5 Bc4 Nf6 Qb3 Qe7 Nc3 c6 Bg5 b5 Nxb5 cxb5 Bxb5+ Nbd7 O-O-O Rd8 Rxd7 Rxd7 Rd1 Qe6 Bxd7+ Nxd7 Qb8+ Nxb8 Rd8#".split(separator: " ").map(String.init)
        for (index, uci) in script.enumerated() {
            let player = clients[index % 2], move = try XCTUnwrap(Move(uci: String(uci)))
            XCTAssertTrue(player.position.legalMoves().contains(move))
            player.request(from: move.from, to: move.to)
            try await wait { clients.allSatisfy { $0.moves.count == index + 1 } }
            XCTAssertTrue(clients.allSatisfy { $0.position.fen == clients[0].position.fen })
        }
        XCTAssertTrue(clients.allSatisfy { $0.room?.result?.reason == .checkmate && $0.room?.result?.score == "1-0" })
        XCTAssertEqual(clients[0].position.fen, "1n1Rkb1r/p4ppp/4q3/4p1B1/4P3/8/PPP2PPP/2K5 b k - 1 17")
        XCTAssertEqual(clients[0].moves.map(\.san), expectedSAN)
        let pgn = try PGN(text: clients[0].pgn)
        XCTAssertEqual(pgn.moves, clients[0].moves)
        clients[2].importPGN(clients[0].pgn)
        clients[2].view(5)
        XCTAssertEqual(clients[2].displayedPosition.fen, pgn.moves[4].fen)
        clients[2].view(nil)
        XCTAssertEqual(clients[2].displayedPosition.fen, clients[0].position.fen)
    }

    @MainActor
    func testQuickPairAndVisibleInvalidRoom() async throws {
        guard let endpoint = ProcessInfo.processInfo.environment["GC_INTEGRATION_SERVER"] else {
            throw XCTSkip("Set GC_INTEGRATION_SERVER to run against the real Dart server.")
        }
        let prefix = UUID().uuidString.prefix(8)
        let first = CourtStore(clientId: "\(prefix)-pair-a", endpoint: endpoint, name: "Pair A", platform: "swift-test")
        let second = CourtStore(clientId: "\(prefix)-pair-b", endpoint: endpoint, name: "Pair B", platform: "swift-test")
        defer { first.connection.stop(); second.connection.stop() }
        first.connect(); second.connect()
        try await wait { first.ready && second.ready }
        first.join("ZZZZZZ")
        try await wait { first.notice != nil && !first.busy }
        XCTAssertNil(first.room)
        first.quickPair(bot: false)
        try await wait { first.queue != nil }
        first.action(.cancelPair)
        try await wait { first.queue == nil && !first.busy }
        first.quickPair(bot: false)
        try await wait { first.queue != nil }
        second.quickPair(bot: false)
        try await wait { first.room?.status == .playing && second.room?.status == .playing }
        XCTAssertEqual(first.room?.code, second.room?.code)
        XCTAssertNil(first.queue)
        XCTAssertNil(second.queue)
    }
}
