import SwiftUI

struct ResultsView: View {
  @Bindable var client: GameClient
  @State private var revealed = 0
  @State private var displayedScore = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    ScrollView {
      if let result = client.results {
        VStack(spacing: 24) {
          VStack(spacing: 12) {
            Text("SERVICE COMPLETE!").font(PantryStyle.font(36, weight: "Black"))
            Text(client.level?.name ?? "Panic Pantry").font(PantryStyle.font(20))
            Stars(count: revealed, size: 52)
            Text("\(displayedScore)").font(.custom("Nunito-Black", size: 76))
              .contentTransition(.numericText()).foregroundStyle(PantryStyle.butter)
            Text("TEAM SCORE").font(PantryStyle.font(13))
          }
          .padding(28).frame(maxWidth: .infinity)
          .foregroundStyle(PantryStyle.cream)
          .background(PantryStyle.ink.gradient, in: RoundedRectangle(cornerRadius: 24))
          .overlay {
            if !reduceMotion { Confetti().allowsHitTesting(false).accessibilityHidden(true) }
          }
          .clipShape(RoundedRectangle(cornerRadius: 24))
          PantryCard {
            VStack(spacing: 14) {
              tally("Order points", result.served * 20)
              tally("Tips", result.tips)
              tally("Expired orders", -result.expired * 10)
              Divider()
              tally("Team score", result.score)
              HStack(spacing: 24) {
                ForEach(Array(result.thresholds.enumerated()), id: \.offset) { index, target in
                  VStack {
                    Stars(count: index + 1, size: 16)
                    Text("\(target)").font(PantryStyle.font(20))
                    Text(result.score >= target ? "Earned" : "\(target - result.score) to go")
                      .font(PantryStyle.font(11)).foregroundStyle(.secondary)
                  }.frame(maxWidth: .infinity)
                }
              }.padding(.top, 8)
            }
          }
          PantryCard {
            VStack(alignment: .leading, spacing: 16) {
              Text("SERVICE REPORT").font(PantryStyle.font(18, weight: "Black"))
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {
                metric("Served", result.served, "checkmark.seal.fill")
                metric("Expired", result.expired, "timer")
                metric("Best combo", result.bestCombo, "bolt.fill")
                metric("Burnt pots", result.burntPots, "flame.fill")
                metric("Wrong serves", result.wrongServes, "xmark.circle")
              }
              ForEach(result.servedByDish.keys.sorted(), id: \.self) { key in
                Text("\(Dish(rawValue: key)?.label ?? key) × \(result.servedByDish[key] ?? 0)")
              }
              Divider()
              ForEach(client.room?.players ?? []) { player in
                HStack {
                  Circle().fill(PantryStyle.chefs[max(0, player.slot) % 4]).frame(
                    width: 16, height: 16)
                  Text(player.name)
                  Spacer()
                  Text(player.bot ? "Server bot" : player.platform).foregroundStyle(.secondary)
                }
              }
            }
          }
          if client.isHost {
            Button("Rematch") { client.send(.room(.rematch)) }
              .buttonStyle(ArcadeButtonStyle())
          } else {
            Text("Waiting for the host to call a rematch…")
          }
          Button("Leave kitchen") { client.leave() }.buttonStyle(
            ArcadeButtonStyle(color: PantryStyle.ink))
        }
        .padding(24).frame(maxWidth: 880).frame(maxWidth: .infinity)
        .task(id: client.resultsMatch) {
          if reduceMotion {
            displayedScore = result.score
            revealed = result.stars
            return
          }
          for step in 1...30 {
            do { try await Task.sleep(for: .milliseconds(25)) } catch { return }
            displayedScore = result.score * step / 30
          }
          if result.stars > 0 {
            for index in 1...result.stars {
              do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
              withAnimation(.spring()) { revealed = index }
              PlatformActions.haptic(success: true)
            }
          }
        }
      }
    }
  }
  private func tally(_ label: String, _ value: Int) -> some View {
    HStack {
      Text(label)
      Spacer()
      Text("\(value)").font(.custom("JetBrainsMono-Medium", size: 24))
    }
  }
  private func metric(_ label: String, _ value: Int, _ symbol: String) -> some View {
    HStack {
      Image(systemName: symbol).foregroundStyle(PantryStyle.paprika)
      VStack(alignment: .leading) {
        Text("\(value)").font(PantryStyle.font(24, weight: "Black"))
        Text(label).font(PantryStyle.font(12))
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct Confetti: View {
  @State private var began = Date()
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
      Canvas { context, size in
        let time = timeline.date.timeIntervalSince(began)
        for index in 0..<46 {
          let phase = (time / 5 + Double(index) / 46).truncatingRemainder(dividingBy: 1)
          let x = Double((index * 67) % 101) / 100 * size.width + sin(time + Double(index)) * 12
          let y = phase * (size.height + 24) - 12
          var piece = context
          piece.translateBy(x: x, y: y)
          piece.rotate(by: .radians(time + Double(index)))
          piece.fill(
            Path(CGRect(x: -3, y: -4, width: 6, height: 8)),
            with: .color(PantryStyle.chefs[index % 4].opacity(0.75)))
        }
      }
    }
  }
}

struct HelpView: View {
  @Environment(\.dismiss) private var dismiss
  private let steps: [(String, String, String)] = [
    (
      "shippingbox.fill", "Grab ingredients",
      "Face a crate and press Grab to take a raw ingredient."
    ),
    (
      "scissors", "Chop",
      "Drop it on a cutting board, then hold Action until the bar fills. Your hands must be empty."
    ),
    (
      "flame.fill", "Cook",
      "Put three matching chopped ingredients into a pot on a stove. Cooked soup burns if you leave it!"
    ),
    (
      "leaf.fill", "Salad",
      "Combine chopped lettuce and tomato on a clean plate. No cooking required."
    ),
    (
      "fork.knife", "Plate & serve",
      "Grab a plate from the rack, scoop a cooked pot into it, then drop it at the blue pass."
    ),
    (
      "drop.fill", "Wash up",
      "Served plates return dirty. Carry the stack to the sink and hold Action with empty hands."
    ),
    (
      "fire.extinguisher.fill", "Fires",
      "Grab the extinguisher and hold Action facing the flames. Empty burnt pots into the trash."
    ),
    (
      "timer", "Tips",
      "Serve fast for tips. Serve tickets in order to grow the combo. Expired tickets cost 10 points."
    ),
    (
      "arrow.left.arrow.right", "Kitchen hazards",
      "Belts carry items. Sliding kitchens and ferries carry chefs. Watch the moving doorways."
    ),
    (
      "clock.arrow.circlepath", "Overtime",
      "A plated dish matching an open ticket earns a final five-second chance to serve."
    ),
  ]
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Text("How to play").font(PantryStyle.font(30, weight: "Black"))
          Spacer()
          Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        Text(
          "Work together to serve every ticket before it expires. Earn coins and stars across five kitchens."
        )
        ForEach(steps, id: \.0) { step in
          HStack(alignment: .top, spacing: 14) {
            Image(systemName: step.0).font(.title2).foregroundStyle(PantryStyle.paprika).frame(
              width: 32)
            VStack(alignment: .leading, spacing: 4) {
              Text(step.1).font(PantryStyle.font(18, weight: "ExtraBold"))
              Text(step.2).font(PantryStyle.font(15, weight: "Regular"))
            }
          }
        }
        Divider()
        Text("CONTROLS").font(PantryStyle.font(18, weight: "Black"))
        Text(
          "Move: WASD / arrows or joystick\nGrab / drop: Space, J, Return or Grab\nChop / wash / spray: hold E, K, Shift or Action\nDash: F, L or Dash\nEmotes: 1–6 or smile button\nMenu: Escape · Quick pings: T\nTap/click a nearby station to grab or drop there."
        )
        .font(PantryStyle.font(15)).lineSpacing(6)
        Text(
          "Opening a menu does not pause the shared match. Your chef stops moving when the app loses focus."
        )
        .font(PantryStyle.font(13)).foregroundStyle(.secondary)
        Button("Let's cook!") { dismiss() }.buttonStyle(ArcadeButtonStyle())
      }.padding(28).frame(maxWidth: 650)
    }
    .frame(minWidth: 300, minHeight: 400)
    .font(PantryStyle.font())
  }
}
