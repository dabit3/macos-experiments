import SwiftUI

struct ResearchView: View {
  @ObservedObject var store: GameStore
  var body: some View {
    VStack(spacing: 14) {
      SectionHeader(eyebrow: "SILICON LABS", title: "Research & Dev")
      Panel {
        HStack {
          Image(systemName: "person.3.fill").font(.title2).foregroundStyle(Theme.green)
          VStack(alignment: .leading) {
            Text("Researchers").font(.headline)
            Text(
              "\(store.engine.state.researchers) active · \(NumberFormat.formatRate(store.engine.researchPerSecond))"
            ).font(.caption).foregroundStyle(Theme.muted)
          }
          Spacer()
          Button {
            store.hireResearcher()
          } label: {
            Text(NumberFormat.formatCash(store.engine.researcherCost)).font(
              .system(size: 11, weight: .bold, design: .monospaced)
            ).padding(9).background(
              store.engine.state.cash >= store.engine.researcherCost ? Theme.green : Theme.panel2,
              in: Capsule()
            ).foregroundStyle(
              store.engine.state.cash >= store.engine.researcherCost ? .black : Theme.muted)
          }
        }
      }
      Panel {
        VStack(alignment: .leading, spacing: 12) {
          Text("PROCESS ROADMAP").font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(Theme.green)
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
              ForEach(ProcessNode.allCases, id: \.self) { node in
                Text(node.displayName).font(.system(size: 11, weight: .bold, design: .monospaced))
                  .padding(.horizontal, 9).padding(.vertical, 8).background(
                    node == store.engine.state.node ? Theme.green : Theme.panel2, in: Capsule()
                  ).foregroundStyle(node == store.engine.state.node ? .black : Theme.muted)
              }
            }
          }
          if let next = store.engine.nextNode {
            ProgressView(value: min(1, store.engine.state.researchPoints / next.researchCost)).tint(
              Theme.green)
            HStack {
              Text(next.flavor).font(.caption).foregroundStyle(Theme.muted)
              Spacer()
              Button("Advance · \(NumberFormat.format(next.researchCost)) RP") {
                store.advanceNode()
              }.font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(
                Theme.lime
              ).disabled(!store.engine.canAdvanceNode)
            }
          } else {
            Text("The process has become a rumor.").font(.caption).foregroundStyle(Theme.lime)
          }
        }
      }
      Panel {
        VStack(alignment: .leading, spacing: 7) {
          Label("THE AI WAVE", systemImage: "waveform.path.ecg").font(.headline).foregroundStyle(
            Theme.lime)
          Text(
            store.engine.state.aiWaveTriggered
              ? "DEMAND ×10 ACTIVE · Your silicon is the infrastructure."
              : "\(NumberFormat.format(store.engine.state.gpusShipped)) / 1M GPUs shipped to trigger demand ×10."
          )
          .font(.caption).foregroundStyle(Theme.muted)
          ProgressView(value: min(1, store.engine.state.gpusShipped / 1_000_000)).tint(Theme.green)
        }
      }.overlay(
        RoundedRectangle(cornerRadius: 14).stroke(
          store.engine.state.aiWaveTriggered ? Theme.lime : Theme.green.opacity(0.14),
          lineWidth: store.engine.state.aiWaveTriggered ? 2 : 1))
    }
  }
}
