import CourtCore
import SwiftUI

struct GameScreen: View {
    @ObservedObject var store: CourtStore
    let wide: Bool
    let availableHeight: CGFloat
    let export: () -> Void
    @State private var confirm: Intent?
    private var playing: Bool {
        store.room?.status == .playing && store.review == nil
    }

    private var actionsEnabled: Bool {
        store.ready && !store.busy
    }

    var body: some View {
        VStack(spacing: 18) {
            header
            if wide {
                HStack(alignment: .top, spacing: 24) {
                    boardColumn.frame(maxWidth: max(300, min(760, availableHeight - 130)))
                    sidebar.frame(minWidth: 245, maxWidth: 330)
                }
            } else {
                boardColumn
                sidebar
            }
        }
        .frame(maxWidth: 1180).frame(maxWidth: .infinity)
        .confirmationDialog(confirm == .resign ? "Resign this game?" : "Leave this room? Leaving an active game resigns your seat.",
                            isPresented: Binding(get: { confirm != nil }, set: {
                                if !$0 {
                                    confirm = nil
                                }
                            }), titleVisibility: .visible) {
            Button(confirm == .resign ? "Resign" : "Leave room", role: .destructive) {
                if let action = confirm {
                    store.action(action)
                }; confirm = nil
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.review != nil ? "THE REPLAY" : store.room?.status == .waiting ? "YOUR COURT AWAITS" : "GAME ON").font(Arcade.display(wide ? 25 : 20))
                if let room = store.room, store.review == nil {
                    Text("\(room.timeControl.category) · \(room.timeControl.label) · \(store.mySide == nil ? "Spectating" : "Playing \(store.mySide!.label)")").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("PGN review · \(store.moves.count) plies").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if store.review != nil {
                Button("Close review") { store.closeReview() }.buttonStyle(CourtButtonStyle())
            } else {
                Button {
                    if playing, store.mySide != nil {
                        confirm = .leaveRoom
                    } else {
                        store.action(.leaveRoom)
                    }
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }.buttonStyle(CourtButtonStyle()).accessibilityLabel("Leave room").disabled(!actionsEnabled)
            }
        }
    }

    private var boardColumn: some View {
        VStack(spacing: 12) {
            player(store.orientation.opposite)
            ChessBoard(store: store)
                .overlay {
                    if store.room?.status == .waiting, store.review == nil {
                        waitingOverlay.padding(28)
                    } else if let result = store.room?.result, !store.resultsDismissed, store.review == nil {
                        resultOverlay(result).padding(24)
                    }
                }
            player(store.orientation)
            HStack {
                Text(boardStatus).font(Arcade.mono(12)).foregroundStyle(store.premove == nil ? .secondary : Arcade.aqua)
                Spacer()
                if store.premove != nil {
                    Button("Cancel") { store.cancelInput() }
                }
                Button { store.flipped.toggle() } label: { Image(systemName: "arrow.triangle.2.circlepath") }.accessibilityLabel("Flip board")
            }
            .buttonStyle(.borderless)
        }
    }

    private var boardStatus: String {
        if store.review != nil {
            return "Review · ply \(store.displayedPly)"
        }
        if store.viewPly != nil {
            return "History · ply \(store.displayedPly)"
        }
        if store.premove != nil {
            return "Premove queued"
        }
        if store.busy {
            return "Waiting for server…"
        }
        if !store.ready {
            return "Reconnecting to the court…"
        }
        if store.room?.status == .finished {
            return store.room?.result?.description ?? "Game finished"
        }
        if store.myTurn {
            return store.position.inCheck ? "Check · your move" : "Your move"
        }
        return store.mySide == nil ? "\(store.position.turn.label) to move" : "Opponent’s move · premove available"
    }

    private func player(_ side: Side) -> some View {
        let participant = store.room?.player(side)
        let name = store.review?.tags[side == .white ? "White" : "Black"] ?? participant?.name ?? "Open seat"
        let running = store.review == nil && store.room?.clocks.running == side && playing
        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(side == .white ? Color(hex: 0xE5EAF8) : Arcade.royal)
                if participant?.isBot == true {
                    Image(systemName: "cpu").foregroundStyle(side == .white ? Arcade.midnight : .white)
                } else {
                    Text(String(name.prefix(1)).uppercased()).font(Arcade.display(20)).foregroundStyle(side == .white ? Arcade.midnight : .white)
                }
            }.frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.custom("Manrope-Bold", size: 15)).lineLimit(1)
                Text("\(side.label)\(participant?.clientId == store.clientId ? " · You" : "")\(participant?.isBot == true ? " · Bot \(participant?.botLevel ?? 1)" : participant?.connected == false ? " · Reconnecting" : "")")
                    .font(.caption).foregroundStyle(.secondary)
                capturedMaterial(side)
            }
            Spacer(minLength: 4)
            if store.review == nil {
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    let remaining = store.clock(side, at: context.date)
                    Text(store.room?.timeControl.isUnlimited == true ? "∞" : ClockState.format(remaining))
                        .font(Arcade.mono(wide ? 30 : 26)).monospacedDigit()
                        .foregroundStyle(remaining < 20000 && store.room?.timeControl.isUnlimited == false ? Color.red : running ? Arcade.midnight : Arcade.porcelain)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(running ? Arcade.sunshine : Color(hex: 0x1B2B53), in: RoundedRectangle(cornerRadius: 10))
                        .onChange(of: Int(remaining / 1000)) { _, _ in store.checkLowTime() }
                        .accessibilityLabel("\(side.label) clock \(ClockState.format(remaining))")
                }
            }
        }
    }

    private func capturedMaterial(_ side: Side) -> some View {
        let start = (try? Position(fen: store.startFen)) ?? .initial
        let current = store.displayedPosition
        let captured = [PieceKind.queen, .rook, .bishop, .knight, .pawn].flatMap { kind in
            let original = start.board.compactMap { $0 }.filter { $0.side == side.opposite && $0.kind == kind }.count
            let remaining = current.board.compactMap { $0 }.filter { $0.side == side.opposite && $0.kind == kind }.count
            return Array(repeating: kind, count: max(0, original - remaining))
        }
        let lead = current.board.compactMap { $0 }.reduce(0) { $0 + ($1.side == side ? $1.kind.value : -$1.kind.value) }
        return HStack(spacing: -6) {
            ForEach(Array(captured.enumerated()), id: \.offset) { _, kind in
                PieceGlyph(piece: Piece(side.opposite, kind)).frame(width: 19, height: 19)
            }
            if lead > 0 {
                Text("+\(lead)").font(Arcade.mono(10)).padding(.leading, 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Captured \(captured.map(\.label).joined(separator: ", ")). Material advantage \(max(0, lead))")
    }

    private var waitingOverlay: some View {
        VStack(spacing: 14) {
            Crown().fill(Arcade.sunshine).frame(width: 55, height: 55)
            Text("SAVE A SEAT").font(Arcade.display(23))
            Text("Share this code with a rival.").font(.caption)
            Button { Launch.copy(store.room?.code ?? "") } label: {
                Label(store.room?.code ?? "", systemImage: "doc.on.doc").font(Arcade.mono(27))
            }.buttonStyle(.plain)
            if store.room?.hostClientId == store.clientId {
                Button("Add a bot · level \(store.botLevel)") { store.action(.addBot) }
                    .buttonStyle(CourtButtonStyle(primary: true)).disabled(!actionsEnabled)
            }
        }
        .padding(22).frame(maxWidth: 300).foregroundStyle(.white)
        .background(Arcade.midnight.opacity(0.96), in: RoundedRectangle(cornerRadius: 22))
    }

    private func resultOverlay(_ result: GameResult) -> some View {
        VStack(spacing: 14) {
            Crown().fill(Arcade.sunshine).frame(width: 50, height: 50)
            Text(result.outcome == .draw ? "HONORS EVEN" : result.winner == store.mySide ? "VICTORY!" : "GAME OVER").font(Arcade.display(26))
            Text(result.description).multilineTextAlignment(.center)
            Text(result.score).font(Arcade.mono(24)).foregroundStyle(Arcade.sunshine)
            if store.mySide != nil {
                if store.room?.offers.rematch == store.mySide?.opposite {
                    Button("Accept rematch") { store.action(.acceptRematch) }.buttonStyle(CourtButtonStyle(primary: true)).disabled(!actionsEnabled)
                } else {
                    Button(store.room?.offers.rematch == store.mySide ? "Rematch offered" : "Play again") { store.action(.offerRematch) }
                        .buttonStyle(CourtButtonStyle(primary: true)).disabled(!actionsEnabled || store.room?.offers.rematch == store.mySide)
                }
            }
            Button("Review board") { store.resultsDismissed = true }.foregroundStyle(.white)
        }
        .padding(22).frame(maxWidth: 310).foregroundStyle(.white)
        .background(Arcade.midnight.opacity(0.97), in: RoundedRectangle(cornerRadius: 22))
    }

    private var sidebar: some View {
        VStack(spacing: 18) {
            if let room = store.room, store.review == nil {
                CourtCard {
                    HStack {
                        Text("COURT \(room.code)").font(Arcade.mono(14)).bold()
                        Spacer()
                        Button { Launch.copy(room.code) } label: { Image(systemName: "doc.on.doc") }.accessibilityLabel("Copy room code")
                    }
                    Label("\(room.spectators.count) watching", systemImage: "eye").font(.caption).foregroundStyle(.secondary)
                    if !room.spectators.isEmpty {
                        Text(room.spectators.map(\.name).joined(separator: ", ")).font(.caption)
                    }
                    if let result = room.result {
                        Text(result.description).bold()
                    }
                    if store.mySide != nil {
                        gameActions
                    }
                    if !store.ready {
                        Text("Your seat is held during the server’s reconnect grace period.").font(.caption)
                        Button("Reconnect") { store.connect() }
                    }
                }
            }
            CourtCard {
                HStack { Text("THE PLAYBOOK").font(Arcade.display(18)); Spacer(); Button(action: export) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Export PGN") }
                moveList
                HStack {
                    Button { store.view(0) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("First position")
                    Button { store.step(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous move")
                    Spacer()
                    Button(store.review != nil ? "End" : "Live") { store.view(nil) }
                    Spacer()
                    Button { store.step(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next move")
                    Button { store.view(nil) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("Last position")
                }.buttonStyle(.borderless)
            }
        }
    }

    private var gameActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            offer(store.room?.offers.draw, label: "Draw", accept: .acceptDraw, decline: .declineDraw)
            offer(store.room?.offers.takeback, label: "Takeback", accept: .acceptTakeback, decline: .declineTakeback)
            offer(store.room?.offers.rematch, label: "Rematch", accept: .acceptRematch, decline: .declineRematch)
            if playing {
                HStack {
                    Button("Draw") { store.action(.offerDraw) }.disabled(!actionsEnabled || store.room?.offers.draw != nil)
                    Button("Takeback") { store.action(.offerTakeback) }.disabled(!actionsEnabled || store.moves.isEmpty || store.room?.offers.takeback != nil)
                }.buttonStyle(CourtButtonStyle())
                Button("Resign", role: .destructive) { confirm = .resign }.disabled(!actionsEnabled)
            } else if store.room?.status == .finished, store.room?.offers.rematch == nil {
                Button("Rematch") { store.action(.offerRematch) }.buttonStyle(CourtButtonStyle(primary: true)).disabled(!actionsEnabled)
            }
        }
    }

    @ViewBuilder private func offer(_ side: Side?, label: String, accept: Intent, decline: Intent) -> some View {
        if let side {
            if side == store.mySide {
                Text("\(label) offered · awaiting reply").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("\(label) offered").bold()
                HStack {
                    Button("Accept") { store.action(accept) }.buttonStyle(CourtButtonStyle(primary: true))
                    Button("Decline") { store.action(decline) }.buttonStyle(CourtButtonStyle())
                }.disabled(!actionsEnabled)
            }
        }
    }

    private var moveList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if store.moves.isEmpty {
                    Text("Your story starts with a move.").foregroundStyle(.secondary).padding(.vertical, 24)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                    ForEach(Array(store.moves.enumerated()), id: \.offset) { index, move in
                        Button { store.view(index + 1) } label: {
                            HStack(spacing: 6) {
                                Text(movePrefix(index)).foregroundStyle(.secondary)
                                Text(move.san).bold(); Spacer(minLength: 0)
                            }
                            .font(Arcade.mono(13)).padding(8)
                            .background(store.displayedPly == index + 1 ? Arcade.sunshine.opacity(0.7) : .clear, in: RoundedRectangle(cornerRadius: 7))
                            .foregroundStyle(store.displayedPly == index + 1 ? Arcade.midnight : .primary)
                        }.buttonStyle(.plain).id(index + 1)
                    }
                }
            }
            .frame(height: wide ? 250 : 150)
            .onChange(of: store.displayedPly) { _, ply in proxy.scrollTo(ply, anchor: .center) }
        }
    }

    private func movePrefix(_ index: Int) -> String {
        let start = (try? Position(fen: store.startFen)) ?? .initial
        let offset = index + (start.turn == .black ? 1 : 0)
        return "\(start.fullmove + offset / 2)\(offset % 2 == 0 ? "." : "...")"
    }
}
