import Charts
import SwiftUI

struct GameView: View {
  @ObservedObject var store: GameStore
  var body: some View {
    VStack(spacing: 0) {
      HUDView(store: store)
      ScrollView(showsIndicators: false) {
        VStack(spacing: 14) {
          if store.tab == .fabs || store.tab == .upgrades { TapZone(store: store) }
          Group {
            switch store.tab {
            case .fabs: FabsView(store: store)
            case .upgrades: UpgradesView(store: store)
            case .research: ResearchView(store: store)
            case .market: MarketView(store: store)
            case .awards: AchievementsView(store: store)
            }
          }
        }.padding(.horizontal, 16).padding(.bottom, 90)
      }
    }
    .safeAreaInset(edge: .bottom) { TabBar(store: store) }
  }
}

struct HUDView: View {
  @ObservedObject var store: GameStore
  var engine: GameEngine { store.engine }
  var body: some View {
    VStack(spacing: 9) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 1) {
          Text(NumberFormat.formatCash(engine.state.cash)).font(
            .system(size: 31, weight: .black, design: .monospaced)
          )
          .contentTransition(.numericText()).foregroundStyle(.white)
          Text("LIQUID CASH").font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(Theme.muted)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text(NumberFormat.formatRate(engine.gpusPerSecond)).foregroundStyle(Theme.lime)
          Text(NumberFormat.formatCash(engine.cashPerSecond) + "/s").foregroundStyle(Theme.green)
        }.font(.system(size: 12, weight: .bold, design: .monospaced))
        Button {
          store.showingSettings = true
        } label: {
          Image(systemName: "gearshape").font(.title3)
        }.padding(.leading, 10)
      }
      HStack {
        Label(engine.state.node.displayName, systemImage: "microchip.fill")
        Spacer()
        Text("GEN \(engine.state.generation) · \(Architecture.name(for: engine.state.generation))")
        Spacer()
        Text("RP \(NumberFormat.format(engine.state.researchPoints))").foregroundStyle(Theme.green)
      }.font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Theme.muted)
      TickerView(engine: engine)
    }
    .padding(.horizontal, 16).padding(.top, 9).padding(.bottom, 10)
    .background(.ultraThinMaterial)
  }
}

struct TapZone: View {
  @ObservedObject var store: GameStore
  @State private var pressed = false
  var body: some View {
    ZStack {
      Circle().fill(Theme.green.opacity(0.08)).frame(width: 240, height: 240).blur(radius: 18)
      DieArt(size: 184).scaleEffect(pressed ? 0.92 : 1).animation(
        .spring(response: 0.22, dampingFraction: 0.45), value: pressed)
      TimelineView(.animation(minimumInterval: 1 / 30)) { context in
        ForEach(store.floatingNumbers) { item in
          let age = min(1, max(0, context.date.timeIntervalSince(item.birth)))
          let progress = age / 0.9
          Text(item.value).font(.system(size: 15, weight: .black, design: .monospaced))
            .foregroundStyle(Theme.lime).offset(
              x: item.x,
              y: item.y - 78 - 90 * min(1, progress)
            ).opacity(max(0, 1 - progress)).rotationEffect(.degrees(item.rotation))
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
      }
    }
    .frame(maxWidth: .infinity).frame(height: 230)
    .contentShape(Rectangle())
    .onTapGesture {
      pressed = true
      store.tap()
      withAnimation(.easeOut(duration: 0.45)) { pressed = false }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "GPU chip tap zone. Worth \(NumberFormat.formatCash(store.engine.tapValueCash))"
    )
    .accessibilityAddTraits(.isButton)
  }
}

struct TabBar: View {
  @ObservedObject var store: GameStore
  var body: some View {
    HStack {
      ForEach(GameTab.allCases, id: \.self) { tab in
        Button {
          withAnimation(.easeOut(duration: 0.2)) { store.tab = tab }
        } label: {
          VStack(spacing: 4) {
            Image(systemName: tab.symbol).font(.system(size: 17, weight: .bold))
            Text(tab.rawValue).font(.system(size: 9, weight: .bold, design: .monospaced))
          }.frame(maxWidth: .infinity).foregroundStyle(store.tab == tab ? Theme.lime : Theme.muted)
        }.accessibilityLabel(tab.rawValue)
      }
    }.padding(.top, 9).padding(.bottom, 5).background(Theme.panel.opacity(0.98)).overlay(
      alignment: .top
    ) { Rectangle().fill(Theme.green.opacity(0.25)).frame(height: 1) }
  }
}

struct SectionHeader: View {
  let eyebrow: String
  let title: String
  var body: some View {
    HStack(alignment: .lastTextBaseline) {
      VStack(alignment: .leading, spacing: 1) {
        Text(eyebrow).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(
          Theme.green)
        Text(title).font(.system(size: 23, weight: .black, design: .rounded))
      }
      Spacer()
    }
  }
}

struct Panel<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(13).frame(maxWidth: .infinity, alignment: .leading).background(
      Theme.panel, in: RoundedRectangle(cornerRadius: 14)
    )
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.green.opacity(0.14), lineWidth: 1))
  }
}

struct FabsView: View {
  @ObservedObject var store: GameStore
  @State private var quantity = 1
  var body: some View {
    VStack(spacing: 10) {
      HStack {
        SectionHeader(eyebrow: "PRODUCTION FLOOR", title: "Your Fabs")
        Picker("Buy quantity", selection: $quantity) {
          Text("x1").tag(1)
          Text("x10").tag(10)
          Text("MAX").tag(100)
        }.pickerStyle(.segmented).frame(width: 175)
      }
      ForEach(BuildingKind.allCases, id: \.self) { kind in
        BuildingRow(store: store, kind: kind, quantity: quantity)
      }
    }
  }
}

struct BuildingRow: View {
  @ObservedObject var store: GameStore
  let kind: BuildingKind
  let quantity: Int
  var purchaseCount: Int {
    guard quantity > 1 else { return 1 }
    return max(1, min(quantity, store.engine.affordableCount(of: kind)))
  }
  var cost: Double { store.engine.cost(of: kind, count: purchaseCount) }
  var canPurchase: Bool { store.engine.affordableCount(of: kind) >= 1 }
  var body: some View {
    Panel {
      HStack(spacing: 12) {
        Image(systemName: kind.symbol).font(.title2).foregroundStyle(Theme.green).frame(width: 31)
        VStack(alignment: .leading, spacing: 3) {
          Text(kind.displayName).font(.headline)
          Text(kind.flavor).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
          Text(
            NumberFormat.formatRate(kind.baseRate * Double(store.engine.state.buildings[kind] ?? 0))
          ).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Theme.green)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 5) {
          Text("×\(store.engine.state.buildings[kind] ?? 0)").font(
            .system(size: 19, weight: .black, design: .monospaced))
          Button {
            store.buy(kind, quantity: quantity)
          } label: {
            Text((quantity == 100 ? "MAX · " : "") + NumberFormat.formatCash(cost)).font(
              .system(size: 11, weight: .bold, design: .monospaced)
            ).padding(.horizontal, 10).padding(.vertical, 7).background(
              canPurchase ? Theme.green : Theme.panel2, in: Capsule()
            ).foregroundStyle(canPurchase ? .black : Theme.muted)
          }
          .disabled(!canPurchase)
        }
      }
    }
  }
}

struct UpgradesView: View {
  @ObservedObject var store: GameStore
  var body: some View {
    VStack(spacing: 10) {
      SectionHeader(eyebrow: "R&D STORE", title: "Upgrades")
      ForEach(
        Balance.upgrades.filter { !store.engine.state.purchasedUpgrades.contains($0.id) }, id: \.id
      ) { upgrade in
        Panel {
          HStack(spacing: 12) {
            Image(systemName: "bolt.shield.fill").foregroundStyle(Theme.lime).font(.title3)
            VStack(alignment: .leading, spacing: 3) {
              Text(upgrade.name).font(.headline)
              Text(upgrade.flavor).font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
            }
            Spacer()
            Button {
              store.buyUpgrade(upgrade.id)
            } label: {
              Text(NumberFormat.formatCash(upgrade.cost)).font(
                .system(size: 11, weight: .bold, design: .monospaced)
              ).padding(8).background(
                store.engine.state.cash >= upgrade.cost ? Theme.green : Theme.panel2, in: Capsule()
              ).foregroundStyle(store.engine.state.cash >= upgrade.cost ? .black : Theme.muted)
            }.disabled(store.engine.state.cash < upgrade.cost)
          }
        }
      }
      if !store.engine.state.purchasedUpgrades.isEmpty {
        Text("INSTALLED · \(store.engine.state.purchasedUpgrades.count)").font(
          .system(size: 10, weight: .bold, design: .monospaced)
        ).foregroundStyle(Theme.green).frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}
