import Foundation

public enum PieceKind: String, Codable, CaseIterable, Sendable {
    case pawn = "p", knight = "n", bishop = "b", rook = "r", queen = "q", king = "k"
    public var label: String {
        switch self {
        case .pawn: "Pawn"
        case .knight: "Knight"
        case .bishop: "Bishop"
        case .rook: "Rook"
        case .queen: "Queen"
        case .king: "King"
        }
    }

    public var value: Int {
        switch self {
        case .pawn: 1
        case .knight, .bishop: 3
        case .rook: 5
        case .queen: 9
        case .king: 0
        }
    }

    public static let promotions: [PieceKind] = [.queen, .rook, .bishop, .knight]
}

public struct Piece: Equatable, Sendable {
    public let side: Side
    public let kind: PieceKind
    public init(_ side: Side, _ kind: PieceKind) {
        self.side = side; self.kind = kind
    }

    public var fen: String {
        side == .white ? kind.rawValue.uppercased() : kind.rawValue
    }
}

public enum Square {
    public static func name(_ square: Int) -> String {
        "\(Array("abcdefgh")[square % 8])\(square / 8 + 1)"
    }

    public static func parse(_ name: String) -> Int? {
        let chars = Array(name)
        guard chars.count == 2, let file = Array("abcdefgh").firstIndex(of: chars[0]),
              let rank = chars[1].wholeNumberValue, (1 ... 8).contains(rank) else { return nil }
        return (rank - 1) * 8 + file
    }

    public static func hit(x: Double, y: Double, size: Double, orientation: Side) -> Int? {
        guard size > 0, x >= 0, y >= 0, x < size, y < size else { return nil }
        let file = Int(x / size * 8), row = Int(y / size * 8)
        return orientation == .white ? (7 - row) * 8 + file : row * 8 + 7 - file
    }
}

public struct Move: Equatable, Hashable, Sendable {
    public let from: Int
    public let to: Int
    public let promotion: PieceKind?
    public init(_ from: Int, _ to: Int, promotion: PieceKind? = nil) {
        self.from = from; self.to = to; self.promotion = promotion
    }

    public init?(uci: String) {
        let chars = Array(uci)
        guard (4 ... 5).contains(chars.count),
              let from = Square.parse(String(chars[0 ... 1])), let to = Square.parse(String(chars[2 ... 3])),
              from != to else { return nil }
        let promotion = chars.count == 5 ? PieceKind(rawValue: String(chars[4])) : nil
        if chars.count == 5, !PieceKind.promotions.contains(where: { $0 == promotion }) {
            return nil
        }
        self.init(from, to, promotion: promotion)
    }

    public var uci: String {
        Square.name(from) + Square.name(to) + (promotion?.rawValue ?? "")
    }
}

public enum ChessError: Error, LocalizedError {
    case invalidFEN, invalidPGN(String)
    public var errorDescription: String? {
        switch self {
        case .invalidFEN: "Invalid chess position."
        case let .invalidPGN(text): text
        }
    }
}

public struct Position: Equatable, Sendable {
    public static let startFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    public static let initial = try! Position(fen: startFen)
    public private(set) var board: [Piece?]
    public private(set) var turn: Side
    public private(set) var castling: String
    public private(set) var ep: Int?
    public private(set) var halfmove: Int
    public private(set) var fullmove: Int

    public init(fen: String) throws {
        let parts = fen.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 2, let side = Side(rawValue: parts[1]) else { throw ChessError.invalidFEN }
        let ranks = parts[0].split(separator: "/")
        guard ranks.count == 8 else { throw ChessError.invalidFEN }
        board = Array(repeating: nil, count: 64); turn = side
        castling = parts.count > 2 && parts[2] != "-" ? parts[2] : ""
        ep = parts.count > 3 ? Square.parse(parts[3]) : nil
        halfmove = parts.count > 4 ? Int(parts[4]) ?? 0 : 0
        fullmove = parts.count > 5 ? Int(parts[5]) ?? 1 : 1
        for (row, rank) in ranks.enumerated() {
            var file = 0
            for char in rank {
                if let count = char.wholeNumberValue, (1 ... 8).contains(count) {
                    file += count
                } else {
                    guard file < 8, let kind = PieceKind(rawValue: char.lowercased()) else { throw ChessError.invalidFEN }
                    board[(7 - row) * 8 + file] = Piece(char.isUppercase ? .white : .black, kind)
                    file += 1
                }
            }
            guard file == 8 else { throw ChessError.invalidFEN }
        }
        guard king(.white) != nil, king(.black) != nil else { throw ChessError.invalidFEN }
    }

    public var fen: String {
        var ranks: [String] = []
        for rank in (0 ..< 8).reversed() {
            var text = "", empty = 0
            for file in 0 ..< 8 {
                if let piece = board[rank * 8 + file] {
                    if empty > 0 {
                        text += String(empty); empty = 0
                    }
                    text += piece.fen
                } else {
                    empty += 1
                }
            }
            if empty > 0 {
                text += String(empty)
            }
            ranks.append(text)
        }
        return "\(ranks.joined(separator: "/")) \(turn.rawValue) \(castling.isEmpty ? "-" : castling) \(ep.map(Square.name) ?? "-") \(halfmove) \(fullmove)"
    }

    public func king(_ side: Side) -> Int? {
        board.firstIndex(of: Piece(side, .king))
    }

    private static let knightSteps = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
    private static let diagonals = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    private static let straights = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    private static let kingSteps = diagonals + straights
    private func target(_ square: Int, _ dx: Int, _ dy: Int) -> Int? {
        let x = square % 8 + dx, y = square / 8 + dy
        return (0 ..< 8).contains(x) && (0 ..< 8).contains(y) ? y * 8 + x : nil
    }

    public func attacked(_ square: Int, by side: Side) -> Bool {
        for dx in [-1, 1] {
            if let at = target(square, dx, side == .white ? -1 : 1), board[at] == Piece(side, .pawn) {
                return true
            }
        }
        for (dx, dy) in Self.knightSteps {
            if let at = target(square, dx, dy), board[at] == Piece(side, .knight) {
                return true
            }
        }
        for (dx, dy) in Self.kingSteps {
            if let at = target(square, dx, dy), board[at] == Piece(side, .king) {
                return true
            }
            var distance = 1
            while let at = target(square, dx * distance, dy * distance) {
                if let piece = board[at] {
                    if piece.side == side, piece.kind == .queen || piece.kind == (dx != 0 && dy != 0 ? .bishop : .rook) {
                        return true
                    }
                    break
                }
                distance += 1
            }
        }
        return false
    }

    public func inCheck(_ side: Side) -> Bool {
        king(side).map { attacked($0, by: side.opposite) } ?? true
    }

    public var inCheck: Bool {
        inCheck(turn)
    }

    public func isCapture(_ move: Move) -> Bool {
        board[move.to] != nil || (board[move.from]?.kind == .pawn && move.to == ep)
    }

    public func requiresPromotion(_ from: Int, _ to: Int) -> Bool {
        board[from]?.kind == .pawn && (to / 8 == 0 || to / 8 == 7)
    }

    public func legalMoves(from: Int? = nil) -> [Move] {
        pseudoMoves().filter { (from == nil || $0.from == from) && !applying($0).inCheck(turn) }
    }

    private func pseudoMoves() -> [Move] {
        var moves: [Move] = []
        for from in 0 ..< 64 {
            guard let piece = board[from], piece.side == turn else { continue }
            switch piece.kind {
            case .pawn:
                let direction = turn == .white ? 1 : -1
                var destinations: [Int] = []
                if let one = target(from, 0, direction), board[one] == nil {
                    destinations.append(one)
                    if from / 8 == (turn == .white ? 1 : 6),
                       let two = target(from, 0, direction * 2), board[two] == nil
                    {
                        destinations.append(two)
                    }
                }
                for dx in [-1, 1] {
                    if let to = target(from, dx, direction), board[to]?.side == turn.opposite || to == ep {
                        destinations.append(to)
                    }
                }
                for to in destinations {
                    if requiresPromotion(from, to) {
                        moves += PieceKind.promotions.map { Move(from, to, promotion: $0) }
                    } else {
                        moves.append(Move(from, to))
                    }
                }
            case .knight, .king:
                for (dx, dy) in piece.kind == .knight ? Self.knightSteps : Self.kingSteps {
                    if let to = target(from, dx, dy), board[to]?.side != turn {
                        moves.append(Move(from, to))
                    }
                }
                if piece.kind == .king {
                    moves += castles(from)
                }
            case .bishop, .rook, .queen:
                let directions = piece.kind == .bishop ? Self.diagonals : piece.kind == .rook ? Self.straights : Self.kingSteps
                for (dx, dy) in directions {
                    var step = 1
                    while let to = target(from, dx * step, dy * step) {
                        if board[to]?.side != turn {
                            moves.append(Move(from, to))
                        }
                        if board[to] != nil {
                            break
                        }
                        step += 1
                    }
                }
            }
        }
        return moves
    }

    private func castles(_ from: Int) -> [Move] {
        let rank = turn == .white ? 0 : 7, home = rank * 8
        guard from == home + 4, !inCheck else { return [] }
        var moves: [Move] = []
        for kingside in [true, false] {
            let right = turn == .white ? (kingside ? "K" : "Q") : (kingside ? "k" : "q")
            let rook = home + (kingside ? 7 : 0)
            let empty = kingside ? [5, 6] : [1, 2, 3]
            let safe = kingside ? [5, 6] : [2, 3]
            if castling.contains(right), board[rook] == Piece(turn, .rook),
               empty.allSatisfy({ board[home + $0] == nil }),
               safe.allSatisfy({ !attacked(home + $0, by: turn.opposite) })
            {
                moves.append(Move(from, home + (kingside ? 6 : 2)))
            }
        }
        return moves
    }

    public func applying(_ move: Move) -> Position {
        guard let piece = board[move.from] else { return self }
        var next = self
        next.board[move.from] = nil
        next.board[move.to] = Piece(piece.side, move.promotion ?? piece.kind)
        next.ep = nil
        next.halfmove = piece.kind == .pawn || board[move.to] != nil ? 0 : halfmove + 1
        if piece.kind == .pawn {
            if abs(move.to - move.from) == 16 {
                next.ep = (move.to + move.from) / 2
            }
            if move.to == ep, board[move.to] == nil {
                next.board[move.from / 8 * 8 + move.to % 8] = nil
            }
        }
        if piece.kind == .king {
            next.castling.removeAll { piece.side == .white ? "KQ".contains($0) : "kq".contains($0) }
            if abs(move.to - move.from) == 2 {
                let home = move.from / 8 * 8
                let rookFrom = home + (move.to > move.from ? 7 : 0)
                next.board[home + (move.to > move.from ? 5 : 3)] = board[rookFrom]
                next.board[rookFrom] = nil
            }
        }
        for (square, right): (Int, Character) in [(0, "Q"), (7, "K"), (56, "q"), (63, "k")] {
            if move.from == square || move.to == square {
                next.castling.removeAll { $0 == right }
            }
        }
        next.turn = turn.opposite
        next.fullmove += turn == .black ? 1 : 0
        return next
    }

    public func san(_ move: Move) -> String {
        guard let piece = board[move.from] else { return move.uci }
        var text = ""
        if piece.kind == .king, abs(move.to - move.from) == 2 {
            text = move.to > move.from ? "O-O" : "O-O-O"
        } else {
            let capture = isCapture(move)
            if piece.kind == .pawn {
                if capture {
                    text += String(Array("abcdefgh")[move.from % 8])
                }
            } else {
                text += piece.kind.rawValue.uppercased()
                let rivals = legalMoves().filter { $0.to == move.to && $0.from != move.from && board[$0.from] == piece }
                if !rivals.isEmpty {
                    if !rivals.contains(where: { $0.from % 8 == move.from % 8 }) {
                        text += String(Array("abcdefgh")[move.from % 8])
                    } else if !rivals.contains(where: { $0.from / 8 == move.from / 8 }) {
                        text += String(move.from / 8 + 1)
                    } else {
                        text += Square.name(move.from)
                    }
                }
            }
            if capture {
                text += "x"
            }
            text += Square.name(move.to)
            if let promotion = move.promotion {
                text += "=" + promotion.rawValue.uppercased()
            }
        }
        let next = applying(move)
        if next.inCheck {
            text += next.legalMoves().isEmpty ? "#" : "+"
        }
        return text
    }

    public func parseSAN(_ text: String) -> Move? {
        let clean = text.replacingOccurrences(of: "[+#!?]+$", with: "", options: .regularExpression)
        let legal = legalMoves()
        if let move = Move(uci: clean.replacingOccurrences(of: "-", with: "").lowercased()), legal.contains(move) {
            return move
        }
        let normalized = clean.replacingOccurrences(of: "0", with: "O")
        if normalized == "O-O" || normalized == "O-O-O" {
            return legal.first { board[$0.from]?.kind == .king && $0.to - $0.from == (normalized == "O-O" ? 2 : -2) }
        }
        let pattern = #"^([NBRQK])?([a-h])?([1-8])?x?([a-h][1-8])(?:=?([NBRQ]))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)) else { return nil }
        func group(_ index: Int) -> String? {
            Range(match.range(at: index), in: clean).map { String(clean[$0]) }
        }
        guard let dest = group(4).flatMap(Square.parse) else { return nil }
        let kind = group(1).flatMap { PieceKind(rawValue: $0.lowercased()) } ?? .pawn
        let promo = group(5).flatMap { PieceKind(rawValue: $0.lowercased()) }
        let candidates = legal.filter { move in
            move.to == dest && board[move.from]?.kind == kind &&
                (group(2) == nil || group(2) == String(Array("abcdefgh")[move.from % 8])) &&
                (group(3) == nil || group(3) == String(move.from / 8 + 1)) &&
                (move.promotion == nil || move.promotion == (promo ?? .queen))
        }
        return candidates.count == 1 ? candidates[0] : nil
    }
}
