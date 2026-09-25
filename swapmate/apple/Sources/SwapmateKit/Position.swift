import Foundation

enum PositionError: Error { case invalidFEN }

struct Position {
  var squares: [Piece?]
  var turn: Side
  var castling: String
  var enPassant: Square?
  var reserves: [Side: [PieceKind: Int]]

  init(fen: String) throws {
    let fields = fen.split(separator: " ")
    guard fields.count >= 4, let side = Side(rawValue: String(fields[1])) else {
      throw PositionError.invalidFEN
    }
    squares = Array(repeating: nil, count: 64)
    reserves = [.white: [:], .black: [:]]
    turn = side
    castling = String(fields[2])
    enPassant = fields[3] == "-" ? nil : Square(String(fields[3]))
    if fields[3] != "-" && enPassant == nil { throw PositionError.invalidFEN }
    let placement = String(fields[0])
    let boardPart = placement.split(separator: "[", omittingEmptySubsequences: false)[0]
    let ranks = boardPart.split(separator: "/")
    guard ranks.count == 8 else { throw PositionError.invalidFEN }
    for (row, rank) in ranks.enumerated() {
      var file = 0
      var last: Int?
      for char in rank {
        if char == "~" {
          guard let index = last else { throw PositionError.invalidFEN }
          squares[index]?.promoted = true
          last = nil
        } else if let count = char.wholeNumberValue, (1...8).contains(count) {
          file += count
          last = nil
        } else {
          guard file < 8, let kind = PieceKind(rawValue: String(char).uppercased()) else {
            throw PositionError.invalidFEN
          }
          let index = (7 - row) * 8 + file
          squares[index] = Piece(color: char.isUppercase ? .white : .black, kind: kind)
          last = index
          file += 1
        }
      }
      guard file == 8 else { throw PositionError.invalidFEN }
    }
    if let start = placement.firstIndex(of: "[") {
      guard placement.last == "]" else { throw PositionError.invalidFEN }
      for char in placement[
        placement.index(after: start)..<placement.index(before: placement.endIndex)]
      {
        guard let kind = PieceKind(rawValue: String(char).uppercased()), kind != .king else {
          throw PositionError.invalidFEN
        }
        let color: Side = char.isUppercase ? .white : .black
        reserves[color, default: [:]][kind, default: 0] += 1
      }
    }
  }

  subscript(_ square: Square) -> Piece? { squares[square.index] }
  func reserve(_ side: Side, _ kind: PieceKind) -> Int { reserves[side]?[kind] ?? 0 }

  func attacked(_ square: Square, by side: Side) -> Bool {
    for index in 0..<64 {
      guard let piece = squares[index], piece.color == side else { continue }
      let from = Square(index)
      let dx = square.file - from.file
      let dy = square.rank - from.rank
      switch piece.kind {
      case .pawn:
        if abs(dx) == 1 && dy == (side == .white ? 1 : -1) { return true }
      case .knight:
        if abs(dx) * abs(dy) == 2 { return true }
      case .king:
        if max(abs(dx), abs(dy)) == 1 { return true }
      case .bishop, .rook, .queen:
        let diagonal = abs(dx) == abs(dy) && dx != 0
        let straight = (dx == 0) != (dy == 0)
        guard (diagonal && piece.kind != .rook) || (straight && piece.kind != .bishop) else {
          continue
        }
        if clearRay(from, square) { return true }
      }
    }
    return false
  }

  private func clearRay(_ from: Square, _ to: Square) -> Bool {
    let stepX = (to.file - from.file).signum()
    let stepY = (to.rank - from.rank).signum()
    var x = from.file + stepX
    var y = from.rank + stepY
    while x != to.file || y != to.rank {
      if squares[y * 8 + x] != nil { return false }
      x += stepX
      y += stepY
    }
    return true
  }

  func inCheck(_ side: Side) -> Bool {
    guard let king = squares.firstIndex(where: { $0?.color == side && $0?.kind == .king }) else {
      return true
    }
    return attacked(Square(king), by: side.opposite)
  }

  func legalMoves() -> [Move] {
    var moves: [Move] = []
    for index in 0..<64 where squares[index]?.color == turn {
      let from = Square(index)
      for target in 0..<64 where target != index {
        let to = Square(target)
        guard pseudoLegal(from: from, to: to) else { continue }
        if squares[index]?.kind == .pawn && (to.rank == 0 || to.rank == 7) {
          moves += PieceKind.promotions.map { Move(from: from, to: to, promotion: $0) }
        } else {
          moves.append(Move(from: from, to: to))
        }
      }
    }
    for kind in PieceKind.reserve where reserve(turn, kind) > 0 {
      for index in 0..<64 where squares[index] == nil {
        let to = Square(index)
        if kind == .pawn && (to.rank == 0 || to.rank == 7) { continue }
        moves.append(Move(to: to, drop: kind))
      }
    }
    return moves.filter { !applying($0).inCheck(turn) }
  }

  private func pseudoLegal(from: Square, to: Square) -> Bool {
    guard let piece = self[from], self[to]?.color != turn, self[to]?.kind != .king else {
      return false
    }
    let dx = to.file - from.file
    let dy = to.rank - from.rank
    switch piece.kind {
    case .pawn:
      let step = turn == .white ? 1 : -1
      if dx == 0 && self[to] == nil {
        if dy == step { return true }
        if dy == step * 2 && from.rank == (turn == .white ? 1 : 6) {
          return squares[from.index + step * 8] == nil
        }
      }
      if abs(dx) == 1 && dy == step {
        if self[to] != nil { return true }
        if to == enPassant {
          return squares[to.index - step * 8] == Piece(color: turn.opposite, kind: .pawn)
        }
      }
      return false
    case .knight: return abs(dx) * abs(dy) == 2
    case .bishop: return abs(dx) == abs(dy) && clearRay(from, to)
    case .rook: return (dx == 0 || dy == 0) && clearRay(from, to)
    case .queen: return (dx == 0 || dy == 0 || abs(dx) == abs(dy)) && clearRay(from, to)
    case .king:
      if max(abs(dx), abs(dy)) == 1 { return true }
      guard dy == 0, abs(dx) == 2, from.file == 4,
        from.rank == (turn == .white ? 0 : 7), !inCheck(turn)
      else { return false }
      let kingside = dx > 0
      let right = turn == .white ? (kingside ? "K" : "Q") : (kingside ? "k" : "q")
      guard castling.contains(right),
        squares[from.rank * 8 + (kingside ? 7 : 0)] == Piece(color: turn, kind: .rook)
      else { return false }
      let empty = kingside ? [5, 6] : [1, 2, 3]
      guard empty.allSatisfy({ squares[from.rank * 8 + $0] == nil }) else { return false }
      return !attacked(Square(from.index + dx.signum()), by: turn.opposite)
        && !attacked(to, by: turn.opposite)
    }
  }

  private func applying(_ move: Move) -> Self {
    var next = self
    if let kind = move.drop {
      next.squares[move.to.index] = Piece(color: turn, kind: kind)
      next.reserves[turn, default: [:]][kind, default: 0] -= 1
    } else if let from = move.from, let piece = self[from] {
      next.squares[from.index] = nil
      if piece.kind == .pawn, move.to == enPassant, self[move.to] == nil {
        next.squares[move.to.index + (turn == .white ? -8 : 8)] = nil
      }
      if piece.kind == .king && abs(move.to.file - from.file) == 2 {
        let kingside = move.to.file > from.file
        let rook = from.rank * 8 + (kingside ? 7 : 0)
        next.squares[from.rank * 8 + (kingside ? 5 : 3)] = squares[rook]
        next.squares[rook] = nil
      }
      next.squares[move.to.index] =
        move.promotion.map { Piece(color: turn, kind: $0, promoted: true) } ?? piece
    }
    return next
  }
}
