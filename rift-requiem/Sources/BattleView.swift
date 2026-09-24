import SwiftUI
import SpriteKit

struct BattleView: View {
    @ObservedObject var client: DuelClient
    @ObservedObject private var sound = Sound.shared
    @State private var scene: ArenaScene = {
        let scene = ArenaScene(size: CGSize(width: 1100, height: 520))
        scene.scaleMode = .aspectFill
        return scene
    }()
    @State private var menu = false
    @State private var confirmLeave = false
    @State private var lastHP: Double = 100

    var body: some View {
        ZStack {
            SpriteView(scene: scene).ignoresSafeArea()
            VStack(spacing: 0) {
                hud
                statusLine
                Spacer()
                if client.automated {
                    Text("AUTOMATED INPUT DRIVER  •  \(client.driverStep)")
                        .font(Type.label(8)).padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Palette.black.opacity(0.85)).foregroundStyle(Palette.gold)
                        .padding(.bottom, 4)
                }
                controls
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            overlays
            if menu { menuPlate }
        }
        .onAppear { scene.match = client.state }
        .onChange(of: client.state?.tick) { _, _ in
            scene.match = client.state
            if let hp = client.me?.hp {
                if hp < lastHP { Haptics.hit() }
                lastHP = hp
            }
        }
        .animation(.easeOut(duration: 0.18), value: menu)
    }

    private var slot: Int { client.me?.slot ?? 0 }
    private var players: [Duelist] { client.state?.players ?? [] }
    private var fighting: Bool { client.state?.phase == "fight" && client.state?.paused != true && client.connected }

    // MARK: Top HUD

    private var hud: some View {
        HStack(alignment: .top, spacing: 6) {
            if let first = players.first { playerHUD(first, mirror: false) }
            timer
            if players.count > 1, let last = players.last { playerHUD(last, mirror: true) }
        }
    }

    private var timer: some View {
        let seconds = Int(ceil(client.state?.seconds ?? 60))
        return ZStack {
            Gear().fill(Palette.plate)
            Gear().stroke(Palette.gold, lineWidth: 2)
            Circle().stroke(Palette.cream.opacity(0.4), lineWidth: 1).padding(9)
            VStack(spacing: -7) {
                Text("\(seconds)").font(Type.display(40))
                    .foregroundStyle(seconds <= 10 ? Palette.red : Palette.cream)
                    .contentTransition(.numericText())
                Text("ROUND \(client.state?.round ?? 1)").font(Type.label(7))
                    .foregroundStyle(Palette.gold)
            }
        }
        .frame(width: 84, height: 72)
        .accessibilityLabel("\(seconds) seconds, round \(client.state?.round ?? 1)")
    }

    private func playerHUD(_ player: Duelist, mirror: Bool) -> some View {
        let mine = player.id == client.playerID
        return VStack(alignment: mirror ? .trailing : .leading, spacing: 3) {
            HStack(spacing: 6) {
                if mirror { Spacer(minLength: 0) }
                Text(player.style.uppercased()).font(Type.display(24))
                    .shadow(color: Palette.red, radius: 0, x: 2, y: 1)
                Text(player.name).font(Type.body(10)).lineLimit(1).foregroundStyle(Palette.cream.opacity(0.85))
                if mine { Chip(text: "YOU", fill: Palette.gold, foreground: Palette.black) }
                if !mirror { Spacer(minLength: 0) }
            }
            GeometryReader { geo in
                ZStack(alignment: mirror ? .trailing : .leading) {
                    BladePanel().fill(Palette.black.opacity(0.9))
                    BladePanel().fill(Palette.darkRed.opacity(0.8))
                    BladePanel().fill(LinearGradient(colors: [Palette.red, .orange, Palette.gold],
                                                     startPoint: .bottom, endPoint: .top))
                        .frame(width: max(0, geo.size.width * player.hp / 100))
                        .animation(.easeOut(duration: 0.25), value: player.hp)
                    BladePanel().stroke(mine ? Palette.gold : Palette.cream.opacity(0.8), lineWidth: mine ? 2 : 1.2)
                    HStack(spacing: 0) {
                        ForEach(0..<10, id: \.self) { _ in
                            Rectangle().fill(.black.opacity(0.35)).frame(width: 1)
                            Spacer(minLength: 0)
                        }
                    }.padding(.horizontal, 10)
                    Text("\(Int(player.hp))").font(Type.label(10))
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: mirror ? .leading : .trailing)
                        .shadow(color: .black, radius: 1)
                }
            }.frame(height: 20)
            HStack(spacing: 6) {
                if mirror { Spacer(minLength: 0) }
                ForEach(0..<2, id: \.self) { index in
                    Image(systemName: index < player.wins ? "diamond.fill" : "diamond")
                        .font(.system(size: 10)).foregroundStyle(Palette.gold)
                }
                if player.combo > 1 {
                    Text("\(player.combo) HIT").font(Type.display(16)).foregroundStyle(Palette.gold)
                        .shadow(color: Palette.red, radius: 0, x: 1, y: 1)
                        .transition(.scale.combined(with: .opacity))
                }
                if !player.connected {
                    Chip(text: "DISCONNECTED", fill: Palette.red)
                }
                if !mirror { Spacer(minLength: 0) }
            }
            .frame(height: 18)
            .animation(.spring(duration: 0.2), value: player.combo)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(player.style) \(Int(player.hp)) health, \(player.wins) rounds won")
    }

    private var statusLine: some View {
        HStack {
            Text("THE CATHEDRAL ENGINE")
            Spacer()
            Circle().fill(client.connected ? Color(red: 0.45, green: 0.85, blue: 0.55) : Palette.red)
                .frame(width: 6, height: 6)
            Text("ROOM \(client.code)  •  \(client.connected ? "LIVE" : "RECONNECTING")  •  P\(slot + 1)")
        }
        .font(Type.label(8)).tracking(1).foregroundStyle(Palette.cream.opacity(0.7))
        .padding(.horizontal, 6).padding(.top, 2)
    }

    // MARK: Bottom HUD

    private var meters: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(players) { player in
                let mirror = player.slot == 1
                VStack(alignment: mirror ? .trailing : .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        if mirror { Spacer(minLength: 0) }
                        Text("TENSION").foregroundStyle(Palette.muted)
                        Text("\(Int(player.meter))%").foregroundStyle(Palette.gold)
                        Text(player.meter >= 50 ? "RED RC" : player.meter >= 25 ? "YELLOW RC" : "BUILD")
                            .foregroundStyle(player.meter >= 50 ? Palette.red : player.meter >= 25 ? Palette.gold : Palette.muted)
                        if !mirror { Spacer(minLength: 0) }
                    }.font(Type.label(8)).lineLimit(1).minimumScaleFactor(0.7)
                    GeometryReader { geometry in
                        ZStack(alignment: mirror ? .trailing : .leading) {
                            BladePanel(cut: 6).fill(Palette.black.opacity(0.85))
                            BladePanel(cut: 6).fill(player.meter >= 50 ? Palette.red : Palette.gold)
                                .frame(width: geometry.size.width * player.meter / 100)
                                .animation(.easeOut(duration: 0.2), value: player.meter)
                            BladePanel(cut: 6).stroke(Palette.gold.opacity(0.8), lineWidth: 1)
                            HStack(spacing: 0) {
                                Spacer().frame(width: geometry.size.width * 0.25)
                                Rectangle().fill(Palette.cream.opacity(0.7)).frame(width: 1)
                                Spacer().frame(width: geometry.size.width * 0.25)
                                Rectangle().fill(Palette.cream).frame(width: 1.5)
                                Spacer(minLength: 0)
                            }
                        }
                    }.frame(height: 9)
                }
                .frame(maxWidth: 170)
            }
        }
    }

    private var controls: some View {
        let meter = client.me?.meter ?? 0
        let cancelTint = meter >= 50 ? Palette.red : meter >= 25 ? Palette.gold.opacity(0.9) : Palette.plate
        return HStack(alignment: .bottom, spacing: 10) {
            HStack(alignment: .bottom, spacing: 6) {
                HoldControl(title: "◀", subtitle: "MOVE", tint: Palette.plate, width: 58) { down in
                    client.action("move", value: down ? -1 : 0)
                }.accessibilityIdentifier("move-left")
                VStack(spacing: 6) {
                    actionButton("↑", subtitle: "JUMP", action: "jump", tint: Palette.plate, width: 54)
                    actionButton("»", subtitle: "DASH", action: "dash", tint: Palette.plate, width: 54)
                }
                HoldControl(title: "▶", subtitle: "MOVE", tint: Palette.plate, width: 58) { down in
                    client.action("move", value: down ? 1 : 0)
                }.accessibilityIdentifier("move-right")
            }
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Button { menu = true; confirmLeave = false } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal").font(.system(size: 12, weight: .bold))
                        Text("MENU").font(Type.label(8))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(Palette.black.opacity(0.75)))
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.6), lineWidth: 1))
                }.buttonStyle(.plain).accessibilityIdentifier("duel-menu")
                meters
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 6) {
                HoldControl(title: "◇", subtitle: "GUARD", tint: Palette.steel.opacity(0.9), width: 58) { down in
                    client.action("guard", value: down ? 1 : 0)
                }.accessibilityIdentifier("guard")
                actionButton("RC", subtitle: "CANCEL", action: "cancel", tint: cancelTint, width: 54,
                             glow: meter >= 25)
                VStack(spacing: 6) {
                    actionButton("SP", subtitle: "SPECIAL", action: "special", tint: Palette.violet.opacity(0.85), width: 56)
                    actionButton("S", subtitle: "SLASH", action: "slash", tint: Palette.red, width: 56)
                }
                actionButton("H", subtitle: "HEAVY", action: "heavy", tint: Palette.darkRed, width: 60, tall: true)
            }
        }
        .foregroundStyle(Palette.cream)
        .disabled(!fighting)
        .opacity(fighting ? 1 : 0.55)
        .animation(.easeOut(duration: 0.2), value: fighting)
    }

    private func actionButton(_ title: String, subtitle: String, action: String, tint: Color, width: CGFloat,
                              glow: Bool = false, tall: Bool = false) -> some View {
        Button { Haptics.tap(); client.action(action) } label: {
            ControlFace(title: title, subtitle: subtitle, tint: tint, glow: glow, height: tall ? 88 : 41)
                .frame(width: width)
        }
        .buttonStyle(ControlPress())
        .accessibilityLabel(subtitle).accessibilityIdentifier(action)
    }

    // MARK: Overlays

    @ViewBuilder private var overlays: some View {
        if let state = client.state {
            if state.paused || !client.connected {
                centerPlate(title: "SIGNAL LOST",
                            subtitle: client.connected ? "DUEL PAUSED  •  RIVAL RECONNECTING  •  30s GRACE"
                                                       : "RECONNECTING\(client.retryAttempt > 0 ? "  •  ATTEMPT \(client.retryAttempt)" : "")…")
            } else if state.phase == "countdown" {
                countdownPlate(state)
            } else if state.phase == "roundEnd" {
                roundPlate(state)
            } else if state.phase == "result" {
                result(state)
            }
        }
    }

    private func countdownPlate(_ state: MatchState) -> some View {
        let count = max(1, Int(ceil(Double(state.countdown) / 60)))
        return VStack(spacing: -4) {
            Text("ROUND \(state.round)").font(Type.display(30)).foregroundStyle(Palette.gold)
            Text("\(count)").font(Type.display(96)).foregroundStyle(Palette.red)
                .contentTransition(.numericText(countsDown: true))
                .shadow(color: Palette.cream, radius: 0, x: 3, y: 3)
            Text(state.round == 1 ? "HEAVEN'S GATES ARE OPEN" : "DRAW YOUR WEAPON")
                .font(Type.label(9)).tracking(3).foregroundStyle(Palette.cream.opacity(0.85))
        }
        .padding(.horizontal, 70).padding(.vertical, 10)
        .background(BladePanel(cut: 20).fill(Palette.black.opacity(0.82)))
        .overlay(BladePanel(cut: 20).stroke(Palette.gold, lineWidth: 1))
        .animation(.easeOut(duration: 0.3), value: count)
        .allowsHitTesting(false)
    }

    private func roundPlate(_ state: MatchState) -> some View {
        let winner = players.first { $0.id == state.roundWinner }
        let knockout = players.contains { $0.hp <= 0 }
        let mine = winner?.id == client.playerID
        return VStack(spacing: 4) {
            Text(knockout ? "K.O." : "TIME").font(Type.display(60))
                .foregroundStyle(knockout ? Palette.red : Palette.gold)
            Text(winner == nil ? "ROUND \(state.round) IS A DRAW"
                 : "\(winner?.style.uppercased() ?? "") TAKES ROUND \(state.round)")
                .font(Type.display(26))
            if winner != nil {
                Text(mine ? "YOU WIN THE ROUND" : "YOU LOSE THE ROUND").font(Type.label(9)).tracking(3)
                    .foregroundStyle(mine ? Palette.gold : Palette.muted)
            }
            HStack(spacing: 20) {
                ForEach(players) { player in
                    HStack(spacing: 5) {
                        Text(player.style.uppercased()).font(Type.label(9))
                        ForEach(0..<2, id: \.self) { index in
                            Image(systemName: index < player.wins ? "diamond.fill" : "diamond")
                                .font(.system(size: 9)).foregroundStyle(Palette.gold)
                        }
                    }
                }
            }.padding(.top, 2)
        }
        .padding(.horizontal, 50).padding(.vertical, 14)
        .background(BladePanel(cut: 20).fill(Palette.black.opacity(0.9)))
        .overlay(BladePanel(cut: 20).stroke(Palette.gold, lineWidth: 1))
        .allowsHitTesting(false)
    }

    private func centerPlate(title: String, subtitle: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(Type.display(42))
            Text(subtitle).font(Type.label(9)).tracking(2).multilineTextAlignment(.center)
        }
        .foregroundStyle(Palette.cream)
        .padding(.horizontal, 50).padding(.vertical, 16)
        .background(BladePanel(cut: 20).fill(Palette.black.opacity(0.9)))
        .overlay(BladePanel(cut: 20).stroke(Palette.gold, lineWidth: 1))
        .allowsHitTesting(false)
    }

    private func result(_ state: MatchState) -> some View {
        let winner = players.first { $0.id == state.winner }
        let mine = winner?.id == client.playerID
        let rival = players.first { $0.id != client.playerID }
        return VStack(spacing: 8) {
            Text("THE REQUIEM IS WRITTEN").font(Type.label(9)).tracking(3).foregroundStyle(Palette.gold)
            Text(winner == nil ? "DRAW" : mine ? "VICTORY" : "DEFEAT")
                .font(Type.display(54)).foregroundStyle(mine ? Palette.gold : Palette.red)
                .shadow(color: .black, radius: 0, x: 3, y: 3)
            Text(winner == nil ? "NEITHER DUELIST PREVAILS" : "\(winner?.style.uppercased() ?? "") WINS THE DUEL")
                .font(Type.display(20))
            HStack(spacing: 14) {
                ForEach(players) { player in
                    VStack(spacing: 3) {
                        Text(player.style.uppercased()).font(Type.display(18))
                        Text("\(player.wins)").font(.system(size: 26, weight: .black, design: .monospaced))
                        Chip(text: player.rematch ? "REMATCH ✓" : "DECIDING…",
                             fill: player.rematch ? Palette.gold : .white.opacity(0.12),
                             foreground: player.rematch ? Palette.black : Palette.muted)
                    }
                    .frame(width: 120).padding(.vertical, 6)
                    .background(player.id == client.playerID ? Palette.darkRed.opacity(0.6) : .black.opacity(0.4))
                    .overlay(Rectangle().stroke(.white.opacity(0.15), lineWidth: 1))
                }
            }
            HStack(spacing: 10) {
                Button {
                    Haptics.tap(); client.rematch()
                } label: {
                    Text(client.me?.rematch == true
                         ? (rival?.rematch == true ? "STARTING…" : "WAITING FOR RIVAL")
                         : (rival?.rematch == true ? "ACCEPT REMATCH" : "REMATCH"))
                }
                .buttonStyle(MetalButton(kind: .primary, expand: true))
                .disabled(client.me?.rematch == true).accessibilityIdentifier("rematch")
                Button("LEAVE ROOM") { client.leave() }.buttonStyle(MetalButton(kind: .ghost))
            }
            Text("Both duelists must accept  •  scores reset for the rematch").font(Type.body(10))
                .foregroundStyle(Palette.muted)
        }
        .padding(22).frame(width: 400)
        .background(BladePanel(cut: 20).fill(Palette.plate.opacity(0.97)))
        .overlay(BladePanel(cut: 20).stroke(Palette.gold, lineWidth: 2))
        .shadow(color: .black.opacity(0.7), radius: 30)
        .accessibilityIdentifier("match-result")
    }

    private var menuPlate: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { menu = false }
            VStack(spacing: 10) {
                Text("DUEL OPTIONS").font(Type.display(28))
                HStack(spacing: 8) {
                    Text("ROOM \(client.code)").font(Type.mono(12)).foregroundStyle(Palette.gold)
                    StatusPill(tone: client.connected ? .live : .bad, text: client.status)
                }
                Text("The online match continues while this menu is open.").font(Type.body(11))
                    .foregroundStyle(Palette.muted)
                Button("RETURN TO DUEL") { menu = false }.buttonStyle(MetalButton(kind: .primary, expand: true))
                HStack(spacing: 8) {
                    Button(sound.muted ? "ENABLE SOUND" : "MUTE SOUND") { sound.muted.toggle() }
                    Button("RECONNECT") { client.reconnect(); menu = false }
                }.buttonStyle(MetalButton(expand: true))
                Button(confirmLeave ? "CONFIRM — LEAVE ROOM" : "LEAVE ROOM") {
                    if confirmLeave { client.leave() } else { confirmLeave = true }
                }
                .buttonStyle(MetalButton(kind: confirmLeave ? .primary : .ghost, expand: true))
                .accessibilityIdentifier("leave-room")
            }
            .padding(22).frame(width: 360)
            .background(BladePanel(cut: 16).fill(Palette.plate))
            .overlay(BladePanel(cut: 16).stroke(Palette.gold, lineWidth: 1))
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }
}

struct ControlPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .brightness(configuration.isPressed ? 0.25 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct ControlFace: View {
    let title: String
    let subtitle: String
    let tint: Color
    var glow = false
    var height: CGFloat = 41
    var body: some View {
        VStack(spacing: -3) {
            Text(title).font(Type.display(height > 60 ? 30 : 24))
            Text(subtitle).font(Type.label(7)).tracking(0.5).foregroundStyle(Palette.cream.opacity(0.85))
        }
        .frame(maxWidth: .infinity).frame(height: height)
        .background(BladePanel(cut: 8).fill(tint.opacity(0.92)))
        .overlay(BladePanel(cut: 8).stroke(glow ? Palette.gold : Palette.cream.opacity(0.7), lineWidth: glow ? 1.8 : 1))
        .shadow(color: glow ? Palette.gold.opacity(0.7) : .black.opacity(0.5), radius: glow ? 8 : 3, y: 2)
        .contentShape(Rectangle())
    }
}

struct HoldControl: View {
    let title: String
    let subtitle: String
    let tint: Color
    var width: CGFloat = 58
    let changed: (Bool) -> Void
    @State private var down = false
    var body: some View {
        ControlFace(title: title, subtitle: subtitle, tint: down ? Palette.red : tint, glow: down, height: 88)
            .frame(width: width)
            .scaleEffect(down ? 0.95 : 1)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !down { down = true; Haptics.tap(); changed(true) } }
                .onEnded { _ in down = false; changed(false) })
            .onDisappear { if down { changed(false) } }
            .accessibilityLabel(subtitle)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { changed(true); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { changed(false) } }
    }
}
