import CourtCore
import SwiftUI

struct LobbyScreen: View {
    @ObservedObject var store: CourtStore
    let wide: Bool
    let openPGN: () -> Void
    @State private var inviteCode = ""
    @State private var publicRoom = true
    @State private var spectate = false
    @State private var botFallback = true
    @State private var customMinutes = 5.0
    @State private var customIncrement = 3.0
    private var enabled: Bool {
        store.ready && !store.busy && store.queue == nil
    }

    var body: some View {
        VStack(spacing: 24) {
            marquee
            if wide {
                HStack(alignment: .top, spacing: 24) {
                    playCard
                    VStack(spacing: 24) { inviteCard; roomsCard; reviewCard }
                }
            } else {
                playCard; inviteCard; roomsCard; reviewCard
            }
            HStack {
                Text("CHESS. WITH A LITTLE MORE GAME.").font(Arcade.mono(10))
                Spacer()
                Text("Server-authoritative · Protocol 1").font(.caption2)
            }.foregroundStyle(.secondary)
        }
        .frame(maxWidth: 1180)
        .frame(maxWidth: .infinity)
    }

    private var marquee: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("THE COURT IS OPEN").font(Arcade.mono(11)).foregroundStyle(Arcade.aqua)
                Text("MAKE\nYOUR MOVE.").font(Arcade.display(wide ? 46 : 32)).lineSpacing(-3)
                    .fixedSize(horizontal: false, vertical: true).foregroundStyle(.white)
                Text("One board. Endless possibilities.\nPull up a seat and play.").foregroundStyle(.white.opacity(0.78))
                Label("\(store.online) players online", systemImage: "circle.fill")
                    .font(.caption.bold()).foregroundStyle(Arcade.sunshine)
            }.padding(wide ? 32 : 22).frame(maxWidth: .infinity, alignment: .leading)
            if wide, let url = Bundle.main.url(forResource: "arena", withExtension: "png", subdirectory: "art"),
               let data = try? Data(contentsOf: url)
            {
                #if os(macOS)
                    if let image = NSImage(data: data) {
                        Image(nsImage: image).resizable().scaledToFill().frame(width: 350, height: 270).clipped().accessibilityHidden(true)
                    }
                #else
                    if let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 350, height: 270).clipped().accessibilityHidden(true)
                    }
                #endif
            }
        }
        .background(LinearGradient(colors: [Arcade.royal, Color(hex: 0x172E85)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color(hex: 0x5978E7), lineWidth: 2))
        .shadow(color: Arcade.midnight.opacity(0.3), radius: 0, y: 6)
    }

    private var playCard: some View {
        CourtCard {
            Text("PICK YOUR PACE").font(Arcade.display(22))
            Text("A quick duel or room to think. Your clock, your call.").foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(TimeControl.presets, id: \.self) { time in
                    Button { store.timeControl = time } label: {
                        VStack(spacing: 5) {
                            Text(time.label).font(Arcade.display(23))
                            Text(time.category.uppercased()).font(Arcade.mono(10))
                        }
                        .frame(maxWidth: .infinity).padding(14)
                        .foregroundStyle(store.timeControl == time ? Arcade.midnight : .primary)
                        .background(store.timeControl == time ? Arcade.sunshine : Arcade.royal.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(store.timeControl == time ? Arcade.sunshine : Arcade.royal.opacity(0.25)))
                    }.buttonStyle(.plain).accessibilityAddTraits(store.timeControl == time ? [.isSelected] : [])
                }
            }
            Button("No clock · ∞") { store.timeControl = .unlimited }
                .buttonStyle(CourtButtonStyle(primary: store.timeControl.isUnlimited))
            DisclosureGroup("Custom clock · selected \(store.timeControl.label)") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Minutes: \(customMinutes < 1 ? "30 sec" : "\(Int(customMinutes)) min")")
                    Slider(value: $customMinutes, in: 0.5 ... 180, step: 0.5)
                    Text("Increment: \(Int(customIncrement)) seconds")
                    Slider(value: $customIncrement, in: 0 ... 180, step: 1)
                    Button("Use custom clock") {
                        store.timeControl = TimeControl(initialMs: Int(customMinutes * 60000), incrementMs: Int(customIncrement * 1000))
                    }.buttonStyle(CourtButtonStyle())
                }.padding(.vertical, 12)
            }
            Toggle("Play a bot if nobody joins the queue", isOn: $botFallback)
            Button { store.quickPair(bot: botFallback) } label: {
                Label(store.queue == nil ? "QUICK PLAY" : "FINDING A MATCH", systemImage: "bolt.fill").frame(maxWidth: .infinity)
            }.buttonStyle(CourtButtonStyle(primary: true)).disabled(!enabled)
            Divider()
            Text("PRACTICE MAKES ROYALTY").font(Arcade.mono(12))
            Picker("Bot level", selection: $store.botLevel) {
                Text("1 · Novice").tag(1); Text("2 · Club").tag(2); Text("3 · Expert").tag(3); Text("4 · Master").tag(4)
            }
            Picker("Your side", selection: $store.sidePreference) {
                Text("White").tag(SidePreference.white); Text("Random").tag(SidePreference.random); Text("Black").tag(SidePreference.black)
            }.pickerStyle(.segmented)
            Button { store.create(bot: true, isPublic: publicRoom) } label: {
                Label("Challenge a bot", systemImage: "cpu").frame(maxWidth: .infinity)
            }.buttonStyle(CourtButtonStyle()).disabled(!enabled)
            if !store.ready {
                Button("Reconnect to server") { store.connect() }.buttonStyle(.borderless)
            }
        }
    }

    private var inviteCard: some View {
        CourtCard {
            Text("BRING A RIVAL").font(Arcade.display(21))
            Toggle("List my room publicly", isOn: $publicRoom)
            Button { store.create(isPublic: publicRoom) } label: {
                Label("Create room · \(store.timeControl.label)", systemImage: "plus.circle").frame(maxWidth: .infinity)
            }.buttonStyle(CourtButtonStyle()).disabled(!enabled)
            Divider()
            HStack {
                TextField("ROOM CODE", text: $inviteCode).font(Arcade.mono(18)).textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled().onSubmit(join)
                    .onChange(of: inviteCode) { _, value in inviteCode = String(value.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6)) }
                Button("Join", action: join).buttonStyle(CourtButtonStyle(primary: true)).disabled(!enabled || inviteCode.count != 6)
            }
            Toggle("Join as a spectator", isOn: $spectate)
        }
    }

    private func join() {
        store.join(inviteCode, spectate: spectate)
    }

    private var roomsCard: some View {
        CourtCard {
            HStack {
                Text("ON THE COURT").font(Arcade.display(21))
                Spacer()
                Button { store.action(.listRooms) } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh rooms").disabled(!store.ready)
            }
            if store.rooms.isEmpty {
                Text(store.ready ? "No public rooms yet. Start one and set the pace." : "Connect to see live rooms.").foregroundStyle(.secondary).padding(.vertical, 14)
            } else {
                ForEach(store.rooms) { room in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(room.code).font(Arcade.mono(14)).bold()
                            Spacer()
                            Text("\(room.timeControl.label) · \(room.status.rawValue.capitalized)").font(.caption)
                        }
                        Text("\(room.hostName) · \(room.playerCount)/2 players\(room.hasBot ? " · Bot" : "")").lineLimit(2)
                        HStack {
                            Label("\(room.spectatorCount)", systemImage: "eye").font(.caption)
                            Spacer()
                            if room.status == .waiting, room.playerCount < 2 {
                                Button("Play") { store.join(room.code) }.buttonStyle(CourtButtonStyle(primary: true)).disabled(!enabled)
                            }
                            Button("Watch") { store.join(room.code, spectate: true) }.buttonStyle(CourtButtonStyle()).disabled(!enabled)
                        }
                    }.padding(.vertical, 6)
                    if room.id != store.rooms.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var reviewCard: some View {
        CourtCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("STUDY THE GAME").font(Arcade.display(18))
                    Text("Import PGN and explore every move.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open PGN", action: openPGN).buttonStyle(CourtButtonStyle())
            }
        }
    }
}
