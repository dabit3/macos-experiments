import CourtCore
import SwiftUI

struct ChessBoard: View {
    @ObservedObject var store: CourtStore
    @State private var dragging: Int?
    @State private var dragPoint = CGPoint.zero
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var position: Position {
        store.displayedPosition
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height), cell = size / 8
            ZStack(alignment: .topLeading) {
                ForEach(0 ..< 64, id: \.self) { square in
                    squareView(square, cell: cell)
                        .position(center(square, cell: cell))
                        .onTapGesture { focused = true; store.tap(square) }
                        .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .named("board"))
                            .onChanged { value in
                                guard store.canInteract, position.board[square]?.side == store.mySide else { return }
                                focused = true; dragging = square; dragPoint = value.location
                            }
                            .onEnded { value in
                                defer { dragging = nil }
                                guard dragging != nil,
                                      let to = Square.hit(x: value.location.x, y: value.location.y, size: size, orientation: store.orientation) else { return }
                                store.request(from: square, to: to)
                            })
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibility(square))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { store.tap(square) }
                }
                if let dragging, let piece = position.board[dragging] {
                    PieceGlyph(piece: piece).frame(width: cell * 1.12, height: cell * 1.12)
                        .position(dragPoint).shadow(color: .black.opacity(0.4), radius: 8, y: 6)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "board")
            .frame(width: size, height: size)
            .clipped()
            .focusable().focused($focused)
            .onKeyPress(.leftArrow) { store.step(-1); return .handled }
            .onKeyPress(.rightArrow) { store.step(1); return .handled }
            .onKeyPress(.upArrow) { store.view(0); return .handled }
            .onKeyPress(.downArrow) { store.view(nil); return .handled }
            .onKeyPress(.home) { store.view(0); return .handled }
            .onKeyPress(.end) { store.view(nil); return .handled }
            .onKeyPress(.escape) { store.cancelInput(); return .handled }
            .onKeyPress("f") { store.flipped.toggle(); return .handled }
            .onChange(of: store.room?.code) { _, _ in dragging = nil }
            .onChange(of: store.orientation) { _, _ in dragging = nil }
            .onChange(of: store.canInteract) {
                _, allowed in if !allowed {
                    dragging = nil
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(8)
        .background(Color(hex: 0x223B73), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: 0x506698), lineWidth: 2))
        .shadow(color: Arcade.midnight.opacity(0.3), radius: 16, y: 8)
    }

    private func center(_ square: Int, cell: CGFloat) -> CGPoint {
        let file = square % 8, rank = square / 8
        return CGPoint(x: (CGFloat(store.orientation == .white ? file : 7 - file) + 0.5) * cell,
                       y: (CGFloat(store.orientation == .white ? 7 - rank : rank) + 0.5) * cell)
    }

    private func accessibility(_ square: Int) -> String {
        let piece = position.board[square]
        var label = Square.name(square) + ", " + (piece.map { "\($0.side.label) \($0.kind.label)" } ?? "empty")
        if store.selected == square {
            label += ", selected"
        }
        if store.legalTargets.contains(square) {
            label += ", legal destination"
        }
        return label
    }

    private func squareView(_ square: Int, cell: CGFloat) -> some View {
        let piece = position.board[square]
        let file = square % 8, rank = square / 8
        let dark = (file + rank) % 2 == 0
        let leftEdge = store.orientation == .white ? file == 0 : file == 7
        let bottomEdge = store.orientation == .white ? rank == 0 : rank == 7
        return ZStack {
            dark ? Color(hex: 0x6581BA) : Color(hex: 0xE4EAF8)
            if store.lastMove?.from == square || store.lastMove?.to == square {
                Arcade.sunshine.opacity(0.65)
            }
            if store.premove?.from == square || store.premove?.to == square {
                Arcade.aqua.opacity(0.6)
            }
            if store.selected == square {
                Arcade.sunshine.opacity(0.85)
            }
            if piece?.kind == .king, let piece, position.inCheck(piece.side) {
                RadialGradient(colors: [Color.red.opacity(0.9), .clear], center: .center, startRadius: 0, endRadius: cell * 0.7)
            }
            if let piece {
                PieceGlyph(piece: piece).padding(2).opacity(dragging == square ? 0.2 : 1)
                    .transition(reduceMotion ? .identity : .opacity)
            }
            if store.legalTargets.contains(square) {
                if piece == nil {
                    Circle().fill(Arcade.midnight.opacity(0.45)).frame(width: cell * 0.23)
                } else {
                    Circle().strokeBorder(Arcade.midnight.opacity(0.45), lineWidth: cell * 0.07).padding(3)
                }
            }
            VStack {
                HStack {
                    if leftEdge {
                        Text(String(rank + 1))
                    }
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    if bottomEdge {
                        Text(String(Array("abcdefgh")[file]))
                    }
                }
            }
            .font(Arcade.mono(max(8, min(13, cell * 0.18))))
            .foregroundStyle(dark ? Color(hex: 0xE4EAF8) : Color(hex: 0x223B73))
            .padding(3)
        }
        .frame(width: cell, height: cell)
        .contentShape(Rectangle())
    }
}
