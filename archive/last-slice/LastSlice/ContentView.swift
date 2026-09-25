import SwiftUI
import UIKit

struct ContentView: View {
  @Bindable var model: GameModel
  @State private var share: SharePayload?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      Palette.cream.ignoresSafeArea()
      switch model.screen {
      case .home: home
      case .game: game
      case .result: result
      }
    }
    .foregroundStyle(Palette.ink)
    .tint(Palette.red)
    .sheet(isPresented: $model.showHelp) { tutorial }
    .sheet(isPresented: $model.showSettings) { settings }
    .sheet(isPresented: $model.showPause) { pause }
    .sheet(isPresented: $model.showMenu) { menu }
    .sheet(item: $share) { payload in
      ActivitySheet(image: payload.image, text: payload.text)
        .presentationDetents([.large])
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: model.screen)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }

  private var home: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 0) {
          HStack {
            eyebrow("A GAME OF GOOD TASTE")
            Spacer()
            iconButton("slider.horizontal.3", label: "Settings", id: "settings") {
              model.showSettings = true
            }
          }.padding(.horizontal, 24).padding(.top, 8)
          VStack(spacing: -10) {
            Text("LAST").tracking(7)
            Text("SLICE").italic()
          }
          .font(Palette.serif(78))
          .foregroundStyle(Palette.red)
          .accessibilityElement(children: .combine)
          .padding(.top, 6)
          HStack(spacing: 12) {
            Rectangle().frame(height: 1)
            Text("EVERYONE WANTS A PIECE").font(.system(size: 10, weight: .bold)).tracking(2)
            Rectangle().frame(height: 1)
          }.foregroundStyle(Palette.red).padding(.horizontal, 28).padding(.top, 14)
          ZStack {
            PizzaArt(
              toppings: Menu.dinners[6].toppings, cuts: [Cut.line(angle: -.pi / 6)],
              decorative: true
            )
            .rotationEffect(.degrees(-8))
            VStack {
              HStack {
                Text("wood-fired\nbrain food").font(Palette.serif(16)).italic()
                  .rotationEffect(.degrees(-11)).padding(.top, 22)
                Spacer()
              }
              Spacer()
              HStack {
                Spacer()
                VStack(spacing: 3) {
                  Text("12").font(Palette.serif(29))
                  Text("DINNERS").font(.system(size: 8, weight: .black)).tracking(1)
                }.frame(width: 74, height: 74)
                  .background(Palette.olive, in: Circle())
                  .foregroundStyle(Palette.paper).rotationEffect(.degrees(10))
              }
            }.padding(.horizontal, 20).padding(.vertical, 2)
          }.frame(height: min(geometry.size.width * 0.83, max(240, geometry.size.height - 465)))
          Text("Fair slices. Picky people.").font(Palette.serif(26)).padding(.top, 8)
          Text("A delicious little geometry game.")
            .font(.system(size: 14)).foregroundStyle(Palette.olive).padding(.top, 6)
          Spacer(minLength: 22)
          VStack(spacing: 13) {
            primaryButton(
              model.completed == 0 ? "A table for two" : "Back to the table", symbol: "arrow.right",
              id: "startDinner"
            ) {
              model.start(index: min(model.dinnerIndex, model.unlocked))
            }
            HStack {
              Button {
                model.showMenu = true
              } label: {
                Label("Dinner menu", systemImage: "menucard").font(
                  .system(size: 14, weight: .semibold))
              }.accessibilityIdentifier("dinnerMenu").frame(minHeight: 44)
              Spacer()
              Text("\(model.totalStars) / 36").font(
                .system(size: 13, weight: .semibold, design: .monospaced))
              Image(systemName: "star.fill").font(.system(size: 11))
            }
          }.padding(.horizontal, 26)
          CheckerBand().padding(.top, 16)
        }.frame(minHeight: geometry.size.height)
      }.scrollIndicators(.hidden)
    }
  }

  private var game: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 0) {
          HStack {
            Button {
              model.showPause = true
            } label: {
              Image(systemName: "pause").font(.system(size: 18, weight: .semibold)).frame(
                width: 44, height: 44)
            }.accessibilityLabel("Pause dinner").accessibilityIdentifier("pause")
            Spacer()
            eyebrow(
              model.daily
                ? "TODAY'S TABLE · UTC"
                : "DINNER \(String(format: "%02d", model.dinnerIndex + 1)) / 12")
            Spacer()
            iconButton("questionmark", label: "How to play", id: "help") { model.showHelp = true }
          }.padding(.horizontal, 15)
          Text(model.dinner.title).font(Palette.serif(29)).minimumScaleFactor(0.7).lineLimit(1)
            .padding(.horizontal, 20).padding(.top, 4)
          HStack(spacing: 7) {
            ForEach(0..<model.dinner.budget, id: \.self) { index in
              Image(systemName: "scissors")
                .foregroundStyle(index < model.cuts.count ? Palette.line : Palette.red)
            }
            Text(
              "\(model.dinner.budget - model.cuts.count) \(model.dinner.budget - model.cuts.count == 1 ? "cut" : "cuts") left"
            )
            .foregroundStyle(Palette.olive)
          }.font(.system(size: 12, weight: .medium)).padding(.top, 9).accessibilityIdentifier(
            "knifeBudget")
          guests
            .padding(.horizontal, 18).padding(.top, 19)
          ZStack {
            PizzaArt(
              toppings: model.dinner.toppings, cuts: model.cuts, preview: model.preview,
              hint: model.showHint
                ? model.dinner.solution[min(model.cuts.count, model.dinner.solution.count - 1)]
                : nil,
              labels: true
            )
            .contentShape(Rectangle())
            .gesture(
              DragGesture(minimumDistance: 8).onChanged { value in
                let side = boardSize(geometry)
                let radius = side * 0.4
                model.previewCut(
                  Cut(
                    start: Point(
                      x: (value.startLocation.x - side / 2) / radius,
                      y: (value.startLocation.y - side / 2) / radius),
                    end: Point(
                      x: (value.location.x - side / 2) / radius,
                      y: (value.location.y - side / 2) / radius)))
              }
            )
            .accessibilityIdentifier("pizzaBoard")
            if !model.cuts.isEmpty { FlourBurst().id(model.cuts.count) }
          }
          .frame(width: boardSize(geometry), height: boardSize(geometry))
          .frame(maxWidth: .infinity)
          .padding(.top, 0)
          Text(model.notice)
            .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.olive)
            .multilineTextAlignment(.center).frame(minHeight: 35)
            .padding(.horizontal, 28).accessibilityIdentifier("cutNotice")
          HStack(spacing: 0) {
            quietButton("Undo", icon: "arrow.uturn.backward", id: "undo") { model.undo() }
              .disabled(model.cuts.isEmpty && model.preview == nil)
            Spacer()
            quietButton("Reset", icon: "arrow.counterclockwise", id: "reset") { model.reset() }
            Spacer()
            quietButton(
              model.showHint ? "Hide guide" : "Chef's hint", icon: "lightbulb", id: "hint"
            ) { model.showHint.toggle() }
          }.padding(.horizontal, 26).padding(.top, 3)
          Spacer(minLength: 8)
          VStack(spacing: 10) {
            if model.preview != nil {
              primaryButton("Cut here", symbol: "scissors", id: "commitCut") {
                withAnimation(reduceMotion ? nil : .spring(response: 0.3)) { model.commitCut() }
              }.disabled(!model.canCut)
            } else {
              primaryButton("Serve the table", symbol: "arrow.right", id: "serve") { model.serve() }
                .disabled(model.cuts.isEmpty)
            }
            Text("±5 percentage points · exact topping counts")
              .font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.olive)
          }.padding(.horizontal, 24).padding(.bottom, 16)
          CheckerBand(height: 10)
        }.frame(minHeight: geometry.size.height)
      }.scrollIndicators(.hidden)
    }
  }

  private func boardSize(_ geometry: GeometryProxy) -> CGFloat {
    min(geometry.size.width, max(235, geometry.size.height - 454), 430)
  }

  private var guests: some View {
    HStack(alignment: .top, spacing: 8) {
      ForEach(model.dinner.guests) { guest in
        let match = model.liveVerdict.matches.first { $0.guest.id == guest.id }
        let hasCut = !model.cuts.isEmpty || model.preview != nil
        VStack(spacing: 4) {
          GuestPortrait(id: guest.id, happy: match?.passed == true).frame(width: 46, height: 46)
          Text(guest.name.uppercased()).font(.system(size: 10, weight: .bold)).tracking(1.2)
          Text("WANTS \(guest.percent)%").font(.system(size: 13, weight: .heavy)).padding(.top, 2)
          HStack(spacing: 2) {
            Text("\(guest.count) ×").font(.system(size: 12, weight: .semibold))
            ToppingIcon(kind: guest.topping)
          }
          VStack(spacing: 3) {
            Text(hasCut ? (model.preview == nil ? "ON THE PLATE" : "PREVIEW") : "YOUR SLICE")
              .font(.system(size: 8, weight: .heavy)).tracking(0.8)
            HStack(spacing: 3) {
              Text(
                hasCut
                  ? (match?.portionIndex == nil
                    ? "—" : "\(match?.percent ?? 0)% · \(match?.count ?? 0)") : "— · —")
              Image(
                systemName: !hasCut
                  ? "circle.dotted"
                  : (match?.passed == true ? "checkmark.circle.fill" : "xmark.circle"))
            }.font(.system(size: 13, weight: .bold))
          }
          .foregroundStyle(!hasCut || match?.passed == true ? Palette.olive : Palette.red)
          .frame(maxWidth: .infinity).frame(height: 42)
          .background(
            (!hasCut || match?.passed == true ? Palette.olive : Palette.red).opacity(0.07),
            in: RoundedRectangle(cornerRadius: 7))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          "\(guest.name) wants \(guest.percent) percent and exactly \(guest.count) \(guest.topping.title). \(match?.portionIndex == nil ? "No slice yet." : "Current \(match?.percent ?? 0) percent, \(match?.count ?? 0) toppings. \(match?.passed == true ? "Passing" : "Not passing")")"
        )
      }
    }
  }

  private var result: some View {
    ScrollView {
      if let verdict = model.result {
        VStack(spacing: 0) {
          HStack {
            iconButton("house", label: "Back home", id: "resultHome") { model.screen = .home }
            Spacer()
            eyebrow(
              model.daily
                ? "DAILY SPECIAL · SERVED"
                : "DINNER \(String(format: "%02d", model.dinnerIndex + 1)) · SERVED")
            Spacer()
            iconButton("square.and.arrow.up", label: "Share result", id: "shareTop") {
              shareResult()
            }
          }.padding(.horizontal, 16).padding(.top, 5)
          Text(verdict.success ? "Tutti felici!" : "Not quite, chef.")
            .font(Palette.serif(42)).foregroundStyle(Palette.red).padding(.top, 13)
          Text(
            verdict.success
              ? "Every guest. Every last bite." : "A good dinner is worth another try."
          )
          .font(.system(size: 14)).foregroundStyle(Palette.olive).padding(.top, 6)
          PizzaArt(toppings: model.dinner.toppings, cuts: model.cuts, labels: true, exploded: true)
            .frame(height: 275)
            .overlay(alignment: .bottom) {
              if verdict.success {
                HStack(spacing: 7) {
                  ForEach(0..<3, id: \.self) { star in
                    Image(systemName: star < verdict.stars ? "star.fill" : "star")
                  }
                }.font(.system(size: 22)).foregroundStyle(Palette.red)
                  .padding(.bottom, 4)
              }
            }
          HStack {
            eyebrow(
              verdict.success
                ? "\(verdict.accuracy)% PRECISION"
                : "\(verdict.passedCount) OF \(model.dinner.guests.count) GUESTS HAPPY")
            Spacer()
            Text(
              "\(model.cuts.count) / \(model.dinner.budget) \(model.dinner.budget == 1 ? "cut" : "cuts")"
            ).font(
              .system(size: 12, weight: .medium))
          }.padding(.horizontal, 25).padding(.vertical, 12)
          VStack(spacing: 0) {
            ForEach(verdict.matches, id: \.guest.id) { match in
              resultRow(match, portion: match.portionIndex.map { verdict.portions[$0] })
            }
          }.padding(.horizontal, 24)
          if verdict.extraPortions > 0 {
            Text("\(verdict.extraPortions) extra portion(s). Every piece needs a guest.")
              .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.red)
              .padding(.top, 12)
          }
          VStack(spacing: 10) {
            if verdict.success && !model.daily && model.dinnerIndex < Menu.dinners.count - 1 {
              primaryButton("The next dinner", symbol: "arrow.right", id: "nextDinner") {
                model.nextDinner()
              }
            } else {
              primaryButton(
                verdict.success ? "Back to the menu" : "Try that again", symbol: "arrow.right",
                id: "retryPrimary"
              ) {
                if verdict.success {
                  model.screen = .home
                  model.showMenu = true
                } else {
                  model.reset()
                  model.screen = .game
                }
              }
            }
            HStack {
              quietButton("Play again", icon: "arrow.counterclockwise", id: "replay") {
                model.reset()
                model.screen = .game
              }
              Spacer()
              quietButton("Share the table", icon: "square.and.arrow.up", id: "share") {
                shareResult()
              }
            }
          }.padding(.horizontal, 24).padding(.top, 21)
          CheckerBand().padding(.top, 12)
        }
      }
    }.scrollIndicators(.hidden)
  }

  private func resultRow(_ match: GuestMatch, portion: Portion?) -> some View {
    VStack(spacing: 0) {
      Rectangle().fill(Palette.line).frame(height: 0.7)
      HStack(spacing: 12) {
        GuestPortrait(id: match.guest.id, happy: match.passed).frame(width: 48, height: 48)
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(match.guest.name).font(Palette.serif(22))
            Text(match.passed ? "DELIZIOSO" : "NOT YET").font(.system(size: 9, weight: .black))
              .tracking(1)
              .foregroundStyle(match.passed ? Palette.olive : Palette.red)
          }
          if match.portionIndex != nil {
            Text("\(match.percent)% area · wants \(match.guest.percent)%")
              .font(.system(size: 13)).foregroundStyle(Palette.olive)
            Text("\(match.count) \(match.guest.topping.title) · wants \(match.guest.count)")
              .font(.system(size: 13)).foregroundStyle(Palette.olive)
          } else {
            Text(
              "No portion. Wants \(match.guest.percent)% + \(match.guest.count) \(match.guest.topping.title)."
            )
            .font(.system(size: 13)).foregroundStyle(Palette.red)
          }
          if !match.passed, match.portionIndex != nil {
            Text(
              !match.areaPass
                ? "Area is outside the ±5 point tolerance." : "Topping count must match exactly."
            )
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.red)
          }
        }
        Spacer(minLength: 0)
        if let portion {
          ServedPlate(portion: portion, index: match.guest.id)
            .frame(width: 58, height: 58)
        }
      }.padding(.vertical, 14)
    }.accessibilityElement(children: .combine)
  }

  private var tutorial: some View {
    sheetPage(title: "A slice of advice", kicker: "WELCOME TO THE TABLE") {
      PizzaArt(toppings: Menu.dinners[0].toppings, preview: .line(angle: .pi / 2), labels: true)
        .frame(height: 220)
      instruction(
        "01", "Draw, then decide.",
        "Drag a straight line across the crust. See the portions before tapping Cut.")
      instruction(
        "02", "Read your guests.",
        "Match their area within ±5 percentage points and their topping count exactly. Other toppings are welcome."
      )
      instruction(
        "03", "Serve every slice.",
        "One portion per guest. We find the best assignment. Toppings belong where their centers fall; a center on a cut goes to one side."
      )
      Text(
        "Undo and reset are free. Chef's hint reveals a suggested cut. The preview under each guest shows their current area and topping count."
      )
      .font(.system(size: 12)).foregroundStyle(Palette.olive).padding(.vertical, 12)
      primaryButton("Let's cook", symbol: "arrow.right", id: "tutorialDone") {
        model.finishTutorial()
      }
    }
  }

  private var settings: some View {
    sheetPage(title: "At your service", kicker: "THE LITTLE DETAILS") {
      Toggle("Haptic feedback", isOn: $model.haptics)
        .font(Palette.serif(22)).padding(.vertical, 22).accessibilityIdentifier("hapticsToggle")
      Text(
        "A quiet kitchen. This game has no music or sound effects. Haptics are available on supported iPhones."
      )
      .font(.system(size: 14)).foregroundStyle(Palette.olive)
      Divider().padding(.vertical, 18)
      Text(
        "\(model.completed) \(model.completed == 1 ? "dinner" : "dinners") served · \(model.totalStars) \(model.totalStars == 1 ? "star" : "stars")"
      )
      .font(Palette.serif(22))
      Text(
        "Progress stays on this device. Reduced Motion follows your iPhone's accessibility setting."
      )
      .font(.system(size: 14)).foregroundStyle(Palette.olive).padding(.top, 10)
      primaryButton("Back to the kitchen", symbol: "arrow.right", id: "settingsDone") {
        model.showSettings = false
      }
      .padding(.top, 26)
    }
  }

  private var pause: some View {
    sheetPage(title: "Let it rest.", kicker: "THE TABLE CAN WAIT") {
      Text("Your cuts are right where you left them.")
        .font(Palette.serif(22)).padding(.vertical, 28)
      primaryButton("Keep cooking", symbol: "play.fill", id: "resume") { model.showPause = false }
      quietButton("Restart dinner", icon: "arrow.counterclockwise", id: "pauseRestart") {
        model.reset()
        model.showPause = false
      }.padding(.top, 15)
      quietButton("Back home", icon: "house", id: "pauseHome") {
        model.showPause = false
        model.screen = .home
      }
    }.presentationDetents([.medium])
  }

  private var menu: some View {
    sheetPage(title: "The dinner menu", kicker: "\(model.completed) / 12 TABLES SERVED") {
      Button {
        model.showMenu = false
        model.start(index: Menu.dailyIndex(), daily: true)
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Today's special").font(Palette.serif(23))
            Text("A daily table for everyone · changes at 00:00 UTC").font(.system(size: 11))
          }
          Spacer()
          Image(systemName: "sun.max")
        }.padding(17).foregroundStyle(Palette.paper).background(Palette.olive)
      }.accessibilityIdentifier("dailyChallenge").padding(.vertical, 16)
      ForEach(Menu.dinners) { dinner in
        Button {
          model.showMenu = false
          model.start(index: dinner.id)
        } label: {
          VStack(spacing: 0) {
            HStack(spacing: 13) {
              Text(String(format: "%02d", dinner.id + 1)).font(
                .system(size: 13, design: .monospaced)
              ).foregroundStyle(Palette.red)
              VStack(alignment: .leading, spacing: 4) {
                Text(dinner.title).font(Palette.serif(20))
                Text(
                  "\(dinner.guests.count) guests · \(dinner.budget) \(dinner.budget == 1 ? "cut" : "cuts")"
                ).font(
                  .system(size: 11))
              }
              Spacer()
              if dinner.id > model.unlocked {
                Image(systemName: "lock").font(.system(size: 14))
              } else if model.best[dinner.id] > 0 {
                Text(String(repeating: "★", count: model.best[dinner.id])).font(.system(size: 13))
                  .foregroundStyle(Palette.red)
              } else {
                Image(systemName: "arrow.right").font(.system(size: 14))
              }
            }.padding(.vertical, 16)
            Rectangle().fill(Palette.line).frame(height: 0.5)
          }
        }.disabled(dinner.id > model.unlocked)
          .opacity(dinner.id > model.unlocked ? 0.45 : 1)
          .accessibilityLabel(
            "Dinner \(dinner.id + 1), \(dinner.title), \(dinner.id > model.unlocked ? "locked" : "\(model.best[dinner.id]) \(model.best[dinner.id] == 1 ? "star" : "stars")")"
          )
          .accessibilityIdentifier("dinner\(dinner.id + 1)")
      }
    }
  }

  private func sheetPage<Content: View>(
    title: String, kicker: String, @ViewBuilder content: () -> Content
  ) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        CheckerBand().padding(.bottom, 28)
        eyebrow(kicker)
        Text(title).font(Palette.serif(34)).foregroundStyle(Palette.red).padding(.top, 9)
        content()
      }.padding(25)
    }
    .presentationDragIndicator(.visible)
    .presentationBackground(Palette.cream)
    .foregroundStyle(Palette.ink)
  }

  private func instruction(_ number: String, _ title: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Text(number).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(
        Palette.red
      ).padding(.top, 5)
      VStack(alignment: .leading, spacing: 6) {
        Text(title).font(Palette.serif(22))
        Text(text).font(.system(size: 13)).foregroundStyle(Palette.olive).fixedSize(
          horizontal: false, vertical: true)
      }
    }.padding(.bottom, 18)
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text).font(.system(size: 10, weight: .bold)).tracking(1.5)
  }

  private func primaryButton(
    _ text: String, symbol: String, id: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Text(text).font(.system(size: 16, weight: .semibold))
        Spacer()
        Image(systemName: symbol).font(.system(size: 17, weight: .medium))
      }.padding(.horizontal, 22).frame(minHeight: 55)
    }
    .buttonStyle(PrimaryButtonStyle())
    .accessibilityIdentifier(id)
  }

  private func quietButton(_ text: String, icon: String, id: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Label(text, systemImage: icon).font(.system(size: 12, weight: .semibold)).frame(minHeight: 44)
    }.accessibilityIdentifier(id)
  }

  private func iconButton(_ symbol: String, label: String, id: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 17, weight: .medium)).frame(
        width: 44, height: 44)
    }.accessibilityLabel(label).accessibilityIdentifier(id)
  }

  private func shareResult() {
    guard let verdict = model.result else { return }
    let renderer = ImageRenderer(
      content: ResultPostcard(dinner: model.dinner, cuts: model.cuts, verdict: verdict))
    renderer.scale = 3
    guard let image = renderer.uiImage else { return }
    share = SharePayload(
      image: image,
      text:
        "Last Slice · \(model.dinner.title). \(verdict.passedCount)/\(model.dinner.guests.count) happy guests, \(model.cuts.count) \(model.cuts.count == 1 ? "cut" : "cuts"), \(verdict.accuracy)% precision. \(verdict.success ? "Tutti felici!" : "Another round, chef.")"
    )
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(Palette.paper)
      .background(enabled ? Palette.red : Palette.olive.opacity(0.4))
      .clipShape(RoundedRectangle(cornerRadius: 5))
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
  }
}

struct SharePayload: Identifiable {
  let id = UUID()
  let image: UIImage
  let text: String
}

struct ActivitySheet: UIViewControllerRepresentable {
  let image: UIImage
  let text: String
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [text, image], applicationActivities: nil)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct ResultPostcard: View {
  let dinner: Dinner
  let cuts: [Cut]
  let verdict: Verdict
  var body: some View {
    VStack(spacing: 0) {
      CheckerBand(height: 18)
      Text("LAST SLICE").font(Palette.serif(48)).foregroundStyle(Palette.red).padding(.top, 24)
      Text("AN OUTRAGEOUS ORDER, BEAUTIFULLY DIVIDED")
        .font(.system(size: 8, weight: .bold)).tracking(1.3).padding(.top, 8)
      PizzaArt(toppings: dinner.toppings, cuts: cuts, labels: true, exploded: true).frame(
        height: 310)
      Text(dinner.title).font(Palette.serif(26))
      Text(
        "\(verdict.passedCount)/\(dinner.guests.count) happy guests · \(cuts.count) \(cuts.count == 1 ? "cut" : "cuts") · \(verdict.accuracy)% precision"
      )
      .font(.system(size: 12)).padding(.top, 9)
      HStack(spacing: 19) {
        ForEach(dinner.guests) { guest in
          VStack(spacing: 5) {
            GuestPortrait(
              id: guest.id, happy: verdict.matches.first { $0.guest.id == guest.id }?.passed == true
            )
            .frame(width: 41, height: 41)
            Text("\(guest.percent)% + \(guest.count) \(guest.topping.title)")
              .font(.system(size: 9, weight: .medium))
          }
        }
      }.padding(.top, 22)
      Spacer()
      Text(verdict.success ? "Tutti felici!" : "The table awaits a second try.")
        .font(Palette.serif(20)).italic().foregroundStyle(Palette.red).padding(.bottom, 19)
      CheckerBand(height: 18)
    }.frame(width: 390, height: 650).background(Palette.cream).foregroundStyle(Palette.ink)
  }
}
