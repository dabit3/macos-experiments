import SwiftUI

struct ArenaAnchorKey: PreferenceKey {
  static var defaultValue: [String: Anchor<CGRect>] = [:]
  static func reduce(
    value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]
  ) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

struct BoardPane: View {
  @EnvironmentObject private var client: GameClient
  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let room: RoomState
  let game: GameState
  let board: BoardID
  let orientation: Side
  var compact = false
  @State private var selected: Square?
  @State private var reserve: PieceKind?
  @State private var targets: Set<Square> = []
  @State private var promotion: Move?
  @State private var dragging: Square?
  @State private var dragPoint: CGPoint?
  @State private var movingPiece: Piece?
  @State private var motion: CGFloat = 1
  private var snapshot: BoardSnapshot { game.boards[board] }
  private var position: Position? { try? Position(fen: snapshot.fen) }
  private var interactive: Bool {
    client.mySeat?.board == board && game.result == nil && client.online
  }
  private var myTurn: Bool { position?.turn == client.mySeat?.color }
  private var premove: Move? { client.mySeat?.board == board ? game.premove : nil }

  var body: some View {
    VStack(spacing: 6) {
      HStack {
        Text("BOARD \(board.label)").font(BrandFont.display(compact ? 18 : 23))
        Text(
          client.mySeat?.board == board ? "YOU" : client.mySeat == nil ? "SPECTATING" : "PARTNER"
        )
        .font(BrandFont.body(9)).tracking(1)
        .foregroundStyle(Palette(scheme).muted)
        Spacer()
        if snapshot.inCheck {
          Text("CHECK").font(.caption.bold()).foregroundStyle(Palette(scheme).danger)
        }
      }
      playerBar(orientation.opposite)
      reserveTray(orientation.opposite)
      boardSurface
      reserveTray(orientation)
      playerBar(orientation)
      if let premove {
        Button("Cancel \(premove.drop == nil ? "premove" : "pre-drop"): \(premove.uci)") {
          clearSelection()
          client.cancelPremove()
        }.font(BrandFont.body(11)).buttonStyle(.borderless)
      } else if interactive {
        Text(myTurn ? "Your move · tap or drag a piece" : "Waiting · queue a premove or pre-drop")
          .font(BrandFont.body(10)).foregroundStyle(Palette(scheme).muted)
      }
    }
    .confirmationDialog(
      "Promote pawn to",
      isPresented: Binding(get: { promotion != nil }, set: { if !$0 { promotion = nil } })
    ) {
      ForEach(PieceKind.promotions) { kind in
        Button(kind.label) {
          if var move = promotion {
            move.promotion = kind
            submit(move)
            promotion = nil
          }
        }
      }
      Button("Cancel", role: .cancel) {
        promotion = nil
        clearSelection()
      }
    }
    .onChange(of: snapshot.fen) { _, _ in clearSelection() }
    .onChange(of: client.online) { _, _ in clearSelection() }
    .onChange(of: client.selectionSerial) { _, _ in clearSelection() }
    .onChange(of: game.result?.reason) { _, _ in clearSelection() }
    .task(id: snapshot.fen) {
      movingPiece = nil
      motion = 1
      guard !reduceMotion, let move = snapshot.lastMove, move.from != nil else { return }
      movingPiece = position?[move.to]
      motion = 0
      do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
      withAnimation(.easeOut(duration: 0.18)) { motion = 1 }
      do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
      movingPiece = nil
    }
  }

  private func playerBar(_ side: Side) -> some View {
    let seat = Seat.at(board, side)
    let player = room.seated(seat)
    return HStack(spacing: 8) {
      Circle().fill(Palette(scheme).team(seat.team)).frame(width: 7, height: 7)
      Text(player?.name ?? "Empty").lineLimit(1).font(
        .custom("Inter-SemiBold", size: compact ? 10 : 12))
      if player?.bot == true { Image(systemName: "cpu").font(.caption2) }
      if player?.connected == false {
        Image(systemName: "wifi.slash").foregroundStyle(Palette(scheme).danger)
      }
      Spacer(minLength: 0)
      ClockView(clock: snapshot.clock, side: side, sampledAt: game.serverTime, compact: compact)
    }.padding(8).background(Palette(scheme).sunken, in: RoundedRectangle(cornerRadius: 8))
  }

  private func reserveTray(_ side: Side) -> some View {
    let seat = Seat.at(board, side)
    let enabled = interactive && seat == client.mySeat
    return HStack(spacing: 4) {
      ForEach(PieceKind.reserve) { kind in
        let count = position?.reserve(side, kind) ?? 0
        Button {
          if reserve == kind {
            clearSelection()
          } else {
            selected = nil
            reserve = kind
            refreshTargets()
          }
        } label: {
          HStack(spacing: 1) {
            PieceGlyph(piece: Piece(color: side, kind: kind)).frame(
              width: compact ? 18 : 25, height: compact ? 22 : 30)
            Text("\(count)").font(.system(size: compact ? 10 : 12, weight: .bold, design: .rounded))
          }.frame(maxWidth: .infinity).padding(.vertical, 3)
            .background(
              reserve == kind && enabled
                ? Palette(scheme).accent.opacity(0.4) : Palette(scheme).raised,
              in: RoundedRectangle(cornerRadius: 6)
            )
            .opacity(count > 0 || (enabled && !myTurn) ? 1 : 0.45)
        }.buttonStyle(.plain)
          .disabled(!enabled || (myTurn && count == 0))
          .draggable("reserve:\(seat.id):\(kind.rawValue)")
          .accessibilityLabel(
            "\(side.label) reserve \(kind.label), \(count). \(enabled && !myTurn ? "Queue pre-drop" : "Select to drop")"
          )
      }
    }.anchorPreference(key: ArenaAnchorKey.self, value: .bounds) { ["reserve.\(seat.id)": $0] }
  }

  private var boardSurface: some View {
    GeometryReader { geometry in
      let size = geometry.size.width
      let cell = size / 8
      ZStack(alignment: .topLeading) {
        ForEach(0..<64, id: \.self) { index in
          let square = Square(index)
          let point = center(square, size: size)
          ZStack {
            Rectangle().fill(squareColor(square))
            if premove?.from == square || premove?.to == square { Color.blue.opacity(0.4) }
            if selected == square { Palette(scheme).accent.opacity(0.65) }
            if let piece = position?[square], dragging != square,
              movingPiece == nil || snapshot.lastMove?.to != square
            {
              PieceGlyph(piece: piece).padding(cell * 0.025)
              if piece.promoted {
                Text("~").font(.system(size: cell * 0.22, weight: .bold)).foregroundStyle(
                  Color(hex: 0x173D3C)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(
                  2)
              }
            }
            if targets.contains(square) {
              if position?[square] == nil {
                Circle().fill(.black.opacity(0.25)).frame(width: cell * 0.24, height: cell * 0.24)
              } else {
                Circle().stroke(.black.opacity(0.3), lineWidth: cell * 0.07).padding(2)
              }
            }
            coordinates(square, cell: cell)
          }.frame(width: cell, height: cell).position(point)
            .contentShape(Rectangle())
            .onTapGesture { tap(square) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
              "\(square.description), \(pieceLabel(square))\(targets.contains(square) ? ", legal target" : "")"
            )
            .accessibilityAddTraits(interactive ? .isButton : [])
            .accessibilityAction { tap(square) }
        }
        if let dragging, let piece = position?[dragging], let dragPoint {
          PieceGlyph(piece: piece).frame(width: cell * 1.15, height: cell * 1.15).position(
            dragPoint
          )
          .shadow(radius: 5).allowsHitTesting(false)
        }
        if let movingPiece, let move = snapshot.lastMove, let from = move.from {
          let start = center(from, size: size)
          let end = center(move.to, size: size)
          PieceGlyph(piece: movingPiece).frame(width: cell, height: cell)
            .position(
              x: start.x + (end.x - start.x) * motion, y: start.y + (end.y - start.y) * motion
            )
            .allowsHitTesting(false).accessibilityHidden(true)
        }
      }
      .coordinateSpace(name: "board-\(board.id)")
      .gesture(
        DragGesture(minimumDistance: 8, coordinateSpace: .named("board-\(board.id)"))
          .onChanged { value in
            guard interactive else { return }
            if dragging == nil, let square = square(at: value.startLocation, size: size),
              position?[square]?.color == client.mySeat?.color
            {
              dragging = square
              selected = square
              reserve = nil
              refreshTargets()
            }
            if dragging != nil { dragPoint = value.location }
          }
          .onEnded { value in
            defer {
              dragging = nil
              dragPoint = nil
            }
            guard let from = dragging, let to = square(at: value.location, size: size), from != to
            else { return }
            tryMove(from, to)
          }
      )
      .dropDestination(for: String.self) { items, point in
        guard interactive, let value = items.first, let to = square(at: point, size: size) else {
          return false
        }
        let parts = value.split(separator: ":")
        guard let seat = client.mySeat, parts.count == 3, parts[0] == "reserve",
          parts[1] == seat.rawValue,
          let kind = PieceKind(rawValue: String(parts[2])), position?[to] == nil
        else { return false }
        submit(Move(to: to, drop: kind))
        return true
      }
      .anchorPreference(key: ArenaAnchorKey.self, value: .bounds) { ["board.\(board.id)": $0] }
    }
    .aspectRatio(1, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0x203F45), lineWidth: 3))
  }

  private func coordinates(_ square: Square, cell: CGFloat) -> some View {
    let bottom = square.rank == (orientation == .white ? 0 : 7)
    let left = square.file == (orientation == .white ? 0 : 7)
    return ZStack {
      if bottom {
        Text(String(Array("abcdefgh")[square.file])).frame(
          maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      }
      if left {
        Text("\(square.rank + 1)").frame(
          maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
    }.font(.system(size: max(7, cell * 0.16), weight: .bold)).padding(3)
      .foregroundStyle(Color(hex: 0x173D3C).opacity(0.8)).allowsHitTesting(false)
      .accessibilityHidden(true)
  }

  private func squareColor(_ square: Square) -> Color {
    if snapshot.inCheck, let piece = position?[square], piece.kind == .king,
      piece.color == position?.turn
    {
      return Palette(scheme).danger.opacity(0.8)
    }
    if snapshot.lastMove?.from == square || snapshot.lastMove?.to == square {
      return Color(hex: 0xC8D66E)
    }
    return (square.file + square.rank).isMultiple(of: 2)
      ? Palette(scheme).boardDark : Palette(scheme).boardLight
  }
  private func pieceLabel(_ square: Square) -> String {
    guard let piece = position?[square] else { return "empty" }
    return "\(piece.color.label) \(piece.kind.label)"
  }
  private func center(_ square: Square, size: CGFloat) -> CGPoint {
    CGPoint(
      x: (CGFloat(orientation == .white ? square.file : 7 - square.file) + 0.5) * size / 8,
      y: (CGFloat(orientation == .white ? 7 - square.rank : square.rank) + 0.5) * size / 8)
  }
  private func square(at point: CGPoint, size: CGFloat) -> Square? {
    guard size > 0, point.x >= 0, point.x < size, point.y >= 0, point.y < size else { return nil }
    let x = Int(point.x / (size / 8))
    let y = Int(point.y / (size / 8))
    return Square((orientation == .white ? 7 - y : y) * 8 + (orientation == .white ? x : 7 - x))
  }
  private func clearSelection() {
    selected = nil
    reserve = nil
    targets = []
    dragging = nil
    dragPoint = nil
  }
  private func refreshTargets() {
    guard myTurn, let position else {
      targets = []
      return
    }
    targets = Set(
      position.legalMoves().filter { move in
        if let reserve { return move.drop == reserve }
        return move.from == selected && move.drop == nil
      }.map(\.to))
  }
  private func tap(_ square: Square) {
    guard interactive else { return }
    if let reserve, position?[square] == nil {
      submit(Move(to: square, drop: reserve))
      return
    }
    if selected == square {
      clearSelection()
      return
    }
    if position?[square]?.color == client.mySeat?.color {
      selected = square
      reserve = nil
      refreshTargets()
      return
    }
    if let from = selected { tryMove(from, square) }
  }
  private func tryMove(_ from: Square, _ to: Square) {
    guard interactive else { return }
    if position?[from]?.kind == .pawn && (to.rank == 0 || to.rank == 7) {
      if myTurn && !targets.contains(to) {
        client.error = "Illegal move."
        clearSelection()
        return
      }
      promotion = Move(from: from, to: to)
    } else {
      submit(Move(from: from, to: to))
    }
  }
  private func submit(_ move: Move) {
    client.submit(move, on: board)
    clearSelection()
  }
}

struct ClockView: View {
  @EnvironmentObject private var client: GameClient
  @Environment(\.colorScheme) private var scheme
  let clock: BoardClock
  let side: Side
  let sampledAt: Int64
  let compact: Bool
  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.1)) { _ in
      let remaining = clock.remaining(side, sampledAt: sampledAt, now: client.serverNow)
      let seconds = (remaining + 999) / 1000
      let value =
        remaining < 10_000
        ? String(format: "%d.%d", remaining / 1000, (remaining % 1000) / 100)
        : String(format: "%d:%02d", seconds / 60, seconds % 60)
      Text(value).font(.system(size: compact ? 17 : 23, weight: .bold, design: .monospaced))
        .foregroundStyle(remaining < 10_000 ? Palette(scheme).danger : Palette(scheme).text)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(
          clock.running == side ? Palette(scheme).accent.opacity(0.2) : .clear,
          in: RoundedRectangle(cornerRadius: 6)
        )
        .accessibilityLabel("\(side.label) clock \(value)")
    }
  }
}
