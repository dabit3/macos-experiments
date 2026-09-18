import SpriteKit
import SwiftUI

@main
struct LanternfallApp: App {
  var body: some Scene {
    WindowGroup { LanternfallView().preferredColorScheme(.dark) }
  }
}

enum Palette {
  static let ink = Color(red: 0.025, green: 0.065, blue: 0.09)
  static let panel = Color(red: 0.055, green: 0.13, blue: 0.16)
  static let gold = Color(red: 1, green: 0.8, blue: 0.43)
  static let goldDeep = Color(red: 0.78, green: 0.56, blue: 0.24)
  static let mint = Color(red: 0.47, green: 0.9, blue: 0.8)
  static let rose = Color(red: 0.96, green: 0.47, blue: 0.6)
  static let cream = Color(red: 0.97, green: 0.94, blue: 0.83)
  static let muted = Color(red: 0.58, green: 0.7, blue: 0.7)
  static let goldSheen = LinearGradient(
    colors: [Color(red: 1, green: 0.93, blue: 0.74), gold, goldDeep], startPoint: .top,
    endPoint: .bottom)
}

extension Font {
  static func display(_ size: CGFloat) -> Font { .custom("Didot", size: size) }
  static func displayItalic(_ size: CGFloat) -> Font { .custom("Didot-Italic", size: size) }
  static func label(_ size: CGFloat) -> Font { .custom("AvenirNext-DemiBold", size: size) }
  static func prose(_ size: CGFloat) -> Font { .custom("AvenirNext-Regular", size: size) }
  static func proseMedium(_ size: CGFloat) -> Font { .custom("AvenirNext-Medium", size: size) }
}

struct LanternfallView: View {
  @StateObject private var store = GameStore()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var showingGuide = false
  var body: some View {
    ZStack {
      Palette.ink.ignoresSafeArea()
      if store.screen == "title" {
        title
      } else {
        gameplay
        if store.game.phase == .choosing { upgrades }
        if store.game.phase == .paused { pause }
        if store.game.phase == .victory || store.game.phase == .defeat { results }
      }
      if showingGuide { guide }
    }
    .foregroundStyle(Palette.cream)
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { store.game.pause() }
    }
    .statusBarHidden()
  }

  private var title: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 760
      ZStack {
        GardenBackdrop(animated: !reduceMotion)
        VStack(spacing: 0) {
          HStack {
            eyebrow("A MIDNIGHT SURVIVAL")
            Spacer()
            soundButton
          }
          .padding(.top, 8)
          Spacer(minLength: 6)
          VStack(spacing: 10) {
            Text("Lanternfall")
              .font(.display(min(64, geometry.size.width * 0.155)))
              .tracking(-1)
              .foregroundStyle(
                LinearGradient(
                  colors: [Palette.cream, Color(red: 0.98, green: 0.86, blue: 0.62)],
                  startPoint: .top, endPoint: .bottom)
              )
              .shadow(color: Palette.gold.opacity(0.35), radius: 22)
            Flourish(text: "KEEP THE LIGHT ALIVE")
          }
          ZStack {
            Circle().fill(
              RadialGradient(
                colors: [Palette.gold.opacity(0.14), Palette.gold.opacity(0)], center: .center,
                startRadius: 10, endRadius: 130)
            ).frame(width: 260, height: 260)
            Circle().stroke(Palette.gold.opacity(0.25), lineWidth: 1).frame(width: 196, height: 196)
            TickRing(count: 60).stroke(Palette.gold.opacity(0.28), lineWidth: 1)
              .frame(width: 222, height: 222)
            Circle().stroke(Palette.mint.opacity(0.10), lineWidth: 1).frame(width: 262, height: 262)
            Image(uiImage: UIImage(cgImage: GardenArt.texture("keeper").cgImage()))
              .resizable().interpolation(.high)
              .frame(width: 168, height: 168)
              .shadow(color: Palette.gold.opacity(0.3), radius: 28, x: 24)
            Image(systemName: "sparkle").font(.system(size: 15)).foregroundStyle(Palette.gold)
              .offset(x: -102, y: -48)
            Image(systemName: "diamond.fill").font(.system(size: 9)).foregroundStyle(Palette.mint)
              .offset(x: 104, y: 62)
          }
          .frame(height: min(compact ? 236 : 278, geometry.size.height * 0.33))
          VStack(spacing: 8) {
            Text("One keeper. Five minutes until dawn.")
              .font(.displayItalic(compact ? 17 : 19))
            Text("Gather light. Grow stronger.\nFace what waits in the garden.")
              .font(.prose(13)).foregroundStyle(Palette.muted)
              .multilineTextAlignment(.center).lineSpacing(4)
          }
          Spacer(minLength: 14)
          HStack(spacing: 0) {
            record(value: clock(store.bestSeconds), label: "BEST SURVIVAL")
            Rectangle().fill(Palette.gold.opacity(0.22)).frame(width: 1, height: 30)
            record(value: "\(store.bestKills)", label: "MOST BANISHED")
            Rectangle().fill(Palette.gold.opacity(0.22)).frame(width: 1, height: 30)
            record(value: "\(store.victories)", label: "DAWNS SEEN")
          }
          .padding(.vertical, 16)
          .background(Palette.ink.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
          .overlay(CornerOrnaments().padding(1))
          .padding(.bottom, 16)
          primary("Enter the garden", icon: "arrow.right") { store.start() }
          Button {
            showingGuide = true
          } label: {
            Label("How to keep the light", systemImage: "hand.draw")
              .font(.proseMedium(12))
              .foregroundStyle(Palette.muted).frame(height: 46)
          }
          .accessibilityIdentifier("howToPlay")
        }
        .padding(.horizontal, 27)
        .padding(.bottom, 4)
      }
    }
  }
  private var gameplay: some View {
    ZStack {
      SpriteView(scene: store.scene, options: [.ignoresSiblingOrder])
        .ignoresSafeArea()
      VStack {
        LinearGradient(
          stops: [
            .init(color: Palette.ink.opacity(0.94), location: 0),
            .init(color: Palette.ink.opacity(0.82), location: 0.55),
            .init(color: .clear, location: 1),
          ], startPoint: .top, endPoint: .bottom
        )
        .frame(height: store.game.bossSpawned && !store.game.bossDefeated ? 250 : 200)
        Spacer()
        LinearGradient(
          colors: [.clear, Palette.ink.opacity(0.72)], startPoint: .top, endPoint: .bottom
        )
        .frame(height: 130)
      }
      .ignoresSafeArea().allowsHitTesting(false)
      VStack(spacing: 0) {
        HStack(spacing: 10) {
          meter(
            store.game.experience / store.game.neededExperience, color: Palette.mint, height: 3)
          Text("LV \(store.game.level)").font(.label(10)).tracking(1).foregroundStyle(Palette.mint)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Palette.ink.opacity(0.7), in: Capsule())
            .overlay(Capsule().stroke(Palette.mint.opacity(0.35)))
        }
        .padding(.bottom, 12)
        HStack(alignment: .center, spacing: 14) {
          DawnDial(progress: store.game.elapsed / GameModel.duration) {
            clockDigits(store.game.timeText, size: 20)
          }
          .frame(width: 78, height: 78)
          VStack(alignment: .leading, spacing: 8) {
            eyebrow(store.game.elapsed < 240 ? "UNTIL DAWN" : "THE FINAL HOUR")
            HStack(spacing: 8) {
              Image(systemName: "heart.fill").font(.system(size: 10)).foregroundStyle(Palette.rose)
              meter(store.game.health / store.game.maxHealth, color: Palette.rose, height: 6)
              Text("\(Int(store.game.health))").font(.label(11)).monospacedDigit()
                .frame(minWidth: 26, alignment: .trailing)
            }
            Text(store.game.stage).font(.displayItalic(13)).foregroundStyle(Palette.muted)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          VStack(alignment: .trailing, spacing: 4) {
            Text("\(store.game.kills)").font(.display(30)).monospacedDigit()
              .foregroundStyle(Palette.goldSheen)
            eyebrow("BANISHED")
          }
          Button {
            store.game.pause()
          } label: {
            Image(systemName: "pause.fill").font(.system(size: 15)).frame(width: 46, height: 46)
              .background(Palette.ink.opacity(0.75), in: Circle())
              .overlay(Circle().stroke(Palette.gold.opacity(0.3)))
          }
          .accessibilityLabel("Pause")
        }
        Group {
          if let boss = store.game.enemies.first(where: { $0.kind == .boss }) {
            VStack(spacing: 6) {
              HStack {
                Text("THE HOLLOW GARDENER").font(.label(9)).tracking(2)
                Spacer()
                Image(systemName: "location.north.fill")
                  .rotationEffect(
                    .radians(
                      .pi / 2
                        - atan2(
                          boss.position.y - store.game.player.y,
                          boss.position.x - store.game.player.x)))
              }
              .foregroundStyle(Palette.gold)
              meter(boss.health / boss.maxHealth, color: Palette.gold, height: 4)
            }
            .padding(12).background(Palette.ink.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
            .overlay(CornerOrnaments())
          } else if store.game.elapsed < 8 {
            hint("Drag the stick to move. Your lantern attacks on its own.", color: Palette.cream)
          } else if store.game.elapsed >= 43 && store.game.elapsed < 55 {
            hint("Thorn blooms. Step out of the rose rings.", color: Palette.rose)
          } else if store.game.experience >= store.game.neededExperience
            && store.game.nextGiftIn > 0
          {
            hint("A new gift blooms in \(Int(ceil(store.game.nextGiftIn)))s", color: Palette.mint)
          } else if store.game.elapsed < 16 {
            hint("Gather turquoise gems to grow your light.", color: Palette.mint)
          }
        }
        .padding(.top, 14)
        Spacer()
        HStack(alignment: .bottom) {
          VStack(alignment: .leading, spacing: 8) {
            eyebrow("YOUR LIGHT")
            HStack(spacing: 10) {
              weapon("sparkles", rank: 1 + store.game.rank(.lantern), color: Palette.gold)
              if store.game.rank(.orbit) > 0 {
                weapon(
                  "moonphase.waning.crescent", rank: store.game.rank(.orbit), color: Palette.mint)
              }
              if store.game.rank(.nova) > 0 {
                weapon("sun.max", rank: store.game.rank(.nova), color: Palette.gold)
              }
            }
          }
          Spacer(minLength: 8)
          Joystick { movement in store.game.movement = movement }
        }
        .padding(.bottom, 4)
      }
      .padding(.horizontal, 20).padding(.top, 6)
    }
  }
  private var upgrades: some View {
    overlay {
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          eyebrow("LIGHT GATHERED")
          Spacer()
          Text("LEVEL \(store.game.level)").font(.label(10)).tracking(1.5)
            .foregroundStyle(Palette.mint)
        }
        VStack(alignment: .leading, spacing: 8) {
          Text("Let it bloom.").font(.display(40))
          Text("Choose a gift. The garden can wait.").font(.prose(13)).foregroundStyle(
            Palette.muted)
        }
        ForEach(store.game.choices) { upgrade in
          let accent = upgrade == .orbit || upgrade == .magnet ? Palette.mint : Palette.gold
          let rank = store.game.rank(upgrade)
          Button {
            store.choose(upgrade)
          } label: {
            HStack(spacing: 16) {
              ZStack {
                Circle().fill(
                  RadialGradient(
                    colors: [accent.opacity(0.32), Palette.ink], center: .center, startRadius: 2,
                    endRadius: 34))
                Circle().stroke(accent.opacity(0.5), lineWidth: 1)
                Image(systemName: upgrade.symbol).font(.system(size: 24, weight: .light))
                  .foregroundStyle(accent)
              }
              .frame(width: 60, height: 60)
              VStack(alignment: .leading, spacing: 5) {
                Text(
                  upgrade == .lantern || upgrade == .orbit || upgrade == .nova
                    ? "WEAPON" : "BLESSING"
                )
                .font(.label(8)).tracking(2).foregroundStyle(accent.opacity(0.8))
                Text(upgrade.title).font(.display(21))
                Text(upgrade.detail(after: rank)).font(.prose(12))
                  .foregroundStyle(Palette.muted)
                  .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
              }
              Spacer(minLength: 4)
              VStack(spacing: 6) {
                RankPips(filled: rank + 1, color: accent)
                Text("RANK \(rank + 1)").font(.label(8)).tracking(1).foregroundStyle(
                  Palette.muted)
              }
            }
            .padding(.vertical, 16).padding(.horizontal, 18)
            .background(
              LinearGradient(
                colors: [Palette.panel, Palette.ink], startPoint: .topLeading,
                endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.28)))
            .overlay(CornerOrnaments(color: accent).padding(3))
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("upgrade-\(upgrade.rawValue)")
        }
        Label("Time is paused while you choose", systemImage: "pause.circle")
          .font(.prose(11)).foregroundStyle(Palette.muted)
          .frame(maxWidth: .infinity).padding(.top, 3)
      }
    }
  }
  private var pause: some View {
    overlay {
      VStack(spacing: 22) {
        Image(systemName: "moon.stars").font(.system(size: 38, weight: .ultraLight))
          .foregroundStyle(Palette.gold)
        Flourish(text: "A MOMENT OF STILLNESS")
        Text("The light can wait.").font(.display(36))
        Text("Your run is paused at \(store.game.timeText).")
          .font(.prose(14)).foregroundStyle(Palette.muted)
        primary("Return to the garden", icon: "play.fill") { store.game.resume() }
        HStack(spacing: 16) {
          Button {
            store.toggleSound()
          } label: {
            Label(
              store.sound ? "Sound on" : "Sound off",
              systemImage: store.sound ? "speaker.wave.2" : "speaker.slash")
          }
          Spacer()
          Button("How to play") { showingGuide = true }
        }
        .font(.proseMedium(13)).foregroundStyle(Palette.muted).frame(height: 44)
        Button("End this run") {
          store.game.defeatCause = .ended
          store.game.phase = .defeat
          store.finish()
        }
        .font(.proseMedium(13)).foregroundStyle(Palette.muted).frame(height: 44)
      }
    }
  }
  private var results: some View {
    let victory = store.game.phase == .victory
    let newBest =
      store.game.elapsed > 0 && store.game.elapsed >= store.bestSeconds
      && store.game.defeatCause != .ended
    return overlay {
      VStack(spacing: 20) {
        ZStack {
          TickRing(count: 48).stroke(Palette.gold.opacity(0.3), lineWidth: 1)
            .frame(width: 104, height: 104)
          Circle().stroke(Palette.gold.opacity(0.18)).frame(width: 88, height: 88)
          Image(systemName: victory ? "sun.max" : "sparkle")
            .font(.system(size: 42, weight: .ultraLight)).foregroundStyle(Palette.goldSheen)
        }
        Flourish(text: victory ? "THE GARDEN REMEMBERS" : "EVERY LIGHT LEAVES A TRACE")
        VStack(spacing: 10) {
          Text(victory ? "You brought the dawn." : "An ember remains.")
            .font(.display(36)).multilineTextAlignment(.center)
          Text(
            victory
              ? "The Hollow Gardener falls. The flowers open."
              : store.game.defeatCause?.advice ?? "The garden is patient. Return a little brighter."
          )
          .font(.prose(13)).foregroundStyle(Palette.muted)
          .multilineTextAlignment(.center).lineSpacing(4)
        }
        VStack(spacing: 14) {
          if newBest {
            Text("NEW BEST SURVIVAL").font(.label(9)).tracking(2).foregroundStyle(Palette.ink)
              .padding(.horizontal, 12).padding(.vertical, 5)
              .background(Palette.goldSheen, in: Capsule())
          }
          HStack(spacing: 0) {
            record(value: store.game.timeText, label: "SURVIVED")
            Rectangle().fill(Palette.gold.opacity(0.22)).frame(width: 1, height: 30)
            record(value: "\(store.game.kills)", label: "BANISHED")
            Rectangle().fill(Palette.gold.opacity(0.22)).frame(width: 1, height: 30)
            record(value: "\(store.game.level)", label: "LEVEL")
          }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Palette.panel.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
        .overlay(CornerOrnaments().padding(3))
        HStack {
          Image(systemName: "laurel.leading").foregroundStyle(Palette.gold)
          Text("LOCAL BEST  \(clock(store.bestSeconds))  ·  \(store.bestKills) BANISHED")
            .font(.label(9)).tracking(1)
          Image(systemName: "laurel.trailing").foregroundStyle(Palette.gold)
        }
        primary("Light another lantern", icon: "arrow.clockwise") { store.start() }
        HStack {
          Button("Back to garden gate") { store.screen = "title" }
          Spacer()
          ShareLink(
            item:
              "I kept the light alive for \(store.game.timeText) and banished \(store.game.kills) shades in Lanternfall."
          ) {
            Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
          }
        }
        .font(.proseMedium(12)).foregroundStyle(Palette.muted)
      }
    }
  }
  private var guide: some View {
    overlay {
      VStack(alignment: .leading, spacing: 24) {
        eyebrow("THE KEEPER'S FIELD NOTES")
        Text("A little light\ngoes a long way.").font(.display(36))
        guideRow(
          "hand.draw", title: "Wander with one thumb",
          text:
            "Drag the lower-right stick to move. Let go to stop. Your lantern targets nearby enemies."
        )
        guideRow(
          "diamond", title: "Gather what glimmers",
          text:
            "Turquoise gems grant levels. Choose one of three gifts each time. Rose gems restore health."
        )
        guideRow(
          "sun.max", title: "Earn your dawn",
          text:
            "Survive five minutes and defeat the Hollow Gardener, who arrives in the final minute.")
        Text(
          "Leave rose-colored thorn rings before they bloom.\nCircle back for gems. Pause whenever you need."
        )
        .font(.prose(12)).foregroundStyle(Palette.gold).lineSpacing(4)
        primary("I’ll keep the light", icon: "checkmark") { showingGuide = false }
      }
    }
  }
  private func overlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ZStack {
      Palette.ink.ignoresSafeArea()
      GardenBackdrop(animated: false).opacity(0.7).allowsHitTesting(false)
      ScrollView {
        content().padding(25).frame(maxWidth: 480)
          .frame(maxWidth: .infinity)
      }
      .scrollBounceBehavior(.basedOnSize)
      .defaultScrollAnchor(.center)
    }
  }
  private var soundButton: some View {
    Button {
      store.toggleSound()
    } label: {
      Image(systemName: store.sound ? "speaker.wave.2" : "speaker.slash")
        .font(.system(size: 15)).foregroundStyle(Palette.muted)
        .frame(width: 44, height: 44)
    }
    .accessibilityLabel(store.sound ? "Mute sound" : "Enable sound")
  }
  private func primary(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        Spacer()
        Text(title).font(.label(16))
        Spacer()
        Image(systemName: icon).font(.system(size: 14, weight: .semibold))
      }
      .foregroundStyle(Palette.ink)
      .padding(.horizontal, 22).frame(height: 58)
      .background(Palette.goldSheen, in: RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(
            LinearGradient(
              colors: [Color.white.opacity(0.55), Color.white.opacity(0)], startPoint: .top,
              endPoint: .bottom), lineWidth: 1)
      )
      .shadow(color: Palette.gold.opacity(0.32), radius: 18, y: 6)
    }
    .buttonStyle(.plain)
  }
  private func eyebrow(_ text: String) -> some View {
    Text(text).font(.label(9)).tracking(2).foregroundStyle(Palette.muted)
  }
  private func hint(_ text: String, color: Color) -> some View {
    Text(text).font(.proseMedium(11)).foregroundStyle(color)
      .padding(.horizontal, 14).padding(.vertical, 8)
      .background(Palette.ink.opacity(0.7), in: Capsule())
      .overlay(Capsule().stroke(color.opacity(0.25)))
  }
  private func record(value: String, label: String) -> some View {
    VStack(spacing: 6) {
      Text(value).font(.display(26)).monospacedDigit().foregroundStyle(Palette.cream)
      Text(label).font(.label(8)).tracking(1.5).foregroundStyle(Palette.muted)
    }
    .frame(maxWidth: .infinity)
  }
  private func clockDigits(_ text: String, size: CGFloat) -> some View {
    HStack(spacing: 0) {
      ForEach(Array(text.enumerated()), id: \.offset) { _, character in
        Text(String(character)).font(.display(size))
          .frame(width: character == ":" ? size * 0.28 : size * 0.6)
      }
    }
  }
  private func meter(_ value: Double, color: Color, height: Double) -> some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(color.opacity(0.14))
        Capsule().fill(
          LinearGradient(
            colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing)
        )
        .frame(width: proxy.size.width * min(1, max(0, value)))
        .shadow(color: color.opacity(0.6), radius: 4)
      }
    }
    .frame(height: height)
  }
  private func weapon(_ symbol: String, rank: Int, color: Color) -> some View {
    VStack(spacing: 5) {
      ZStack {
        Circle().fill(Palette.ink.opacity(0.75))
        Circle().stroke(color.opacity(0.45), lineWidth: 1)
        Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(color)
      }
      .frame(width: 40, height: 40)
      RankPips(filled: rank, color: color)
    }
  }
  private func guideRow(_ symbol: String, title: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: symbol).font(.system(size: 24, weight: .light)).foregroundStyle(
        Palette.gold
      ).frame(width: 32)
      VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.display(19))
        Text(text).font(.prose(13)).foregroundStyle(Palette.muted).lineSpacing(4)
      }
    }
  }
  private func clock(_ seconds: Double) -> String {
    String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
  }
}

/// Thin gold rules with a diamond, framing an engraved caption.
struct Flourish: View {
  var text: String
  var body: some View {
    HStack(spacing: 10) {
      Rectangle().fill(Palette.gold.opacity(0.4)).frame(width: 30, height: 1)
      Image(systemName: "diamond.fill").font(.system(size: 5)).foregroundStyle(Palette.gold)
      Text(text).font(.label(10)).tracking(3).foregroundStyle(Palette.gold)
      Image(systemName: "diamond.fill").font(.system(size: 5)).foregroundStyle(Palette.gold)
      Rectangle().fill(Palette.gold.opacity(0.4)).frame(width: 30, height: 1)
    }
  }
}

/// Engraved corner brackets that turn a plain panel into a plaque.
struct CornerOrnaments: View {
  var color: Color = Palette.gold
  var body: some View {
    Canvas { context, size in
      let arm: CGFloat = 12
      let inset: CGFloat = 5
      for (sx, sy) in [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)] {
        let origin = CGPoint(
          x: sx > 0 ? inset : size.width - inset, y: sy > 0 ? inset : size.height - inset)
        var path = Path()
        path.move(to: CGPoint(x: origin.x, y: origin.y + sy * arm))
        path.addLine(to: origin)
        path.addLine(to: CGPoint(x: origin.x + sx * arm, y: origin.y))
        context.stroke(path, with: .color(color.opacity(0.7)), lineWidth: 1)
        context.fill(
          Path(ellipseIn: CGRect(x: origin.x - 1.5, y: origin.y - 1.5, width: 3, height: 3)),
          with: .color(color))
      }
    }
    .allowsHitTesting(false)
  }
}

struct TickRing: Shape {
  var count: Int
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    for index in 0..<count {
      let angle = Double(index) / Double(count) * 2 * .pi
      let length: CGFloat = index.isMultiple(of: 5) ? 6 : 3
      path.move(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
      path.addLine(
        to: CGPoint(
          x: center.x + cos(angle) * (radius - length), y: center.y + sin(angle) * (radius - length)
        ))
    }
    return path
  }
}

struct RankPips: View {
  var filled: Int
  var color: Color
  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<5, id: \.self) { index in
        Circle().fill(index < filled ? color : color.opacity(0.18)).frame(width: 4, height: 4)
      }
    }
    .accessibilityLabel("Rank \(filled)")
  }
}

/// Timer dial: moon at dusk that fills toward the golden dawn as the five minutes pass.
struct DawnDial<Content: View>: View {
  var progress: Double
  @ViewBuilder var content: Content
  var body: some View {
    ZStack {
      Circle().fill(Palette.ink.opacity(0.75))
      TickRing(count: 30).stroke(Palette.gold.opacity(0.25), lineWidth: 1).padding(1)
      Circle().stroke(Palette.gold.opacity(0.18), lineWidth: 3).padding(7)
      Circle().trim(from: 0, to: min(1, max(0, progress)))
        .stroke(Palette.goldSheen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .rotationEffect(.degrees(-90)).padding(7)
        .shadow(color: Palette.gold.opacity(0.5), radius: 4)
      content
    }
    .accessibilityLabel("Time until dawn")
  }
}

struct Joystick: View {
  var changed: (V2) -> Void
  @State private var offset: CGSize = .zero
  var body: some View {
    ZStack {
      Circle().fill(Palette.ink.opacity(0.55))
      Circle().stroke(Palette.gold.opacity(0.28), lineWidth: 1)
      TickRing(count: 24).stroke(Palette.gold.opacity(0.22), lineWidth: 1).padding(4)
      Circle().stroke(Palette.muted.opacity(0.1), lineWidth: 1).padding(22)
      Circle().fill(Palette.mint.opacity(0.18)).frame(width: 46, height: 46)
        .overlay(Circle().stroke(Palette.mint.opacity(0.6)))
        .overlay(Circle().fill(Palette.mint.opacity(0.7)).frame(width: 5, height: 5))
        .shadow(color: Palette.mint.opacity(0.4), radius: 8)
        .offset(offset)
    }
    .frame(width: 118, height: 118)
    .contentShape(Circle())
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          let vector = V2(x: value.location.x - 59, y: 59 - value.location.y)
          let clamped = vector.normalized * min(38, vector.length)
          offset = CGSize(width: clamped.x, height: -clamped.y)
          changed(clamped * (1 / 38))
        }
        .onEnded { _ in
          offset = .zero
          changed(.zero)
        }
    )
    .accessibilityLabel("Movement stick")
    .accessibilityHint("Drag in the direction you want to move")
    .onDisappear {
      offset = .zero
      changed(.zero)
    }
  }
}

/// Layered night garden: moon, distant hedges, drifting fireflies and foreground fronds.
struct GardenBackdrop: View {
  var animated: Bool
  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      ZStack {
        LinearGradient(
          colors: [Color(red: 0.05, green: 0.16, blue: 0.19), Palette.ink, Palette.ink],
          startPoint: .top, endPoint: .bottom)
        RadialGradient(
          colors: [Palette.gold.opacity(0.22), Palette.gold.opacity(0)],
          center: UnitPoint(x: 0.14, y: 0.06), startRadius: 0, endRadius: size.width * 0.45)
        Canvas { context, size in
          var random = SeededRandom(state: 722)
          for _ in 0..<80 {
            let x = random.next() * size.width
            let y = random.next() * size.height * 0.7
            let radius = random.next() > 0.85 ? 1.6 : 0.8
            context.fill(
              Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
              with: .color(Palette.cream.opacity(0.15 + random.next() * 0.4)))
          }
          let moon = CGPoint(x: size.width * 0.14, y: size.height * 0.06)
          context.fill(
            Path(ellipseIn: CGRect(x: moon.x - 20, y: moon.y - 20, width: 40, height: 40)),
            with: .color(Color(red: 0.98, green: 0.92, blue: 0.74).opacity(0.9)))
          context.blendMode = .destinationOut
          context.fill(
            Path(ellipseIn: CGRect(x: moon.x - 12, y: moon.y - 27, width: 40, height: 40)),
            with: .color(.black))
          context.blendMode = .normal
          for layer in 0..<3 {
            let base = size.height * (0.56 + Double(layer) * 0.1)
            var hills = Path()
            hills.move(to: CGPoint(x: 0, y: size.height))
            hills.addLine(to: CGPoint(x: 0, y: base))
            var x: Double = 0
            while x < size.width {
              let width = 60 + random.next() * 80
              let height = 24 + random.next() * 40 * (1 - Double(layer) * 0.2)
              hills.addQuadCurve(
                to: CGPoint(x: x + width, y: base + random.next() * 10),
                control: CGPoint(x: x + width / 2, y: base - height))
              x += width
            }
            hills.addLine(to: CGPoint(x: size.width, y: size.height))
            hills.closeSubpath()
            let shade = 0.05 - Double(layer) * 0.012
            context.fill(
              hills, with: .color(Color(red: shade, green: shade * 2.6, blue: shade * 2.7)))
          }
          for side in [0.0, 1.0] {
            for index in 0..<9 {
              let bottom = size.height * (0.62 + Double(index) * 0.045)
              let reach = 30 + Double(index % 3) * 22
              var frond = Path()
              frond.move(to: CGPoint(x: side * size.width, y: bottom + 120))
              frond.addQuadCurve(
                to: CGPoint(x: side == 0 ? reach : size.width - reach, y: bottom),
                control: CGPoint(x: side == 0 ? 4 : size.width - 4, y: bottom + 10))
              context.stroke(frond, with: .color(Palette.mint.opacity(0.16)), lineWidth: 1.2)
              for leaf in 1..<5 {
                let t = Double(leaf) / 5
                let point = CGPoint(
                  x: side == 0 ? reach * t * t : size.width - reach * t * t,
                  y: bottom + 120 * (1 - t) * (1 - t) + 4)
                context.fill(
                  Path(
                    ellipseIn: CGRect(
                      x: point.x - 12, y: point.y - 3, width: 24, height: 6)),
                  with: .color(Palette.mint.opacity(0.08)))
              }
            }
          }
        }
        if animated {
          TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
              for index in 0..<14 {
                let seed = Double(index)
                let x =
                  size.width * (0.08 + 0.84 * ((sin(seed * 1.7) + 1) / 2))
                  + sin(time * 0.35 + seed) * 22
                let y =
                  size.height * (0.3 + 0.55 * ((cos(seed * 2.3) + 1) / 2))
                  + cos(time * 0.27 + seed * 1.3) * 16
                let pulse = (sin(time * 1.6 + seed * 2) + 1) / 2
                context.fill(
                  Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)),
                  with: .color(Palette.gold.opacity(0.08 + pulse * 0.12)))
                context.fill(
                  Path(ellipseIn: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)),
                  with: .color(Palette.gold.opacity(0.35 + pulse * 0.6)))
              }
            }
          }
        }
      }
    }
    .ignoresSafeArea()
  }
}
