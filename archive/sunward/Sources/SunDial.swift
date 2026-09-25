import SwiftUI
import UIKit

struct SunDial: View {
  let day: SunDay
  let place: Place
  let date: Date
  let onScrub: (Double) -> Void
  @Binding var isScrubbing: Bool

  private func point(_ position: SunPosition, size: CGSize) -> CGPoint {
    let radius = min(size.width, size.height) * 0.33
    let distance =
      radius
      * (position.altitude >= 0 ? 1 - position.altitude / 90 : 1 - position.altitude / 90 * 0.18)
    let angle = (position.azimuth - 90) * .pi / 180
    return CGPoint(
      x: size.width / 2 + cos(angle) * distance, y: size.height / 2 + sin(angle) * distance)
  }

  var body: some View {
    GeometryReader { geometry in
      Canvas { context, size in
        let sun = Solar.position(at: date, place: place)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.33
        let outer = radius * 1.28
        let circle = CGRect(
          x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(
          Path(
            ellipseIn: CGRect(
              x: center.x - radius * 1.18, y: center.y - radius * 1.18, width: radius * 2.36,
              height: radius * 2.36)),
          with: .color(Color(red: 0.20, green: 0.25, blue: 0.37).opacity(0.22)))
        context.fill(
          Path(ellipseIn: circle),
          with: .radialGradient(
            Gradient(colors: [
              sun.altitude < -6
                ? Color(red: 0.16, green: 0.23, blue: 0.39)
                : Palette.copper.opacity(0.42),
              Color(red: 0.16, green: 0.19, blue: 0.30).opacity(0.7),
            ]),
            center: CGPoint(x: center.x, y: center.y + radius * 0.65), startRadius: 0,
            endRadius: radius * 1.7))
        for ratio in [0.33, 0.66, 1.0] {
          let r = radius * ratio
          context.stroke(
            Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
            with: .color(Palette.cream.opacity(ratio == 1 ? 0.4 : 0.1)), lineWidth: 0.7)
        }
        for degree in stride(from: 0, to: 360, by: 5) {
          let angle = (Double(degree) - 90) * .pi / 180
          let long = degree % 30 == 0
          var tick = Path()
          tick.move(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
          tick.addLine(
            to: CGPoint(
              x: center.x + cos(angle) * (outer - (long ? 8 : 3)),
              y: center.y + sin(angle) * (outer - (long ? 8 : 3))))
          context.stroke(
            tick, with: .color(Palette.cream.opacity(long ? 0.55 : 0.2)), lineWidth: 0.8)
        }
        for (index, label) in ["N", "E", "S", "W"].enumerated() {
          let angle = (Double(index * 90) - 90) * .pi / 180
          context.draw(
            Text(label).font(.system(size: 12, weight: .medium, design: .monospaced))
              .foregroundColor(Palette.cream),
            at: CGPoint(
              x: center.x + cos(angle) * (outer + 12), y: center.y + sin(angle) * (outer + 12)))
        }
        var cross = Path()
        cross.move(to: CGPoint(x: center.x - 5, y: center.y))
        cross.addLine(to: CGPoint(x: center.x + 5, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - 5))
        cross.addLine(to: CGPoint(x: center.x, y: center.y + 5))
        context.stroke(cross, with: .color(Palette.cream.opacity(0.25)), lineWidth: 0.7)
        context.draw(
          Text("90°").font(.system(size: 11, design: .monospaced)).foregroundColor(
            Palette.muted), at: CGPoint(x: center.x, y: center.y + 17))
        context.draw(
          Text("0°").font(.system(size: 10, design: .monospaced)).foregroundColor(Palette.muted),
          at: CGPoint(x: center.x + 12, y: center.y - radius + 12))
        for index in 1..<day.samples.count {
          let a = day.samples[index - 1]
          let b = day.samples[index]
          var segment = Path()
          segment.move(to: point(a.position, size: size))
          segment.addLine(to: point(b.position, size: size))
          let golden = (-4...6).contains(b.position.altitude)
          context.stroke(
            segment,
            with: .color(
              golden
                ? Palette.cream
                : b.position.altitude >= 0
                  ? Palette.copper : Color(red: 0.47, green: 0.58, blue: 0.76)),
            style: StrokeStyle(
              lineWidth: golden ? 3 : 1.5, lineCap: .round,
              dash: b.position.altitude < -4 ? [2, 3] : []))
        }
        let p = point(sun, size: size)
        if isScrubbing {
          context.stroke(
            Path(ellipseIn: CGRect(x: p.x - 15, y: p.y - 15, width: 30, height: 30)),
            with: .color(Palette.cream), lineWidth: 1)
        }
        for r in [20.0, 12.0, 6.0] {
          context.fill(
            Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
            with: .color(
              (sun.altitude >= -4 ? Palette.copper : Palette.cream).opacity(
                r == 6 ? 1 : r == 12 ? 0.15 : 0.05)))
        }
      }
      .overlay {
        DialTouchSurface(
          shouldBegin: { location in
            day.samples.contains {
              let p = point($0.position, size: geometry.size)
              return hypot(p.x - location.x, p.y - location.y) < 24
            }
          },
          onMove: { location in
            let closest = day.samples.min {
              let a = point($0.position, size: geometry.size)
              let b = point($1.position, size: geometry.size)
              return hypot(a.x - location.x, a.y - location.y)
                < hypot(b.x - location.x, b.y - location.y)
            }
            if let closest { onScrub(day.fraction(at: closest.date)) }
          },
          onActive: { isScrubbing = $0 }
        )
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Interactive sun path, compass sky projection")
    .accessibilityValue(
      "\(Solar.time(date, in: place)), altitude \(Int(Solar.position(at: date, place: place).altitude)) degrees"
    )
    .accessibilityHint(
      "Swipe up or down to move fifteen minutes. The time slider also controls this diagram."
    )
    .accessibilityAdjustableAction { direction in
      onScrub(day.fraction(at: date) + (direction == .increment ? 900 : -900) / day.duration)
    }
  }
}

private struct DialTouchSurface: UIViewRepresentable {
  let shouldBegin: (CGPoint) -> Bool
  let onMove: (CGPoint) -> Void
  let onActive: (Bool) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    let press = UILongPressGestureRecognizer(
      target: context.coordinator, action: #selector(Coordinator.handle(_:)))
    press.minimumPressDuration = 0.25
    press.allowableMovement = 10
    press.delegate = context.coordinator
    view.addGestureRecognizer(press)
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    context.coordinator.parent = self
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    var parent: DialTouchSurface
    init(_ parent: DialTouchSurface) { self.parent = parent }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
      parent.shouldBegin(gestureRecognizer.location(in: gestureRecognizer.view))
    }

    @objc func handle(_ recognizer: UILongPressGestureRecognizer) {
      switch recognizer.state {
      case .began:
        parent.onActive(true)
        UISelectionFeedbackGenerator().selectionChanged()
        parent.onMove(recognizer.location(in: recognizer.view))
      case .changed:
        parent.onMove(recognizer.location(in: recognizer.view))
      default:
        parent.onActive(false)
      }
    }
  }
}
