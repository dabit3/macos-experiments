import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var store: RallyStore
  @Environment(\.dynamicTypeSize) private var textSize
  @State private var playing = false
  @State private var showSettings = false
  @State private var showRecords = false
  @State private var playFromRecords = false

  var body: some View {
    ZStack {
      Velvet.background.ignoresSafeArea()
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HStack {
            HStack(spacing: 9) {
              Circle().fill(Velvet.orange).frame(width: 7, height: 7)
              Eyebrow(text: "The pocket racquet club")
            }
            Spacer()
            CircleControl(icon: "slider.horizontal.3", label: "Match settings") {
              showSettings = true
            }
          }
          VStack(alignment: .leading, spacing: -8) {
            Text("Velvet").font(.system(size: 74, weight: .regular, design: .serif))
            HStack(alignment: .firstTextBaseline) {
              Text("Rally").font(.system(size: 80, weight: .regular, design: .serif)).italic()
              Spacer()
              if !textSize.isAccessibilitySize {
                Text("TABLE\nTENNIS\nREIMAGINED")
                  .font(.system(size: 11, weight: .medium, design: .monospaced))
                  .tracking(1.3).lineSpacing(5).foregroundStyle(Velvet.muted)
              }
            }
          }
          .foregroundStyle(Velvet.cream)
          .accessibilityElement(children: .combine)
          CourtArt(court: store.settings.court)
            .frame(height: 245)
            .background(
              RadialGradient(
                colors: [Velvet.court(store.settings.court).opacity(0.4), .clear],
                center: .center, startRadius: 0, endRadius: 200)
            )
            .padding(.horizontal, -12).padding(.top, -16)
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
              Eyebrow(text: "01 / Your court")
              Text(store.settings.court.title)
                .font(.system(.title2, design: .serif))
                .foregroundStyle(Velvet.cream)
            }
            Spacer()
            Button {
              showSettings = true
            } label: {
              HStack(spacing: 8) {
                Text("\(store.settings.difficulty.title) · First to \(store.settings.target)")
                Image(systemName: "chevron.down")
              }
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(Velvet.cream)
              .padding(.vertical, 14)
            }
            .accessibilityLabel("Choose court and difficulty")
          }
          PrimaryButton(title: "Step onto the court") { playing = true }
          HStack {
            Text("One thumb. Endless rhythm.")
              .font(.system(.footnote, design: .serif)).italic().foregroundStyle(Velvet.muted)
            Spacer()
            Button {
              showRecords = true
            } label: {
              HStack(spacing: 5) {
                Text("Club record")
                Image(systemName: "arrow.up.right")
              }
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(Velvet.cream)
              .padding(.vertical, 12)
            }
          }
        }
        .padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 20)
      }
      .scrollIndicators(.hidden)
    }
    .sheet(isPresented: $showSettings) { SettingsView() }
    .sheet(
      isPresented: $showRecords,
      onDismiss: {
        if playFromRecords {
          playFromRecords = false
          playing = true
        }
      }
    ) {
      RecordsView { playFromRecords = true }
    }
    .fullScreenCover(isPresented: $playing) {
      MatchView(settings: store.settings)
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject private var store: RallyStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var textSize

  private var surfaceLayout: AnyLayout {
    textSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: 14))
      : AnyLayout(HStackLayout(spacing: 14))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          Text("Make it your game.").font(.system(size: 36, design: .serif))
          VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "01 / Surface")
            surfaceLayout {
              ForEach(Court.allCases) { court in
                Button {
                  store.settings.court = court
                } label: {
                  VStack(alignment: .leading, spacing: 8) {
                    CourtArt(court: court).frame(maxWidth: 200).frame(height: 100)
                    HStack {
                      Text(court.title).font(.system(.subheadline, design: .serif))
                      Spacer()
                      if store.settings.court == court {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Velvet.orange)
                      }
                    }
                  }
                  .padding(12).frame(maxWidth: .infinity)
                  .background(Velvet.panel, in: RoundedRectangle(cornerRadius: 16))
                  .overlay(
                    RoundedRectangle(cornerRadius: 16).stroke(
                      store.settings.court == court ? Velvet.orange : .clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(store.settings.court == court ? .isSelected : [])
              }
            }
          }
          VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "02 / Opponent")
            ForEach(Difficulty.allCases) { difficulty in
              Button {
                store.settings.difficulty = difficulty
              } label: {
                HStack {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.title).font(.system(.headline, design: .serif))
                    Text(difficulty.subtitle).font(.caption).foregroundStyle(Velvet.muted)
                  }
                  Spacer()
                  Image(
                    systemName: store.settings.difficulty == difficulty
                      ? "circle.inset.filled" : "circle"
                  )
                  .foregroundStyle(
                    store.settings.difficulty == difficulty ? Velvet.orange : Velvet.muted)
                }
                .padding(14).background(Velvet.panel, in: RoundedRectangle(cornerRadius: 12))
              }.buttonStyle(.plain)
                .accessibilityAddTraits(store.settings.difficulty == difficulty ? .isSelected : [])
            }
          }
          VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "03 / Match length")
            if textSize.isAccessibilitySize {
              ForEach([7, 3], id: \.self) { target in
                Button {
                  store.settings.target = target
                } label: {
                  HStack {
                    Text(target == 7 ? "First to 7 · Classic" : "First to 3 · Sprint")
                      .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Image(
                      systemName: store.settings.target == target
                        ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(Velvet.orange)
                  }
                  .padding(14).background(Velvet.panel, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(store.settings.target == target ? .isSelected : [])
              }
            } else {
              Picker("Match length", selection: $store.settings.target) {
                Text("First to 7 · Classic").tag(7)
                Text("First to 3 · Sprint").tag(3)
              }.pickerStyle(.segmented)
            }
            Text("No deuce. Every point counts.").font(.caption).foregroundStyle(Velvet.muted)
          }
          Toggle("Paddle haptics", isOn: $store.settings.haptics).font(.subheadline)
        }
        .padding(24).foregroundStyle(Velvet.cream)
      }
      .background(Velvet.background)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) { Eyebrow(text: "Match settings") }
        ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
      }
    }
  }
}

struct RecordsView: View {
  @EnvironmentObject private var store: RallyStore
  @Environment(\.dismiss) private var dismiss
  @State private var clear = false
  var play: () -> Void
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("Your club\nrecord.").font(.system(size: 44, design: .serif))
          if store.records.isEmpty {
            CourtArt(court: store.settings.court).frame(height: 220)
            Text("A clean scorecard.").font(.system(.title2, design: .serif))
            Text(
              "Finish your first match to start a collection of good games. Your results stay on this iPhone."
            )
            .foregroundStyle(Velvet.muted)
            PrimaryButton(title: "Play your first match") {
              play()
              dismiss()
            }
          } else {
            HStack {
              recordStat("\(store.records.filter(\.won).count)", "WINS")
              Spacer()
              recordStat("\(store.records.map(\.bestRally).max() ?? 0)", "BEST RALLY")
              Spacer()
              recordStat("\(store.records.count)", "MATCHES")
            }
            Divider().overlay(Velvet.muted)
            ForEach(store.records) { record in
              HStack {
                VStack(alignment: .leading, spacing: 6) {
                  Text(record.won ? "Well played." : "Next one's yours.")
                    .font(.system(.headline, design: .serif))
                  Text(
                    "\(record.difficulty.title) · \(record.court.title) · First to \(record.target)"
                  )
                  .font(.caption).foregroundStyle(Velvet.muted)
                  Text(record.date, style: .date).font(.caption2).foregroundStyle(Velvet.muted)
                }
                Spacer()
                Text("\(record.playerScore)–\(record.opponentScore)")
                  .font(.system(size: 30, design: .serif))
                  .foregroundStyle(record.won ? Velvet.orange : Velvet.cream)
              }
              Divider().overlay(Velvet.muted.opacity(0.3))
            }
            Button("Clear match history", role: .destructive) { clear = true }.padding(
              .vertical, 14)
          }
        }.padding(24).foregroundStyle(Velvet.cream)
      }
      .background(Velvet.background)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
      .confirmationDialog(
        "Clear all local match history?", isPresented: $clear, titleVisibility: .visible
      ) {
        Button("Clear history", role: .destructive) { store.clearRecords() }
      }
    }
  }
  private func recordStat(_ value: String, _ title: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(value).font(.system(size: 42, design: .serif)).foregroundStyle(Velvet.orange)
      Eyebrow(text: title)
    }
  }
}
