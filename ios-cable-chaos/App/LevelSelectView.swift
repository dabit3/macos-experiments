import SwiftUI

struct LevelSelectView: View {
  @EnvironmentObject var store: GameStore
  var namespace: Namespace.ID
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Button {
          store.showTitle()
          Haptics.tap()
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Palette.green)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Palette.charcoal.opacity(0.9)))
            .overlay(Circle().strokeBorder(Palette.green.opacity(0.4), lineWidth: 1))
        }
        .accessibilityLabel("Back to title")
        VStack(alignment: .leading, spacing: 2) {
          Text("SELECT LEVEL").font(.mono(11)).tracking(2).foregroundStyle(Palette.green)
          Text("Wafer map").font(.display(24)).foregroundStyle(Palette.paper)
        }
        Spacer()
        HStack(spacing: 5) {
          Image(systemName: "star.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(
            Palette.green)
          Text("\(store.progress.totalStars)").font(.mono(15, weight: .bold)).foregroundStyle(
            Palette.paper)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(
          Capsule().fill(Palette.charcoal.opacity(0.9)).overlay(
            Capsule().strokeBorder(Palette.green.opacity(0.35), lineWidth: 1)))
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 12)

      ScrollView {
        LazyVGrid(columns: columns, spacing: 10) {
          ForEach(1...LevelCatalog.count, id: \.self) { id in
            LevelCard(
              id: id, unlocked: store.progress.isUnlocked(id), result: store.progress.results[id],
              isNext: id == store.progress.nextLevel
            )
            .onTapGesture { store.start(level: id) }
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        legend.padding(.horizontal, 16).padding(.bottom, 30)
      }
    }
  }

  private var legend: some View {
    HStack(spacing: 16) {
      legendItem(color: Palette.green, text: "Power")
      legendItem(color: Palette.amber, text: "PCIe")
      legendItem(color: Palette.ember, text: "Heat from Lv.10")
      legendItem(color: Palette.steel, text: "Locked")
    }
    .font(.mono(10))
    .foregroundStyle(Palette.mist)
  }

  private func legendItem(color: Color, text: String) -> some View {
    HStack(spacing: 5) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(text)
    }
  }
}

struct LevelCard: View {
  let id: Int
  let unlocked: Bool
  let result: Progress.Result?
  let isNext: Bool

  var body: some View {
    let level = LevelCatalog.spec(id)
    let tint: Color =
      !unlocked
      ? Palette.steel
      : level.hotTiles > 0 ? Palette.ember : level.nets > 1 ? Palette.amber : Palette.green
    VStack(spacing: 6) {
      Text(String(format: "%02d", id))
        .font(.mono(22, weight: .black))
        .foregroundStyle(unlocked ? Palette.paper : Palette.steel)
      if let result {
        StarRow(count: result.stars, size: 10)
      } else if unlocked {
        Text(isNext ? "NEXT" : "OPEN").font(.mono(9)).tracking(1.5).foregroundStyle(tint)
      } else {
        Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(
          Palette.steel)
      }
      HStack(spacing: 3) {
        ForEach(0..<level.nets, id: \.self) { i in
          Circle().fill(i == 0 ? Palette.green : Palette.amber).frame(width: 5, height: 5)
        }
        ForEach(0..<level.hotTiles, id: \.self) { _ in
          Image(systemName: "flame.fill").font(.system(size: 7)).foregroundStyle(Palette.ember)
        }
      }
      .opacity(unlocked ? 1 : 0.35)
      .frame(height: 8)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 84)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(unlocked ? Palette.charcoal.opacity(0.92) : Palette.ink.opacity(0.7))
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(tint.opacity(isNext ? 1 : 0.4), lineWidth: isNext ? 2 : 1)
        )
        .shadow(color: isNext ? tint.opacity(0.55) : .clear, radius: 12)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Level \(id), \(level.name), \(unlocked ? (result.map { "\($0.stars) stars" } ?? "unsolved") : "locked")"
    )
  }
}
