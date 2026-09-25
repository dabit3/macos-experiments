import SpriteKit
import SwiftUI

enum Theme {
  static let ink = Color(red: 0.045, green: 0.045, blue: 0.08)
  static let panel = Color.white.opacity(0.06)
  static let edge = Color.white.opacity(0.14)
  static let gold = Color(red: 1, green: 0.80, blue: 0.25)
  static let cyan = Color(red: 0.26, green: 0.94, blue: 1)
  static let red = Color(red: 1, green: 0.30, blue: 0.42)
  static let green = Color(red: 0.42, green: 0.95, blue: 0.55)
  static let muted = Color.white.opacity(0.55)

  static func label(_ size: CGFloat = 10) -> Font { .system(size: size, weight: .heavy) }
  static func display(_ size: CGFloat) -> Font {
    .system(size: size, weight: .black, design: .rounded)
  }
  static func body(_ size: CGFloat = 14) -> Font { .system(size: size, weight: .medium) }
}

private let ink = Theme.ink
private let gold = Theme.gold
private let cyan = Theme.cyan

@main
struct SkylinePulseApp: App {
  @StateObject private var session = Session()
  var body: some Scene {
    WindowGroup {
      RootView(session: session)
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
  }
}

struct ArcadeButton: View {
  enum Style { case primary, secondary, quiet }
  let title: String
  var style = Style.secondary
  var action: () -> Void
  @Environment(\.isEnabled) private var enabled
  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 14, weight: .heavy, design: .rounded))
        .tracking(1.4)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .foregroundStyle(style == .primary ? ink : gold)
        .background(style == .primary ? gold : (style == .secondary ? Theme.panel : .clear))
        .overlay(
          Rectangle().stroke(
            gold.opacity(style == .primary ? 1 : (style == .secondary ? 0.45 : 0)),
            lineWidth: 1)
        )
        .opacity(enabled ? 1 : 0.4)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(title)
  }
}

struct SectionHeader: View {
  let number: String
  let title: String
  var trailing: Text? = nil
  var body: some View {
    HStack(spacing: 8) {
      Text(number).foregroundStyle(gold)
      Text(title).tracking(2)
      Spacer()
      trailing
    }.font(Theme.label(12))
  }
}

struct StatusChip: View {
  let status: String
  var color: Color {
    switch status {
    case "CONNECTED": return cyan
    case "CONNECTING", "RECONNECTING": return gold
    default: return Theme.muted
    }
  }
  var body: some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(status).tracking(1.5)
    }
    .font(Theme.label(10)).foregroundStyle(color)
    .padding(.horizontal, 10).padding(.vertical, 6)
    .background(color.opacity(0.12)).overlay(Rectangle().stroke(color.opacity(0.4)))
  }
}

struct RootView: View {
  @ObservedObject var session: Session
  @State private var scene = HighwayScene(size: CGSize(width: 1200, height: 800))
  @State private var mode = "create"
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        ink.ignoresSafeArea()
        if session.state?.phase == "playing" {
          SpriteView(scene: scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
            .ignoresSafeArea()
            .onAppear {
              scene.session = session
              session.scene = scene
            }
          matchHUD(size: geometry.size)
          if session.status != "CONNECTED" { connectionVeil }
        } else if session.state?.phase == "results" {
          results
        } else {
          lobby
        }
        if session.guide { guide }
      }
    }
    .onAppear {
      if Launch.has("create") {
        session.connect(create: true)
      } else if Launch.value("room") != nil {
        mode = "join"
        session.connect(create: false)
      }
    }
  }

  private var brand: some View {
    HStack(spacing: 12) {
      Image(systemName: "waveform.path").font(.system(size: 27, weight: .heavy)).foregroundStyle(
        gold)
      VStack(alignment: .leading, spacing: 2) {
        Text("SKYLINE PULSE").font(Theme.display(25)).tracking(3)
        Text("REACH BEYOND THE RHYTHM").font(.system(size: 9, weight: .bold)).tracking(3)
          .foregroundStyle(gold)
      }
    }
  }

  // MARK: Lobby

  private var lobby: some View {
    GeometryReader { geo in
      HStack(spacing: 0) {
        ZStack(alignment: .bottomLeading) {
          Image("aria").resizable().scaledToFill()
            .frame(width: geo.size.width * 0.32, height: geo.size.height).clipped()
            .allowsHitTesting(false)
          LinearGradient(
            colors: [.clear, ink.opacity(0.4), ink], startPoint: .center, endPoint: .bottom
          )
          .allowsHitTesting(false)
          VStack(alignment: .leading, spacing: 12) {
            Text("SKY COURIER / 01").font(Theme.label(11)).tracking(3).foregroundStyle(gold)
            Text("ARIA").font(.system(size: 55, weight: .ultraLight)).tracking(9)
            Text("The city is listening.\nGive it a new heartbeat.").font(Theme.body(16))
              .foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 12) {
              legend("TAP", Theme.red)
              legend("HOLD", gold)
              legend("SLIDE", cyan)
              legend("AIR ↑", Theme.green)
            }.padding(.top, 8)
          }.padding(26)
        }.frame(width: geo.size.width * 0.32)
        VStack(alignment: .leading, spacing: 18) {
          HStack(alignment: .center) {
            brand
            Spacer()
            StatusChip(status: session.status)
            Button {
              session.guide = true
            } label: {
              Label("HOW TO PLAY", systemImage: "questionmark.circle")
                .font(Theme.label(10)).foregroundStyle(gold)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .overlay(Rectangle().stroke(gold.opacity(0.45)))
                .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("howToPlay")
          }
          SectionHeader(
            number: "01", title: "CHOOSE A TRACK",
            trailing: Text(songHint).foregroundStyle(Theme.muted).font(Theme.label(9)))
          HStack(spacing: 14) {
            ForEach(Chart.all) { chart in
              songCard(chart)
            }
          }
          SectionHeader(
            number: "02", title: session.state == nil ? "OPEN A ROOM" : "YOUR ROOM",
            trailing: session.state == nil
              ? nil : Text("PING \(Int(session.rtt)) ms").foregroundStyle(cyan))
          if session.state == nil { connectionForm } else { roomPanel }
          if !session.error.isEmpty {
            HStack(spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
              Text(session.error)
            }
            .font(Theme.body(12)).foregroundStyle(Theme.red)
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.red.opacity(0.1)).overlay(Rectangle().stroke(Theme.red.opacity(0.4)))
            .accessibilityIdentifier("connectionError")
          }
          Spacer(minLength: 0)
          HStack {
            Text("16-SEGMENT TOUCH SURFACE  /  TWO-PLAYER SCORE BATTLE")
            Spacer()
            if session.demo {
              Text("AUTOMATED INPUT DRIVER").foregroundStyle(cyan)
            }
            Text("VOL. 01")
          }.font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(Theme.muted)
        }.padding(26)
      }
    }.ignoresSafeArea()
  }

  private func legend(_ title: String, _ color: Color) -> some View {
    HStack(spacing: 5) {
      RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 5)
      Text(title)
    }.font(Theme.label(10)).foregroundStyle(.white.opacity(0.9))
  }

  private var isHost: Bool { session.state == nil || session.state?.host == session.playerID }

  private var songHint: String {
    if session.state == nil { return "ORIGINAL TRACKS" }
    return isHost ? "YOU PICK THE TRACK" : "HOST PICKS THE TRACK"
  }

  private func songCard(_ chart: Chart) -> some View {
    let chosen = session.selectedSong == chart.id
    return Button {
      session.select(chart.id)
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        ZStack(alignment: .bottomLeading) {
          GeometryReader { card in
            Image("aria").resizable().scaledToFill()
              .frame(width: card.size.width, height: card.size.height).clipped()
              .hueRotation(.degrees(chart.id == "neon" ? 0 : 85))
              .saturation(chosen ? 1 : 0.5)
          }.allowsHitTesting(false)
          LinearGradient(
            colors: [.clear, .black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
          VStack(alignment: .leading, spacing: 4) {
            Text(chart.id == "neon" ? "SKYLINE / NIGHTFALL" : "SKYLINE / DAYBREAK")
              .font(Theme.label(8)).tracking(2).foregroundStyle(gold)
            Text(chart.title).font(Theme.display(23)).italic()
          }.padding(12)
          if chosen {
            VStack {
              HStack {
                Spacer()
                Label("SELECTED", systemImage: "checkmark").font(Theme.label(8))
                  .padding(.horizontal, 8).padding(.vertical, 5).background(gold).foregroundStyle(
                    ink)
              }
              Spacer()
            }.padding(7)
          }
        }
        HStack(alignment: .center) {
          VStack(alignment: .leading, spacing: 4) {
            Text(chart.id == "neon" ? "ADVANCED" : "EXPERT").font(Theme.label(11)).tracking(1.2)
            Text(
              "\(Int(chart.bpm)) BPM  •  \(Int(chart.duration)) SEC  •  \(chart.notes.count) NOTES"
            )
            .font(.system(size: 10, weight: .semibold))
          }
          Spacer()
          VStack(spacing: 0) {
            Text("LV").font(Theme.label(8))
            Text(chart.level).font(Theme.display(30))
          }
        }.foregroundStyle(ink).padding(12).background(chosen ? gold : Color.white)
      }
      .overlay(
        Rectangle().stroke(chosen ? gold : Theme.edge, lineWidth: chosen ? 3 : 1)
      )
      .contentShape(Rectangle())
      .opacity(isHost || chosen ? 1 : 0.55)
    }
    .buttonStyle(.plain)
    .allowsHitTesting(isHost)
    .accessibilityIdentifier(chart.id)
  }

  private var connectionForm: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        field("GUEST NAME", text: $session.name, id: "guestName")
        field("SERVER ADDRESS", text: $session.address, id: "serverAddress")
      }
      HStack(spacing: 0) {
        modeTab("create", "HOST A NEW ROOM")
        modeTab("join", "JOIN WITH A CODE")
      }.overlay(Rectangle().stroke(Theme.edge))
      if mode == "create" {
        HStack(spacing: 12) {
          ArcadeButton(title: "CREATE ROOM", style: .primary) { session.connect(create: true) }
            .frame(maxWidth: 260)
          Text("You'll get a six-character code to share with the second iPad.")
            .font(Theme.body(12)).foregroundStyle(Theme.muted)
        }
      } else {
        HStack(spacing: 12) {
          TextField("ROOM CODE", text: $session.roomCode)
            .textInputAutocapitalization(.characters).autocorrectionDisabled()
            .font(.system(size: 20, weight: .heavy, design: .monospaced))
            .multilineTextAlignment(.center)
            .padding(12).background(Theme.panel).overlay(Rectangle().stroke(Theme.edge))
            .frame(maxWidth: 190)
            .accessibilityIdentifier("roomCode")
          ArcadeButton(title: "JOIN ROOM", style: .primary) { session.connect(create: false) }
            .frame(maxWidth: 260)
            .disabled(session.roomCode.trimmingCharacters(in: .whitespaces).count < 6)
          Text("Enter the code shown on the host's screen.")
            .font(Theme.body(12)).foregroundStyle(Theme.muted)
        }
      }
    }
  }

  private func modeTab(_ id: String, _ title: String) -> some View {
    Button {
      mode = id
    } label: {
      Text(title).font(Theme.label(10)).tracking(1.2)
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .foregroundStyle(mode == id ? ink : Theme.muted)
        .background(mode == id ? gold : Color.clear)
        .contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityIdentifier("mode-\(id)")
  }

  private func field(_ title: String, text: Binding<String>, id: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title).font(Theme.label(9)).tracking(1).foregroundStyle(Theme.muted)
      TextField(title, text: text).textInputAutocapitalization(.never).autocorrectionDisabled()
        .font(.system(size: 14, weight: .medium, design: .monospaced)).padding(10)
        .background(Theme.panel).overlay(Rectangle().stroke(Theme.edge))
        .accessibilityIdentifier(id)
    }
  }

  private var roomPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 14) {
        VStack(alignment: .leading, spacing: 2) {
          Text("ROOM CODE").font(Theme.label(9)).tracking(1.5).foregroundStyle(Theme.muted)
          Text(session.roomCode).font(.system(size: 34, weight: .heavy, design: .monospaced))
            .tracking(6).foregroundStyle(gold)
            .accessibilityIdentifier("activeRoom")
        }
        Text(
          session.opponent == nil
            ? "Share this code with the other player." : "Both players are here."
        )
        .font(Theme.body(12)).foregroundStyle(Theme.muted)
        Spacer()
      }
      HStack(spacing: 12) {
        ForEach(session.state?.players ?? []) { player in
          playerSlot(player)
        }
        if session.opponent == nil {
          HStack {
            ProgressView().tint(cyan)
            Text("Waiting for the second player…").font(Theme.body(12)).foregroundStyle(Theme.muted)
          }
          .padding(14).frame(maxWidth: .infinity, alignment: .leading)
          .overlay(
            Rectangle().stroke(Theme.edge, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        }
      }
      HStack(spacing: 12) {
        ArcadeButton(
          title: session.me?.ready == true ? "CANCEL READY" : "READY TO FLY", style: .primary
        ) { session.ready() }
        .disabled(!session.clockReady)
        ArcadeButton(title: "LEAVE", style: .quiet) { session.leave() }.frame(maxWidth: 160)
      }
      Text(readyHint).font(Theme.body(12)).foregroundStyle(cyan)
    }
  }

  private var readyHint: String {
    if !session.clockReady { return "Syncing the room clock…" }
    if session.opponent == nil {
      return "You can ready up now; the match starts once both players are ready."
    }
    if session.me?.ready == true {
      return session.opponent?.ready == true
        ? "Both ready — starting!"
        : "Waiting for \(session.opponent?.name ?? "your rival") to ready up."
    }
    return session.opponent?.ready == true
      ? "\(session.opponent?.name ?? "Your rival") is ready. Tap READY TO FLY to start."
      : "Tap READY TO FLY when you're set."
  }

  private func playerSlot(_ player: Player) -> some View {
    let me = player.id == session.playerID
    return HStack(spacing: 10) {
      Circle().fill(player.connected ? cyan : Theme.muted).frame(width: 8, height: 8)
      VStack(alignment: .leading, spacing: 2) {
        Text(player.name).font(Theme.label(13)).lineLimit(1)
        Text(me ? "YOU" : (player.connected ? "RIVAL" : "RECONNECTING"))
          .font(Theme.label(8)).tracking(1.5).foregroundStyle(Theme.muted)
      }
      Spacer()
      Text(player.ready ? "READY" : "NOT READY").font(Theme.label(9)).tracking(1)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .foregroundStyle(player.ready ? ink : Theme.muted)
        .background(player.ready ? gold : Theme.panel)
    }
    .padding(12).frame(maxWidth: .infinity)
    .background(Theme.panel)
    .overlay(Rectangle().stroke(player.ready ? gold.opacity(0.8) : Theme.edge))
  }

  // MARK: Match HUD

  private func matchHUD(size: CGSize) -> some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 10) {
        VStack(alignment: .leading, spacing: 6) {
          Text(session.name).font(Theme.display(18)).foregroundStyle(gold)
          Text("ROOM \(session.roomCode) · ROUND \(session.state?.round ?? 1)")
            .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(
              .white.opacity(0.7))
          Text(session.chart?.title ?? "").font(.system(size: 12, weight: .black)).italic()
        }.frame(width: size.width * 0.22, alignment: .leading)
        VStack(spacing: 6) {
          HStack(alignment: .firstTextBaseline) {
            Text("SCORE").font(Theme.label(10))
            Text(String(format: "%07d", session.me?.score ?? 0)).font(Theme.display(34))
              .monospacedDigit()
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
              Text("ACCURACY").font(Theme.label(8))
              Text(String(format: "%.2f%%", session.me?.accuracy ?? 100)).font(
                .system(size: 16, weight: .black)
              ).monospacedDigit()
            }
          }.foregroundStyle(ink)
          TimelineView(.animation) { _ in
            GeometryReader { bar in
              let chart = session.chart
              let fraction = chart.map { min(1, max(0, session.songTime / $0.duration)) } ?? 0
              ZStack(alignment: .leading) {
                Rectangle().fill(ink.opacity(0.2))
                Rectangle().fill(ink).frame(width: bar.size.width * fraction)
              }
            }
          }.frame(height: 5)
        }.padding(.horizontal, 15).padding(.vertical, 8).background(gold)
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Circle().fill(session.opponent?.connected == true ? cyan : Theme.muted)
              .frame(width: 7, height: 7)
            Text(session.opponent?.name ?? "WAITING").font(Theme.label(12)).lineLimit(1)
          }
          Text(String(format: "%07d", session.opponent?.score ?? 0))
            .font(.system(size: 22, weight: .heavy, design: .monospaced)).foregroundStyle(cyan)
            .monospacedDigit()
          Text(leadText).font(Theme.label(10)).foregroundStyle(leadColor).monospacedDigit()
        }.frame(width: size.width * 0.20, alignment: .leading).padding(10).background(
          ink.opacity(0.9)
        ).overlay(Rectangle().stroke(cyan.opacity(0.4)))
      }.padding(.horizontal, 17).padding(.top, 12)
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Text("RIVAL COMBO").font(Theme.label(9)).tracking(2).foregroundStyle(cyan)
          Text("\(session.opponent?.combo ?? 0)").font(Theme.display(28)).monospacedDigit()
          if session.opponent?.connected == false {
            Text("RIVAL RECONNECTING").font(Theme.label(9)).foregroundStyle(Theme.red)
          }
          Spacer()
          if session.demo {
            Text("AUTOMATED\nINPUT DRIVER").font(.system(size: 13, weight: .black)).foregroundStyle(
              cyan)
            Text("Real touch-event path\nLive WebSocket peers").font(.system(size: 9))
              .foregroundStyle(.white)
          }
          VStack(alignment: .leading, spacing: 5) {
            legend("TAP", Theme.red)
            legend("HOLD", gold)
            legend("SLIDE", cyan)
            legend("AIR  SWIPE UP", Theme.green)
          }
        }
        .padding(14).frame(width: size.width * 0.23, alignment: .leading)
        .background(
          LinearGradient(
            colors: [ink.opacity(0.95), ink.opacity(0.15), ink.opacity(0.9)], startPoint: .top,
            endPoint: .bottom))
        Spacer()
      }.padding(.top, 12).padding(.leading, 14).padding(.bottom, 34)
      Text("TOUCH BELOW THE GOLD LINE  ·  SWIPE UP FOR AIR NOTES")
        .font(Theme.label(8)).tracking(1).foregroundStyle(gold).padding(.bottom, 7)
    }.allowsHitTesting(false)
  }

  private var lead: Int { (session.me?.score ?? 0) - (session.opponent?.score ?? 0) }
  private var leadText: String {
    guard session.opponent != nil else { return "NO RIVAL YET" }
    if lead == 0 { return "TIED" }
    return lead > 0 ? "▲ \(lead.formatted()) AHEAD" : "▼ \((-lead).formatted()) BEHIND"
  }
  private var leadColor: Color { lead >= 0 ? gold : Theme.red }

  private var connectionVeil: some View {
    VStack(spacing: 10) {
      ProgressView().tint(gold).scaleEffect(1.4)
      Text(session.status).font(Theme.display(22)).foregroundStyle(gold).tracking(3)
      Text("Your inputs pause until the link is back. The song keeps the shared clock.")
        .font(Theme.body(13)).foregroundStyle(.white.opacity(0.8))
    }
    .padding(28).background(ink.opacity(0.92)).overlay(Rectangle().stroke(gold.opacity(0.6)))
    .allowsHitTesting(false)
  }

  // MARK: Results

  private var results: some View {
    GeometryReader { viewport in
      ScrollView {
        VStack(spacing: 18) {
          brand
          Text("TRACK COMPLETE").font(Theme.label(12)).tracking(5).foregroundStyle(gold)
          Text(resultTitle).font(Theme.display(51)).italic()
          Text(resultSubtitle).font(Theme.body(14)).foregroundStyle(.white.opacity(0.85))
          Text(
            "\(session.chart?.title ?? "")   /   ROOM \(session.roomCode)   /   ROUND \(session.state?.round ?? 0)"
          )
          .font(Theme.label(10)).tracking(1).foregroundStyle(Theme.muted)
          HStack(spacing: 18) {
            ForEach(session.state?.players ?? []) { player in resultCard(player) }
          }.frame(maxWidth: 800)
          HStack(spacing: 15) {
            ArcadeButton(
              title: session.me?.ready == true ? "CANCEL REMATCH" : "REMATCH", style: .primary
            ) { session.ready() }
            ArcadeButton(
              title: "RECONNECT", style: session.status == "CONNECTED" ? .quiet : .secondary
            ) {
              session.reconnect()
            }
            ArcadeButton(title: "LEAVE ROOM", style: .quiet) { session.leave() }
          }.frame(maxWidth: 800)
          Text(rematchHint).font(Theme.body(13)).foregroundStyle(cyan)
          if session.demo {
            Text("AUTOMATED INPUT DRIVER • NETWORK-VERIFIED RESULTS").font(Theme.label(10))
              .foregroundStyle(gold)
          }
        }.padding(24).frame(maxWidth: .infinity, minHeight: viewport.size.height)
      }
      .background {
        Image("aria").resizable().scaledToFill()
          .frame(width: viewport.size.width, height: viewport.size.height)
          .clipped().opacity(0.24).overlay(ink.opacity(0.55))
          .allowsHitTesting(false)
      }
    }
  }

  private var winnerID: String? {
    guard let players = session.state?.players, players.count == 2,
      players[0].score != players[1].score
    else { return nil }
    return players.max { $0.score < $1.score }?.id
  }

  private var resultTitle: String {
    guard let me = session.me, let opponent = session.opponent else { return "BATTLE COMPLETE" }
    if me.score == opponent.score { return "PERFECT SYMMETRY" }
    return me.score > opponent.score ? "YOU TAKE THE SKY" : "REACH EVEN HIGHER"
  }

  private var resultSubtitle: String {
    guard let me = session.me, let opponent = session.opponent else {
      return "Your rival left before the results came in."
    }
    let gap = abs(me.score - opponent.score).formatted()
    if me.score == opponent.score { return "Identical scores. Settle it with a rematch." }
    return me.score > opponent.score
      ? "You beat \(opponent.name) by \(gap) points."
      : "\(opponent.name) finished \(gap) points ahead."
  }

  private var rematchHint: String {
    if session.status != "CONNECTED" {
      return "Connection lost. Reconnect to keep your seat in this room."
    }
    if session.me?.ready == true {
      return session.opponent?.ready == true
        ? "Both ready — the rematch is starting."
        : "Waiting for \(session.opponent?.name ?? "your rival") to accept the rematch."
    }
    if session.opponent?.ready == true {
      return "\(session.opponent?.name ?? "Your rival") wants a rematch. Tap REMATCH to accept."
    }
    return "Both players choose REMATCH to play the same chart again."
  }

  private func resultCard(_ player: Player) -> some View {
    let won = player.id == winnerID
    return VStack(spacing: 10) {
      HStack {
        Text(player.name).font(.system(size: 19, weight: .black))
        Spacer()
        if won {
          Label("WINNER", systemImage: "crown.fill").font(Theme.label(9))
            .padding(.horizontal, 8).padding(.vertical, 4).background(gold).foregroundStyle(ink)
        }
        Text(player.id == session.playerID ? "YOU" : "RIVAL").font(Theme.label(10))
          .foregroundStyle(gold)
      }
      Text(String(format: "%07d", player.score)).font(Theme.display(43))
        .foregroundStyle(won || winnerID == nil ? gold : .white).monospacedDigit()
      HStack {
        Text(String(format: "%.2f%% ACCURACY", player.accuracy))
        Spacer()
        Text("\(player.maxCombo) MAX COMBO")
      }.font(Theme.label(10))
      Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
      resultRow("JUSTICE CRITICAL", player.counts.critical, gold, player)
      resultRow("JUSTICE", player.counts.justice, .yellow, player)
      resultRow("ATTACK", player.counts.attack, cyan, player)
      resultRow("MISS", player.counts.miss, Theme.red, player)
      if player.ready {
        Text("REMATCH ACCEPTED").font(Theme.label(9)).tracking(1.5).foregroundStyle(cyan)
          .padding(.top, 4)
      }
    }.padding(20).background(ink.opacity(0.94))
      .overlay(Rectangle().stroke(won ? gold : Theme.edge, lineWidth: won ? 2 : 1))
  }

  private func resultRow(_ title: String, _ value: Int, _ color: Color, _ player: Player)
    -> some View
  {
    let total = max(
      1, player.counts.critical + player.counts.justice + player.counts.attack + player.counts.miss)
    return VStack(spacing: 3) {
      HStack {
        Text(title)
        Spacer()
        Text("\(value)").monospacedDigit()
      }.font(Theme.label(11)).foregroundStyle(color)
      GeometryReader { bar in
        ZStack(alignment: .leading) {
          Rectangle().fill(color.opacity(0.15))
          Rectangle().fill(color).frame(width: bar.size.width * CGFloat(value) / CGFloat(total))
        }
      }.frame(height: 3)
    }
  }

  // MARK: Guide

  private var guide: some View {
    ZStack {
      ink.opacity(0.98).ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          HStack {
            Text("YOUR HANDS. THE SKY.").font(.system(size: 34, weight: .black)).foregroundStyle(
              gold)
            Spacer()
            Button {
              session.guide = false
            } label: {
              Image(systemName: "xmark").font(.system(size: 16, weight: .heavy)).foregroundStyle(
                gold
              )
              .padding(12).overlay(Rectangle().stroke(gold.opacity(0.45))).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("closeGuide")
          }
          Text(
            "Play on the sixteen-segment slider below the gold line.\nMatch the notes as they reach the line, in time with the music."
          ).font(Theme.body(17))
          guideRow("TAP", "Touch anywhere across the red note's width.", Theme.red)
          guideRow(
            "HOLD",
            "Keep a finger down through the gold ribbon. Releasing loses ticks; reholding recovers.",
            gold)
          guideRow(
            "SLIDE", "Keep touching and follow the cyan ribbon horizontally across the slider.",
            cyan)
          guideRow(
            "AIR ↑",
            "Start on the slider, then swipe upward by at least 9% of the screen in under half a second.",
            Theme.green)
          VStack(alignment: .leading, spacing: 8) {
            Text("TIMING").font(Theme.label(11)).tracking(2).foregroundStyle(gold)
            HStack(spacing: 14) {
              timingChip("JUSTICE CRITICAL", "±45 ms", gold)
              timingChip("JUSTICE", "±90 ms", .yellow)
              timingChip("ATTACK", "±160 ms", cyan)
              timingChip("AIR", "±200 ms", Theme.green)
            }
          }
          HStack {
            Text("INPUT OFFSET").font(Theme.label(12))
            Slider(value: $session.timingOffset, in: -150...150, step: 5)
              .tint(gold).onChange(of: session.timingOffset) { _, value in
                UserDefaults.standard.set(value, forKey: "timingOffset")
              }
            Text("\(Int(session.timingOffset)) ms").font(.system(size: 13, design: .monospaced))
              .frame(width: 75)
          }
          Text(
            "Hitting early? Move the offset right. Hitting late? Move it left. Music is scheduled to the shared room clock."
          )
          .font(Theme.body(12)).foregroundStyle(Theme.muted)
          ArcadeButton(title: "LET'S FLY", style: .primary) { session.guide = false }
        }.padding(35).frame(maxWidth: 900)
      }
    }
  }

  private func timingChip(_ title: String, _ window: String, _ color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(Theme.label(9)).tracking(1)
      Text(window).font(.system(size: 14, weight: .heavy, design: .monospaced))
    }
    .foregroundStyle(color).padding(10).frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.1)).overlay(Rectangle().stroke(color.opacity(0.4)))
  }

  private func guideRow(_ title: String, _ detail: String, _ color: Color) -> some View {
    HStack(alignment: .top, spacing: 18) {
      Text(title).font(.system(size: 18, weight: .black)).foregroundStyle(color).frame(
        width: 95, alignment: .leading)
      Text(detail).font(Theme.body(15))
    }
  }
}
