import SceneKit
import SwiftUI

@main
struct StarcapCircuitApp: App {
  var body: some Scene {
    WindowGroup { CircuitView().preferredColorScheme(.dark).statusBarHidden() }
  }
}

struct CircuitView: View {
  @StateObject private var client = RaceClient()
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        SceneView(
          scene: client.world.scene, pointOfView: client.world.cameraNode,
          options: [.rendersContinuously], preferredFramesPerSecond: 60,
          antialiasingMode: .multisampling4X
        )
        .ignoresSafeArea()
        if client.racing {
          RaceHUD(client: client)
        } else if client.state?.phase == "results" {
          ResultsPanel(client: client, width: geometry.size.width)
        } else {
          LobbyPanel(client: client, size: geometry.size)
        }
        if !client.connected && client.state != nil {
          ConnectionLost(client: client)
        }
      }
      .animation(.spring(response: 0.45, dampingFraction: 0.82), value: client.state?.phase)
      .onChange(of: client.racer) { _, value in client.world.preview(racer: value) }
    }
    .onReceive(
      NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
    ) { _ in
      client.throttle = false
      client.brake = true
      client.drift = false
      client.steer = 0
    }
  }
}

struct ConnectionLost: View {
  @ObservedObject var client: RaceClient
  var body: some View {
    ZStack {
      ink.opacity(0.7).ignoresSafeArea()
      VStack(spacing: 12) {
        Image(systemName: "wifi.exclamationmark").font(.system(size: 40, weight: .black))
          .foregroundStyle(cherry)
        OutlinedText(text: "PIT STOP!", size: 34, fill: [sunshine, .orange])
        Text("Your connection dropped. Your seat is saved for this room.")
          .font(label(13)).foregroundStyle(ink.opacity(0.75)).multilineTextAlignment(.center)
        Text(client.status).font(label(11)).foregroundStyle(ink.opacity(0.5))
        HStack(spacing: 12) {
          ArcadeButton("RECONNECT", icon: "arrow.clockwise") { client.join() }
          ArcadeButton("LEAVE", tint: .white) { client.leave() }
        }.padding(.top, 4)
      }
      .padding(24).frame(width: 420).background(CardBackground())
    }
  }
}

struct RacerPortrait: View {
  let racer: Int
  var body: some View {
    if let image = RaceWorld.portraits[racer] {
      Image(uiImage: image).resizable().scaledToFit()
    } else {
      emblem
    }
  }

  private var emblem: some View {
    GeometryReader { geo in
      let color = Racer.all[racer].color
      ZStack {
        Ellipse().fill(color.opacity(0.2)).frame(width: 65, height: 42).offset(y: 7)
        ForEach([-1, 1], id: \.self) { side in
          Capsule().fill(color).frame(width: racer == 1 ? 11 : 16, height: racer == 1 ? 28 : 17)
            .rotationEffect(.degrees(Double(side * 12))).offset(x: CGFloat(side * 18), y: -19)
        }
        RoundedRectangle(cornerRadius: racer == 2 ? 12 : 24).fill(color).frame(
          width: 52, height: 43)
        RoundedRectangle(cornerRadius: 14).fill(
          racer == 2 ? ink : Color(red: 1, green: 0.91, blue: 0.79)
        )
        .frame(width: 41, height: 22).offset(y: 7)
        HStack(spacing: 13) {
          Capsule().fill(racer == 2 ? .cyan : ink).frame(width: 5, height: 9)
          Capsule().fill(racer == 2 ? .cyan : ink).frame(width: 5, height: 9)
        }.offset(y: 5)
        Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(.white).offset(
          y: -10)
      }
      .frame(width: 65, height: 65)
      .scaleEffect(min(1, min(geo.size.width, geo.size.height) / 65))
      .frame(width: geo.size.width, height: geo.size.height)
    }
  }
}

struct MiniMap: View {
  let state: RaceState?
  let playerID: String
  let track: Int
  var body: some View {
    Canvas { context, size in
      func point(_ x: Double, _ z: Double) -> CGPoint {
        CGPoint(x: size.width * (0.5 + x / 200), y: size.height * (0.5 + z / 180))
      }
      var road = Path()
      for index in 0...240 {
        let p = Course.point(track, Double(index))
        if index == 0 { road.move(to: point(p.x, p.z)) } else { road.addLine(to: point(p.x, p.z)) }
      }
      context.stroke(road, with: .color(ink), lineWidth: 9)
      context.stroke(road, with: .color(.white.opacity(0.9)), lineWidth: 5)
      for p in state?.players ?? [] {
        let at = point(p.x, p.z)
        let radius: CGFloat = p.id == playerID ? 5 : 4
        let dot = Path(
          ellipseIn: CGRect(
            x: at.x - radius, y: at.y - radius, width: radius * 2, height: radius * 2))
        context.fill(dot, with: .color(Racer.all[p.racer].color))
        context.stroke(dot, with: .color(ink), lineWidth: 2)
      }
    }
  }
}

struct TrackArt: View {
  let track: Int
  var body: some View {
    ZStack {
      LinearGradient(
        colors: track == 0
          ? [Color(red: 0.3, green: 0.8, blue: 1), Color(red: 0.1, green: 0.45, blue: 0.95)]
          : [Color(red: 0.45, green: 0.2, blue: 0.85), Color(red: 1, green: 0.3, blue: 0.65)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
      Circle().fill(track == 0 ? sunshine : .white.opacity(0.9)).frame(width: 34)
        .offset(x: -48, y: -18).shadow(color: .white.opacity(0.7), radius: 10)
      MiniMap(state: nil, playerID: "", track: track).padding(12).offset(x: 14)
    }
  }
}
