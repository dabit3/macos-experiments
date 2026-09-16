import Charts
import Foundation
import SwiftUI

struct TickerView: View {
  let engine: GameEngine
  var expanded = false
  private var change: Double {
    guard let previous = engine.state.stockHistory.dropLast().last, previous > 0 else { return 0 }
    return (engine.stockPrice - previous) / previous * 100
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline) {
        Text("FABT").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(
          Theme.green)
        Text(NumberFormat.formatCash(engine.stockPrice)).font(
          .system(size: expanded ? 25 : 16, weight: .black, design: .monospaced))
        Text("\(change >= 0 ? "▲" : "▼") \(String(format: "%.1f", abs(change)))%").font(
          .system(size: 10, weight: .bold, design: .monospaced)
        ).foregroundStyle(change >= 0 ? Theme.lime : .red)
        Spacer()
        Text("MKT CAP " + NumberFormat.formatCash(engine.marketCap)).font(
          .system(size: 10, weight: .bold, design: .monospaced)
        ).foregroundStyle(Theme.muted)
      }
      Chart(Array(engine.state.stockHistory.suffix(60).enumerated()), id: \.offset) {
        index, value in
        AreaMark(x: .value("Tick", index), y: .value("Price", value)).foregroundStyle(
          LinearGradient(
            colors: [Theme.green.opacity(0.36), .clear], startPoint: .top, endPoint: .bottom))
        LineMark(x: .value("Tick", index), y: .value("Price", value)).foregroundStyle(Theme.lime)
          .lineStyle(StrokeStyle(lineWidth: 2))
      }.chartXAxis(.hidden).chartYAxis(.hidden).frame(height: expanded ? 220 : 26)
    }
  }
}

struct MarketView: View {
  @ObservedObject var store: GameStore
  @State private var showingPrestige = false
  var body: some View {
    VStack(spacing: 12) {
      SectionHeader(eyebrow: "FABRICATION EXCHANGE", title: "Market")
      Panel { TickerView(engine: store.engine, expanded: true) }
      HStack(spacing: 10) {
        StatBox(
          label: "LIFETIME CASH", value: NumberFormat.formatCash(store.engine.state.lifetimeCash))
        StatBox(label: "GPUs SHIPPED", value: NumberFormat.format(store.engine.state.gpusShipped))
      }
      Panel {
        VStack(alignment: .leading, spacing: 8) {
          Text("NEW ARCHITECTURE").font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(Theme.green)
          Text("Prestige into \(Architecture.name(for: store.engine.state.generation + 1))").font(
            .title3.bold())
          Text(
            "+10% production per architecture point. Reset your fabs, keep your reputation, and come back stronger."
          )
          .font(.caption).foregroundStyle(Theme.muted)
          HStack {
            Text(
              "\(store.engine.earnedArchitecturePoints) point\(store.engine.earnedArchitecturePoints == 1 ? "" : "s") ready"
            ).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(
              Theme.lime)
            Spacer()
            Button("Prestige") { showingPrestige = true }.buttonStyle(.borderedProminent).tint(
              Theme.green
            ).disabled(!store.engine.canPrestige)
          }
        }
      }
    }.alert("Start a New Architecture?", isPresented: $showingPrestige) {
      Button("Prestige", role: .destructive) { store.prestige() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Your cash, buildings, upgrades, node and researchers reset. Architecture points and lifetime stats remain."
      )
    }
  }
}

struct StatBox: View {
  let label: String
  let value: String
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(value).font(.system(size: 17, weight: .black, design: .monospaced))
      Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(
        Theme.muted)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(
      Theme.panel, in: RoundedRectangle(cornerRadius: 12))
  }
}
