import SwiftUI

struct GardenBoard: View {
  @Bindable var store: GardenStore

  var body: some View {
    GeometryReader { geometry in
      let inset = 68.0
      let hedge = 22.0
      let field = geometry.size.width - inset - hedge
      let cell = field / 7.5
      let laneHeight = geometry.size.height / 5
      let phase = store.garden.elapsed
      let nextLane =
        store.garden.endless && store.garden.wave >= 4 && store.garden.phase == .playing
        ? store.garden.schedule.first?.lane : nil
      ZStack(alignment: .topLeading) {
        Canvas { context, size in
          let brush = Brush(context: context)
          context.fill(
            Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 18),
            with: .linearGradient(
              Gradient(colors: [
                Color(red: 0.47, green: 0.60, blue: 0.36),
                Color(red: 0.40, green: 0.53, blue: 0.31),
              ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
          for row in 0..<5 {
            let y = Double(row) * laneHeight
            let rect = CGRect(x: inset - 6, y: y + 1.5, width: field + 6, height: laneHeight - 3)
            let light =
              row % 2 == 0
              ? Color(red: 0.64, green: 0.80, blue: 0.42)
              : Color(red: 0.57, green: 0.74, blue: 0.38)
            let dark =
              row % 2 == 0
              ? Color(red: 0.53, green: 0.71, blue: 0.36)
              : Color(red: 0.47, green: 0.65, blue: 0.33)
            context.fill(
              Path(roundedRect: rect, cornerRadius: 9),
              with: .linearGradient(
                Gradient(colors: [light, dark]), startPoint: CGPoint(x: inset, y: y),
                endPoint: CGPoint(x: size.width, y: y)))
            if row == nextLane {
              context.stroke(
                Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 8),
                with: .color(.gold.opacity(0.55 + sin(phase * 4) * 0.25)), lineWidth: 2)
            }
            for column in 0..<7 {
              let x = inset + Double(column) * cell
              let plotRect = CGRect(x: x + 4, y: y + 6, width: cell - 8, height: laneHeight - 12)
              let plot = Path(roundedRect: plotRect, cornerRadius: 9)
              context.fill(
                plot,
                with: .linearGradient(
                  Gradient(colors: [
                    Color(red: 0.60, green: 0.43, blue: 0.27).opacity(0.7),
                    Color(red: 0.45, green: 0.30, blue: 0.18).opacity(0.85),
                  ]), startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x, y: y + laneHeight)))
              context.stroke(plot, with: .color(Color.cream.opacity(0.28)), lineWidth: 1.2)
              for furrow in 1..<4 {
                let fy = plotRect.minY + plotRect.height * Double(furrow) / 4
                brush.line(
                  [
                    CGPoint(x: plotRect.minX + 7, y: fy),
                    CGPoint(x: plotRect.maxX - 7, y: fy + (furrow % 2 == 0 ? 1 : -1)),
                  ], Color.ink.opacity(0.11), 1)
              }
            }
            for tuft in 0..<5 {
              let tx = inset + Double(tuft) * cell * 1.45 + Double(row * 9 % 30)
              let ty = y + laneHeight - 3
              brush.line(
                [CGPoint(x: tx, y: ty), CGPoint(x: tx - 2, y: ty - 5)], .cream.opacity(0.28), 1)
              brush.line(
                [CGPoint(x: tx, y: ty), CGPoint(x: tx + 2, y: ty - 6)], .cream.opacity(0.28), 1)
              brush.line(
                [CGPoint(x: tx, y: ty), CGPoint(x: tx + 5, y: ty - 3)], .cream.opacity(0.2), 1)
            }
          }
          for index in 0..<22 {
            let y = Double(index) * size.height / 22 - 4
            let x = size.width - hedge + Double((index * 7) % 3) * 3
            brush.orb(
              CGRect(x: x - 6, y: y, width: hedge + 8, height: size.height / 22 + 12),
              index % 2 == 0
                ? Color(red: 0.30, green: 0.46, blue: 0.28)
                : Color(red: 0.25, green: 0.40, blue: 0.25),
              Color(red: 0.13, green: 0.25, blue: 0.16))
          }
          for index in 0..<7 {
            let y = Double(index) * size.height / 7 + 8
            brush.oval(
              size.width - hedge + 4 + Double(index % 3) * 4, y, 5, 5,
              index % 2 == 0 ? .gold : Color(red: 0.92, green: 0.5, blue: 0.5))
          }
          for stone in 0..<18 {
            let sx = 6 + Double((stone * 23) % 40)
            let sy = Double(stone) * size.height / 18 + 3
            brush.orb(
              CGRect(x: sx, y: sy, width: 15 + Double(stone % 3) * 3, height: 9),
              Color(red: 0.80, green: 0.76, blue: 0.64), Color(red: 0.58, green: 0.55, blue: 0.46))
          }
          for post in 0..<5 {
            let y = Double(post) * laneHeight + laneHeight - 5
            brush.line(
              [CGPoint(x: inset - 8, y: y - 6), CGPoint(x: inset - 8, y: y + 6)],
              Color(red: 0.80, green: 0.74, blue: 0.58), 3)
          }
          brush.line(
            [CGPoint(x: inset - 8, y: 2), CGPoint(x: inset - 8, y: size.height - 2)],
            Color(red: 0.86, green: 0.80, blue: 0.64), 1.5)
          context.fill(
            Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 18),
            with: .radialGradient(
              Gradient(colors: [.clear, .ink.opacity(0.22)]),
              center: CGPoint(x: size.width / 2, y: size.height / 2),
              startRadius: size.height * 0.5,
              endRadius: size.width * 0.72))
        }
        if let target = store.emberTarget {
          RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.22))
            .overlay(
              RoundedRectangle(cornerRadius: 10).strokeBorder(
                Color.cream.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            )
            .frame(width: cell * 4, height: laneHeight * 3)
            .position(
              x: inset + (Double(target.column) + 0.5) * cell,
              y: (Double(target.lane) + 0.5) * laneHeight
            )
            .allowsHitTesting(false)
          RoundedRectangle(cornerRadius: 9).stroke(Color.gold, lineWidth: 3)
            .overlay {
              Image(systemName: "scope").foregroundStyle(Color.cream).font(.system(size: 21))
            }
            .frame(width: cell - 8, height: laneHeight - 12)
            .position(
              x: inset + (Double(target.column) + 0.5) * cell,
              y: (Double(target.lane) + 0.5) * laneHeight
            )
            .allowsHitTesting(false)
        }
        Cottage().frame(width: 50, height: 46)
          .position(x: 26, y: geometry.size.height / 2).allowsHitTesting(false)
          .shadow(color: .ink.opacity(0.3), radius: 3, y: 2)
        ForEach(0..<5) { row in
          ZStack {
            Circle().fill(
              LinearGradient(
                colors: [
                  Color(red: 0.76, green: 0.56, blue: 0.34),
                  Color(red: 0.52, green: 0.34, blue: 0.19),
                ],
                startPoint: .top, endPoint: .bottom)
            ).frame(width: 24, height: 24)
              .overlay(Circle().stroke(Color.cream.opacity(0.55), lineWidth: 1))
            Image(systemName: store.garden.rescuers.contains(row) ? "bird.fill" : "feather")
              .font(.system(size: 11)).foregroundStyle(
                store.garden.rescuers.contains(row) ? Color.cream : Color.ink.opacity(0.35))
          }.position(x: 51, y: (Double(row) + 0.5) * laneHeight - 7)
          Text("\(row + 1)").font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(Color.cream.opacity(0.7))
            .position(x: 51, y: (Double(row) + 0.5) * laneHeight + 11)
          ForEach(0..<7) { column in
            Button {
              store.place(lane: row, column: column)
            } label: {
              Color.clear.contentShape(Rectangle())
            }
            .frame(width: cell, height: laneHeight)
            .position(x: inset + (Double(column) + 0.5) * cell, y: (Double(row) + 0.5) * laneHeight)
            .accessibilityLabel("Lane \(row + 1), plot \(column + 1)")
            .accessibilityIdentifier("plot-\(row)-\(column)")
          }
        }
        ForEach(store.garden.plants) { plant in
          VStack(spacing: 0) {
            GardenArt(seed: plant.seed, phase: phase * 1.6 + Double(plant.column + plant.lane))
              .frame(width: laneHeight * 1.2, height: laneHeight * 1.12)
            if plant.health < plant.seed.health {
              Capsule().fill(Color.ink.opacity(0.7)).frame(width: 34, height: 4)
                .overlay(alignment: .leading) {
                  Capsule().fill(Color.gold).frame(
                    width: 34 * max(0, plant.health / plant.seed.health), height: 4)
                }
                .overlay(Capsule().stroke(Color.cream.opacity(0.8), lineWidth: 0.6))
            }
          }.position(
            x: inset + (Double(plant.column) + 0.5) * cell,
            y: (Double(plant.lane) + 0.5) * laneHeight
          )
          .allowsHitTesting(false)
        }
        ForEach(store.garden.pests) { pest in
          VStack(spacing: 0) {
            PestArt(kind: pest.kind, slowed: pest.slow > 0, phase: phase * 3 + Double(pest.id))
              .frame(width: laneHeight * 1.3, height: laneHeight * 1.04)
            Capsule().fill(Color.ink.opacity(0.3)).frame(width: 26, height: 3)
              .overlay(alignment: .leading) {
                Capsule().fill(
                  pest.slow > 0 ? Color.cyan : Color(red: 0.72, green: 0.26, blue: 0.20)
                )
                .frame(
                  width: 26 * max(0, pest.health / (pest.kind.health * pest.strength)), height: 3)
              }
          }.position(x: inset + pest.x * cell, y: (Double(pest.lane) + 0.5) * laneHeight)
            .allowsHitTesting(false)
        }
        ForEach(store.garden.shots) { shot in
          let tint =
            shot.icy
            ? Color(red: 0.75, green: 0.92, blue: 1) : Color(red: 0.90, green: 0.96, blue: 0.48)
          Capsule().fill(
            LinearGradient(
              colors: [tint.opacity(0), tint], startPoint: .leading, endPoint: .trailing)
          )
          .frame(width: 30, height: 5)
          .overlay(alignment: .trailing) {
            Circle().fill(
              RadialGradient(colors: [.white, tint], center: .center, startRadius: 0, endRadius: 5)
            )
            .frame(width: 10, height: 10)
            .shadow(color: (shot.icy ? Color.cyan : Color.gold).opacity(0.7), radius: 4)
          }
          .position(x: inset + shot.x * cell - 8, y: (Double(shot.lane) + 0.42) * laneHeight)
          .allowsHitTesting(false)
        }
        ForEach(store.garden.bursts) { burst in
          let progress = 1 - burst.life / 0.7
          ZStack {
            Circle().stroke(
              burst.fiery ? Color.orange : Color.cream, lineWidth: burst.fiery ? 9 : 2.5
            )
            .frame(width: progress * (burst.fiery ? cell * 3 : 26))
            if burst.fiery {
              Circle().fill(
                RadialGradient(
                  colors: [.gold.opacity(0.7), .clear], center: .center, startRadius: 0,
                  endRadius: cell)
              )
              .frame(width: cell * 1.6)
            }
            ForEach(0..<6, id: \.self) { spark in
              let angle = Double(spark) * .pi / 3 + (burst.fiery ? 0.4 : 0)
              Circle().fill(burst.fiery ? Color.gold : Color.cream)
                .frame(width: burst.fiery ? 6 : 3)
                .offset(
                  x: cos(angle) * progress * (burst.fiery ? cell * 1.4 : 16),
                  y: sin(angle) * progress * (burst.fiery ? cell * 1.4 : 16))
            }
          }
          .opacity(burst.life / 0.7)
          .position(x: inset + burst.x * cell, y: (Double(burst.lane) + 0.5) * laneHeight)
          .allowsHitTesting(false)
        }
        ForEach(store.garden.drops) { drop in
          let pulse = 0.5 + sin(phase * 5 + Double(drop.id)) * 0.5
          Button {
            store.collect(drop.id)
          } label: {
            ZStack {
              Circle().fill(
                RadialGradient(
                  colors: [.gold.opacity(0.45), .clear], center: .center, startRadius: 6,
                  endRadius: 24)
              )
              .frame(width: 48, height: 48).scaleEffect(1 + pulse * 0.12)
              SunCoin().frame(width: 32, height: 32)
                .shadow(color: Color.goldDeep.opacity(0.5), radius: 2, y: 2)
              Text("\(drop.amount)").font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 0.26, blue: 0.05))
            }.frame(width: 46, height: 46).contentShape(Circle())
              .offset(y: sin(phase * 2.5 + Double(drop.id)) * 2)
          }.buttonStyle(.plain)
            .position(x: inset + drop.x * cell, y: (Double(drop.lane) + 0.3) * laneHeight)
            .accessibilityLabel("Gather \(drop.amount) sunshine")
        }
      }.clipped().clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
          RoundedRectangle(cornerRadius: 18).stroke(
            LinearGradient(
              colors: [.cream.opacity(0.45), .cream.opacity(0.12)], startPoint: .top,
              endPoint: .bottom), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }
  }
}

/// A gold sun coin used for sunshine drops and the HUD medallion.
struct SunCoin: View {
  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width / 32, y: size.height / 32)
      let brush = Brush(context: context)
      for index in 0..<8 {
        let angle = Double(index) * .pi / 4
        brush.line(
          [
            CGPoint(x: 16 + cos(angle) * 11, y: 16 + sin(angle) * 11),
            CGPoint(x: 16 + cos(angle) * 15.5, y: 16 + sin(angle) * 15.5),
          ], .goldDeep, 2.5)
      }
      brush.orb(
        CGRect(x: 4, y: 4, width: 24, height: 24), Color(red: 1, green: 0.92, blue: 0.55), .gold)
      brush.outline(CGRect(x: 4, y: 4, width: 24, height: 24), .goldDeep, 1.5)
      brush.outline(CGRect(x: 7, y: 7, width: 18, height: 18), .goldDeep.opacity(0.35), 0.8)
    }.accessibilityHidden(true)
  }
}
