import SpriteKit
import SwiftUI

private let ice = Color(red: 0.38, green: 0.98, blue: 0.96)
private let mist = Color(red: 0.57, green: 0.65, blue: 0.76)
private let coral = Color(red: 1, green: 0.40, blue: 0.48)
private let panel = Color(red: 0.045, green: 0.065, blue: 0.12)

struct FlightView: View {
  @ObservedObject var flight: FlightController
  @Environment(\.scenePhase) private var scenePhase
  @State private var scene = CanyonScene(size: CGSize(width: 402, height: 874))

  var body: some View {
    ZStack {
      SpriteView(scene: scene, options: [.ignoresSiblingOrder])
        .ignoresSafeArea()
        .accessibilityLabel("Luminous hovercraft flying through a three-lane neon canyon")
        .gesture(
          DragGesture(minimumDistance: 25)
            .onEnded { value in
              if abs(value.translation.width) > abs(value.translation.height) {
                flight.steer(flight.engine.lane + (value.translation.width > 0 ? 1 : -1))
              }
            })
      LinearGradient(
        colors: [.black.opacity(0.48), .clear, .clear, .black.opacity(0.85)],
        startPoint: .top, endPoint: .bottom
      )
      .ignoresSafeArea()
      .allowsHitTesting(false)
      if flight.engine.phase == .ready {
        home
      } else {
        cockpit
      }
      if flight.engine.phase == .paused { pausePanel }
      if flight.engine.phase == .ended { resultPanel }
      if flight.tutorial { tutorialPanel }
    }
    .font(.system(size: 14, weight: .medium, design: .rounded))
    .foregroundStyle(.white)
    .onAppear {
      scene.flight = flight
      flight.scene = scene
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { flight.pause() }
    }
  }

  private var home: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Label("AFTERHOURS ARCADE", systemImage: "sparkle")
          .font(.system(size: 10, weight: .bold, design: .monospaced))
          .tracking(1.8)
          .foregroundStyle(ice)
        Spacer()
        Text("VOL. 01").font(.system(size: 10, design: .monospaced)).foregroundStyle(mist)
      }
      .padding(.top, 16)
      VStack(alignment: .leading, spacing: -20) {
        Text("LUMEN").foregroundStyle(.white)
        Text("DRIFT").foregroundStyle(ice)
      }
      .font(.custom("AvenirNextCondensed-Heavy", size: 92))
      .tracking(-2.5)
      .padding(.top, 24)
      Text("Find your line. Chase the light.")
        .font(.system(size: 14, weight: .regular))
        .foregroundStyle(mist)
        .padding(.top, 8)
      Spacer(minLength: 30)
      HStack(spacing: 8) {
        Capsule().fill(ice).frame(width: 18, height: 2)
        eyebrow("CANYON 01  /  THE AFTERGLOW", color: ice)
      }
      .padding(.bottom, 16)
      HStack {
        recordStat("ENDLESS BEST", value: flight.record.endlessBest)
        Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 35)
        Spacer()
        recordStat("PRACTICE BEST", value: flight.record.practiceBest)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
      .background(panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).stroke(ice.opacity(0.15)))
      .padding(.bottom, 14)
      action("Start endless", detail: "FULL THROTTLE", symbol: "arrow.up.right", primary: true) {
        flight.start(.endless)
      }
      .accessibilityIdentifier("startEndless")
      .padding(.bottom, 10)
      action("Practice flight", detail: "LEARN THE LINE", symbol: "scope", primary: false) {
        flight.tutorial = true
      }
      .accessibilityIdentifier("practiceFlight")
      HStack {
        Text("OFFLINE. IN THE FLOW.")
        Spacer()
        Text("SWIPE / TAP")
      }
      .font(.system(size: 9, weight: .medium, design: .monospaced))
      .tracking(1.2)
      .foregroundStyle(mist.opacity(0.7))
      .padding(.top, 17)
      .padding(.bottom, 9)
    }
    .padding(.horizontal, 26)
  }

  private var cockpit: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 0) {
          eyebrow(
            flight.engine.mode == .practice ? "PRACTICE  /  SLOW FLOW" : "ENDLESS  /  LIVE RUN",
            color: ice)
          Text(String(format: "%05d", flight.engine.score))
            .font(.custom("AvenirNextCondensed-DemiBold", size: 64))
            .monospacedDigit()
            .accessibilityIdentifier("score")
            .accessibilityLabel("Score \(flight.engine.score)")
        }
        Spacer()
        Button(action: flight.pause) {
          Image(systemName: "pause.fill")
            .font(.system(size: 16, weight: .bold))
            .frame(width: 48, height: 48)
            .background(panel.opacity(0.85), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.15)))
        }
        .accessibilityLabel("Pause flight")
        .accessibilityIdentifier("pauseFlight")
      }
      .padding(.top, 16)
      HStack(spacing: 14) {
        HStack(spacing: 5) {
          Image(systemName: "shield.lefthalf.filled")
          ForEach(0..<2) { index in
            Capsule()
              .fill(index < flight.engine.shields ? ice : .white.opacity(0.13))
              .frame(width: 17, height: 5)
          }
        }
        .foregroundStyle(flight.engine.shields == 0 ? coral : ice)
        .accessibilityLabel("\(flight.engine.shields) shields remaining")
        Spacer()
        Label("\(flight.engine.energy)", systemImage: "bolt.fill").foregroundStyle(ice)
          .accessibilityLabel("\(flight.engine.energy) energy collected")
        Text("×\(flight.engine.multiplier)")
          .foregroundStyle(flight.engine.multiplier > 1 ? ice : mist)
        Text("\(Int(flight.engine.distance)) m").foregroundStyle(mist)
      }
      .font(.system(size: 13, weight: .semibold, design: .monospaced))
      .padding(.bottom, 18)
      Rectangle().fill(.white.opacity(0.1)).frame(height: 1)
      if flight.engine.mode == .practice {
        practiceGuide.padding(.top, 15)
      }
      Spacer()
      if !flight.message.isEmpty {
        VStack(spacing: 5) {
          eyebrow(
            flight.message,
            color: flight.message.contains("SHIELD") || flight.message.contains("HULL")
              ? coral : ice)
          Text(flight.messageDetail)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(mist)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(panel.opacity(0.9), in: Capsule())
        .padding(.bottom, 100)
        .allowsHitTesting(false)
      }
      HStack(spacing: 10) {
        laneButton(0, title: "LEFT", symbol: "arrow.left")
        laneButton(1, title: "CENTER", symbol: "arrow.up")
        laneButton(2, title: "RIGHT", symbol: "arrow.right")
      }
      .padding(.bottom, 12)
      eyebrow("TAP A LANE  ·  SWIPE TO SHIFT", color: mist.opacity(0.8))
        .padding(.bottom, 12)
    }
    .padding(.horizontal, 24)
  }

  private var practiceGuide: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let wave = flight.engine.approaching {
        let names = ["LEFT", "CENTER", "RIGHT"]
        HStack {
          eyebrow("ENERGY → \(names[wave.energy])", color: ice)
          Spacer()
          Text("\(max(0, Int(ceil((1 - wave.progress) * flight.engine.mode.travelTime))))s")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(mist)
        }
        HStack(spacing: 7) {
          Image(systemName: "exclamationmark.diamond")
            .foregroundStyle(coral)
          Text("Coral on \(names[wave.hazard].lowercased()). Choose your line.")
            .font(.system(size: 12))
            .foregroundStyle(mist)
        }
        GeometryReader { proxy in
          Capsule().fill(.white.opacity(0.06))
            .overlay(alignment: .leading) {
              Capsule().fill(ice.opacity(0.6))
                .frame(width: proxy.size.width * min(1, wave.progress))
            }
        }
        .frame(height: 2)
      }
    }
    .padding(14)
    .background(panel.opacity(0.76), in: RoundedRectangle(cornerRadius: 14))
    .accessibilityIdentifier("practiceGuide")
  }

  private var pausePanel: some View {
    overlayCard {
      eyebrow("FLIGHT PAUSED", color: ice)
      Text("Take a breath.").font(.custom("AvenirNextCondensed-DemiBold", size: 46))
      Text("The canyon can wait. Your line is right where you left it.")
        .font(.system(size: 14)).foregroundStyle(mist)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 12)
      action(
        "Resume flight", detail: "", symbol: "play.fill", primary: true, execute: flight.resume
      )
      .accessibilityIdentifier("resumeFlight")
      action("Restart flight", detail: "", symbol: "arrow.counterclockwise", primary: false) {
        flight.start(flight.engine.mode)
      }
      action(
        "Return to hangar", detail: "", symbol: "arrow.down.right", primary: false,
        execute: flight.home)
    }
  }

  private var resultPanel: some View {
    overlayCard {
      eyebrow("SIGNAL LOST  /  \(flight.engine.mode.title.uppercased())", color: coral)
      Text("One more horizon.").font(.custom("AvenirNextCondensed-DemiBold", size: 40))
      Text(String(format: "%05d", flight.engine.score))
        .font(.custom("AvenirNextCondensed-Heavy", size: 80))
        .foregroundStyle(ice)
        .monospacedDigit()
        .accessibilityIdentifier("finalScore")
      HStack {
        resultStat("ENERGY", value: "\(flight.engine.energy)")
        Spacer()
        resultStat("NEAR MISSES", value: "\(flight.engine.nearMisses)")
        Spacer()
        resultStat("DISTANCE", value: "\(Int(flight.engine.distance)) m")
      }
      .padding(.bottom, 10)
      HStack(spacing: 8) {
        Image(systemName: "crown").foregroundStyle(ice)
        Text(
          "\(flight.engine.mode.title) best  \(String(format: "%05d", flight.record.best(for: flight.engine.mode)))"
        )
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundStyle(mist)
      }
      .padding(.bottom, 16)
      action("Fly again", detail: "", symbol: "arrow.up.right", primary: true) {
        flight.start(flight.engine.mode)
      }
      .accessibilityIdentifier("flyAgain")
      action(
        "Return to hangar", detail: "", symbol: "arrow.down.right", primary: false,
        execute: flight.home)
    }
  }

  private var tutorialPanel: some View {
    overlayCard {
      HStack {
        eyebrow("FLIGHT SCHOOL  /  01", color: ice)
        Spacer()
        Button {
          flight.tutorial = false
        } label: {
          Image(systemName: "xmark").frame(width: 34, height: 34)
        }
        .accessibilityLabel("Close flight school")
      }
      Text("Make your first\nclean line.")
        .font(.custom("AvenirNextCondensed-DemiBold", size: 46))
        .lineSpacing(-6)
        .padding(.bottom, 6)
      lesson(
        "01", symbol: "arrow.left.and.right", title: "Pick a lane",
        detail: "Tap LEFT, CENTER or RIGHT. Swipe to shift one lane.")
      lesson(
        "02", symbol: "bolt", title: "Chase cyan. Dodge coral.",
        detail: "Energy earns 100 points. Pass beside a hazard for a near-miss combo.")
      lesson(
        "03", symbol: "shield", title: "Two shields. One hull.",
        detail: "Two impacts are absorbed. A third ends your flight. Pause whenever you need.")
      Text("SLOW FLOW   /   12 SECONDS TO READ EACH WAVE")
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundStyle(ice)
        .padding(.vertical, 12)
      action("Enter practice", detail: "", symbol: "arrow.up.right", primary: true) {
        flight.tutorial = false
        flight.start(.practice)
      }
      .accessibilityIdentifier("enterPractice")
    }
  }

  private func laneButton(_ lane: Int, title: String, symbol: String) -> some View {
    Button {
      flight.steer(lane)
    } label: {
      VStack(spacing: 7) {
        Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
        Text(title).font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 62)
      .foregroundStyle(flight.engine.lane == lane ? ice : mist)
      .background(
        flight.engine.lane == lane ? ice.opacity(0.13) : panel.opacity(0.85),
        in: RoundedRectangle(cornerRadius: 15)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 15).stroke(
          flight.engine.lane == lane ? ice.opacity(0.65) : .white.opacity(0.10)))
    }
    .accessibilityLabel("Steer \(title.lowercased())")
    .accessibilityIdentifier("lane\(lane)")
    .accessibilityAddTraits(flight.engine.lane == lane ? [.isSelected] : [])
  }

  private func action(
    _ title: String, detail: String, symbol: String, primary: Bool, execute: @escaping () -> Void
  ) -> some View {
    Button(action: execute) {
      HStack {
        Text(title).font(.system(size: 16, weight: .semibold))
        Spacer()
        if !detail.isEmpty {
          Text(detail).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.7)
        }
        Image(systemName: symbol).font(.system(size: 17, weight: .medium)).padding(.leading, 4)
      }
      .padding(.horizontal, 18)
      .frame(height: 57)
      .foregroundStyle(primary ? Color(red: 0.015, green: 0.07, blue: 0.10) : .white)
      .background(primary ? ice : panel, in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(primary ? ice : .white.opacity(0.12)))
    }
    .buttonStyle(.plain)
  }

  private func overlayCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ZStack {
      Color.black.opacity(0.67).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 13, content: content)
        .padding(24)
        .background(
          LinearGradient(
            colors: [Color(red: 0.055, green: 0.085, blue: 0.15), panel], startPoint: .topLeading,
            endPoint: .bottomTrailing),
          in: RoundedRectangle(cornerRadius: 28)
        )
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(ice.opacity(0.22)))
        .padding(.horizontal, 24)
    }
    .accessibilityAddTraits(.isModal)
  }

  private func eyebrow(_ text: String, color: Color) -> some View {
    Text(text).font(.system(size: 10, weight: .semibold, design: .monospaced))
      .tracking(1.2).foregroundStyle(color)
  }

  private func recordStat(_ title: String, value: Int) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      eyebrow(title, color: mist)
      Text(String(format: "%05d", value))
        .font(.custom("AvenirNextCondensed-DemiBold", size: 28))
        .monospacedDigit()
    }
  }

  private func resultStat(_ title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(value).font(.custom("AvenirNextCondensed-DemiBold", size: 24))
      Text(title).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(mist)
    }
  }

  private func lesson(_ number: String, symbol: String, title: String, detail: String) -> some View
  {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: symbol).font(.system(size: 19)).foregroundStyle(ice)
        .frame(width: 36, height: 42)
        .background(ice.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
      VStack(alignment: .leading, spacing: 5) {
        Text("\(number)  \(title)").font(.system(size: 14, weight: .semibold))
        Text(detail).font(.system(size: 12)).foregroundStyle(mist)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.vertical, 5)
  }
}
