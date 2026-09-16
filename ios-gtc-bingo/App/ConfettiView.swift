import SwiftUI

struct ConfettiView: View {
  @State private var start = Date()

  var body: some View {
    TimelineView(.animation) { timeline in
      Canvas { context, size in
        let elapsed = min(timeline.date.timeIntervalSince(start), 3)
        for index in 0..<120 {
          let seed = Double(index * 37 % 101) / 101
          let x = seed * size.width
          let speed = 60 + Double(index % 5) * 20
          let position = elapsed * speed + seed * size.height
          let y = (position * 1.3).truncatingRemainder(dividingBy: size.height + 40) - 20
          let s = CGFloat(4 + index % 5)
          let rect = CGRect(x: x, y: y, width: s, height: s * 1.8)
          let colors = [Theme.green, .white, Theme.charcoal]
          context.withCGContext { cg in
            cg.saveGState()
            cg.translateBy(x: rect.midX, y: rect.midY)
            cg.rotate(by: CGFloat(elapsed * Double(index + 1)))
            cg.translateBy(x: -rect.midX, y: -rect.midY)
            if let color = colors[index % colors.count].opacity(0.9).cgColor {
              cg.setFillColor(color)
              cg.fill(rect)
            }
            cg.restoreGState()
          }
        }
      }
    }
    .allowsHitTesting(false)
    .onAppear { start = Date() }
    .ignoresSafeArea()
  }
}
