import SwiftUI

private struct ParadeSession: Identifiable {
  let id = UUID()
  let puzzle: Puzzle
  let restored: Parade?
}

struct HomeView: View {
  @EnvironmentObject private var progress: Progress
  @State private var active: ParadeSession?
  @State private var showTowns = false
  @State private var showSettings = false

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 720
      ZStack {
        NightBackground()
        ScrollView(showsIndicators: false) {
          VStack(spacing: 0) {
            HStack {
              Eyebrow(text: "The midnight festival")
              Spacer()
              Button {
                showSettings = true
              } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 17, weight: .light))
                  .foregroundStyle(Ink.muted).frame(width: 44, height: 44)
              }.accessibilityLabel("Settings").accessibilityIdentifier("settings")
            }.padding(.horizontal, 28).padding(.top, 4)
            VStack(spacing: -12) {
              Text("Lantern").font(TypeStyle.title(compact ? 52 : 72)).tracking(-1.5)
              Text("Parade").font(TypeStyle.italic(compact ? 58 : 78)).tracking(-2)
            }.foregroundStyle(Ink.cream).padding(.top, compact ? 0 : 8)
              .accessibilityElement(children: .ignore).accessibilityLabel("Lantern Parade")
              .accessibilityAddTraits(.isHeader)
            FestivalVignette()
              .frame(height: min(460, geometry.size.height * (compact ? 0.48 : 0.46)))
              .padding(.top, -10)
            VStack(spacing: 13) {
              Text("One ribbon. A thousand little lights.")
                .font(TypeStyle.italic(17)).foregroundStyle(Ink.cream.opacity(0.8))
                .padding(.bottom, 5)
              Button {
                if let saved = progress.saved, !saved.completed,
                  let puzzle = Towns.puzzle(id: saved.puzzleID)
                {
                  active = ParadeSession(puzzle: puzzle, restored: saved)
                } else {
                  active = ParadeSession(puzzle: progress.nextTown, restored: nil)
                }
              } label: {
                HStack {
                  Text(
                    progress.saved?.completed == false ? "Continue your parade" : "Begin the parade"
                  )
                  Spacer()
                  Image(systemName: "arrow.right")
                }.padding(.horizontal, 22)
              }.buttonStyle(GoldButtonStyle()).accessibilityIdentifier("begin-parade")
              HStack(spacing: 22) {
                Button {
                  active = ParadeSession(puzzle: Towns.daily(), restored: nil)
                } label: {
                  Label("Daily light", systemImage: "moon")
                }.buttonStyle(GoldButtonStyle(secondary: true)).accessibilityIdentifier(
                  "daily-challenge")
                Button {
                  showTowns = true
                } label: {
                  Label("Town atlas", systemImage: "map")
                }.buttonStyle(GoldButtonStyle(secondary: true)).accessibilityIdentifier("towns")
              }
              HStack(spacing: 10) {
                Text("\(progress.completedCount) of 12 towns aglow")
                Circle().fill(Ink.gold).frame(width: 2, height: 2)
                Text("\(progress.stars) / 36 stars")
              }.font(.system(size: 11)).tracking(0.4).foregroundStyle(Ink.muted).padding(.top, 4)
            }.padding(.horizontal, 28).padding(.top, -5)
          }.padding(.bottom, 24)
        }.clipped()
      }
    }
    .fullScreenCover(item: $active) { session in
      GameView(puzzle: session.puzzle, restored: session.restored)
        .environmentObject(progress)
    }
    .sheet(isPresented: $showTowns) {
      TownList { puzzle in
        showTowns = false
        active = ParadeSession(puzzle: puzzle, restored: nil)
      }.environmentObject(progress)
    }
    .sheet(isPresented: $showSettings) { SettingsView().environmentObject(progress) }
  }
}

struct TownList: View {
  @EnvironmentObject private var progress: Progress
  @Environment(\.dismiss) private var dismiss
  let select: (Puzzle) -> Void
  var body: some View {
    NavigationStack {
      ZStack {
        NightBackground()
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: "An atlas of little lights").padding(.top, 16)
            Text("Where shall\nwe wander?")
              .font(TypeStyle.title(42)).foregroundStyle(Ink.cream).padding(.vertical, 14)
            Text(
              "Explore in any order. Earn three stars with a clean route at or under par, without a guide."
            )
            .font(.subheadline).foregroundStyle(Ink.muted).padding(.bottom, 20)
            ForEach(Array(Towns.all.enumerated()), id: \.element.id) { index, puzzle in
              Button {
                select(puzzle)
              } label: {
                HStack(spacing: 14) {
                  VStack(spacing: 5) {
                    Text(String(format: "%02d", index + 1))
                      .font(TypeStyle.italic(27)).foregroundStyle(Ink.gold)
                    Rectangle().fill(Ink.rule).frame(width: 18, height: 0.5)
                  }.frame(width: 34)
                  VStack(alignment: .leading, spacing: 5) {
                    Text(puzzle.title).font(TypeStyle.title(24)).foregroundStyle(
                      Ink.cream)
                    Text("\(puzzle.size) × \(puzzle.size) streets · par \(puzzle.par)")
                      .font(.caption).foregroundStyle(Ink.muted)
                  }
                  Spacer()
                  VStack(alignment: .trailing, spacing: 8) {
                    Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .light))
                      .foregroundStyle(Ink.muted)
                    Stars(count: progress.best[puzzle.id] ?? 0).font(.system(size: 10))
                  }
                }.padding(.vertical, 16)
              }.accessibilityIdentifier("town-\(index + 1)")
              Rectangle().fill(Ink.rule).frame(height: 0.5)
            }
          }.padding(24)
        }
      }.navigationTitle("The atlas").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Done") { dismiss() }.accessibilityIdentifier("close-towns") }
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject private var progress: Progress
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ZStack {
        NightBackground()
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            PaperLantern(size: 40)
            Text("A quieter kind\nof celebration.")
              .font(TypeStyle.title(38)).foregroundStyle(Ink.cream)
            Toggle("Haptic feedback", isOn: $progress.haptics).accessibilityIdentifier(
              "haptics-toggle")
            Text(
              "Lantern Parade is intentionally silent. Haptics mark each step on supported iPhones."
            )
            .font(.subheadline).foregroundStyle(Ink.muted)
            Divider()
            Text("HOW TO PARADE").font(.caption.monospaced()).tracking(2).foregroundStyle(Ink.gold)
            Text(
              "Draw along neighboring street lights, or tap them one by one. Collect 1 Amber, 2 Rose, then 3 Jade. Matching lanterns open gates. Bring every color to the square without crossing your ribbon."
            )
            .font(.subheadline).foregroundStyle(Ink.cream)
            Text(
              "Undo is free. A guide reveals a possible route; using it reduces your star rating. Daily light changes at midnight UTC. All progress stays on this iPhone."
            )
            .font(.subheadline).foregroundStyle(Ink.muted)
          }.fixedSize(horizontal: false, vertical: true).padding(28)
        }
      }.navigationTitle("Under the lanterns").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Done") { dismiss() }.accessibilityIdentifier("close-settings") }
    }.presentationDetents([.large])
  }
}
