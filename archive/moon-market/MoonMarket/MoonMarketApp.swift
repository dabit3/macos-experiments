import SwiftUI
import UIKit

@main
struct MoonMarketApp: App {
  @StateObject private var store = MarketStore()
  var body: some Scene {
    WindowGroup {
      MarketRoot()
        .environmentObject(store)
        .preferredColorScheme(.dark)
    }
  }
}

struct MarketRoot: View {
  @EnvironmentObject private var store: MarketStore
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("moon.haptics") private var haptics = true
  @AppStorage("moon.learned") private var learned = false
  @State private var sheet: Panel?
  @State private var confirmRestart = false
  @State private var sharePayload: SharePayload?
  @State private var tutorialStep = 0

  private enum Panel: String, Identifiable {
    case tutorial, settings, pause
    var id: String { rawValue }
  }

  var body: some View {
    ZStack {
      Palette.ink.ignoresSafeArea()
      if store.atHome {
        home
      } else if store.run.finished {
        results
      } else if store.run.settlement != nil {
        settlement
      } else {
        market
      }
    }
    .foregroundStyle(Palette.cream)
    .tint(Palette.mint)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: store.atHome)
    .sheet(item: $sheet) { panel in
      Group {
        switch panel {
        case .tutorial: tutorial
        case .settings: settings
        case .pause: pause
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Palette.panel)
      .presentationDetents(panel == .tutorial ? [.height(510)] : [.medium])
      .presentationDragIndicator(.visible)
    }
    .sheet(item: $sharePayload) { payload in
      ShareSheet(image: payload.image, text: payload.text)
        .presentationDetents([.medium, .large])
    }
    .confirmationDialog(
      "Begin this market again?", isPresented: $confirmRestart, titleVisibility: .visible
    ) {
      Button("Restart from night 1", role: .destructive) {
        let run = store.run
        sheet = nil
        store.start(daily: run.daily, seed: run.seed)
      }
    } message: {
      Text("This run will be replaced. Your best receipt stays saved.")
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { store.save() }
    }
  }

  private var home: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 0) {
          HStack {
            brand
            Spacer()
            iconButton("slider.horizontal.3", label: "Settings", id: "settings") {
              sheet = .settings
            }
          }
          .padding(.horizontal, 24)
          .padding(.top, 10)
          VStack(spacing: 0) {
            eyebrow("A LITTLE COMMERCE AMONG THE STARS")
              .padding(.bottom, 10)
            Text("Moon Market")
              .font(Lettering.display(58))
              .tracking(-2.5)
              .minimumScaleFactor(0.7)
              .lineLimit(1)
              .foregroundStyle(Palette.gold)
            HStack(spacing: 12) {
              Rectangle().fill(Palette.rule).frame(width: 25, height: 0.5)
              Text("THE LUNAR BAZAAR").font(Lettering.label(9)).tracking(4)
              Rectangle().fill(Palette.rule).frame(width: 25, height: 0.5)
            }.foregroundStyle(Palette.muted)
          }
          .padding(.horizontal, 20)
          .padding(.top, 22)
          BazaarScene(flourishing: true)
            .frame(height: max(250, min(350, geometry.size.height * 0.41)))
            .padding(.top, -8)
          VStack(spacing: 16) {
            VStack(spacing: 4) {
              Text("Small stall. Infinite possibility.")
                .font(Lettering.italic(23))
              Text("Buy wisely. Read the crowd. Make your moonshot.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
            }.padding(.top, -12)
            FineRule().padding(.top, 2)
            HStack(spacing: 0) {
              homeFact("8", "NIGHTS")
              homeFact("90", "STARTING CREDITS")
              homeFact(String(Run.goal), "YOUR MOONSHOT")
            }
            if let run = store.archive.run, !run.finished {
              primary("Resume night \(run.round)", icon: "arrow.right", id: "resume") {
                store.atHome = false
              }
              Button("Start a fresh market") {
                store.start(daily: false)
                offerTutorial()
              }
              .font(.system(size: 15, weight: .medium))
              .frame(minHeight: 44)
              .accessibilityIdentifier("new-market")
            } else {
              primary("Open your market", icon: "arrow.right", id: "start") {
                store.start(daily: false)
                offerTutorial()
              }
            }
            Button {
              store.start(daily: true)
              offerTutorial()
            } label: {
              HStack {
                Image(systemName: "moonphase.waning.crescent").foregroundStyle(Palette.orange)
                VStack(alignment: .leading, spacing: 3) {
                  Text("The daily orbit").font(Lettering.display(19))
                  Text("A NEW MARKET, EVERY EARTH DAY")
                    .font(Lettering.label(8)).tracking(1)
                    .foregroundStyle(Palette.muted)
                }
                Spacer()
                Text(String(Run.dailySeed())).font(.system(size: 10, design: .monospaced))
                  .foregroundStyle(Palette.orange)
                Image(systemName: "arrow.up.right").font(.system(size: 12))
              }
              .padding(.horizontal, 14)
              .frame(minHeight: 54)
              .background(Palette.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: 7))
              .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.rule, lineWidth: 0.7))
            }
            .accessibilityLabel("Daily orbit. Same market for everyone today.")
            .accessibilityIdentifier("daily")
            HStack {
              Button("How to trade") {
                tutorialStep = 0
                sheet = .tutorial
              }
              .accessibilityIdentifier("how-to-play")
              Spacer()
              Text(
                store.archive.best > 0
                  ? "BEST  \(store.archive.best) cr" : "YOUR FIRST ORBIT AWAITS"
              )
              .font(.system(size: 10, weight: .semibold, design: .monospaced))
              .tracking(1)
            }
            .font(.system(size: 13))
            .foregroundStyle(Palette.muted)
            .frame(minHeight: 44)
          }
          .padding(.horizontal, 24)
          .padding(.bottom, 18)
        }
        .frame(minHeight: geometry.size.height, alignment: .top)
      }
      .scrollIndicators(.hidden)
    }
  }

  private var market: some View {
    GeometryReader { geometry in
      marketContent(compact: geometry.size.height < 700)
    }
  }

  private func marketContent(compact: Bool) -> some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          eyebrow("NIGHT \(String(format: "%02d", store.run.round)) / 08")
          Text(nightTitle).font(Lettering.display(26))
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        Spacer()
        iconButton("questionmark", label: "Trading guide", id: "guide") {
          tutorialStep = 0
          sheet = .tutorial
        }
        iconButton("pause", label: "Pause market", id: "pause") { sheet = .pause }
      }
      .padding(.horizontal, 22)
      .padding(.top, 8)
      OrbitTrack(night: store.run.round).padding(.horizontal, 24).padding(.vertical, 10)
      ScrollView {
        VStack(spacing: 12) {
          HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
              Text("\(store.run.cash)").font(Lettering.display(36))
                .contentTransition(.numericText())
              VStack(alignment: .leading, spacing: 0) {
                Text("CREDITS").font(Lettering.label(8)).tracking(1)
                Text("in your purse").font(Lettering.italic(12))
              }.foregroundStyle(Palette.muted)
            }
            .accessibilityLabel("Wallet \(store.run.cash) credits")
            Spacer()
            stat("\(store.run.occupied)/12", caption: "CRATE SPACE")
            Spacer()
            stat(
              "\(store.run.cash >= Run.goal ? Run.legendGoal : Run.goal) cr",
              caption: store.run.cash >= Run.goal ? "LEGEND GOAL" : "FINAL GOAL")
          }
          .padding(.horizontal, 24)
          if !compact {
            BazaarScene(flourishing: store.run.cash >= Run.goal, fitted: true)
              .frame(height: 158)
              .padding(.vertical, -8)
          }
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Image(systemName: "waveform.path").foregroundStyle(Palette.orange)
              Text(store.run.market.headline.uppercased())
                .font(Lettering.label(10)).tracking(0.8)
            }
            Text(store.run.market.detail)
              .font(.system(size: 12))
              .foregroundStyle(Palette.muted)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.leading, 12)
          .padding(.vertical, 3)
          .overlay(alignment: .leading) {
            Rectangle().fill(Palette.orange.opacity(0.6)).frame(width: 1)
          }
          .padding(.horizontal, 24)
          forecastNote
          VStack(spacing: 9) {
            HStack {
              eyebrow("THE PRODUCE EXCHANGE")
              Spacer()
              Text("12 SPACES · 5 cr RENT").font(
                .system(size: 9, weight: .medium, design: .monospaced)
              ).foregroundStyle(Palette.muted)
            }
            ForEach(Produce.allCases) { produce in productCard(produce) }
          }
          .padding(.horizontal, 18)
          if store.run.inventory.reduce(0, +) > 0 {
            Button {
              store.change { $0.clearInventory() }
              tick()
            } label: {
              Text("Clear carried stock for \(store.run.salvageValue) cr")
                .font(.system(size: 13, weight: .medium)).underline()
                .frame(minHeight: 44)
            }
            .accessibilityIdentifier("clear-stock")
          }
        }
        .padding(.top, 10)
        .padding(.bottom, 14)
      }
      .scrollIndicators(.visible)
      .clipped()
    }
    .safeAreaInset(edge: .bottom, spacing: 0) { orderBar }
  }

  private var nightTitle: String {
    if store.run.round == 1 { return "The moon is open." }
    if store.run.round == 8 { return "Make it a moonshot." }
    return [
      "", "", "Find your rhythm.", "A little lunar hustle.", "Read the room.",
      "Follow the starlight.", "Your stall is stirring.", "One more good trade.",
    ][store.run.round]
  }

  private var forecastNote: some View {
    HStack(spacing: 8) {
      Image(systemName: "moonphase.first.quarter").font(.system(size: 15)).foregroundStyle(
        Palette.mint)
      VStack(alignment: .leading, spacing: 3) {
        Text(store.run.round < 8 ? "TOMORROW'S QUEUE" : "LAST CALL")
          .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
        Text(
          store.run.round < 8
            ? Produce.allCases.map { "\($0.name) \(store.run.forecast.quotes[$0.rawValue].demand)" }
              .joined(separator: "  ·  ")
            : "Leftovers clear at half tonight's buy price."
        )
        .font(.system(size: 12)).foregroundStyle(Palette.muted)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 24)
  }

  private func productCard(_ produce: Produce) -> some View {
    let index = produce.rawValue
    let quote = store.run.market.quotes[index]
    let held = store.run.inventory[index]
    let quantity = store.run.order[index]
    return HStack(spacing: 10) {
      ProduceArt(kind: index).frame(width: 50, height: 70)
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 3) {
          Text(produce.name).font(Lettering.display(21))
            .lineLimit(1).minimumScaleFactor(0.8)
          if held > 0 {
            Text("+\(held) held").font(.system(size: 12, weight: .medium)).foregroundStyle(
              Palette.mint
            )
            .lineLimit(1).minimumScaleFactor(0.8)
          }
        }
        HStack(spacing: 10) {
          Text("Buy \(quote.buy)").foregroundStyle(Palette.orange)
          Text("Sell \(quote.sell)").foregroundStyle(Palette.cream)
        }
        .font(.system(size: 12, weight: .medium))
        .monospacedDigit()
        Text("\(quote.demand) want tonight")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Palette.mint)
        Text(
          held + quantity > quote.demand
            ? "\(held + quantity - quote.demand) will carry over"
            : "\(max(0, quote.demand - held - quantity)) more can sell tonight"
        )
        .font(.system(size: 12))
        .foregroundStyle(Palette.muted)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 0) {
        Button {
          store.change { $0.adjust(index, by: -1) }
          tick()
        } label: {
          Image(systemName: "minus").font(.system(size: 14, weight: .semibold)).frame(
            width: 44, height: 48)
        }
        .disabled(quantity == 0)
        .opacity(quantity == 0 ? 0.3 : 1)
        .accessibilityLabel("Remove one \(produce.name)")
        .accessibilityIdentifier("minus-\(index)")
        Text("\(quantity)")
          .font(Lettering.label(19))
          .monospacedDigit()
          .frame(width: 30)
          .lineLimit(1)
          .accessibilityLabel("\(quantity) \(produce.name) ordered")
        Button {
          store.change { $0.adjust(index, by: 1) }
          tick()
        } label: {
          Image(systemName: "plus").font(.system(size: 14, weight: .semibold)).frame(
            width: 44, height: 48)
        }
        .disabled(!store.run.canAdd(index))
        .opacity(store.run.canAdd(index) ? 1 : 0.3)
        .accessibilityLabel("Add one \(produce.name)")
        .accessibilityIdentifier("plus-\(index)")
      }
      .background(Palette.ink.opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
      .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.rule, lineWidth: 0.5))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 10)
    .foregroundStyle(Palette.cream)
    .background(
      LinearGradient(
        colors: [Palette.panel, Palette.panel.opacity(0.45)],
        startPoint: .topLeading, endPoint: .bottomTrailing),
      in: RoundedRectangle(cornerRadius: 10)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(
          quantity > 0 ? Palette.orange.opacity(0.6) : Palette.cream.opacity(0.13), lineWidth: 0.7)
    )
    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: quantity)
  }

  private var orderBar: some View {
    VStack(spacing: 10) {
      HStack {
        Text("ORDER \(store.run.orderCost)  +  RENT 5").font(
          .system(size: 11, weight: .medium, design: .monospaced))
        Spacer()
        Text("After sales  \(store.run.projectedCash) cr")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Palette.mint)
      }
      .foregroundStyle(Palette.muted)
      primary("Open market", icon: "sparkles", id: "open-market") {
        store.change { $0.openMarket() }
        if haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
      }
    }
    .padding(.horizontal, 22)
    .padding(.top, 13)
    .padding(.bottom, 10)
    .background(Palette.ink)
    .overlay(alignment: .top) { Rectangle().fill(Palette.rule).frame(height: 0.5) }
  }

  private var settlement: some View {
    let receipt = store.run.settlement
    return ScrollView {
      VStack(spacing: 16) {
        HStack {
          eyebrow("NIGHT \(store.run.round) · MARKET CLOSED")
          Spacer()
          iconButton("pause", label: "Pause market", id: "pause") { sheet = .pause }
        }
        .padding(.horizontal, 24)
        Text(receipt?.customers == 0 ? "A quiet little orbit." : "You made their night.")
          .font(Lettering.display(34))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 20)
        BazaarScene(
          flourishing: store.run.cash >= Run.goal, celebrating: (receipt?.customers ?? 0) > 0
        )
        .frame(height: 245)
        .padding(.vertical, -10)
        VStack(spacing: 13) {
          HStack {
            Text("THE NIGHT'S TAKINGS").font(.system(size: 10, weight: .bold, design: .monospaced))
              .tracking(2)
            Spacer()
            Text(
              "\(receipt?.customers ?? 0) happy \(receipt?.customers == 1 ? "customer" : "customers")"
            ).font(.system(size: 11))
          }.foregroundStyle(Palette.muted)
          HStack(spacing: 16) {
            ForEach(Produce.allCases) { produce in
              HStack(spacing: 2) {
                ProduceArt(kind: produce.rawValue).frame(width: 36, height: 40)
                Text("×\(receipt?.sold[produce.rawValue] ?? 0)")
                  .font(.system(size: 16, weight: .medium, design: .rounded))
              }
            }
          }
          Text("\((receipt?.net ?? 0) >= 0 ? "+" : "")\(receipt?.net ?? 0) cr tonight")
            .font(Lettering.display(34))
            .foregroundStyle((receipt?.net ?? 0) >= 0 ? Palette.mint : Palette.orange)
          FineRule()
          ledgerLine("Sales", "+\(receipt?.revenue ?? 0) cr")
          ledgerLine("Stock bought", "−\(receipt?.cost ?? 0) cr")
          ledgerLine("Stall rent", "−\(receipt?.rent ?? 0) cr")
          HStack(alignment: .firstTextBaseline) {
            Text("Wallet").font(.system(size: 16, weight: .medium))
            Spacer()
            Text("\(store.run.cash) cr").font(
              Lettering.display(36)
            ).foregroundStyle(Palette.mint)
          }
          if store.run.inventory.reduce(0, +) > 0 {
            Text(
              "\(store.run.inventory.reduce(0, +)) unsold \(store.run.inventory.reduce(0, +) == 1 ? "item stays" : "items stay") in your crate."
            )
            .font(.system(size: 12)).foregroundStyle(Palette.muted)
          }
          Text(
            store.run.cash >= Run.goal
              ? "Your cart has become a glowing lunar stall."
              : "\(max(0, Run.goal - store.run.cash)) credits from a glowing stall."
          )
          .font(.system(size: 12)).foregroundStyle(Palette.orange)
        }
        .padding(20)
        .background(Palette.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.rule, lineWidth: 0.5))
        .padding(.horizontal, 24)
        .padding(.bottom, 15)
      }
    }
    .scrollIndicators(.hidden)
    .safeAreaInset(edge: .bottom) {
      primary(
        store.run.round == 8
          ? "See your final receipt" : "Next night · \(store.run.round + 1) of 8",
        icon: "arrow.right", id: "next-night"
      ) {
        store.change { $0.advance() }
        tick()
      }
      .padding(.horizontal, 24).padding(.bottom, 14).background(Palette.ink)
    }
  }

  private var results: some View {
    ScrollView {
      VStack(spacing: 15) {
        HStack {
          brand
          Spacer()
          Button("Home") { store.atHome = true }
            .font(.system(size: 14, weight: .medium)).frame(minHeight: 44)
            .accessibilityIdentifier("home")
        }
        .padding(.horizontal, 24)
        eyebrow(
          store.run.won
            ? "EIGHT NIGHTS. ONE BRIGHT LITTLE STALL." : "EVERY MERCHANT STARTS SOMEWHERE."
        )
        .padding(.top, 10)
        Text(store.run.rank).font(Lettering.display(37))
          .foregroundStyle(Palette.gold)
          .multilineTextAlignment(.center).padding(.horizontal, 20)
        BazaarScene(flourishing: store.run.won, celebrating: store.run.won)
          .frame(height: 208)
          .padding(.vertical, -12)
        ReceiptView(run: store.run)
          .padding(.horizontal, 28)
        Text(
          store.run.won
            ? "The whole crater knows your name."
            : "Match your stock to the queue. Try another orbit."
        )
        .font(.system(size: 12)).foregroundStyle(Palette.muted)
        .multilineTextAlignment(.center).padding(.horizontal, 24)
        primary("Share your receipt", icon: "square.and.arrow.up", id: "share") { share() }
          .padding(.horizontal, 24)
        HStack(spacing: 16) {
          Button("Replay this seed") {
            let run = store.run
            store.start(daily: run.daily, seed: run.seed)
          }.accessibilityIdentifier("replay")
          Text("·").foregroundStyle(Palette.muted)
          Button("New orbit") { store.start(daily: false) }.accessibilityIdentifier("new-orbit")
        }
        .font(.system(size: 14, weight: .medium))
        .frame(minHeight: 44)
        Text(
          "BEST RECEIPT  \(store.archive.best) cr  ·  \(store.archive.completed) \(store.archive.completed == 1 ? "ORBIT" : "ORBITS")"
        )
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .tracking(1).foregroundStyle(Palette.muted)
      }
      .padding(.bottom, 24)
    }.scrollIndicators(.hidden)
  }

  private var tutorial: some View {
    VStack(spacing: 20) {
      HStack {
        eyebrow("FIELD NOTES · \(tutorialStep + 1) / 3")
        Spacer()
        Button("Close") { sheet = nil }.frame(minHeight: 44).accessibilityIdentifier("close-guide")
      }
      tutorialExample
      Text(
        ["Buy small. Dream lunar.", "Read the queue.", "Make eight nights count."][tutorialStep]
      )
      .font(Lettering.display(31))
      .multilineTextAlignment(.center)
      Text(
        [
          "Start with 90 credits and 12 crate spaces. Tap + to order produce. The left price is what you pay; the right is what each customer pays you.",
          "“Want” is exactly how many will buy tonight. Rival effects are already included. Unsold stock carries over; tomorrow's queue helps you plan.",
          "Open market to buy your order and serve the queue. Rent is 5 credits a night. Finish with \(Run.goal) to light up your stall, or \(Run.legendGoal) for Lunar Legend. Leftovers clear at half buy price after night 8.",
        ][tutorialStep]
      )
      .font(.system(size: 16)).foregroundStyle(Palette.muted).lineSpacing(4)
      .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      primary(
        tutorialStep == 2 ? "Let's trade" : "Next field note", icon: "arrow.right",
        id: "tutorial-next"
      ) {
        if tutorialStep == 2 {
          learned = true
          sheet = nil
        } else {
          tutorialStep += 1
        }
      }
    }
  }

  private var tutorialExample: some View {
    HStack(spacing: 14) {
      ProduceArt(kind: tutorialStep).frame(width: 66, height: 76)
      VStack(alignment: .leading, spacing: 7) {
        Text(["BUY 7  →  SELL 16", "3 IN CRATE · 2 WANT", "90 − 14 + 32 − 5"][tutorialStep])
          .font(.system(size: 14, weight: .bold, design: .monospaced))
        Text(
          [
            "9 credits earned per sale", "2 sold · 1 saved for tomorrow",
            "= 103 credits after market",
          ][tutorialStep]
        )
        .font(.system(size: 12))
      }
      Spacer(minLength: 0)
    }
    .padding(12)
    .foregroundStyle(Palette.cream)
    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.rule, lineWidth: 0.5))
  }

  private var settings: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("A quieter corner.").font(Lettering.display(32))
      Toggle("Haptic feedback", isOn: $haptics)
        .accessibilityIdentifier("haptics")
        .frame(minHeight: 44)
      Text(
        "Moon Market is intentionally silent. Motion follows your device's Reduce Motion setting. Your progress stays on this device."
      )
      .font(.system(size: 14)).foregroundStyle(Palette.muted).lineSpacing(3)
      Text("Daily orbit resets at midnight UTC.")
        .font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.mint)
      Spacer(minLength: 0)
      primary("Back to the moon", icon: "arrow.right", id: "close-settings") { sheet = nil }
    }
  }

  private var pause: some View {
    VStack(spacing: 16) {
      eyebrow("YOUR STALL IS SAFE")
      Text("Take a little moonwalk.").font(Lettering.display(30))
        .multilineTextAlignment(.center)
      Text("No timers. No rush. Every trade is saved.")
        .font(.system(size: 14)).foregroundStyle(Palette.muted)
      primary("Keep trading", icon: "play.fill", id: "resume-game") { sheet = nil }
      HStack {
        Button("Restart this seed") { confirmRestart = true }.accessibilityIdentifier("restart")
        Spacer()
        Button("Save & home") {
          store.save()
          store.atHome = true
          sheet = nil
        }.accessibilityIdentifier("save-home")
      }.font(.system(size: 14)).frame(minHeight: 44)
      Text("SEED \(store.run.seed)\(store.run.daily ? " · DAILY" : "")")
        .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted)
    }
  }

  private var brand: some View {
    HStack(spacing: 9) {
      MoonSeal(size: 32)
      VStack(alignment: .leading, spacing: 2) {
        Text("LUNE TRADING CO.").font(Lettering.label(9)).tracking(2)
        Text("PURVEYORS OF OTHERWORLDLY GOODS")
          .font(Lettering.label(6)).tracking(0.9).foregroundStyle(Palette.muted)
      }
    }
  }
  private func eyebrow(_ text: String) -> some View {
    Text(text).font(Lettering.label(9))
      .tracking(1.5).foregroundStyle(Palette.orange)
  }
  private func homeFact(_ value: String, _ label: String) -> some View {
    VStack(spacing: 5) {
      Text(value).font(Lettering.display(25))
      Text(label).font(Lettering.label(8)).tracking(0.8)
        .foregroundStyle(Palette.muted)
    }.frame(maxWidth: .infinity)
  }
  private func stat(_ value: String, caption: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(value).font(Lettering.label(16))
      Text(caption).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(0.7)
        .foregroundStyle(Palette.muted)
    }
  }
  private func ledgerLine(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label).foregroundStyle(Palette.muted)
      Spacer()
      Text(value).monospacedDigit()
    }.font(.system(size: 14))
  }
  private func primary(_ label: String, icon: String, id: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      HStack {
        Image(systemName: "moon.fill").font(.system(size: 12))
        Text(label).font(Lettering.label(16)).padding(.leading, 4)
        Spacer()
        Image(systemName: icon).font(.system(size: 15, weight: .semibold))
      }
      .padding(.horizontal, 20)
      .frame(minHeight: 56)
      .foregroundStyle(Palette.ink)
      .background(Palette.gold, in: RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 5).stroke(Palette.cream.opacity(0.5), lineWidth: 0.7)
          .padding(3)
      )
      .shadow(color: Palette.orange.opacity(0.1), radius: 18, y: 5)
    }
    .buttonStyle(PressStyle())
    .accessibilityIdentifier(id)
  }
  private func iconButton(_ icon: String, label: String, id: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: icon).font(.system(size: 15, weight: .light))
        .frame(width: 44, height: 44)
        .overlay(Circle().stroke(Palette.rule, lineWidth: 0.7))
    }.accessibilityLabel(label).accessibilityIdentifier(id)
  }
  private func offerTutorial() {
    if !learned {
      tutorialStep = 0
      sheet = .tutorial
    }
  }
  private func tick() {
    if haptics { UISelectionFeedbackGenerator().selectionChanged() }
  }
  private var shareText: String {
    "Moon Market · \(store.run.rank)\n\(store.run.cash) credits · \(store.run.profit >= 0 ? "+" : "")\(store.run.profit) profit\n8 nights · seed \(store.run.seed)\(store.run.daily ? " · Daily orbit" : "")"
  }
  private func share() {
    let renderer = ImageRenderer(
      content:
        VStack(spacing: 22) {
          Text("Moon Market").font(Lettering.display(38)).tracking(-1)
            .foregroundStyle(Palette.cream)
          Image(store.run.won ? "BazaarThriving" : "Bazaar")
            .resizable().scaledToFit().frame(width: 330, height: 220)
            .mask {
              LinearGradient(
                stops: [
                  .init(color: .clear, location: 0),
                  .init(color: .white, location: 0.09),
                  .init(color: .white, location: 0.9),
                  .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
          ReceiptView(run: store.run)
          Text("Small stall. Infinite possibility.")
            .font(Lettering.italic(17)).foregroundStyle(Palette.muted)
        }
        .padding(30).frame(width: 390).background(Palette.ink)
    )
    renderer.scale = 3
    sharePayload = SharePayload(image: renderer.uiImage, text: shareText)
  }
}

struct ReceiptView: View {
  let run: Run
  var body: some View {
    VStack(spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("LUNE TRADING CO.").font(Lettering.label(9)).tracking(2)
          Text("OFFICIAL MARKET RECEIPT").font(.system(size: 7, design: .monospaced)).tracking(1)
        }
        Spacer()
        Image(systemName: "moon.stars.fill").font(.system(size: 24, weight: .ultraLight))
      }
      Rectangle().fill(Palette.ink.opacity(0.3)).frame(height: 0.5)
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 0) {
          Text("FINAL BALANCE").font(Lettering.label(8)).tracking(1.5)
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(run.cash)").font(Lettering.display(65)).tracking(-3)
            Text("cr").font(Lettering.italic(22))
          }
        }
        Spacer()
        ZStack {
          Circle().stroke(Palette.ink.opacity(0.5), lineWidth: 1)
          Circle().stroke(Palette.ink.opacity(0.25), lineWidth: 0.5).padding(4)
          VStack(spacing: 1) {
            Image(systemName: run.won ? "sparkles" : "moon")
              .font(.system(size: 15, weight: .light))
            Text("VIII").font(Lettering.display(22))
            Text("NIGHTS").font(Lettering.label(6)).tracking(1.5)
          }
        }
        .frame(width: 70, height: 70).rotationEffect(.degrees(-12))
        .accessibilityHidden(true)
      }
      HStack {
        Text("NET PROFIT")
        Spacer()
        Text("\(run.profit >= 0 ? "+" : "")\(run.profit) cr").bold()
      }.font(.system(size: 13, design: .monospaced))
      Rectangle().fill(Palette.ink.opacity(0.2)).frame(height: 0.5)
      HStack {
        Text("NIGHTLY NET").font(Lettering.label(8)).tracking(1)
        Spacer()
        Text("CREDITS · + GAIN / − LOSS").font(.system(size: 7, design: .monospaced))
      }
      HStack(alignment: .top, spacing: 6) {
        ForEach(Array(run.history.enumerated()), id: \.offset) { index, settlement in
          let height =
            CGFloat(abs(settlement.net))
            / CGFloat(max(1, run.history.map { abs($0.net) }.max() ?? 1)) * 21
          VStack(spacing: 0) {
            Rectangle().fill(Palette.ink.opacity(0.7))
              .frame(height: settlement.net > 0 ? max(2, height) : 0)
              .frame(height: 21, alignment: .bottom)
            Rectangle().fill(Palette.ink.opacity(0.3)).frame(height: 0.5)
            Rectangle().fill(Palette.ink.opacity(0.35))
              .frame(height: settlement.net < 0 ? max(2, height) : 0)
              .frame(height: 21, alignment: .top)
            Text("\(settlement.net >= 0 ? "+" : "")\(settlement.net)")
              .font(.system(size: 8, weight: .semibold, design: .monospaced))
              .padding(.top, 3)
            Text(String(index + 1)).font(.system(size: 7, design: .monospaced)).padding(.top, 3)
          }
          .frame(maxWidth: .infinity)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Night \(index + 1), net \(settlement.net) credits")
        }
      }
      HStack {
        Text("\(run.history.reduce(0) { $0 + $1.customers }) CUSTOMERS")
        Spacer()
        Text(run.won ? "MOONSHOT MADE" : "ORBIT COMPLETE")
      }.font(.system(size: 10, design: .monospaced))
      Rectangle().fill(Palette.ink.opacity(0.25))
        .frame(height: 0.5).padding(.horizontal, -22)
      Text("\(run.daily ? "DAILY ORBIT" : "ORBIT") / \(String(run.seed))")
        .font(.system(size: 9, design: .monospaced)).tracking(1)
      Text("Thank you for trading among the stars.")
        .font(Lettering.italic(14))
    }
    .padding(22)
    .foregroundStyle(Palette.ink)
    .background(Palette.cream, in: ReceiptShape())
    .overlay { PaperGrain().clipShape(ReceiptShape()) }
    .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
    .accessibilityElement(children: .combine)
  }
}

struct ReceiptShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: .init(x: 0, y: 0))
    path.addLine(to: .init(x: rect.maxX, y: 0))
    path.addLine(to: .init(x: rect.maxX, y: rect.maxY - 7))
    let count = 22
    for index in stride(from: count, through: 0, by: -1) {
      let x = rect.width * CGFloat(index) / CGFloat(count)
      path.addLine(to: .init(x: x, y: rect.maxY - (index % 2 == 0 ? 7 : 0)))
    }
    path.closeSubpath()
    return path
  }
}

struct PressStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let image: UIImage?
  let text: String
  func makeUIViewController(context: Context) -> UIActivityViewController {
    if let image {
      return UIActivityViewController(activityItems: [image, text], applicationActivities: nil)
    }
    return UIActivityViewController(activityItems: [text], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct SharePayload: Identifiable {
  let id = UUID()
  let image: UIImage?
  let text: String
}
