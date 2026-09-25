@testable import CourtCore
import XCTest

final class ChessTests: XCTestCase {
    func testInitialBoardAndCoordinates() throws {
        XCTAssertEqual(Position.initial.board.compactMap { $0 }.count, 32)
        XCTAssertEqual(Position.initial.fen, Position.startFen)
        XCTAssertEqual(Square.hit(x: 25, y: 375, size: 400, orientation: .white), Square.parse("a1"))
        XCTAssertEqual(Square.hit(x: 25, y: 375, size: 400, orientation: .black), Square.parse("h8"))
        XCTAssertNil(Square.hit(x: 400, y: 40, size: 400, orientation: .white))
        XCTAssertThrowsError(try Position(fen: "8/8/8/8/8/8/8/9 w - - 0 1"))
    }

    private func perft(_ position: Position, _ depth: Int) -> Int {
        if depth == 0 {
            return 1
        }
        return position.legalMoves().reduce(0) { $0 + perft(position.applying($1), depth - 1) }
    }

    func testLegalGenerationPerft() throws {
        XCTAssertEqual(perft(.initial, 3), 8902)
        let kiwipete = try Position(fen: "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
        XCTAssertEqual(perft(kiwipete, 2), 2039)
        let endgame = try Position(fen: "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
        XCTAssertEqual(perft(endgame, 3), 2812)
    }

    func testCastlingEnPassantAndPromotion() throws {
        let castle = try Position(fen: "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
        let move = try XCTUnwrap(castle.parseSAN("O-O"))
        let next = castle.applying(move)
        XCTAssertEqual(next.board[5], Piece(.white, .rook))
        XCTAssertEqual(next.board[6], Piece(.white, .king))
        XCTAssertEqual(next.castling, "kq")
        let pinned = try Position(fen: "k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
        XCTAssertFalse(try pinned.legalMoves().contains(XCTUnwrap(Move(uci: "e5d6"))))
        let ep = try Position(fen: "k7/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
        let captured = try ep.applying(XCTUnwrap(ep.parseSAN("exd6")))
        XCTAssertNil(captured.board[35])
        let promotion = try Position(fen: "7k/P7/8/8/8/8/8/7K w - - 0 1")
        XCTAssertEqual(promotion.legalMoves(from: 48).count, 4)
        XCTAssertEqual(try promotion.applying(XCTUnwrap(Move(uci: "a7a8n"))).board[56], Piece(.white, .knight))
    }

    func testPGNReviewAndRoundTrip() throws {
        let text = #"""
        [Event "Test \"court\""]
        [White "Ada"]
        1. e4 {A comment} e5 2.Nf3 (2. d4 (2... exd4)) Nc6
        3. Bb5 a6 $1 4. Ba4 Nf6 5. O-O Be7 1/2-1/2
        """#
        let pgn = try PGN(text: text)
        XCTAssertEqual(pgn.moves.count, 10)
        XCTAssertNil(pgn.warning)
        let exported = try PGN(text: pgn.text)
        XCTAssertEqual(exported.moves, pgn.moves)
        XCTAssertEqual(exported.tags["Event"], #"Test "court""#)
        XCTAssertEqual(exported.tags["Result"], "1/2-1/2")
        let mate = try PGN(text: "1. f3 e5 2. g4 Qh4# 0-1")
        let final = try Position(fen: XCTUnwrap(mate.moves.last).fen)
        XCTAssertTrue(final.inCheck)
        XCTAssertTrue(final.legalMoves().isEmpty)
        let partial = try PGN(text: "1. e4 e5 2. invalid")
        XCTAssertEqual(partial.moves.count, 2)
        XCTAssertNotNil(partial.warning)
        XCTAssertThrowsError(try PGN(text: "not chess"))
    }

    func testBlackStartAndUnderpromotionPGN() throws {
        let pgn = try PGN(text: #"""
        [SetUp "1"]
        [FEN "7k/8/8/8/8/8/p7/7K b - - 0 18"]
        18... a1=N *
        """#)
        XCTAssertEqual(pgn.moves.first?.uci, "a2a1n")
        XCTAssertTrue(pgn.text.contains("18... a1=N"))
        XCTAssertEqual(try PGN(text: pgn.text).moves, pgn.moves)
    }
}
