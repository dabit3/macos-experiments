import SwiftUI

@main
struct GoldenDropApp: App {
  @StateObject private var store = GameStore()
  @Environment(\.scenePhase) private var scenePhase
  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(store)
        .preferredColorScheme(store.screen == .home ? .dark : .light)
        .onAppear { store.startClock() }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active { store.startClock() } else { store.background() }
        }
    }
  }
}

struct RootView: View {
  @EnvironmentObject private var store: GameStore
  var body: some View {
    ZStack {
      Palette.cream.ignoresSafeArea()
      LinenTexture().ignoresSafeArea()
      switch store.screen {
      case .home: HomeView()
      case .boards: GardensView()
      case .play: PlayView()
      }
      if store.screen == .play {
        if store.help {
          InstructionsView()
        } else if store.paused {
          PauseView()
        } else if store.game.phase == .won || store.game.phase == .lost {
          ResultsView()
        }
      }
    }
    .foregroundStyle(Palette.ink)
    .tint(Palette.ink)
    .dynamicTypeSize(.xSmall ... .xxxLarge)
  }
}

struct LinenTexture: View {
  var body: some View {
    Canvas { context, size in
      let width = max(Int(size.width), 1)
      let height = max(Int(size.height), 1)
      for i in 0..<160 {
        let x = Double((i * 97) % width)
        let y = Double((i * 61) % height)
        star(&context, x, y, i % 5 == 0 ? 2.2 : 1.1, Palette.brassMid.opacity(0.13))
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct HomeView: View {
  @EnvironmentObject private var store: GameStore
  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 730
      ZStack(alignment: .top) {
        LinearGradient(
          stops: [
            .init(color: Palette.dusk, location: 0),
            .init(color: Palette.duskMauve, location: 0.2),
            .init(color: Palette.duskMauve.opacity(0.45), location: 0.32),
            .init(color: Palette.cream.opacity(0), location: 0.46),
          ], startPoint: .top, endPoint: .bottom
        ).ignoresSafeArea()
        DuskStars().frame(height: geometry.size.height * 0.36).ignoresSafeArea()
        VStack(spacing: 0) {
          HStack {
            eyebrow("THE CELESTIAL COLLECTION", color: Palette.brassLight)
            Spacer()
            SoundButton()
          }.padding(.horizontal, 26)
          Spacer(minLength: 6)
          VStack(spacing: 6) {
            Ornament(color: Palette.brassLight).frame(width: 150)
            Text("Golden Drop")
              .font(Type.display(compact ? 52 : 58)).tracking(-1)
              .foregroundStyle(
                LinearGradient(
                  colors: [.white, Palette.brassLight, Palette.brassMid], startPoint: .top,
                  endPoint: .bottom)
              )
              .shadow(color: Palette.brassDark.opacity(0.55), radius: 12, y: 6)
            Text("Make a little magic.").font(Type.italic(20)).foregroundStyle(Palette.brassLight)
          }
          TheaterArt(game: GameRules(board: Board.all[1]), decorative: true)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, compact ? 44 : 38)
            .padding(.top, 14)
            .shadow(color: Palette.brassDark.opacity(0.28), radius: 24, y: 14)
            .overlay(alignment: .bottom) {
              Text("AIM  ·  DROP  ·  DELIGHT")
                .font(Type.demi(10)).tracking(3.2).foregroundStyle(Palette.gold)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Palette.cream, in: Capsule())
                .overlay(Capsule().stroke(Palette.brass, lineWidth: 1))
                .offset(y: 10)
            }
          VStack(spacing: 12) {
            Text("A joyful little game of beautiful bounces.")
              .font(Type.ui(13.5)).foregroundStyle(Palette.ink.opacity(0.72))
              .padding(.top, 20)
            PrimaryButton(title: "Play Cloud Nine", symbol: "arrow.right", gilded: true) {
              store.start(Board.all[0])
            }
            Button {
              store.screen = .boards
            } label: {
              HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2").foregroundStyle(Palette.gold)
                Text("The six gardens")
                Spacer()
                Text("\(store.records.values.reduce(0) { $0 + $1.stars }) / 18")
                Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(Palette.gold)
              }.font(Type.demi(14)).padding(.horizontal, 20).frame(height: 50)
                .background(Palette.paper.opacity(0.7), in: Capsule())
                .overlay(Capsule().stroke(Palette.brassMid.opacity(0.45), lineWidth: 1))
            }.buttonStyle(.plain).accessibilityIdentifier("gardens")
            HStack(spacing: 6) {
              Image(systemName: "sparkle")
              Text("A pocketful of wonder.  No hurry required.")
            }.font(Type.ui(10.5)).foregroundStyle(Palette.gold)
          }.padding(.horizontal, 26).padding(.bottom, 10)
        }
      }
    }
  }
}

struct DuskStars: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      Canvas { context, size in
        let t = timeline.date.timeIntervalSinceReferenceDate
        for i in 0..<70 {
          let x = Double((i * 137) % Int(max(size.width, 1)))
          let y = Double((i * 89) % Int(max(size.height, 1))) * 0.92
          let pulse = 0.5 + 0.5 * sin(t * (0.8 + Double(i % 5) * 0.3) + Double(i))
          let fade = 1 - y / size.height
          if i % 6 == 0 {
            star(
              &context, x, y, 2.4 + pulse * 1.6,
              Palette.brassLight.opacity(fade * (0.4 + pulse * 0.5)))
          } else {
            circle(&context, x, y, 0.9 + pulse * 0.5, .white.opacity(fade * (0.25 + pulse * 0.5)))
          }
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct Ornament: View {
  var color = Palette.brassMid
  var body: some View {
    HStack(spacing: 8) {
      Rectangle().fill(
        LinearGradient(colors: [.clear, color], startPoint: .leading, endPoint: .trailing)
      ).frame(height: 1)
      Image(systemName: "sparkle").font(.system(size: 9)).foregroundStyle(color)
      Rectangle().fill(
        LinearGradient(colors: [color, .clear], startPoint: .leading, endPoint: .trailing)
      ).frame(height: 1)
    }.accessibilityHidden(true)
  }
}

struct GardensView: View {
  @EnvironmentObject private var store: GameStore
  var body: some View {
    VStack(spacing: 16) {
      HStack {
        RoundButton(symbol: "arrow.left", label: "Home") { store.screen = .home }
        Spacer()
        eyebrow("CHOOSE YOUR CONSTELLATION")
        Spacer()
        Color.clear.frame(width: 44, height: 44)
      }
      VStack(spacing: 5) {
        Text("The six gardens").font(Type.display(36))
        Text("Little worlds. Lovely possibilities.").font(Type.italic(17))
          .foregroundStyle(Palette.gold)
        Ornament().frame(width: 120).padding(.top, 4)
      }
      ScrollView {
        VStack(spacing: 12) {
          ForEach(Board.all) { board in
            let record = store.records[String(board.id)]
            Button {
              store.start(board)
            } label: {
              HStack(spacing: 16) {
                GardenThumbnail(board: board)
                VStack(alignment: .leading, spacing: 6) {
                  eyebrow("GARDEN 0\(board.id + 1)")
                  Text(board.name).font(Type.display(23)).lineLimit(1).minimumScaleFactor(0.75)
                  HStack(spacing: 6) {
                    StarRow(count: record?.stars ?? 0, size: 12)
                    Text(record.map { "\($0.score.formatted()) best" } ?? "Unexplored")
                      .font(Type.medium(12)).foregroundStyle(Palette.ink.opacity(0.8))
                  }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold))
                  .foregroundStyle(Palette.paper).frame(width: 32, height: 32)
                  .background(Palette.brass, in: Circle())
              }.padding(14).brassCard(radius: 28)
            }.buttonStyle(.plain).accessibilityIdentifier("board-\(board.id)")
          }
        }.padding(.bottom, 12).padding(.horizontal, 2)
      }.scrollIndicators(.hidden)
    }.padding(.horizontal, 22).padding(.top, 8)
  }
}

struct PlayView: View {
  @EnvironmentObject private var store: GameStore
  var body: some View {
    VStack(spacing: 8) {
      HStack(alignment: .center) {
        RoundButton(symbol: "pause.fill", label: "Pause") { store.paused = true }
        Spacer()
        VStack(spacing: 3) {
          eyebrow("GARDEN 0\(store.game.board.id + 1)")
          Text(store.game.board.name).font(Type.display(26))
        }
        Spacer()
        SoundButton()
      }.padding(.horizontal, 22)
      HStack(spacing: 0) {
        metric("SCORE", value: store.game.score.formatted())
        divider
        metric("GOLD LEFT", value: "\(store.game.remainingGold) / \(store.game.goldTotal)")
        divider
        metric("BOOST", value: "×\(store.game.multiplier)", accent: store.game.multiplier > 1)
      }.padding(.vertical, 9).padding(.horizontal, 12).brassCard(radius: 22)
        .padding(.horizontal, 22)
      Text(feedbackLine)
        .font(store.toastLife > 0 ? Type.demi(12) : Type.ui(12))
        .foregroundStyle(store.toastLife > 0 ? Palette.gold : Palette.ink.opacity(0.75))
        .lineLimit(1).minimumScaleFactor(0.85)
        .frame(height: 24).frame(maxWidth: .infinity)
        .background(
          store.toastLife > 0 ? Palette.brassLight.opacity(0.35) : Palette.paper.opacity(0.6),
          in: Capsule()
        )
        .overlay(Capsule().stroke(Palette.brassMid.opacity(store.toastLife > 0 ? 0.6 : 0.25)))
        .padding(.horizontal, 30)
      GeometryReader { geometry in
        let scale = min(geometry.size.width / 390, geometry.size.height / 560)
        TheaterArt(game: store.game, sparks: store.particles)
          .shadow(color: Palette.brassDark.opacity(0.22), radius: 18, y: 10)
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0).onChanged { value in
              guard !store.paused, !store.help else { return }
              let x = (value.location.x - (geometry.size.width - 390 * scale) / 2) / scale
              let y = (value.location.y - (geometry.size.height - 560 * scale) / 2) / scale
              store.game.aim(at: .init(x: x, y: y))
            }
          )
          .accessibilityElement()
          .accessibilityLabel("Aim the launcher")
          .accessibilityValue("\(Int(store.game.angle * 180 / .pi)) degrees")
          .accessibilityAdjustableAction { direction in
            guard store.game.phase == .aiming else { return }
            store.game.angle = min(
              1.2, max(-1.2, store.game.angle + (direction == .increment ? 0.08 : -0.08)))
          }
          .accessibilityIdentifier("aim-field")
      }.padding(.horizontal, 14)
      VStack(spacing: 10) {
        HStack {
          HStack(spacing: 8) {
            BallTray(balls: store.game.balls)
            Text("\(store.game.balls)").font(Type.bold(14)).monospacedDigit()
            Text(store.game.balls == 1 ? "ball left" : "balls left").font(Type.ui(13))
              .foregroundStyle(Palette.ink.opacity(0.75))
          }.lineLimit(1).fixedSize().layoutPriority(1)
          Spacer()
          Text(
            store.game.phase == .flying
              ? "\(store.game.shotHits) PEGS  ·  +\(store.game.shotScore)" : "DRAG TO AIM"
          )
          .font(Type.demi(11)).tracking(1).foregroundStyle(Palette.gold)
        }
        HStack(spacing: 10) {
          RoundButton(symbol: "chevron.left", label: "Aim left") { nudge(-0.06) }
            .disabled(store.game.phase != .aiming)
          PrimaryButton(
            title: store.game.phase == .flying ? "A little gravity…" : "Drop the ball",
            symbol: store.game.phase == .flying ? "sparkles" : "arrow.down", gilded: true
          ) { store.fire() }
          .disabled(store.game.phase != .aiming)
          .accessibilityIdentifier("launch")
          RoundButton(symbol: "chevron.right", label: "Aim right") { nudge(0.06) }
            .disabled(store.game.phase != .aiming)
        }
        Text("Gold clears the garden. The cup gifts a ball.")
          .font(Type.ui(12)).foregroundStyle(Palette.ink.opacity(0.7))
      }.padding(.horizontal, 24).padding(.bottom, 6)
    }.padding(.top, 4)
  }

  var divider: some View {
    Rectangle().fill(
      LinearGradient(
        colors: [.clear, Palette.brassMid.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom
      )
    ).frame(width: 1, height: 34)
  }

  var feedbackLine: String {
    if store.toastLife > 0 { return store.toast }
    if !store.lastShotSummary.isEmpty { return store.lastShotSummary }
    return store.game.phase == .flying
      ? "Ball in play · let the garden work its magic" : "A little aim. A lovely possibility."
  }

  func nudge(_ amount: Double) {
    guard store.game.phase == .aiming else { return }
    store.game.angle = min(1.2, max(-1.2, store.game.angle + amount))
  }

  func metric(_ title: String, value: String, accent: Bool = false) -> some View {
    VStack(spacing: 3) {
      Text(title).font(Type.demi(9.5)).tracking(1.6).foregroundStyle(Palette.gold)
      Text(value).font(accent ? Type.displayBold(24) : Type.display(24)).monospacedDigit()
        .foregroundStyle(accent ? Palette.brassDark : Palette.ink)
    }.frame(maxWidth: .infinity)
  }
}

struct InstructionsView: View {
  @EnvironmentObject private var store: GameStore
  var body: some View {
    ModalCard {
      Medallion(symbol: "sparkles")
      eyebrow("A LITTLE FIELD GUIDE")
      Text("Follow your\ngolden instinct.").font(Type.display(34))
        .multilineTextAlignment(.center)
      Ornament().frame(width: 110)
      VStack(alignment: .leading, spacing: 20) {
        instruction(
          "hand.draw", title: "Aim, then tap Drop",
          text: "Drag across the garden to aim. Tap Drop the ball to launch.")
        instruction(
          "circle.inset.filled", title: "Gold is the goal",
          text: "Clear every gold peg. More pegs in one shot multiply your points.")
        instruction(
          "plus.circle", title: "A little extra luck",
          text: "Green pegs gift a ball. Catch the moving cup for another, plus 500 points.")
      }.padding(.vertical, 6)
      PrimaryButton(title: "Let’s make magic", symbol: "arrow.right", gilded: true) {
        store.dismissHelp()
      }
    }
  }

  func instruction(_ icon: String, title: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: icon).font(.system(size: 16, weight: .medium))
        .foregroundStyle(Palette.paper).frame(width: 36, height: 36)
        .background(Palette.brass, in: Circle())
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(Type.demi(15))
        Text(text).font(Type.ui(13)).foregroundStyle(Palette.ink.opacity(0.72)).fixedSize(
          horizontal: false, vertical: true)
      }
    }
  }
}

struct PauseView: View {
  @EnvironmentObject private var store: GameStore
  var body: some View {
    ModalCard {
      Medallion(symbol: "moon.zzz")
      eyebrow("TAKE YOUR TIME")
      Text("A quiet moment.").font(Type.display(32))
      Text("Your garden will be right here.").font(Type.italic(17)).foregroundStyle(Palette.gold)
      PrimaryButton(title: "Keep playing", symbol: "play.fill", gilded: true) {
        store.paused = false
        store.lastTick = nil
      }
      Button("Begin this garden again") { store.start(store.game.board) }.font(Type.demi(14))
        .frame(minHeight: 44)
      HStack {
        Button("How to play") { store.help = true }.frame(minHeight: 44)
        Spacer()
        Button("The gardens") {
          store.paused = false
          store.screen = .boards
        }.frame(minHeight: 44)
      }.font(Type.medium(13)).foregroundStyle(Palette.gold)
    }
  }
}

struct ResultsView: View {
  @EnvironmentObject private var store: GameStore
  var won: Bool { store.game.phase == .won }
  var starDescription: String {
    switch store.game.stars {
    case 3: return "Three stars · saved 7+ balls"
    case 2: return "Two stars · saved 3+ balls"
    case 1: return "Garden cleared · save 3 balls for two stars"
    default: return "Clear the gold to earn your first star."
    }
  }
  var body: some View {
    ModalCard {
      Medallion(symbol: won ? "sun.max" : "moon.stars")
      Text(
        store.newRecord
          ? "NEW PERSONAL BEST" : (won ? "EVERY WISH, GRANTED" : "THE STARS WILL WAIT")
      )
      .font(Type.demi(10)).tracking(2).foregroundStyle(
        store.newRecord ? Palette.paper : Palette.gold
      )
      .padding(.horizontal, 12).padding(.vertical, 5)
      .background(
        store.newRecord ? AnyShapeStyle(Palette.brass) : AnyShapeStyle(.clear), in: Capsule())
      Text(won ? "Golden hour." : "One more wish?").font(Type.display(40)).tracking(-0.5)
      Text(
        won
          ? "A beautiful finish in \(store.game.board.name)."
          : "\(store.game.remainingGold) gold pegs left. A new angle awaits."
      )
      .font(Type.ui(13.5)).foregroundStyle(Palette.ink.opacity(0.72))
      VStack(spacing: 8) {
        StarRow(count: store.game.stars, size: 28)
        Text(starDescription).font(Type.medium(12)).foregroundStyle(Palette.ink.opacity(0.8))
      }
      VStack(spacing: 4) {
        Text(store.game.score.formatted()).font(Type.display(54)).monospacedDigit()
          .foregroundStyle(Palette.goldText)
          .shadow(color: Palette.brassLight.opacity(0.8), radius: 0, y: 1)
        if !store.newRecord {
          Text(
            "Personal best · \(store.records[String(store.game.board.id)]?.score.formatted() ?? "0")"
          )
          .font(Type.medium(12)).foregroundStyle(Palette.gold)
        }
      }
      VStack(spacing: 8) {
        resultLine(
          "Pegs & combos",
          store.game.score - store.game.caught * 500 - (won ? 2500 + store.game.balls * 1000 : 0))
        resultLine("Lovely catches · \(store.game.caught)", store.game.caught * 500)
        if won {
          resultLine("Sunlight bonus", 2500)
          resultLine("Saved balls · \(store.game.balls) × 1,000", store.game.balls * 1000)
        }
      }.padding(14).background(
        Palette.brassLight.opacity(0.22), in: RoundedRectangle(cornerRadius: 18)
      )
      .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.brassMid.opacity(0.35)))
      PrimaryButton(
        title: won ? "Next garden" : "Try a new angle", symbol: "arrow.right", gilded: true
      ) {
        store.start(won ? Board.all[(store.game.board.id + 1) % Board.all.count] : store.game.board)
      }
      HStack {
        Button("Play again") { store.start(store.game.board) }
        Spacer()
        ShareLink(
          item:
            "I scored \(store.game.score.formatted()) in Golden Drop’s \(store.game.board.name), earning \(store.game.stars) stars. A pocketful of wonder!"
        ) {
          Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
            .foregroundStyle(Palette.gold)
        }.accessibilityLabel("Share your score")
        Spacer()
        Button("Gardens") { store.screen = .boards }
      }.font(Type.demi(13.5)).frame(minHeight: 44)
    }
  }
  func resultLine(_ title: String, _ value: Int) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(title)
      Line().stroke(Palette.brassMid.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
        .frame(height: 1).offset(y: -3)
      Text(value.formatted()).font(Type.demi(13)).monospacedDigit()
    }.font(Type.ui(13)).foregroundStyle(Palette.ink.opacity(0.9))
  }
}

struct Line: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: .init(x: rect.minX, y: rect.midY))
    path.addLine(to: .init(x: rect.maxX, y: rect.midY))
    return path
  }
}

struct Medallion: View {
  let symbol: String
  var body: some View {
    Image(systemName: symbol).font(.system(size: 24, weight: .light))
      .foregroundStyle(Palette.goldText).frame(width: 62, height: 62)
      .background(
        RadialGradient(
          colors: [Palette.paper, Palette.brassLight.opacity(0.5)], center: .center, startRadius: 4,
          endRadius: 34),
        in: Circle()
      )
      .overlay(Circle().stroke(Palette.brass, lineWidth: 1.8))
      .overlay(Circle().stroke(Palette.brassDark.opacity(0.4), lineWidth: 0.6).padding(4))
      .shadow(color: Palette.brassDark.opacity(0.2), radius: 8, y: 4)
      .accessibilityHidden(true)
  }
}

struct ModalCard<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    ZStack {
      Palette.inkDeep.opacity(0.5).ignoresSafeArea()
      ScrollView {
        VStack(spacing: 16) { content }
          .padding(26).frame(maxWidth: 370)
          .brassCard(radius: 36)
          .shadow(color: Palette.inkDeep.opacity(0.35), radius: 30, y: 16)
          .padding(20)
          .frame(maxWidth: .infinity)
      }.scrollIndicators(.hidden).defaultScrollAnchor(.center)
    }
  }
}

struct BrassCard: ViewModifier {
  let radius: Double
  func body(content: Content) -> some View {
    content
      .background(
        LinearGradient(
          colors: [Palette.paper, Palette.paper.opacity(0.94)], startPoint: .top, endPoint: .bottom
        ), in: RoundedRectangle(cornerRadius: radius)
      )
      .overlay(RoundedRectangle(cornerRadius: radius).stroke(Palette.brass, lineWidth: 1.4))
      .overlay(
        RoundedRectangle(cornerRadius: radius - 4).stroke(
          Palette.brassDark.opacity(0.25), lineWidth: 0.6
        )
        .padding(4)
      )
      .shadow(color: Palette.brassDark.opacity(0.12), radius: 10, y: 5)
  }
}

extension View {
  func brassCard(radius: Double) -> some View { modifier(BrassCard(radius: radius)) }
}

struct PrimaryButton: View {
  let title: String
  var symbol = "arrow.right"
  var gilded = false
  let action: () -> Void
  @Environment(\.isEnabled) private var enabled
  var body: some View {
    Button(action: action) {
      HStack {
        Spacer(minLength: 0)
        Text(title).font(Type.demi(15.5))
        Spacer(minLength: 0)
        Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
      }.padding(.horizontal, 22).frame(height: 56)
        .foregroundStyle(Palette.paper)
        .background(
          LinearGradient(
            colors: enabled
              ? [Palette.ink, Palette.inkDeep]
              : [Palette.ink.opacity(0.55), Palette.ink.opacity(0.5)],
            startPoint: .top, endPoint: .bottom),
          in: Capsule()
        )
        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1).padding(1.5))
        .overlay(
          Capsule().stroke(
            gilded && enabled
              ? AnyShapeStyle(Palette.brass) : AnyShapeStyle(Palette.ink.opacity(0.4)),
            lineWidth: 1.6)
        )
        .shadow(color: Palette.inkDeep.opacity(enabled ? 0.3 : 0), radius: 10, y: 6)
    }.buttonStyle(.plain)
  }
}

struct RoundButton: View {
  let symbol: String
  let label: String
  let action: () -> Void
  @Environment(\.isEnabled) private var enabled
  var body: some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Palette.ink.opacity(enabled ? 1 : 0.4))
        .frame(width: 46, height: 46)
        .background(Palette.paper, in: Circle())
        .overlay(Circle().stroke(Palette.brass, lineWidth: 1.3).opacity(enabled ? 1 : 0.45))
        .shadow(color: Palette.brassDark.opacity(enabled ? 0.16 : 0), radius: 6, y: 3)
    }.buttonStyle(.plain).accessibilityLabel(label)
  }
}

struct SoundButton: View {
  @EnvironmentObject private var store: GameStore
  var body: some View {
    RoundButton(
      symbol: store.sound ? "speaker.wave.2" : "speaker.slash",
      label: store.sound ? "Mute sound" : "Enable sound"
    ) {
      store.toggleSound()
    }
  }
}

struct StarRow: View {
  let count: Int
  var size = 14.0
  var body: some View {
    HStack(spacing: size * 0.36) {
      ForEach(0..<3) { index in
        Image(systemName: index < count ? "star.fill" : "star")
          .foregroundStyle(
            index < count
              ? AnyShapeStyle(Palette.goldText) : AnyShapeStyle(Palette.brassMid.opacity(0.7))
          )
          .shadow(color: index < count ? Palette.brassLight : .clear, radius: 0, y: 0.8)
      }
    }.font(.system(size: size)).accessibilityLabel("\(count) of 3 stars")
  }
}

func eyebrow(_ title: String, color: Color = Palette.gold) -> some View {
  Text(title).font(Type.demi(9.5)).tracking(2.4).foregroundStyle(color)
}
