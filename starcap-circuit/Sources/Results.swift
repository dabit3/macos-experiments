import SwiftUI

struct ResultsPanel: View {
  @ObservedObject var client: RaceClient
  let width: CGFloat

  var body: some View {
    let rank = client.me?.rank ?? 1
    let (number, suffix) = ordinal(rank)
    let fill: [Color] =
      rank == 1 ? [sunshine, .orange] : [.white, Color(red: 0.55, green: 0.8, blue: 1)]
    let next = Course.names[(client.state?.track ?? 0) == 0 ? 1 : 0]
    return ZStack {
      LinearGradient(
        colors: [ink.opacity(0.2), ink.opacity(0.65)], startPoint: .leading, endPoint: .trailing
      ).ignoresSafeArea()
      Confetti(time: client.clock).ignoresSafeArea().allowsHitTesting(false)
      HStack(spacing: 16) {
        VStack(spacing: 4) {
          Ribbon(text: Course.names[client.state?.track ?? 0], tint: skyBlue)
          HStack(alignment: .top, spacing: 2) {
            OutlinedText(text: number, size: 110, fill: fill, stroke: 4)
            OutlinedText(text: suffix, size: 40, fill: fill, stroke: 3).padding(.top, 16)
          }
          OutlinedText(
            text: rank == 1 ? "SUPERSTAR!" : "SO CLOSE!", size: 32,
            fill: rank == 1 ? [.white, sunshine] : [.white, skyBlue], stroke: 2.5)
          Text(rank == 1 ? "You took the checkered flag." : "Grab a rematch and take it back.")
            .font(label(12)).foregroundStyle(.white).shadow(color: ink, radius: 0, x: 1, y: 1)
        }.frame(width: width * 0.36)
        VStack(alignment: .leading, spacing: 9) {
          HStack {
            Text("FINISH ORDER").font(display(20)).foregroundStyle(ink)
            Spacer()
            Text("ROOM \(client.code)").font(label(10)).foregroundStyle(ink.opacity(0.5))
          }
          ForEach((client.state?.players ?? []).sorted { $0.rank < $1.rank }) { p in row(p) }
          Spacer(minLength: 0)
          HStack(spacing: 10) {
            ArcadeButton("REMATCH • \(next)", height: 46, icon: "arrow.triangle.2.circlepath") {
              client.rematch()
            }
            ArcadeButton("GARAGE", tint: .white, height: 46) { client.leave() }
              .frame(width: 118)
          }
          Text("Same rivals, fresh course. Both racers ready up again.")
            .font(label(9)).foregroundStyle(ink.opacity(0.5)).frame(maxWidth: .infinity)
        }
        .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CardBackground())
      }.padding(.horizontal, 12).padding(.vertical, 14)
    }
  }

  private func row(_ p: KartState) -> some View {
    let mine = p.id == client.playerID
    let medal = p.rank == 1 ? sunshine : Color(red: 0.78, green: 0.82, blue: 0.9)
    return HStack(spacing: 10) {
      ZStack {
        Circle().fill(medal).overlay(Circle().strokeBorder(ink, lineWidth: 2.5))
        Text("\(p.rank)").font(display(20)).foregroundStyle(ink)
      }.frame(width: 38, height: 38)
      RacerPortrait(racer: p.racer).frame(width: 44, height: 44)
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(p.name).font(display(17)).foregroundStyle(ink).lineLimit(1)
            .minimumScaleFactor(0.6)
          if mine {
            Text("YOU").font(display(9)).foregroundStyle(.white).padding(.horizontal, 6)
              .padding(.vertical, 2).background(cherry, in: Capsule())
          }
        }
        HStack(spacing: 5) {
          chip("shippingbox.fill", "\(p.shots) ITEMS")
          chip("sparkles", "\(p.drifts) TURBOS")
          chip("bolt.fill", "\(p.hits) HITS")
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
      Text(p.finish > 0 ? String(format: "%.2fs", p.finish / 1000) : "DNF")
        .font(.system(size: 18, weight: .black, design: .rounded)).monospacedDigit()
        .foregroundStyle(ink).fixedSize()
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: 15).fill(
        mine ? Racer.all[p.racer].color.opacity(0.25) : ink.opacity(0.05))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 15).strokeBorder(mine ? ink : .clear, lineWidth: 2.5))
  }

  private func chip(_ icon: String, _ text: String) -> some View {
    Label(text, systemImage: icon).font(label(8)).foregroundStyle(ink.opacity(0.65))
      .padding(.horizontal, 6).padding(.vertical, 2)
      .background(.white, in: Capsule())
      .overlay(Capsule().strokeBorder(ink.opacity(0.12)))
  }
}

struct Confetti: View {
  let time: Double
  var body: some View {
    Canvas { context, size in
      let colors: [Color] = [cherry, sunshine, mintGlow, skyBlue, .white, .purple]
      for i in 0..<70 {
        let seed = Double(i)
        let x = (sin(seed * 91.7) * 0.5 + 0.5) * size.width + sin(time * 1.3 + seed) * 18
        let fall = (time * (40 + (seed * 13).truncatingRemainder(dividingBy: 50)) + seed * 37)
        let y = fall.truncatingRemainder(dividingBy: size.height + 40) - 20
        let spin = time * 4 + seed
        let rect = CGRect(x: -4, y: -7 * abs(cos(spin)), width: 8, height: 14 * abs(cos(spin)))
        var piece = context
        piece.translateBy(x: x, y: y)
        piece.rotate(by: .radians(spin * 0.6))
        piece.fill(Path(rect), with: .color(colors[i % colors.count]))
      }
    }
  }
}
