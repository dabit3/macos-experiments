import SwiftUI

struct ResultsView: View {
  let record: ScoreRecord
  let isRecord: Bool
  let state: GameState
  var onRetry: () -> Void
  var onTracks: () -> Void

  @State private var shownScore = 0
  @State private var appeared = false

  private var grade: Grade { Grade(rawValue: record.grade) ?? .d }

  var body: some View {
    VStack(spacing: 0) {
      Spacer()
      Text(grade.rawValue)
        .font(.hero(120, .heavy))
        .foregroundStyle(grade == .s ? Palette.green : .white)
        .greenGlow(grade == .s ? 24 : 10)
        .scaleEffect(appeared ? 1 : 1.6)
        .opacity(appeared ? 1 : 0)
      Text(grade.title)
        .font(.hero(20, .heavy))
        .tracking(4)
        .foregroundStyle(Palette.green)
        .opacity(appeared ? 1 : 0)
      Text(grade.flavor)
        .font(.mono(12, .medium))
        .foregroundStyle(Palette.dim)
        .multilineTextAlignment(.center)
        .padding(.top, 6)
        .padding(.horizontal, 40)
        .opacity(appeared ? 1 : 0)

      if isRecord {
        Text("NEW RECORD")
          .font(.mono(13, .heavy))
          .tracking(3)
          .foregroundStyle(Palette.black)
          .padding(.horizontal, 14)
          .padding(.vertical, 6)
          .background(Palette.green)
          .clipShape(RoundedRectangle(cornerRadius: 3))
          .greenGlow(12)
          .padding(.top, 18)
      }

      Spacer()

      VStack(spacing: 14) {
        Text("\(shownScore)")
          .font(.mono(46, .heavy))
          .foregroundStyle(.white)
          .contentTransition(.numericText())
        HStack(spacing: 28) {
          stat("ACCURACY", String(format: "%.1f%%", record.accuracy * 100))
          stat("MAX COMBO", "x\(record.maxCombo)")
          stat("AVG FPS", "\(Int(state.averageFPS))")
        }
        VStack(alignment: .leading, spacing: 5) {
          ForEach(Judgment.allCases, id: \.self) { j in
            judgmentBar(j)
          }
        }
        .padding(.horizontal, 60)
        .padding(.top, 8)
      }
      .opacity(appeared ? 1 : 0)

      Spacer()

      HStack(spacing: 16) {
        Button(action: onRetry) {
          Text("RETRY")
            .font(.hero(17, .heavy))
            .tracking(3)
            .foregroundStyle(Palette.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Palette.green)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .greenGlow(10)
        }
        Button(action: onTracks) {
          Text("TRACKS")
            .font(.mono(15, .bold))
            .tracking(2)
            .foregroundStyle(Palette.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .overlay(
              RoundedRectangle(cornerRadius: 4)
                .stroke(Palette.faint, lineWidth: 1)
            )
        }
      }
      .padding(.horizontal, 28)
      .padding(.bottom, 56)
      .opacity(appeared ? 1 : 0)
    }
    .onAppear {
      withAnimation(.spring(duration: 0.6)) { appeared = true }
      // Count-up the score over ~1s.
      let steps = 30
      for i in 1...steps {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) / 30) {
          shownScore = record.score * i / steps
        }
      }
    }
  }

  private func judgmentBar(_ j: Judgment) -> some View {
    let count = state.counts[j, default: 0]
    let total = max(1, state.notes.count)
    let color: Color = j == .miss ? Palette.red : (j == .perfect ? Palette.green : .white)
    return HStack(spacing: 10) {
      Text(j.rawValue.uppercased())
        .font(.mono(10, .bold))
        .foregroundStyle(color)
        .frame(width: 70, alignment: .leading)
      GeometryReader { g in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2).fill(Palette.panel)
          RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(0.8))
            .frame(width: g.size.width * CGFloat(count) / CGFloat(total))
        }
      }
      .frame(height: 6)
      Text("\(count)")
        .font(.mono(11, .bold))
        .foregroundStyle(Palette.dim)
        .frame(width: 36, alignment: .trailing)
    }
  }

  private func stat(_ label: String, _ value: String) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(.mono(10, .medium))
        .foregroundStyle(Palette.faint)
      Text(value)
        .font(.mono(20, .bold))
        .foregroundStyle(Palette.green)
    }
  }
}
