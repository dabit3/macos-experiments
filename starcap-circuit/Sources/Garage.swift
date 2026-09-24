import SwiftUI

struct LobbyPanel: View {
  @ObservedObject var client: RaceClient
  let width: CGFloat
  @State private var tab = 0

  init(client: RaceClient, size: CGSize) {
    self.client = client
    self.width = size.width
  }

  private var racer: Racer { Racer.all[client.me?.racer ?? client.racer] }
  private var course: Int { client.state?.track ?? client.track }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [ink.opacity(0.5), .clear, .clear, ink.opacity(0.55)], startPoint: .leading,
        endPoint: .trailing
      ).ignoresSafeArea().allowsHitTesting(false)
      HStack(alignment: .top, spacing: 12) {
        showcase.frame(width: width * 0.38)
        panel.frame(maxWidth: .infinity, maxHeight: .infinity)
      }.padding(.horizontal, 10).padding(.top, 10).padding(.bottom, 14)
    }
  }

  private var showcase: some View {
    VStack(alignment: .leading, spacing: 6) {
      Logo(size: 24)
      Spacer()
      Ribbon(text: client.connected ? "YOUR RACER" : "GARAGE", tint: racer.color)
      OutlinedText(text: racer.name, size: 50, fill: [.white, racer.color], stroke: 2.5)
      Text("\(racer.subtitle.uppercased()) • \(racer.kart.uppercased())").font(label(10))
        .foregroundStyle(.white).shadow(color: ink, radius: 0, x: 1, y: 1)
      VStack(alignment: .leading, spacing: 5) {
        StatBar(name: "SPEED", value: racer.speed, tint: cherry)
        StatBar(name: "ACCEL", value: racer.accel, tint: sunshine)
        StatBar(name: "HANDLING", value: racer.handling, tint: mintGlow)
      }.padding(10).background(ink.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
    }.frame(maxWidth: .infinity, alignment: .leading)
  }

  private var panel: some View {
    VStack(spacing: 10) {
      if client.connected { roomLobby } else { setup }
    }
    .padding(14).background(CardBackground())
  }

  private var header: some View {
    HStack(spacing: 6) {
      ForEach(Array(["RACER", "COURSE", "ROOM"].enumerated()), id: \.offset) { index, name in
        let detail = [
          racer.name, Course.names[course].components(separatedBy: " ")[0], client.code,
        ]
        Button {
          withAnimation(.spring(response: 0.3)) { tab = index }
        } label: {
          VStack(spacing: 0) {
            Text("\(index + 1) \(name)").font(display(12))
            Text(detail[index]).font(label(8)).opacity(0.75).lineLimit(1)
          }
          .foregroundStyle(tab == index ? .white : ink)
          .frame(maxWidth: .infinity).padding(.vertical, 5)
          .background(
            Capsule().fill(tab == index ? skyBlue : ink.opacity(0.07))
              .overlay(Capsule().stroke(tab == index ? ink : .clear, lineWidth: 2.5)))
        }.buttonStyle(.plain).accessibilityLabel("\(name) step")
      }
      muteButton
    }
  }

  private var muteButton: some View {
    Button {
      client.toggleMute()
    } label: {
      Image(systemName: client.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
        .font(.system(size: 14, weight: .black)).foregroundStyle(ink)
        .frame(width: 36, height: 36).background(ink.opacity(0.07), in: Circle())
    }.accessibilityLabel("Toggle sound").buttonStyle(.plain)
  }

  private var setup: some View {
    VStack(spacing: 10) {
      header
      Group {
        switch tab {
        case 0: racerPicker
        case 1: coursePicker
        default: roomForm
        }
      }
      .frame(maxHeight: .infinity)
      .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
      HStack(spacing: 6) {
        Image(systemName: "person.2.fill")
        Text(client.status).lineLimit(1).minimumScaleFactor(0.7)
        Spacer()
        Text("2 LAPS • 2 PLAYERS ONLINE")
      }.font(label(9)).foregroundStyle(ink.opacity(0.55))
      ArcadeButton(
        "RACE ONLINE • ROOM \(client.code.uppercased())", height: 48, icon: "flag.checkered"
      ) { client.join() }
    }
  }

  private var racerPicker: some View {
    HStack(spacing: 8) {
      ForEach(Racer.all) { r in
        let selected = client.racer == r.id
        Button {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { client.racer = r.id }
        } label: {
          VStack(spacing: 2) {
            RacerPortrait(racer: r.id).frame(height: 70).padding(.top, 8)
              .scaleEffect(selected ? 1.1 : 0.95)
            Text(r.name).font(display(18)).foregroundStyle(ink)
            Text(r.subtitle).font(label(9)).foregroundStyle(ink.opacity(0.55))
            Text(r.kart.uppercased()).font(label(8)).foregroundStyle(.white)
              .padding(.horizontal, 7).padding(.vertical, 3)
              .background(selected ? r.color.opacity(1) : ink.opacity(0.3), in: Capsule())
              .padding(.top, 3)
            Spacer(minLength: 0)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(
            RoundedRectangle(cornerRadius: 16).fill(
              LinearGradient(
                colors: [r.color.opacity(selected ? 0.45 : 0.14), .white], startPoint: .top,
                endPoint: .bottom))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16).strokeBorder(
              selected ? ink : ink.opacity(0.12), lineWidth: selected ? 3 : 1.5)
          )
          .overlay(alignment: .topTrailing) {
            if selected {
              Image(systemName: "checkmark.circle.fill").font(.system(size: 18, weight: .black))
                .foregroundStyle(.white, r.color).padding(6)
            }
          }
          .offset(y: selected ? -3 : 0)
        }.buttonStyle(.plain).accessibilityLabel("Select \(r.name)")
      }
    }
  }

  private var coursePicker: some View {
    HStack(spacing: 10) {
      ForEach(0..<2) { track in
        let selected = client.track == track
        Button {
          withAnimation(.spring(response: 0.3)) { client.setTrack(track) }
        } label: {
          VStack(alignment: .leading, spacing: 3) {
            TrackArt(track: track).frame(maxHeight: .infinity)
              .clipShape(RoundedRectangle(cornerRadius: 11))
            Text(Course.names[track]).font(display(14)).foregroundStyle(ink)
            Text(Course.moods[track]).font(label(8)).foregroundStyle(ink.opacity(0.55))
            HStack(spacing: 2) {
              ForEach(0..<3) { star in
                Image(systemName: star < Course.difficulty[track] ? "star.fill" : "star")
              }
              Text("DIFFICULTY").padding(.leading, 3)
            }.font(label(8)).foregroundStyle(.orange)
          }
          .padding(7)
          .background(RoundedRectangle(cornerRadius: 15).fill(.white))
          .overlay(
            RoundedRectangle(cornerRadius: 15).strokeBorder(
              selected ? ink : ink.opacity(0.12), lineWidth: selected ? 3 : 1.5)
          )
          .overlay(alignment: .topTrailing) {
            if selected {
              Image(systemName: "checkmark.circle.fill").font(.system(size: 20, weight: .black))
                .foregroundStyle(.white, skyBlue).padding(10)
            }
          }
        }.buttonStyle(.plain).accessibilityLabel("Select \(Course.names[track])")
      }
    }
  }

  private var roomForm: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        entry("GUEST NAME", icon: "person.fill", text: $client.name)
        entry("ROOM CODE", icon: "number", text: $client.code)
      }
      entry("SERVER ADDRESS", icon: "server.rack", text: $client.address)
      Text("Share the room code with a friend. The first racer's course is used for the room.")
        .font(label(9)).foregroundStyle(ink.opacity(0.55))
      Spacer(minLength: 0)
    }
  }

  private func entry(_ title: String, icon: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title).font(label(8)).tracking(1).foregroundStyle(ink.opacity(0.55))
      HStack(spacing: 6) {
        Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(skyBlue)
        TextField(title, text: text)
          .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(ink)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .accessibilityLabel(title)
      }
      .padding(.horizontal, 10).padding(.vertical, 9)
      .background(.white, in: RoundedRectangle(cornerRadius: 11))
      .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(ink.opacity(0.2), lineWidth: 2))
    }
  }

  private var roomLobby: some View {
    let players = client.state?.players ?? []
    let ready = client.me?.ready == true
    return VStack(spacing: 10) {
      HStack(spacing: 8) {
        VStack(alignment: .leading, spacing: 0) {
          Text("ROOM").font(label(9)).foregroundStyle(ink.opacity(0.5))
          Text(client.code).font(.system(size: 22, weight: .black, design: .monospaced))
            .foregroundStyle(ink)
        }
        Spacer()
        Label(Course.names[course], systemImage: course == 0 ? "sun.max.fill" : "moon.stars.fill")
          .font(label(10)).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 6)
          .background(course == 0 ? skyBlue : .purple, in: Capsule())
        muteButton
      }
      HStack(spacing: 8) {
        ForEach(0..<2) { slot in
          if slot < players.count {
            playerSlot(players[slot])
          } else {
            VStack(spacing: 6) {
              ProgressView().tint(ink)
              Text("WAITING FOR RIVAL").font(display(12)).foregroundStyle(ink.opacity(0.6))
              Text("Share code \(client.code)").font(label(9)).foregroundStyle(ink.opacity(0.45))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
              RoundedRectangle(cornerRadius: 16).strokeBorder(
                ink.opacity(0.25), style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
          }
        }
      }.frame(maxHeight: .infinity)
      HStack {
        Button("LEAVE ROOM") { client.leave() }
        Spacer()
        Text("TIP: HOLD GAS ON “2” FOR A ROCKET START").foregroundStyle(.orange)
        Spacer()
        Button(client.autoDrive ? "AUTO DRIVER: ON" : "AUTO DRIVER: OFF") {
          client.autoDrive.toggle()
        }
        .accessibilityLabel("Toggle automated driver")
      }.font(label(9)).foregroundStyle(ink.opacity(0.65)).buttonStyle(.plain)
      ArcadeButton(
        ready ? "READY! WAITING FOR RIVAL…" : "READY TO RACE!", tint: ready ? mintGlow : sunshine,
        height: 48, icon: ready ? "checkmark" : "flag.checkered"
      ) { client.ready() }
      .disabled(ready)
    }
  }

  private func playerSlot(_ p: KartState) -> some View {
    let r = Racer.all[p.racer]
    return VStack(spacing: 3) {
      RacerPortrait(racer: p.racer).frame(height: 62)
      Text(p.name).font(display(15)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.6)
      Text(r.name).font(label(9)).foregroundStyle(ink.opacity(0.55))
      Text(p.ready ? "READY" : p.connected ? "IN THE PITS" : "RECONNECTING")
        .font(display(11)).foregroundStyle(p.ready ? .white : ink.opacity(0.6))
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(p.ready ? Color.green : ink.opacity(0.08), in: Capsule())
        .scaleEffect(p.ready ? 1.08 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: p.ready)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 16).fill(
        LinearGradient(
          colors: [r.color.opacity(0.35), .white], startPoint: .top, endPoint: .bottom))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16).strokeBorder(
        p.id == client.playerID ? ink : ink.opacity(0.12),
        lineWidth: p.id == client.playerID ? 3 : 1.5)
    )
    .overlay(alignment: .topLeading) {
      if p.id == client.playerID {
        Text("YOU").font(display(10)).foregroundStyle(.white).padding(.horizontal, 7)
          .padding(.vertical, 3).background(cherry, in: Capsule()).padding(7)
      }
    }
  }
}
