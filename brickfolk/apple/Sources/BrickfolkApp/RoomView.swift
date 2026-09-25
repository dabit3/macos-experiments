import BrickfolkCore
import SwiftUI

struct RoomView: View {
  @EnvironmentObject private var client: Client
  let room: RoomState
  @State private var leave = false
  @State private var rematch = false
  @State private var showPlayers = false
  private var place: PlaceInfo? { client.content?.places.first { $0.kind == room.experience } }
  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Button {
          leave = true
        } label: {
          Image(systemName: "chevron.left")
        }.accessibilityLabel("Leave room")
        VStack(alignment: .leading, spacing: 3) {
          Text(place?.name ?? room.experience.rawValue).font(.custom("Inter-Bold", size: 16))
            .lineLimit(1)
          Text("\(room.code) · \(room.phase.rawValue.capitalized)").font(.caption).foregroundStyle(
            .secondary
          ).textSelection(.enabled)
        }
        Spacer(minLength: 4)
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
          if let end = room.matchEndsAt, room.phase == .playing {
            let seconds = max(0, (end - client.serverNow) / 1000)
            Text("\(seconds / 60):\(String(format: "%02d", seconds % 60))")
              .font(.system(.headline, design: .monospaced)).monospacedDigit()
          }
        }
        Button {
          showPlayers.toggle()
        } label: {
          Image(systemName: "person.2")
        }.accessibilityLabel("Players")
        Button {
          client.requestedSheet = "chat"
        } label: {
          Image(systemName: "bubble.left")
        }.accessibilityLabel("Room chat")
        Menu {
          Button("Settings") { client.requestedSheet = "settings" }
          Button("Leave match", role: .destructive) { leave = true }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }.padding(16).background(.regularMaterial)
      if showPlayers {
        ScrollView(.horizontal) {
          HStack(spacing: 18) {
            ForEach(room.members) { member in
              Button {
                if !member.player.isBot { client.showProfile(member.id) }
              } label: {
                HStack {
                  AvatarView(avatar: member.player.avatar, size: 42)
                  VStack(alignment: .leading) {
                    Text(member.player.name)
                    Text(stat(member.id)).font(.caption).foregroundStyle(.secondary)
                  }
                }
              }.buttonStyle(.plain)
            }
          }.padding(12)
        }
      }
      switch room.phase {
      case .lobby, .countdown: lobby
      case .playing:
        if room.experience == .tycoon {
          TycoonView()
        } else {
          ActionGameView(experience: room.experience)
        }
      case .results:
        if let results = client.results {
          resultsView(results)
        } else {
          ProgressView("Waiting for the results…").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .confirmationDialog("Leave the match?", isPresented: $leave, titleVisibility: .visible) {
      Button("Leave room", role: .destructive) { client.leaveRoom() }
    } message: {
      Text("You will return to the hub. You can rejoin using the room code.")
    }
    .onChange(of: room.phase) { _, phase in
      if phase == .lobby && rematch {
        client.send(.ready(true))
        rematch = false
      }
    }
  }
  private var lobby: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        if let place {
          Image(place.kind.artwork).resizable().scaledToFill().frame(height: 180).clipped()
            .overlay(alignment: .bottomLeading) {
              Text("Gather your crew.").font(.custom("Inter-ExtraBold", size: 30))
                .foregroundStyle(.white).shadow(radius: 5).padding(24)
            }.clipShape(RoundedRectangle(cornerRadius: 20))
        }
        HStack {
          Text("Room \(room.code)").font(.custom("Inter-Bold", size: 24)).textSelection(.enabled)
          ShareLink(item: room.code) { Image(systemName: "square.and.arrow.up") }
          Spacer()
          Text("\(room.members.filter { !$0.player.isBot }.count)/8").foregroundStyle(.secondary)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 138))], spacing: 14) {
          ForEach(room.members.filter { !$0.player.isBot }) { member in
            VStack(spacing: 8) {
              AvatarView(avatar: member.player.avatar, size: 86)
              Text(member.player.name).font(.custom("Inter-SemiBold", size: 14))
              Text(member.player.platform).font(.caption).foregroundStyle(.secondary)
              Label(
                member.player.online ? member.ready ? "Ready!" : "Getting ready" : "Reconnecting",
                systemImage: member.ready ? "checkmark.circle.fill" : "clock"
              )
              .font(.caption).foregroundStyle(member.ready ? Color.mint : .secondary)
            }.padding(16).frame(maxWidth: .infinity)
              .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
          }
        }
        Text("\(client.botCount) bots will join when the match starts.").font(.callout)
          .foregroundStyle(.secondary)
        Panel {
          VStack(alignment: .leading, spacing: 12) {
            Text("How to play").font(.headline)
            Text(place?.description ?? "")
            Text(
              room.experience == .obby
                ? "Move with A/D or ←/→. Jump with Space, W or ↑. Touch controls are on screen."
                : room.experience == .tag
                  ? "Move with WASD, arrows or the touch stick. Touch a frozen teammate to thaw them."
                  : "Choose a brick, then tap a cell. Conveyors earn more next to droppers. Remove refunds half the cost. Upgrades stack."
            )
            .font(.callout).foregroundStyle(.secondary)
          }
        }
        let ready = room.members.first { $0.id == client.myID }?.ready ?? false
        Button(ready ? "Ready! · tap to unready" : "Ready up") { client.send(.ready(!ready)) }
          .buttonStyle(BrickButtonStyle(color: ready ? .mint : .sky))
          .accessibilityIdentifier("room.ready")
        if room.phase == .countdown {
          TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let seconds = max(
              0,
              Int(
                ceil(Double((room.countdownEndsAt ?? client.serverNow) - client.serverNow) / 1000)))
            Text("Starting in \(seconds)…").font(.custom("Inter-ExtraBold", size: 34))
              .foregroundStyle(Color.sun)
          }
        }
        ChatView(initialChannel: .room)
      }.padding(22).frame(maxWidth: 950).frame(maxWidth: .infinity)
    }
  }
  private func resultsView(_ results: MatchResults) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack {
          Image(systemName: "trophy.fill").font(.largeTitle).foregroundStyle(Color.sun)
          VStack(alignment: .leading) {
            Text("That's a wrap!").font(.custom("Inter-ExtraBold", size: 30))
            Text("Match \(room.round) · \(place?.name ?? "")").foregroundStyle(.secondary)
          }
        }
        ForEach(results.entries) { entry in
          Panel {
            VStack(alignment: .leading, spacing: 10) {
              HStack(alignment: .top) {
                Text("#\(entry.rank)").font(.custom("Inter-ExtraBold", size: 24)).foregroundStyle(
                  entry.rank == 1 ? Color.sun : .secondary)
                AvatarView(avatar: entry.player.avatar, size: 56)
                VStack(alignment: .leading, spacing: 5) {
                  Text(entry.player.name).font(.headline)
                  Text(entry.detail).font(.caption).foregroundStyle(.secondary)
                  Text("\(entry.score) points").font(.custom("Inter-Bold", size: 20))
                }
              }
              if !entry.player.isBot {
                Text("+\(entry.pipsEarned) Pips").foregroundStyle(Color.sun)
                if !entry.badgesEarned.isEmpty {
                  Text("New badges: \(entry.badgesEarned.joined(separator: ", "))").font(.caption)
                }
              }
            }
          }
        }
        HStack {
          Button(rematch ? "Ready for the next match" : "Play again") { rematch = true }
            .buttonStyle(BrickButtonStyle()).disabled(rematch)
          Button("Back to places") { client.leaveRoom() }
        }
        TimelineView(.periodic(from: .now, by: 1)) { _ in
          Text(
            "Lobby opens in \(max(0, ((client.resultsEndsAt ?? client.serverNow) - client.serverNow) / 1000))s"
          )
          .font(.callout).foregroundStyle(.secondary)
        }
        Text("Server result · \(results.checksum)").font(.system(.caption, design: .monospaced))
          .textSelection(.enabled)
        ChatView(initialChannel: .room)
      }.padding(22).frame(maxWidth: 900).frame(maxWidth: .infinity)
    }
  }
  private func stat(_ id: String) -> String {
    switch client.frame {
    case .obby(let frame):
      guard let player = frame.players[id] else { return "Spectating" }
      return player.finishTick != nil
        ? "Finished" : "Stage \(player.checkpoint + 1) · \(player.deaths) falls"
    case .tag(let frame):
      guard let player = frame.players[id] else { return "Spectating" }
      return
        "\(player.totalScore) points · \(player.isTagger ? "Tagger" : player.frozen ? "Frozen" : "Runner")"
    case .tycoon(let frame): return "\(frame.earned[id] ?? 0) earned"
    case nil: return "Waiting"
    }
  }
}

struct TycoonView: View {
  @EnvironmentObject private var client: Client
  @State private var selected = "dropper"
  @State private var remove = false
  @State private var viewedID = ""
  private var snapshot: TycoonFrame? {
    if case .tycoon(let frame) = client.frame { return frame }
    return nil
  }
  var body: some View {
    ScrollView {
      if let snapshot, let content = client.content {
        let id = viewedID.isEmpty ? client.myID : viewedID
        let plot = snapshot.plots[id]
        VStack(alignment: .leading, spacing: 20) {
          if snapshot.plots[client.myID] == nil || !viewedID.isEmpty {
            Picker("Watch plot", selection: $viewedID) {
              if snapshot.plots[client.myID] != nil { Text("My plot").tag("") }
              ForEach(client.room?.members.filter { snapshot.plots[$0.id] != nil } ?? []) {
                Text($0.player.name).tag($0.id)
              }
            }
          }
          if let plot {
            Panel {
              HStack {
                VStack(alignment: .leading) {
                  Text("Cash").foregroundStyle(.secondary)
                  Text("\(plot.cash)").font(.custom("Inter-ExtraBold", size: 30)).foregroundStyle(
                    Color.sun)
                }
                Spacer()
                VStack(alignment: .trailing) {
                  Text("+\(plot.income(content: content))/s").font(.headline).foregroundStyle(
                    Color.mint)
                  Text("\(snapshot.earned[id] ?? 0) earned").font(.caption)
                }
              }
            }
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6
            ) {
              ForEach(plot.cells.indices, id: \.self) { cell in
                let brick = content.bricks.first { $0.id == plot.cells[cell] }
                Button {
                  guard id == client.myID else { return }
                  if remove {
                    client.input(.remove(cell: cell))
                  } else if plot.cells[cell] == nil {
                    client.input(.place(cell: cell, item: selected))
                  }
                } label: {
                  ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(
                      brick.map { Color(argb: $0.color) } ?? Color.white.opacity(0.09))
                    if let brick {
                      VStack(spacing: 3) {
                        Image(systemName: symbol(brick.id)).font(.title2)
                        Text("+\(brick.income)").font(.caption2).monospacedDigit()
                      }.foregroundStyle(Color.ink)
                    } else {
                      Image(systemName: "plus").foregroundStyle(.secondary)
                    }
                  }.aspectRatio(1, contentMode: .fit)
                    .overlay(
                      RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.13), lineWidth: 2))
                }.buttonStyle(.plain)
                  .disabled(id != client.myID || (!remove && plot.cells[cell] != nil))
                  .accessibilityLabel("Cell \(cell + 1), \(brick?.name ?? "empty")")
              }
            }.padding(12).background(
              Color(argb: 0xFF26_3344), in: RoundedRectangle(cornerRadius: 18))
            if id == client.myID {
              Toggle("Remove mode · 50% refund", isOn: $remove)
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 135))], spacing: 12) {
                ForEach(content.bricks) { brick in
                  Button {
                    selected = brick.id
                    remove = false
                  } label: {
                    VStack(spacing: 8) {
                      Label(brick.name, systemImage: symbol(brick.id)).font(.headline)
                      Text("\(brick.cost) cash · +\(brick.income)/s").font(.caption)
                      Text(brick.blurb).font(.caption2)
                    }.padding(14).frame(maxWidth: .infinity, minHeight: 94)
                      .background(
                        Color(argb: brick.color).opacity(
                          selected == brick.id && !remove ? 0.35 : 0.12),
                        in: RoundedRectangle(cornerRadius: 14))
                  }.buttonStyle(.plain)
                }
              }
              Text("Plot upgrades").font(.headline)
              ForEach(content.upgrades) { upgrade in
                HStack {
                  VStack(alignment: .leading) {
                    Text(upgrade.name).font(.headline)
                    Text(upgrade.blurb).font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  Button(plot.upgrades.contains(upgrade.id) ? "Owned" : "\(upgrade.cost) cash") {
                    client.input(.upgrade(upgrade.id))
                  }
                  .disabled(plot.upgrades.contains(upgrade.id) || plot.cash < upgrade.cost)
                }.padding(.vertical, 6)
              }
            }
            Text("Rival builders").font(.headline)
            ForEach(snapshot.earned.sorted { $0.value > $1.value }, id: \.key) { entry in
              HStack {
                Text(client.room?.members.first { $0.id == entry.key }?.player.name ?? entry.key)
                Spacer()
                Text("\(entry.value)")
                Button("Watch") { viewedID = entry.key }
              }
            }
          } else {
            ProgressView("Waiting for a plot…")
          }
        }.padding(22).frame(maxWidth: 850).frame(maxWidth: .infinity)
          .onAppear {
            if snapshot.plots[client.myID] == nil {
              viewedID = snapshot.plots.keys.sorted().first ?? ""
            }
          }
      } else {
        ProgressView("Waiting for the server's plot…").padding(60)
      }
    }
    .background(
      LinearGradient(
        colors: [Color.orange.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom))
  }
  private func symbol(_ id: String) -> String {
    switch id {
    case "dropper": return "shippingbox.fill"
    case "conveyor": return "arrow.right.square.fill"
    case "vault": return "lock.square.fill"
    default: return "sparkles"
    }
  }
}
