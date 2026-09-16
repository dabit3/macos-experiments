import SwiftUI

struct ShareCardView: View {
  let player: Player

  var body: some View {
    ZStack {
      CircuitBackground()
      VStack(spacing: 28) {
        Text("GTC KEYNOTE BINGO")
          .font(.system(size: 38, weight: .black))
          .tracking(3)
          .foregroundStyle(Theme.green)
          .multilineTextAlignment(.center)
        Text(player.name.uppercased())
          .font(.system(size: 24, weight: .heavy))
          .tracking(4)
        ShareGrid(card: player.card)
        Text("Unofficial fan game · no logos were harmed")
          .font(.system(size: 16, weight: .bold, design: .monospaced))
          .foregroundStyle(Theme.muted)
          .multilineTextAlignment(.center)
      }
      .padding(40)
    }
    .frame(width: 1080, height: 1350)
  }
}

struct ShareGrid: View {
  let card: BingoCard

  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 5), spacing: 9) {
      ForEach(card.cells.indices, id: \.self) { index in
        Text(card.cells[index])
          .font(.system(size: 20, weight: .heavy))
          .multilineTextAlignment(.center)
          .minimumScaleFactor(0.55)
          .padding(8)
          .frame(maxWidth: .infinity, minHeight: 140)
          .background(card.marked.contains(index) ? Theme.green : Theme.panel)
          .foregroundStyle(card.marked.contains(index) ? Theme.black : .white)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
  }
}
