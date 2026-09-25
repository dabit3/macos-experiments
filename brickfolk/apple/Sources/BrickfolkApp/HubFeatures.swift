import BrickfolkCore
import SwiftUI

struct AvatarEditor: View {
  @EnvironmentObject private var client: Client
  @State private var draft = Avatar()
  @State private var slot: ItemSlot = .face
  @State private var ownedOnly = false
  @State private var bodyPart = "Torso"
  @State private var purchase: CatalogItem?
  private let parts = ["Head", "Torso", "Arms", "Legs"]
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text("Make it yours.").font(.custom("Inter-ExtraBold", size: 28))
        Panel {
          VStack(spacing: 18) {
            AvatarView(avatar: draft, size: 180)
            HStack {
              Button("Reset") { draft = client.me?.avatar ?? Avatar() }
              Button("Save avatar") { client.send(.avatar(draft)) }
                .buttonStyle(BrickButtonStyle())
                .disabled(draft == client.me?.avatar)
            }
            Text("Preview your look, then save to equip.").font(.caption).foregroundStyle(
              .secondary)
          }.frame(maxWidth: .infinity)
        }
        Panel {
          VStack(alignment: .leading, spacing: 18) {
            Text("Body colours").font(.headline)
            Picker("Body part", selection: $bodyPart) { ForEach(parts, id: \.self) { Text($0) } }
              .pickerStyle(.segmented)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 38))], spacing: 12) {
              ForEach(Array((client.content?.bodyColors ?? []).enumerated()), id: \.offset) {
                index, color in
                Button {
                  setColor(color)
                } label: {
                  Circle().fill(Color(argb: color)).frame(width: 34, height: 34)
                    .overlay {
                      if selectedColor == color {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(
                          Color.ink, .white)
                      }
                    }
                }.buttonStyle(.plain)
                  .accessibilityLabel(client.content?.bodyColorNames[index] ?? "Colour \(index)")
              }
            }
          }
        }
        HStack {
          Text("The Brick Shop").font(.custom("Inter-Bold", size: 23))
          Spacer()
          Label("\(client.me?.pips ?? 0)", systemImage: "diamond.fill").foregroundStyle(Color.sun)
        }
        Picker("Category", selection: $slot) {
          ForEach(ItemSlot.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }.pickerStyle(.segmented)
        Toggle("Owned items only", isOn: $ownedOnly)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 14) {
          ForEach(
            client.content?.catalog.filter { $0.slot == slot && (!ownedOnly || owned($0)) } ?? []
          ) { item in
            VStack(spacing: 8) {
              AvatarView(avatar: preview(item), size: 94)
              Text(item.name).font(.custom("Inter-SemiBold", size: 14))
              Text(item.blurb).font(.caption).foregroundStyle(.secondary)
              Button(
                owned(item) ? (draft.equipped(item) ? "Selected" : "Try on") : "\(item.price) Pips"
              ) {
                if owned(item) { draft.equip(item) } else { purchase = item }
              }.buttonStyle(BrickButtonStyle(color: owned(item) ? .sky : .brick))
                .disabled(!owned(item) && (client.me?.pips ?? 0) < item.price)
            }.frame(maxWidth: .infinity).padding(14)
              .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
          }
        }
      }.padding(22).frame(maxWidth: 1000).frame(maxWidth: .infinity)
    }
    .onAppear { draft = client.me?.avatar ?? Avatar() }
    .confirmationDialog(
      "Buy \(purchase?.name ?? "item") for \(purchase?.price ?? 0) Pips?",
      isPresented: Binding(get: { purchase != nil }, set: { if !$0 { purchase = nil } }),
      titleVisibility: .visible
    ) {
      if let item = purchase {
        Button("Buy") {
          client.send(.buy(item.id))
          purchase = nil
        }
      }
      Button("Cancel", role: .cancel) { purchase = nil }
    }
  }
  private func owned(_ item: CatalogItem) -> Bool {
    item.price == 0 || client.me?.owned.contains(item.id) == true
  }
  private func preview(_ item: CatalogItem) -> Avatar {
    var avatar = draft
    avatar.equip(item)
    return avatar
  }
  private var selectedColor: UInt32 {
    switch bodyPart {
    case "Head": return draft.headColor
    case "Arms": return draft.armColor
    case "Legs": return draft.legColor
    default: return draft.torsoColor
    }
  }
  private func setColor(_ color: UInt32) {
    switch bodyPart {
    case "Head": draft.headColor = color
    case "Arms": draft.armColor = color
    case "Legs": draft.legColor = color
    default: draft.torsoColor = color
    }
  }
}

struct SocialView: View {
  @EnvironmentObject private var client: Client
  @State private var name = ""
  @State private var partyCode = ""
  @State private var experience: Experience = .obby
  @State private var bots = 2
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Text("Better together.").font(.custom("Inter-ExtraBold", size: 28))
        Panel {
          VStack(alignment: .leading, spacing: 16) {
            Text("Your party").font(.headline)
            if let party = client.party {
              HStack {
                Text(party.code).font(.custom("Inter-Bold", size: 30)).tracking(5).textSelection(
                  .enabled)
                ShareLink(item: party.code) { Image(systemName: "square.and.arrow.up") }
                Spacer()
                Button("Leave") { client.send(.partyLeave) }
              }
              ForEach(party.members) { player in
                HStack {
                  playerRow(player)
                  if player.id == party.leaderId {
                    Image(systemName: "crown.fill").foregroundStyle(Color.sun)
                  }
                }
              }
              if let code = party.roomCode {
                Button("Join party room \(code)") { client.send(.roomJoin(code)) }.buttonStyle(
                  BrickButtonStyle())
              } else if client.isLeader {
                Picker("Experience", selection: $experience) {
                  ForEach(client.content?.places ?? []) { Text($0.name).tag($0.kind) }
                }
                Stepper("Bots: \(bots)", value: $bots, in: 0...7)
                Button("Launch party") { client.send(.partyLaunch(experience, bots: bots)) }
                  .buttonStyle(BrickButtonStyle(color: .mint))
              } else {
                Text("Waiting for your leader to launch a place.").foregroundStyle(.secondary)
              }
            } else {
              Text("Bring up to eight friends into the same place with a four-letter code.")
                .foregroundStyle(.secondary)
              Button("Create party") { client.send(.partyCreate(nil)) }.buttonStyle(
                BrickButtonStyle())
              HStack {
                TextField("Party code", text: $partyCode).textFieldStyle(.roundedBorder)
                Button("Join") {
                  client.send(.partyJoin(partyCode.trimmingCharacters(in: .whitespaces)))
                }
                .disabled(partyCode.count != 4)
              }
            }
          }
        }
        Panel {
          VStack(alignment: .leading, spacing: 16) {
            Text("Find a friend").font(.headline)
            HStack {
              TextField("Player name", text: $name).textFieldStyle(.roundedBorder)
              Button("Add") {
                client.send(.friend(.request, name))
                name = ""
              }.disabled(name.isEmpty)
            }
          }
        }
        if !client.friends.incoming.isEmpty {
          Panel {
            VStack(alignment: .leading, spacing: 12) {
              Text("Friend requests").font(.headline)
              ForEach(client.friends.incoming) { player in
                VStack(alignment: .leading) {
                  playerRow(player)
                  HStack {
                    Button("Accept") { client.send(.friend(.accept, player.id)) }
                    Button("Decline") { client.send(.friend(.decline, player.id)) }
                  }
                }
              }
            }
          }
        }
        Panel {
          VStack(alignment: .leading, spacing: 14) {
            Text("Friends · \(client.friends.friends.count)").font(.headline)
            if client.friends.friends.isEmpty {
              Text("Your next adventure could start with a new friend.").foregroundStyle(.secondary)
            }
            ForEach(client.friends.friends) { player in
              HStack {
                playerRow(player)
                Menu {
                  Button("Remove friend", role: .destructive) {
                    client.send(.friend(.remove, player.id))
                  }
                } label: {
                  Image(systemName: "ellipsis")
                }
              }
            }
            ForEach(client.friends.outgoing) { player in
              HStack {
                Text(player.name)
                Spacer()
                Text("Request sent").foregroundStyle(.secondary)
                Button("Cancel") { client.send(.friend(.remove, player.id)) }
              }.font(.caption)
            }
          }
        }
        ChatView(initialChannel: client.party == nil ? .global : .party).frame(minHeight: 360)
      }.padding(22).frame(maxWidth: 900).frame(maxWidth: .infinity)
    }
  }
  private func playerRow(_ player: Player) -> some View {
    Button {
      client.showProfile(player.id)
    } label: {
      HStack {
        AvatarView(avatar: player.avatar, size: 46)
        VStack(alignment: .leading, spacing: 3) {
          Text(player.name).font(.custom("Inter-SemiBold", size: 14))
          Text("\(player.online ? "Online" : "Offline") · \(player.platform)").font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Circle().fill(player.online ? Color.mint : .gray).frame(width: 7, height: 7)
      }
    }.buttonStyle(.plain)
  }
}

struct ChatView: View {
  @EnvironmentObject private var client: Client
  @State private var channel: ChatChannel
  @State private var text = ""
  init(initialChannel: ChatChannel) { _channel = State(initialValue: initialChannel) }
  private var channels: [ChatChannel] {
    [.global] + (client.party == nil ? [] : [.party]) + (client.room == nil ? [] : [.room])
  }
  var body: some View {
    Panel {
      VStack(spacing: 14) {
        Picker("Chat", selection: $channel) {
          ForEach(channels, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }
        .pickerStyle(.segmented)
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
              if messages.isEmpty {
                Text("Say hello. Keep it friendly.").foregroundStyle(.secondary).padding(
                  .vertical, 35)
              }
              ForEach(messages) { message in
                VStack(alignment: .leading, spacing: 4) {
                  Button {
                    client.showProfile(message.from.id)
                  } label: {
                    Text(message.from.name).font(.custom("Inter-SemiBold", size: 12))
                      .foregroundStyle(Color.sky)
                  }.buttonStyle(.plain)
                  Text(message.text).font(.callout).textSelection(.enabled)
                  if message.filtered {
                    Text("Filtered").font(.caption2).foregroundStyle(.secondary)
                  }
                }.id(message.id).frame(maxWidth: .infinity, alignment: .leading)
              }
            }.padding(.vertical, 4)
          }.frame(minHeight: 200, maxHeight: 380)
            .onChange(of: client.chat.count) { _, _ in
              if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
        HStack {
          TextField("Message \(channel.rawValue)…", text: $text).textFieldStyle(.roundedBorder)
            .onSubmit(send)
          Button(action: send) { Image(systemName: "paperplane.fill") }.disabled(
            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          .accessibilityLabel("Send message")
        }
      }
    }.onChange(of: channels) { _, channels in if !channels.contains(channel) { channel = .global } }
  }
  private var messages: [ChatMessage] { client.chat.filter { $0.channel == channel } }
  private func send() {
    let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !message.isEmpty else { return }
    client.send(.chat(channel, message))
    text = ""
  }
}

struct ProfileView: View {
  @EnvironmentObject private var client: Client
  let profile: PlayerProfile
  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      Panel {
        VStack(alignment: .leading, spacing: 14) {
          AvatarView(avatar: profile.avatar, size: 110)
          Text(profile.name).font(.custom("Inter-ExtraBold", size: 30))
          Text("@\(profile.name.lowercased()) · \(profile.platform)").foregroundStyle(.secondary)
          Text(
            "Joined \(Date(timeIntervalSince1970: Double(profile.createdAt) / 1000).formatted(date: .abbreviated, time: .omitted))"
          ).font(.caption)
          HStack {
            Label("\(profile.pips) Pips", systemImage: "diamond.fill").foregroundStyle(Color.sun)
            Spacer()
            Text("\(profile.dailyStreak) day streak")
          }
          if profile.id != client.myID {
            Button(
              client.friends.friends.contains { $0.id == profile.id } ? "Friends" : "Add friend"
            ) {
              client.send(.friend(.request, profile.name))
            }.disabled(client.friends.friends.contains { $0.id == profile.id })
              .buttonStyle(BrickButtonStyle())
          }
        }
      }
      Panel {
        VStack(alignment: .leading, spacing: 16) {
          Text("Stats").font(.headline)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 115))], alignment: .leading, spacing: 18)
          {
            ForEach(
              [
                ("matches", "Matches"), ("wins", "Wins"), ("obbyFinishes", "Obby finishes"),
                ("bricksPlaced", "Bricks placed"), ("freezes", "Freezes"),
                ("pipsEarned", "Pips earned"),
              ], id: \.0
            ) { key, label in
              VStack(alignment: .leading, spacing: 6) {
                Text("\(profile.stats[key] ?? 0)").font(.custom("Inter-Bold", size: 24))
                Text(label).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
        }
      }
      Panel {
        VStack(alignment: .leading, spacing: 16) {
          Text("Badges · \(profile.badges.count)/\(client.content?.badges.count ?? 0)").font(
            .headline)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 20) {
            ForEach(client.content?.badges ?? []) { badge in
              VStack(spacing: 8) {
                Image(systemName: profile.badges.contains(badge.id) ? "seal.fill" : "lock.shield")
                  .font(.largeTitle).foregroundStyle(Color(argb: badge.color))
                Text(badge.name).font(.caption).multilineTextAlignment(.center)
                Text(badge.description).font(.caption2).foregroundStyle(.secondary)
                  .multilineTextAlignment(.center)
              }.opacity(profile.badges.contains(badge.id) ? 1 : 0.45)
            }
          }
        }
      }
      if profile.id == client.myID {
        Panel {
          VStack(alignment: .leading, spacing: 12) {
            Text("Inventory · \(profile.owned.count) items").font(.headline)
            ForEach(client.content?.catalog.filter { profile.owned.contains($0.id) } ?? []) {
              item in
              Label(item.name, systemImage: "checkmark.circle").font(.callout)
            }
            Button("Open avatar editor") {
              client.selectedTab = "avatar"
              client.requestedSheet = nil
            }
          }
        }
      }
    }.frame(maxWidth: 900).frame(maxWidth: .infinity)
  }
}

struct DailyView: View {
  @EnvironmentObject private var client: Client
  @State private var busy = false
  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { _ in
      VStack(spacing: 22) {
        Image(systemName: "gift.fill").font(.system(size: 56)).foregroundStyle(Color.sun)
        Text("A little something, daily.").font(.custom("Inter-Bold", size: 25))
        Text("Come back each day to grow your streak.").foregroundStyle(.secondary)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
          ForEach(1...7, id: \.self) { day in
            VStack(spacing: 10) {
              Text("Day \(day)").font(.caption)
              Image(systemName: "diamond.fill").foregroundStyle(Color.sun)
              Text("\(client.content?.dailyRewards[day - 1] ?? 0)").font(.headline)
            }.padding(12).background(
              Color.sky.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
          }
        }
        Text("Your streak: \(client.me?.dailyStreak ?? 0) days").font(.headline)
        if let daily = client.daily, daily.claimed {
          Text("+\(daily.reward) Pips added to your balance!").foregroundStyle(Color.mint)
        }
        if nextClaim <= client.serverNow {
          Button(busy ? "Claiming…" : "Claim daily reward") {
            busy = true
            client.send(.daily)
          }
          .buttonStyle(BrickButtonStyle(color: .brick)).disabled(busy)
        } else {
          let seconds = max(0, (nextClaim - client.serverNow) / 1000)
          Text("Next reward in \(seconds / 3600)h \((seconds % 3600) / 60)m").foregroundStyle(
            .secondary)
        }
      }.padding(20)
    }.onChange(of: client.daily?.nextClaimAt) { _, _ in busy = false }
      .onChange(of: client.error) { _, _ in busy = false }
  }
  private var nextClaim: Int64 {
    client.daily?.nextClaimAt ?? (client.me?.lastDailyClaim.map { $0 + 86_400_000 } ?? 0)
  }
}

struct SettingsView: View {
  @EnvironmentObject private var client: Client
  @State private var server = ""
  @State private var confirmSignOut = false
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      Text("Settings").font(.custom("Inter-Bold", size: 28))
      Picker("Appearance", selection: $client.theme) {
        Text("System").tag("system")
        Text("Light").tag("light")
        Text("Dark").tag("dark")
      }.pickerStyle(.segmented)
      Toggle("Sound effects", isOn: $client.sound)
      Toggle("Haptic feedback", isOn: $client.haptics)
      Divider()
      Text("Server").font(.headline)
      TextField("ws://localhost:8080/ws", text: $server).textFieldStyle(.roundedBorder)
        .autocorrectionDisabled()
      Text(
        "For another device on your network, use your server Mac's LAN address. Your session is saved separately for each server."
      ).font(.caption).foregroundStyle(.secondary)
      Button("Switch server") {
        do {
          let url = try Endpoint.validated(server)
          client.pause()
          client.me = nil
          client.room = nil
          client.party = nil
          client.chat = []
          client.serverURL = url.absoluteString
          UserDefaults.standard.set(url.absoluteString, forKey: "server")
          client.requestedSheet = nil
          client.start()
        } catch { client.error = "Enter a valid ws:// or wss:// server URL." }
      }.buttonStyle(BrickButtonStyle())
      Button("Reconnect now") { client.reconnect() }
      Divider()
      Text("Native Brickfolk · protocol 1").font(.caption).foregroundStyle(.secondary)
      Text(
        "Inter font © The Inter Project Authors, SIL Open Font License. Original world artwork and Brickfolk character designs retained from Brickfolk."
      ).font(.caption).foregroundStyle(.secondary)
      Button("Sign out", role: .destructive) { confirmSignOut = true }
    }.padding()
      .onAppear { server = client.serverURL }
      .confirmationDialog(
        "Forget this device's saved session? Your profile cannot be recovered by name alone.",
        isPresented: $confirmSignOut, titleVisibility: .visible
      ) {
        Button("Sign out", role: .destructive) {
          client.signOut()
          client.requestedSheet = nil
        }
      }
  }
}
