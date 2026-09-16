import SwiftUI
import UIKit

struct BoardView: View {
  @EnvironmentObject private var store: GameStore
  @State private var showBingo = false
  @State private var showShare = false
  @State private var shareImage: UIImage?
  @State private var boardFlip = false
  @State private var tileBounce: Set<Int> = []

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 5)

  var body: some View {
    ZStack {
      CircuitBackground()
      VStack(spacing: 10) {
        header
        bingoLetters
        board
        footer
      }
      .padding(.horizontal, 14)
      .padding(.top, 6)
      if showBingo {
        ConfettiView()
        bingoOverlay
      }
    }
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $showShare) {
      if let shareImage {
        ShareSheet(items: [shareImage])
      }
    }
  }

  private var header: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(store.currentPlayer.name.uppercased())
          .font(.system(size: 14, weight: .black))
          .tracking(1)
          .foregroundStyle(Theme.green)
        Label("\(store.currentPlayer.wins) wins", systemImage: "trophy.fill")
          .font(.system(size: 11, weight: .bold, design: .monospaced))
          .foregroundStyle(Theme.muted)
      }
      Spacer()
      Text("ROUND \(store.state.totalRounds)")
        .font(.monoStat(12))
        .foregroundStyle(.white)
      Menu {
        Button("New Card", systemImage: "arrow.clockwise") { store.newCard() }
        Button("Share", systemImage: "square.and.arrow.up") { share() }
        NavigationLink("Players", destination: ScoreboardView())
      } label: {
        Image(systemName: "ellipsis.circle")
          .font(.system(size: 24, weight: .bold))
          .foregroundStyle(Theme.green)
      }
    }
  }

  private var bingoLetters: some View {
    HStack {
      ForEach(["B", "I", "N", "G", "O"], id: \.self) {
        Text($0).frame(maxWidth: .infinity)
      }
    }
    .font(.system(size: 13, weight: .black))
    .foregroundStyle(Theme.green)
    .tracking(2)
  }

  private var board: some View {
    LazyVGrid(columns: columns, spacing: 7) {
      ForEach(store.currentPlayer.card.cells.indices, id: \.self) { index in
        TileView(
          text: store.currentPlayer.card.cells[index],
          isMarked: store.currentPlayer.card.marked.contains(index),
          isCenter: index == 12,
          isOneAway: store.currentPlayer.card.wouldCompleteLine(byMarking: index),
          bounce: tileBounce.contains(index)
        ) {
          guard index != 12 else { return }
          let result = store.toggleCurrent(index)
          _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            tileBounce.insert(index)
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            tileBounce.remove(index)
          }
          if result.bingo {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showBingo = true }
          }
        }
        .rotation3DEffect(
          .degrees(boardFlip ? 0 : 0),
          axis: (x: 0, y: 1, z: 0)
        )
      }
    }
    .animation(.easeInOut(duration: 0.35), value: store.currentPlayer.card.marked)
  }

  private var footer: some View {
    VStack(spacing: 12) {
      Text(
        "\(max(0, store.currentPlayer.card.markedCount - 1)) / 24 MARKED  ·  \(store.currentPlayer.card.completedLines.count) LINES"
      )
      .font(.monoStat(12))
      .foregroundStyle(Theme.muted)
      if store.state.players.count > 1 {
        Button {
          withAnimation(.easeInOut(duration: 0.35)) {
            boardFlip.toggle()
            store.passToNextPlayer()
          }
        } label: {
          Label("PASS TO NEXT PLAYER", systemImage: "arrow.right.arrow.left")
        }
        .buttonStyle(GlowButtonStyle())
      }
    }
  }

  private var bingoOverlay: some View {
    VStack(spacing: 16) {
      Text("BINGO!")
        .font(.system(size: 54, weight: .black))
        .tracking(3)
        .foregroundStyle(Theme.green)
        .neonGlow(radius: 18)
      Text("+1 WIN RECORDED FOR \(store.currentPlayer.name.uppercased())")
        .font(.system(size: 12, weight: .black, design: .monospaced))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
      Button("SHARE CARD") { share() }
        .buttonStyle(GlowButtonStyle(filled: true))
      Button("NEW CARD") {
        store.newCard()
        showBingo = false
      }
      .buttonStyle(GlowButtonStyle())
    }
    .padding(24)
    .frame(maxWidth: 320)
    .background(Theme.charcoal)
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.green, lineWidth: 1))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .neonGlow(radius: 18)
    .padding(20)
  }

  private func share() {
    let renderer = ImageRenderer(content: ShareCardView(player: store.currentPlayer))
    renderer.scale = 3
    shareImage = renderer.uiImage
    showShare = shareImage != nil
  }
}

private struct TileView: View {
  let text: String
  let isMarked: Bool
  let isCenter: Bool
  let isOneAway: Bool
  let bounce: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(isMarked ? Theme.green : Theme.charcoal)
          .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(
              isOneAway ? Theme.green : Theme.green.opacity(isMarked ? 0.9 : 0.34),
              lineWidth: isOneAway ? 2 : 1
            ))
        if isCenter {
          FreeChip()
            .stroke(Theme.black, lineWidth: 2)
            .frame(width: 34, height: 34)
        } else {
          Text(text)
            .font(.system(size: 11, weight: .heavy))
            .tracking(0.2)
            .minimumScaleFactor(0.5)
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .padding(5)
        }
      }
      .foregroundStyle(isMarked ? Theme.black : .white)
      .aspectRatio(0.92, contentMode: .fit)
      .scaleEffect(bounce ? 1.08 : 1)
      .shadow(color: isMarked ? Theme.green.opacity(0.6) : .clear, radius: 8)
    }
    .buttonStyle(.plain)
  }
}

private struct FreeChip: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addRoundedRect(in: rect, cornerSize: CGSize(width: 7, height: 7))
    path.move(to: CGPoint(x: rect.minX + 7, y: rect.midY))
    path.addLine(to: CGPoint(x: rect.maxX - 7, y: rect.midY))
    path.move(to: CGPoint(x: rect.midX, y: rect.minY + 7))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 7))
    return path
  }
}
