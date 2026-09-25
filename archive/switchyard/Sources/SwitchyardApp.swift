import SwiftUI
import UIKit

@main
struct SwitchyardApp: App {
  @State private var book = DispatchBook()
  var body: some Scene {
    WindowGroup { HomeView(book: book).preferredColorScheme(.light) }
  }
}

struct HomeView: View {
  @Bindable var book: DispatchBook
  @State private var selection: Scenario?
  @State private var showGuide = false
  private let display = Railway(scenario: Scenario.all[0])
  private var nextShift: Scenario {
    Scenario.all.first { book.scores[String($0.id)] == nil } ?? Scenario.all[0]
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          HStack {
            Label("POCKET RAIL COMPANY", systemImage: "tram.fill")
              .font(.system(.caption2, design: .monospaced, weight: .bold)).tracking(1.3)
            Spacer()
            Button {
              showGuide = true
            } label: {
              Image(systemName: "questionmark").font(.headline).frame(width: 44, height: 44)
                .background(Ink.navy.opacity(0.06), in: Circle())
            }.accessibilityLabel("How to play and settings")
          }
          VStack(alignment: .leading, spacing: 5) {
            Text("Switchyard").font(.system(size: 49, weight: .heavy, design: .rounded)).tracking(
              -2)
            Text("Small trains. Beautiful timing.").font(.subheadline).foregroundStyle(Ink.muted)
          }
          BoardView(railway: display, decorative: true)
            .frame(maxWidth: 286).frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) {
              Text("A LITTLE WORLD, IN YOUR HANDS")
                .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.3)
                .padding(8).background(Ink.paper, in: Capsule()).offset(y: 12)
            }
          Button {
            selection = nextShift
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(book.scores.isEmpty ? "Start First light" : "Continue: \(nextShift.title)")
                  .font(.headline)
                Text(nextShift.subtitle).font(.caption).opacity(0.8)
              }
              Spacer()
              Image(systemName: "arrow.right").font(.headline)
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.navy, in: RoundedRectangle(cornerRadius: 20))
            .foregroundStyle(Ink.paper)
          }.buttonStyle(.plain).padding(.top, 6)
          HStack(alignment: .firstTextBaseline) {
            Text("The timetable").font(.title2.weight(.bold))
            Spacer()
            Text("\(book.scores.count) / 6 COMPLETE")
              .font(.system(.caption2, design: .monospaced, weight: .bold)).foregroundStyle(
                Ink.muted)
          }.padding(.top, 12)
          VStack(spacing: 0) {
            ForEach(Scenario.all) { scenario in
              Button {
                selection = scenario
              } label: {
                HStack(spacing: 14) {
                  Text(String(format: "%02d", scenario.id + 1))
                    .font(.system(.title3, design: .monospaced, weight: .medium))
                    .foregroundStyle(Ink.muted).frame(width: 34)
                  VStack(alignment: .leading, spacing: 4) {
                    Text(scenario.title).font(.headline)
                    Text(
                      "\(scenario.target) trains · \(scenario.id == 0 ? "Learn the line" : "Dispatch puzzle")"
                    )
                    .font(.caption).foregroundStyle(Ink.muted)
                  }
                  Spacer()
                  Image(
                    systemName: book.scores[String(scenario.id)] != nil
                      ? "checkmark.seal.fill"
                      : (book.unlocked(scenario.id) ? "arrow.up.right" : "lock")
                  )
                  .font(.headline)
                }.padding(.vertical, 18).contentShape(Rectangle())
              }
              .disabled(!book.unlocked(scenario.id)).opacity(book.unlocked(scenario.id) ? 1 : 0.45)
              .accessibilityLabel(
                "\(scenario.title), \(scenario.target) trains, \(book.unlocked(scenario.id) ? "available" : "locked")"
              )
              if scenario.id < 5 { Divider().overlay(Ink.navy.opacity(0.06)) }
            }
          }
          Text("MADE FOR A MOMENT OF FOCUS")
            .font(.system(.caption2, design: .monospaced, weight: .medium)).tracking(1.6)
            .foregroundStyle(Ink.muted).frame(maxWidth: .infinity).padding(.vertical, 16)
        }.padding(.horizontal, 24).padding(.bottom, 20)
      }
      .background(Ink.paper).foregroundStyle(Ink.navy)
      .sheet(item: $selection) { scenario in
        GameView(scenario: scenario, book: book).presentationDragIndicator(.hidden)
          .interactiveDismissDisabled()
      }
      .sheet(isPresented: $showGuide) { GuideView(book: book) }
    }.tint(Ink.navy)
  }
}

struct GameView: View {
  private var scenario: Scenario { railway.scenario }
  @Bindable var book: DispatchBook
  @State private var railway: Railway
  @State private var confirmExit = false
  @State private var confirmRestart = false
  @State private var lastTick = Date()
  @State private var newlyCompleted = false
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var typeSize
  private let timer = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect()

  init(scenario: Scenario, book: DispatchBook) {
    self.book = book
    _railway = State(initialValue: Railway(scenario: scenario))
  }
  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 12) {
          HStack {
            Button {
              railway.state = railway.state == .running ? .paused : railway.state
              confirmExit = true
            } label: {
              Image(systemName: "chevron.left").frame(width: 44, height: 44)
                .background(Ink.navy.opacity(0.06), in: Circle())
            }.accessibilityLabel("Back to timetable")
            Spacer()
            VStack(spacing: 3) {
              Text("SHIFT \(String(format: "%02d", scenario.id + 1))")
                .font(.system(.caption2, design: .monospaced, weight: .bold)).tracking(2)
                .foregroundStyle(Ink.muted)
              Text(scenario.title).font(.title3.weight(.bold))
            }
            Spacer()
            Button {
              if railway.state == .running { railway.state = .paused }
              confirmRestart = true
            } label: {
              Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44)
            }.accessibilityLabel("Restart shift")
          }
          HStack {
            Label("\(railway.delivered) / \(scenario.target)", systemImage: "shippingbox")
              .font(.system(.headline, design: .rounded))
              .accessibilityLabel("\(railway.delivered) of \(scenario.target) trains delivered")
            Spacer()
            Text(
              railway.state == .paused
                ? "PAUSED"
                : (railway.state == .ready ? "READY WHEN YOU ARE" : "\(railway.score) POINTS")
            )
            .font(.system(.caption2, design: .monospaced, weight: .bold)).tracking(0.7)
          }
          if typeSize >= .xxxLarge { guidance }
          BoardView(railway: railway, onTouch: haptic)
          arrivals
          if typeSize < .xxxLarge { guidance }
        }.padding(.horizontal, 20).padding(.top, 20)
      }
      controls.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        .background(Ink.paper.shadow(color: Ink.navy.opacity(0.06), radius: 8, y: -4))
    }
    .foregroundStyle(Ink.navy).background(Ink.paper)
    .accessibilityHidden(!railway.isActive)
    .disabled(!railway.isActive)
    .overlay { if !railway.isActive { result } }
    .onReceive(timer) { now in
      let delta = min(now.timeIntervalSince(lastTick), 0.1)
      lastTick = now
      railway.advance(by: delta)
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active && railway.state == .running { railway.state = .paused }
    }
    .onChange(of: railway.state) { _, state in
      if state == .won {
        newlyCompleted = book.scores[String(scenario.id)] == nil
        book.record(railway)
        if book.haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
      }
    }
    .confirmationDialog("Leave this shift?", isPresented: $confirmExit, titleVisibility: .visible) {
      Button("Return to timetable", role: .destructive) { dismiss() }
      Button("Keep dispatching", role: .cancel) {}
    } message: {
      Text("Completed shifts are saved. This shift will restart next time.")
    }
    .confirmationDialog(
      "Restart this shift?", isPresented: $confirmRestart, titleVisibility: .visible
    ) {
      Button("Restart shift", role: .destructive) { restart() }
      Button("Cancel", role: .cancel) {}
    }
  }

  private var arrivals: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text("ARRIVALS").font(.system(.caption2, design: .monospaced, weight: .bold)).tracking(1)
        Text(railway.remaining.isEmpty ? "All aboard" : "Up next")
          .font(.caption2).foregroundStyle(Ink.muted)
      }
      Spacer(minLength: 0)
      ForEach(railway.remaining.prefix(typeSize >= .xxxLarge ? 1 : 3)) { arrival in
        VStack(spacing: 3) {
          Text(arrival.freight.code).font(.system(.caption, design: .rounded, weight: .black))
            .foregroundStyle(.white).frame(width: 26, height: 26).background(
              arrival.freight.color, in: Circle())
          Text(
            "\(arrival.entrance == .west ? "W" : "E") · \(max(0, Int(ceil(arrival.time - railway.elapsed))))s"
          )
          .font(.system(.caption2, design: .monospaced, weight: .bold))
          .lineLimit(1).fixedSize(horizontal: true, vertical: false)
        }.frame(minWidth: 40)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(
            "\(arrival.freight.station), \(arrival.entrance.rawValue), in \(max(0, Int(ceil(arrival.time - railway.elapsed)))) seconds"
          )
      }
    }.frame(minHeight: 42).padding(.horizontal, 14).padding(.vertical, 10)
      .background(.white.opacity(0.50), in: RoundedRectangle(cornerRadius: 16))
  }

  private var dispatchHint: (title: String, detail: String) {
    if let train = railway.trains.first, let destination = train.committedDestination {
      if destination != train.freight {
        return (
          "\(train.freight.code) is bound for \(destination.station)",
          "This train has passed its last switch. Try the shift again to reroute it."
        )
      }
      let next = railway.trains.dropFirst().first?.freight ?? railway.remaining.first?.freight
      return (
        "\(train.freight.code) is on its way to \(destination.station)",
        next.map { "Next \($0.code): \(routeInstruction($0))." }
          ?? "All routes set. Your last train is almost home."
      )
    }
    guard let freight = railway.trains.first?.freight ?? railway.remaining.first?.freight else {
      return ("All trains on the line", "Keep the route clear for the final delivery.")
    }
    if let train = railway.trains.first,
      (train.to == .westSignal && !railway.westOpen)
        || (train.to == .eastSignal && !railway.eastOpen)
    {
      return (
        "\(freight.code) → \(freight.station) · held",
        "Tap the \(train.entrance.rawValue) signal to release when the merge is clear."
      )
    }
    let instruction = routeInstruction(freight)
    return (
      "\(freight.code) → \(freight.station)",
      "Set \(instruction). Tap the dark switches to change tracks."
    )
  }

  private func routeInstruction(_ freight: Freight) -> String {
    freight == .coral ? "A → Rosebay" : "A → To B · B → \(freight.station)"
  }

  private var guidance: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(dispatchHint.title).font(.subheadline.weight(.semibold))
      Text(dispatchHint.detail).font(.footnote).foregroundStyle(Ink.muted)
    }
    .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 12)
  }

  private var controls: some View {
    HStack(spacing: 10) {
      Button {
        haptic()
        railway.startPause()
      } label: {
        Label(
          railway.state == .running ? "Pause" : (railway.state == .ready ? "Dispatch" : "Resume"),
          systemImage: railway.state == .running ? "pause.fill" : "play.fill"
        )
        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
        .background(Ink.navy, in: RoundedRectangle(cornerRadius: 18)).foregroundStyle(Ink.paper)
      }
      Button {
        railway.speed = railway.speed == 1 ? 2 : 1
        haptic()
      } label: {
        Text("\(railway.speed)×").font(.system(.headline, design: .monospaced))
          .frame(width: 64, height: 56).background(
            Ink.butter, in: RoundedRectangle(cornerRadius: 18))
      }.accessibilityLabel("Speed").accessibilityValue("\(railway.speed) times")
    }.buttonStyle(.plain)
  }

  private var result: some View {
    ZStack {
      Ink.navy.opacity(0.35).ignoresSafeArea()
      ViewThatFits(in: .vertical) {
        receipt
        ScrollView { receipt }
      }.padding(24)
    }
    .accessibilityAddTraits(.isModal)
  }

  private var receipt: some View {
    VStack(spacing: 18) {
      Label(
        railway.state == .won ? "SERVICE COMPLETE" : "LINE STOPPED",
        systemImage: railway.state == .won ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
      )
      .font(.system(.caption2, design: .monospaced, weight: .bold)).tracking(1)
      .foregroundStyle(railway.state == .won ? Ink.muted : Freight.coral.color)
      Text(railway.state == .won ? "A beautiful shift." : "Let’s try that again.")
        .font(.system(.title, design: .rounded, weight: .bold)).multilineTextAlignment(.center)
      if case .lost(let reason) = railway.state {
        Text(reason).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Ink.muted)
      } else {
        Text("Every train, right where it belongs.")
          .font(.subheadline).foregroundStyle(Ink.muted).multilineTextAlignment(.center)
        HStack(alignment: .top) {
          ForEach(Freight.allCases, id: \.self) { freight in
            VStack(spacing: 6) {
              Text(freight.code).font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white).frame(width: 36, height: 36)
                .background(freight.color, in: Circle())
              Text("\(scenario.arrivals.filter { $0.freight == freight }.count)")
                .font(.title3.bold())
              Text(freight.station).font(.caption2).minimumScaleFactor(0.8).lineLimit(1)
            }.frame(maxWidth: .infinity)
              .accessibilityElement(children: .ignore)
              .accessibilityLabel(
                "\(scenario.arrivals.filter { $0.freight == freight }.count) delivered to \(freight.station)"
              )
          }
        }.padding(.vertical, 10)
        Divider()
        HStack {
          Text("\(railway.delivered) DELIVERED")
          Spacer()
          Text("\(railway.score) POINTS")
        }.font(.system(.caption, design: .monospaced, weight: .bold)).padding(.vertical, 8)
        if newlyCompleted && scenario.id < 5 {
          Text("NEXT SHIFT UNLOCKED").font(.system(.caption2, design: .monospaced, weight: .bold))
            .tracking(1)
        }
      }
      Button {
        if railway.state == .won && scenario.id < 5 {
          railway = Railway(scenario: Scenario.all[scenario.id + 1])
          lastTick = Date()
        } else {
          railway.state == .won ? dismiss() : restart()
        }
      } label: {
        Text(
          railway.state == .won
            ? (scenario.id < 5
              ? "Next: \(Scenario.all[scenario.id + 1].title)" : "Back to timetable")
            : "Try again"
        )
        .font(.headline).frame(maxWidth: .infinity).padding(18)
        .background(Ink.navy, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(Ink.paper)
      }
      Button(railway.state == .won && scenario.id == 5 ? "Play again" : "Back to timetable") {
        railway.state == .won && scenario.id == 5 ? restart() : dismiss()
      }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
    }
    .padding(26).background(Ink.paper, in: RoundedRectangle(cornerRadius: 28))
  }

  private func restart() {
    railway = Railway(scenario: scenario)
    lastTick = Date()
  }
  private func haptic() {
    if book.haptics { UISelectionFeedbackGenerator().selectionChanged() }
  }
}

struct GuideView: View {
  @Bindable var book: DispatchBook
  @Environment(\.dismiss) private var dismiss
  @State private var confirmReset = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          Text("A good day\non the line.").font(
            .system(.largeTitle, design: .rounded, weight: .bold))
          Text(
            "Guide every train to its matching letter and color. All six shifts use this little railway."
          )
          .foregroundStyle(Ink.muted)
          rule(
            "01", "Choose the track",
            "Tap A for Rosebay (R), or onward to B. Tap B for Lakeview (L) or Sunfield (S). The dotted line previews your route."
          )
          rule(
            "02", "Give trains room",
            "Tap a signal to hold or release an entrance. East starts on hold. Let one train clear the merge before releasing the other."
          )
          rule(
            "03", "Take your time",
            "Pause to plan and set switches. Use 2× for a quicker shift. A wrong station or collision ends the shift; retry as often as you like."
          )
          VStack(alignment: .leading, spacing: 14) {
            Text("YOUR DISPATCH BOOK").font(.system(.caption, design: .monospaced, weight: .bold))
              .tracking(1)
            Text(
              "Each delivery earns 100 points. Finish a shift to save its score and unlock the next. In-progress shifts restart when you leave the app."
            )
            .font(.subheadline).foregroundStyle(Ink.muted)
            Toggle("Tactile controls", isOn: $book.haptics).tint(Ink.muted)
            Button("Reset all progress", role: .destructive) { confirmReset = true }.frame(
              minHeight: 44)
          }
          .padding(20).background(Ink.navy.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        }.padding(24)
      }
      .background(Ink.paper).foregroundStyle(Ink.navy)
      .navigationTitle("Field guide").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .confirmationDialog(
        "Erase all completed shifts?", isPresented: $confirmReset, titleVisibility: .visible
      ) {
        Button("Erase progress", role: .destructive) { book.reset() }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This cannot be undone.")
      }
    }.tint(Ink.navy)
  }
  private func rule(_ number: String, _ title: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Text(number).font(.system(.headline, design: .monospaced)).foregroundStyle(Ink.muted)
      VStack(alignment: .leading, spacing: 7) {
        Text(title).font(.headline)
        Text(text).font(.subheadline).foregroundStyle(Ink.muted)
      }
    }
  }
}
