import SwiftUI
import UniformTypeIdentifiers

struct GameView: View {
  @EnvironmentObject private var client: GameClient
  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let room: RoomState
  let game: GameState
  @State private var spectatorBoard = BoardID.a
  @State private var flip = false
  @State private var chatOpen = false
  @State private var movesOpen = false
  @State private var resign = false
  @State private var uci = ""
  @State private var lastRead = 0
  @State private var pass: GameEvent?
  @State private var passProgress: CGFloat = 0
  private var mainBoard: BoardID { client.mySeat?.board ?? spectatorBoard }
  private func orientation(_ board: BoardID) -> Side {
    if let seat = client.mySeat { return board == seat.board ? seat.color : seat.partner.color }
    return flip ? .black : .white
  }
  var body: some View {
    GeometryReader { geometry in
      let wide = geometry.size.width >= 1060
      let landscape = geometry.size.width > geometry.size.height && geometry.size.width > 660
      ScrollView {
        VStack(spacing: 12) {
          gameToolbar(wide: wide)
          let layout =
            landscape
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            : AnyLayout(VStackLayout(spacing: 16))
          layout {
            BoardPane(room: room, game: game, board: mainBoard, orientation: orientation(mainBoard))
              .frame(
                maxWidth: landscape
                  ? min(520, (geometry.size.width - (wide ? 320 : 48)) * 0.56) : 580)
            BoardPane(
              room: room, game: game, board: mainBoard.other,
              orientation: orientation(mainBoard.other), compact: true
            )
            .frame(maxWidth: landscape ? .infinity : 300)
            if wide {
              VStack(spacing: 14) {
                MoveList(moves: game.moves).frame(height: 220)
                ChatPanel().frame(height: 320)
              }.frame(width: 280)
            }
          }.frame(maxWidth: 1360).frame(maxWidth: .infinity, alignment: .top)
          if client.mySeat != nil {
            HStack {
              TextField("Move: e2e4 or N@f3", text: $uci).textFieldStyle(.roundedBorder)
                .autocorrectionDisabled().onSubmit(playTypedMove)
                #if os(iOS)
                  .textInputAutocapitalization(.never)
                #endif
              Button("Play", action: playTypedMove).disabled(!client.online || uci.isEmpty)
            }.frame(maxWidth: 450)
          }
        }.padding(.horizontal, 16).padding(.bottom, 24)
      }
      .overlayPreferenceValue(ArenaAnchorKey.self) { anchors in
        GeometryReader { proxy in passOverlay(anchors: anchors, proxy: proxy) }.allowsHitTesting(
          false)
      }
      .onChange(of: client.chats.count) { _, value in if wide || chatOpen { lastRead = value } }
    }
    .sheet(isPresented: $chatOpen, onDismiss: { lastRead = client.chats.count }) {
      VStack {
        HStack {
          Text("ROOM CHAT").font(BrandFont.display(26))
          Spacer()
          Button("Done") { chatOpen = false }
        }
        ChatPanel()
      }.padding().frame(minWidth: 300, idealWidth: 480, minHeight: 400).presentationDetents([
        .medium, .large,
      ])
    }
    .sheet(isPresented: $movesOpen) {
      VStack {
        Button("Done") { movesOpen = false }
        MoveList(moves: client.game?.moves ?? game.moves)
      }
      .padding().frame(minWidth: 300, idealWidth: 480, minHeight: 400)
    }
    .confirmationDialog("Resign? Your team loses immediately.", isPresented: $resign) {
      Button("Resign match", role: .destructive) { client.send(.resign) }
    }
    .task(id: client.eventSerial) {
      pass = nil
      guard let event = client.lastEvent, event.kind == .pass else { return }
      pass = event
      passProgress = 0
      do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.62)) { passProgress = 1 }
    }
  }

  private func gameToolbar(wide: Bool) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack {
        matchLabel
        Spacer()
        controls(wide: wide)
      }
      VStack(alignment: .leading, spacing: 8) {
        matchLabel
        controls(wide: wide)
      }
    }
  }
  private var matchLabel: some View {
    HStack {
      Text(
        client.mySeat.map { "\($0.team.label) · \(room.timeControl.label)" }
          ?? "LIVE MATCH · \(room.timeControl.label)"
      )
      .font(BrandFont.display(22))
      .foregroundStyle(
        client.mySeat.map { Palette(scheme).team($0.team) } ?? Palette(scheme).accent)
      if client.mySeat == nil {
        Button("Swap boards") { spectatorBoard = spectatorBoard.other }
        Button {
          flip.toggle()
        } label: {
          Image(systemName: "arrow.up.arrow.down")
        }.accessibilityLabel("Flip boards")
      }
    }
  }
  private func controls(wide: Bool) -> some View {
    HStack(spacing: 8) {
      if client.mySeat != nil {
        Menu(drawLabel) {
          Button("Offer draw") { client.send(.draw(.offer)) }
          Button("Accept draw") { client.send(.draw(.accept)) }
            .disabled(!game.drawOffers.contains { $0.team != client.mySeat?.team })
          Button("Decline / withdraw offer") { client.send(.draw(.decline)) }
            .disabled(game.drawOffers.isEmpty)
        }.disabled(!client.online)
        Button("Resign") { resign = true }.disabled(!client.online)
      }
      if !wide {
        Button {
          lastRead = client.chats.count
          chatOpen = true
        } label: {
          Label(
            client.chats.count > lastRead ? "Chat (\(client.chats.count - lastRead))" : "Chat",
            systemImage: "bubble.left.and.bubble.right")
        }
        Button {
          movesOpen = true
        } label: {
          Image(systemName: "list.number")
        }.accessibilityLabel("Move history")
      }
    }.buttonStyle(.bordered).font(BrandFont.body(11))
  }
  private var drawAction: DrawAction {
    guard let seat = client.mySeat else { return .offer }
    if game.drawOffers.contains(seat) { return .decline }
    return game.drawOffers.contains { $0.team != seat.team } ? .accept : .offer
  }
  private var drawLabel: String {
    switch drawAction {
    case .accept: return "Accept draw"
    case .decline: return "Withdraw draw"
    case .offer: return "Offer draw"
    }
  }
  private func playTypedMove() {
    guard let move = Move(uci: uci.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      client.error = "Use coordinates such as e2e4, e7e8q, or N@f3."
      return
    }
    client.submit(move, on: mainBoard)
    uci = ""
  }
  @ViewBuilder
  private func passOverlay(anchors: [String: Anchor<CGRect>], proxy: GeometryProxy) -> some View {
    if let pass, let board = pass.board, let toBoard = pass.toBoard, let color = pass.toColor,
      let kind = pass.captured, let square = pass.move?.to,
      let boardAnchor = anchors["board.\(board.id)"],
      let targetAnchor = anchors["reserve.\(Seat.at(toBoard, color).id)"]
    {
      let rect = proxy[boardAnchor]
      let target = proxy[targetAnchor]
      let white = orientation(board) == .white
      let start = CGPoint(
        x: rect.minX + (CGFloat(white ? square.file : 7 - square.file) + 0.5) * rect.width / 8,
        y: rect.minY + (CGFloat(white ? 7 - square.rank : square.rank) + 0.5) * rect.height / 8)
      PieceGlyph(piece: Piece(color: color, kind: kind))
        .frame(width: 40, height: 40)
        .modifier(
          PassFlight(
            start: start, end: CGPoint(x: target.midX, y: target.midY), progress: passProgress)
        )
        .accessibilityHidden(true)
    }
  }
}

private struct PassFlight: AnimatableModifier {
  let start: CGPoint
  let end: CGPoint
  var progress: CGFloat
  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }
  func body(content: Content) -> some View {
    content.position(
      x: start.x + (end.x - start.x) * progress,
      y: start.y + (end.y - start.y) * progress - sin(progress * .pi) * 70
    )
    .opacity(progress >= 1 ? 0 : 1)
  }
}

struct MoveList: View {
  @Environment(\.colorScheme) private var scheme
  let moves: [MatchMove]
  var body: some View {
    Panel {
      VStack(alignment: .leading, spacing: 10) {
        Text("MOVE HISTORY").font(BrandFont.display(21))
        HStack(alignment: .top, spacing: 14) {
          ForEach(BoardID.allCases) { board in
            VStack(alignment: .leading, spacing: 8) {
              Text("BOARD \(board.label)").font(.custom("Inter-SemiBold", size: 11))
                .foregroundStyle(Palette(scheme).muted)
              ScrollViewReader { proxy in
                ScrollView {
                  LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(moves.filter { $0.board == board }) { move in
                      Text(move.notation).font(
                        .system(size: 12, weight: .medium, design: .monospaced)
                      )
                      .lineLimit(1).minimumScaleFactor(0.7).textSelection(.enabled).id(move.id)
                    }
                  }.frame(maxWidth: .infinity, alignment: .leading)
                }.onChange(of: moves.count) { _, _ in
                  if let last = moves.last(where: { $0.board == board }) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                  }
                }
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    }
  }
}

struct BPGNDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.plainText] }
  var text: String
  init(text: String) { self.text = text }
  init(configuration: ReadConfiguration) throws {
    text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(text.utf8))
  }
}

struct ResultsView: View {
  @EnvironmentObject private var client: GameClient
  @Environment(\.colorScheme) private var scheme
  let room: RoomState
  let game: GameState
  @State private var exporting = false
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        if let result = game.result {
          Panel {
            VStack(alignment: .leading, spacing: 16) {
              HStack {
                ResultMedal(
                  color: result.winner.map { Palette(scheme).team($0) } ?? Palette(scheme).accent,
                  won: result.winner == client.mySeat?.team && result.winner != nil)
                VStack(alignment: .leading, spacing: 5) {
                  Text(headline(result)).font(BrandFont.display(48))
                  Text(
                    "\(result.score) · \(result.reason.rawValue.capitalized)\(result.board.map { " on Board \($0.label)" } ?? "")"
                  )
                  .font(BrandFont.body(13)).foregroundStyle(Palette(scheme).muted)
                }
              }
              HStack(alignment: .top, spacing: 20) {
                ForEach(Team.allCases) { team in
                  VStack(alignment: .leading, spacing: 10) {
                    TeamHeading(team: team)
                    ForEach(room.players.filter { $0.seat?.team == team }) { player in
                      Text("\(player.name)\(player.id == client.playerID ? " · YOU" : "")")
                        .font(BrandFont.body(12))
                    }
                  }.frame(maxWidth: .infinity, alignment: .leading)
                }
              }
              ViewThatFits(in: .horizontal) {
                HStack { resultActions }
                VStack(alignment: .leading) { resultActions }
              }
              Text("A rematch swaps colors on both boards. All seated humans must vote.")
                .font(BrandFont.body(12)).foregroundStyle(Palette(scheme).muted)
            }
          }
        }
        HStack(alignment: .top, spacing: 16) {
          ForEach(BoardID.allCases) { board in
            BoardPane(room: room, game: game, board: board, orientation: .white, compact: true)
          }
        }
        MoveList(moves: game.moves).frame(height: 300)
        if let bpgn = game.bpgn {
          Panel {
            VStack(alignment: .leading, spacing: 10) {
              HStack {
                Text("BPGN").font(BrandFont.display(23))
                Spacer()
                ShareLink(item: bpgn) { Label("Share", systemImage: "square.and.arrow.up") }
                Button("Save") { exporting = true }
              }
              ScrollView {
                Text(bpgn).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .frame(height: 180)
            }
          }
        }
        ChatPanel().frame(height: 330)
      }.padding(20).frame(maxWidth: 1000).frame(maxWidth: .infinity)
    }
    .fileExporter(
      isPresented: $exporting, document: BPGNDocument(text: game.bpgn ?? ""),
      contentType: .plainText,
      defaultFilename: "Swapmate-\(room.code).bpgn"
    ) { result in
      if case .failure(let error) = result {
        client.error = "Export failed: \(error.localizedDescription)"
      }
    }
  }
  @ViewBuilder private var resultActions: some View {
    if client.mySeat != nil {
      let voted = room.rematchVotes.contains(client.playerID ?? "")
      let humans = room.players.filter { !$0.bot }.count
      Button(
        voted
          ? "Waiting (\(room.rematchVotes.count)/\(humans))"
          : "Rematch (\(room.rematchVotes.count)/\(humans))"
      ) {
        client.send(.rematch)
      }.buttonStyle(ArcadeButtonStyle(primary: true)).disabled(voted || !client.online)
    }
    Button("Copy BPGN") {
      NativeClipboard.copy(game.bpgn ?? "")
      client.notice = "BPGN copied."
    }.disabled(game.bpgn == nil)
    Button("Leave room") { client.send(.leave) }.disabled(!client.online)
  }
  private func headline(_ result: MatchResult) -> String {
    guard let winner = result.winner else { return "DRAW." }
    guard let team = client.mySeat?.team else { return "\(winner.label) WINS." }
    return winner == team ? "VICTORY." : "DEFEAT."
  }
}
