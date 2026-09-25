import SwiftUI
import SpriteKit

@main
struct RiftApp: App {
    @StateObject private var client = DuelClient()
    var body: some Scene {
        WindowGroup {
            RootView(client: client)
                .preferredColorScheme(.dark)
                .onOpenURL { client.open($0) }
                .onAppear {
                    Sound.shared.start()
                    if Launch.value("connect") == "1" { client.connect() }
                }
        }
    }
}

struct RootView: View {
    @ObservedObject var client: DuelClient
    @ObservedObject private var sound = Sound.shared
    @State private var showGuide = false

    var body: some View {
        ZStack {
            Palette.black.ignoresSafeArea()
            if let state = client.state, state.phase != "lobby" {
                BattleView(client: client)
            } else {
                LobbyView(client: client, showGuide: $showGuide)
            }
            if !client.error.isEmpty {
                Color.black.opacity(0.55).ignoresSafeArea()
                errorPlate
            }
            if showGuide {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture { showGuide = false }
                GuideView { showGuide = false }
            }
        }
        .foregroundStyle(Palette.cream)
        .statusBarHidden()
        .animation(.easeOut(duration: 0.2), value: client.error.isEmpty)
        .animation(.easeOut(duration: 0.2), value: showGuide)
    }

    private var errorPlate: some View {
        VStack(spacing: 14) {
            Text("SIGNAL INTERRUPTED").font(Type.display(30)).foregroundStyle(Palette.red)
            Text(client.error).font(Type.body(13)).multilineTextAlignment(.center)
                .foregroundStyle(Palette.cream.opacity(0.9))
            HStack(spacing: 10) {
                if client.state == nil {
                    Button("RETRY") { client.connect() }.buttonStyle(MetalButton(kind: .primary))
                }
                Button("DISMISS") { client.error = "" }.buttonStyle(MetalButton())
            }
        }
        .padding(26).frame(maxWidth: 440)
        .background(BladePanel(cut: 14).fill(Palette.plate))
        .overlay(BladePanel(cut: 14).stroke(Palette.red, lineWidth: 1.5))
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
}

struct LobbyView: View {
    @ObservedObject var client: DuelClient
    @ObservedObject private var sound = Sound.shared
    @Binding var showGuide: Bool
    @FocusState private var focus: Field?
    @State private var copied = false
    @State private var roomInput = ""

    enum Field { case name, room, server }

    var body: some View {
        ZStack {
            ZStack {
                Color.clear.overlay(Image("cathedral").resizable().scaledToFill()).clipped()
                LinearGradient(colors: [.black.opacity(0.92), .black.opacity(0.55), .black.opacity(0.92)],
                               startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black.opacity(0.6), .clear, .black.opacity(0.7)],
                               startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
            .onTapGesture { focus = nil }
            GeometryReader { geometry in
                HStack(spacing: geometry.size.width < 700 ? 12 : 24) {
                    hero(height: geometry.size.height)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    panel
                        .frame(width: min(geometry.size.width * 0.6, 470))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
    }

    private func hero(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CATHEDRAL ENGINE  /  NETWORK DUEL").font(Type.label(9)).tracking(2.5)
                .foregroundStyle(Palette.gold)
            Text("RIFT\nREQUIEM")
                .font(Type.display(min(height * 0.17, 72)))
                .lineSpacing(-18).shadow(color: Palette.red, radius: 0, x: 4, y: 4)
                .shadow(color: .black.opacity(0.9), radius: 12)
            Rectangle().fill(Palette.red).frame(width: 190, height: 4).padding(.vertical, 6)
            Text("BREAK THE CLOCK.\nWRITE YOUR REQUIEM.").font(Type.demi(14)).tracking(2)
                .foregroundStyle(Palette.cream.opacity(0.9))
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Button("HOW TO FIGHT") { showGuide = true }.buttonStyle(MetalButton())
                Button(sound.muted ? "SOUND OFF" : "SOUND ON") { sound.muted.toggle() }
                    .buttonStyle(MetalButton(kind: .ghost))
            }
            Text("ORIGINAL FIGHTERS  •  REAL-TIME TWO-PLAYER  •  BEST OF THREE")
                .font(Type.label(8)).foregroundStyle(Palette.gold.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if client.connected {
                roomLobby
            } else {
                connectionForm
            }
        }
        .padding(16)
        .background(BladePanel(cut: 16).fill(Palette.plate.opacity(0.96)))
        .overlay(BladePanel(cut: 16).stroke(Palette.gold.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 20, y: 8)
        .animation(.easeOut(duration: 0.25), value: client.connected)
    }

    // MARK: Connection form

    private var connectionForm: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(index: "01", title: "CHOOSE YOUR DUELIST")
            HStack(spacing: 8) {
                FighterCard(style: "rook", selected: client.style == "rook") { client.style = "rook"; Haptics.tap() }
                FighterCard(style: "vesper", selected: client.style == "vesper") { client.style = "vesper"; Haptics.tap() }
            }
            SectionLabel(index: "02", title: joining ? "JOIN A DUEL ROOM" : "OPEN A DUEL ROOM")
            HStack(alignment: .top, spacing: 8) {
                field("GUEST NAME", text: $client.name, prompt: "Guest", focus: .name)
                    .frame(maxWidth: .infinity)
                field("ROOM CODE", text: $roomInput, prompt: "BLANK = NEW", focus: .room, code: true)
                    .frame(width: 150)
                    .onAppear { roomInput = client.roomCode }
                    .onChange(of: roomInput) { _, value in
                        client.roomCode = String(value.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                    }
                    .onChange(of: focus) { _, value in
                        if value != .room { roomInput = client.roomCode }
                    }
            }
            field("SERVER ADDRESS", text: $client.address, prompt: "ws://host:8787", focus: .server)
            Button {
                focus = nil
                client.connect()
            } label: {
                HStack {
                    Text(joining ? "JOIN ROOM \(client.roomCode)" : "CREATE DUEL ROOM")
                    Spacer()
                    Image(systemName: client.connecting ? "hourglass" : "arrow.right")
                }
            }
            .buttonStyle(MetalButton(kind: .primary, expand: true))
            .disabled(client.connecting)
            .accessibilityIdentifier("connect")
            StatusPill(tone: client.connecting ? .busy : .idle, text: client.status)
        }
    }

    private var joining: Bool { !client.roomCode.isEmpty }

    private func field(_ label: String, text: Binding<String>, prompt: String, focus target: Field,
                       code: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(Type.label(8)).tracking(1.5).foregroundStyle(Palette.gold)
            HStack(spacing: 4) {
                TextField(prompt, text: text)
                    .textInputAutocapitalization(code ? .characters : .never).autocorrectionDisabled()
                    .keyboardType(target == .server ? .URL : .default)
                    .submitLabel(target == .server ? .join : .next)
                    .font(code ? Type.mono(15) : Type.mono(12))
                    .focused($focus, equals: target)
                    .onSubmit {
                        switch target {
                        case .name: focus = .room
                        case .room: focus = .server
                        case .server: focus = nil; client.connect()
                        }
                    }
                    .accessibilityIdentifier(label)
                if !text.wrappedValue.isEmpty && focus == target {
                    Button { text.wrappedValue = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                    }.buttonStyle(.plain).accessibilityLabel("Clear \(label)")
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 8)
            .background(Rectangle().fill(.white.opacity(focus == target ? 0.12 : 0.06)))
            .overlay(Rectangle().stroke(focus == target ? Palette.gold : Palette.cream.opacity(0.15), lineWidth: 1))
        }
        .onTapGesture { focus = target }
    }

    // MARK: Room lobby

    private var roomLobby: some View {
        let players = client.state?.players ?? []
        let bothReady = players.count == 2 && players.allSatisfy(\.ready)
        return VStack(alignment: .leading, spacing: 9) {
            SectionLabel(index: "01", title: "SHARE THE ROOM CODE")
            HStack(alignment: .center, spacing: 12) {
                Text(client.code).font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundStyle(Palette.gold).tracking(3).accessibilityIdentifier("roomCode")
                Button {
                    UIPasteboard.general.string = client.code
                    copied = true
                    Haptics.notify(.success)
                    Task { try? await Task.sleep(for: .seconds(1.6)); copied = false }
                } label: {
                    Label(copied ? "COPIED" : "COPY", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(Type.label(9))
                }.buttonStyle(MetalButton(kind: .ghost)).accessibilityIdentifier("copy-code")
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("SECOND DEVICE").font(Type.label(7)).foregroundStyle(Palette.muted)
                    Text("Enter this code, then JOIN").font(Type.body(10))
                }
            }
            SectionLabel(index: "02", title: "DUELISTS")
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { slot in
                    if let player = players.first(where: { $0.slot == slot }) {
                        PlayerCard(player: player, isMe: player.id == client.playerID)
                    } else {
                        EmptySlot()
                    }
                }
            }
            SectionLabel(index: "03", title: bothReady ? "DUEL STARTING" : "READY UP")
            HStack(spacing: 8) {
                Button {
                    Haptics.tap(); client.ready()
                } label: {
                    HStack {
                        Image(systemName: client.me?.ready == true ? "checkmark.seal.fill" : "flame.fill")
                        Text(readyTitle(players: players, bothReady: bothReady))
                    }
                }
                .buttonStyle(MetalButton(kind: .primary, expand: true))
                .disabled(client.me?.ready == true)
                .accessibilityIdentifier("ready")
                Button("LEAVE") { client.leave() }.buttonStyle(MetalButton(kind: .ghost))
                    .accessibilityIdentifier("leave-room")
            }
            StatusPill(tone: .live, text: client.status)
        }
    }

    private func readyTitle(players: [Duelist], bothReady: Bool) -> String {
        if bothReady { return "BOTH READY" }
        if client.me?.ready == true { return players.count < 2 ? "READY — AWAITING CHALLENGER" : "READY — AWAITING RIVAL" }
        return "READY / DRAW WEAPONS"
    }
}

struct FighterCard: View {
    let style: String
    let selected: Bool
    let action: () -> Void

    private var title: String { style == "rook" ? "ROOK" : "VESPER" }
    private var weapon: String { style == "rook" ? "ENGINE CLEAVER" : "CRESCENT SCYTHE" }
    private var traits: [(String, Int)] {
        style == "rook" ? [("POWER", 3), ("REACH", 2), ("SPEED", 2)] : [("POWER", 2), ("REACH", 3), ("SPEED", 3)]
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                FighterPreview(style: style).frame(width: 62, height: 84).clipped().allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Type.display(19))
                    Text(weapon).font(Type.label(7)).tracking(0.5).foregroundStyle(Palette.gold)
                    ForEach(traits, id: \.0) { trait in
                        HStack(spacing: 3) {
                            Text(trait.0).font(Type.label(6)).frame(width: 30, alignment: .leading)
                                .foregroundStyle(Palette.muted)
                            ForEach(0..<3, id: \.self) { pip in
                                Rectangle().fill(pip < trait.1 ? Palette.red : .white.opacity(0.15))
                                    .frame(width: 9, height: 4)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(Palette.gold)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(selected ? Palette.darkRed.opacity(0.9) : .black.opacity(0.5))
            .overlay(Rectangle().stroke(selected ? Palette.gold : .white.opacity(0.15), lineWidth: selected ? 1.5 : 1))
            .scaleEffect(selected ? 1 : 0.98)
            .animation(.easeOut(duration: 0.15), value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("select-\(style)")
        .accessibilityLabel("\(title), \(weapon)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct PlayerCard: View {
    let player: Duelist
    let isMe: Bool
    var body: some View {
        HStack(spacing: 6) {
            FighterPreview(style: player.style).frame(width: 50, height: 70).clipped()
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(player.style.uppercased()).font(Type.display(18))
                    if isMe { Chip(text: "YOU") }
                }
                Text(player.name).font(Type.body(11)).lineLimit(1).foregroundStyle(Palette.cream.opacity(0.85))
                Chip(text: player.ready ? "READY" : "STANDBY",
                     fill: player.ready ? Palette.gold : .white.opacity(0.12),
                     foreground: player.ready ? Palette.black : Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(isMe ? Palette.darkRed.opacity(0.7) : .black.opacity(0.5))
        .overlay(Rectangle().stroke(player.ready ? Palette.gold : .white.opacity(0.15), lineWidth: 1))
        .animation(.easeOut(duration: 0.2), value: player.ready)
    }
}

struct EmptySlot: View {
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.fill.questionmark").font(.system(size: 20))
                .foregroundStyle(Palette.muted).opacity(pulse ? 0.4 : 1)
            Text("WAITING FOR A CHALLENGER").font(Type.label(8)).tracking(1).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 78)
        .overlay(Rectangle().stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundStyle(Palette.gold.opacity(0.5)))
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { pulse = true } }
    }
}

struct GuideView: View {
    let dismiss: () -> Void
    private let rows: [(String, String, String)] = [
        ("◀ ▶", "MOVE", "Hold to walk. Walking forward builds Tension."),
        ("↑  »", "JUMP / DASH", "Dash on the ground, or once per jump in the air."),
        ("S  H", "SLASH / HEAVY", "Quick slash, or heavy weapon: longer reach, longer recovery."),
        ("SP", "SPECIAL", "Fires a travelling projectile across the stage."),
        ("◇", "GUARD", "Hold to block attacks you are facing. Chip damage still lands."),
        ("RC", "REQUIEM CANCEL", "25% meter in neutral, 50% mid-attack. Ends recovery and slows your rival.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("THE DUELIST'S CODE").font(Type.display(30))
                Spacer()
                Text("BEST OF 3  •  60s ROUNDS").font(Type.label(9)).foregroundStyle(Palette.gold)
            }
            ForEach(rows, id: \.1) { row in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(row.0).font(Type.display(16)).frame(width: 46, alignment: .leading)
                        .foregroundStyle(Palette.gold)
                    Text(row.1).font(Type.label(9)).frame(width: 110, alignment: .leading)
                    Text(row.2).font(Type.body(12)).foregroundStyle(Palette.cream.opacity(0.85))
                }
            }
            Text("Combo: land a hit → RC → follow with a weapon. Both duelists must vote for a rematch.")
                .font(Type.body(11)).foregroundStyle(Palette.muted)
            Button("RETURN TO THE RIFT", action: dismiss).buttonStyle(MetalButton(kind: .primary, expand: true))
        }
        .padding(22).frame(maxWidth: 680)
        .background(BladePanel(cut: 14).fill(Palette.plate))
        .overlay(BladePanel(cut: 14).stroke(Palette.gold, lineWidth: 1))
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
}

struct FighterPreview: View {
    let style: String
    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
    }
    private var scene: SKScene {
        let scene = SKScene(size: CGSize(width: 150, height: 200))
        scene.backgroundColor = .clear
        scene.scaleMode = .aspectFit
        let art = FighterArt(style: style)
        art.position = CGPoint(x: 78, y: -14)
        art.setScale(0.82)
        art.animate(pose: "idle", frame: 0, time: 0, facing: 1, stunned: false)
        scene.addChild(art)
        return scene
    }
}
