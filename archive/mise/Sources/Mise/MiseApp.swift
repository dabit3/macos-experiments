import SwiftUI
import UIKit

@main
struct MiseApp: App {
  @State private var store = KitchenStore()
  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(store)
        .preferredColorScheme(.light)
        .tint(Palette.green)
    }
  }
}

struct RootView: View {
  @Environment(KitchenStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    @Bindable var store = store
    ZStack {
      Palette.paper.ignoresSafeArea()
      if let recipe = store.recipe {
        if store.state.isCooking {
          CookingView(recipe: recipe)
        } else {
          RecipeView(recipe: recipe)
        }
      } else {
        CollectionView()
      }
    }
    .foregroundStyle(Palette.ink)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !store.state.timers.isEmpty { TimerDock() }
    }
    .sheet(isPresented: $store.showTimers) {
      TimerBoard()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    .alert(
      "A note from your kitchen",
      isPresented: Binding(
        get: { store.storageMessage != nil },
        set: { if !$0 { store.storageMessage = nil } }
      )
    ) {
      Button("Continue") { store.storageMessage = nil }
    } message: {
      Text(store.storageMessage ?? "")
    }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { store.save() }
    }
    .onChange(of: store.state.isCooking) { _, cooking in
      UIApplication.shared.isIdleTimerDisabled = cooking
    }
    .onAppear { UIApplication.shared.isIdleTimerDisabled = store.state.isCooking }
  }
}

struct Eyebrow: View {
  let text: String
  var color = Palette.muted
  var body: some View {
    Text(text).font(.system(size: 10, weight: .bold, design: .monospaced))
      .tracking(2).foregroundStyle(color)
  }
}

struct RoundButton: View {
  let symbol: String
  let label: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 18, weight: .medium))
        .frame(width: 44, height: 44)
        .background(Palette.cream.opacity(0.65), in: Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

struct PrimaryButton: View {
  let title: String
  var symbol = "arrow.right"
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack {
        Text(title).font(.system(size: 16, weight: .semibold))
        Spacer()
        Image(systemName: symbol)
      }
      .foregroundStyle(.white).padding(.horizontal, 23).frame(minHeight: 56)
      .background(Palette.green, in: RoundedRectangle(cornerRadius: 18))
    }
    .buttonStyle(.plain)
  }
}

struct CollectionView: View {
  @Environment(KitchenStore.self) private var store
  private var recipes: [Recipe] {
    store.showSaved ? Recipes.all.filter { store.state.favorites.contains($0.id) } : Recipes.all
  }
  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        Text("mise").font(.system(size: 42, weight: .regular, design: .serif)).tracking(-3)
        Text("A LITTLE ORDER.\nA LOVELY DINNER.").font(
          .system(size: 8, weight: .semibold, design: .monospaced)
        )
        .tracking(1.5).lineSpacing(3).padding(.leading, 8).foregroundStyle(Palette.muted)
        Spacer()
        RoundButton(symbol: "timer", label: "Kitchen timers") { store.showTimers = true }
      }.padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 13)
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          HStack(spacing: 9) {
            Capsule().fill(Palette.red).frame(width: 22, height: 3)
            Eyebrow(
              text: store.showSaved ? "YOUR PERSONAL COOKBOOK" : "GOOD FOOD, UNHURRIED",
              color: Palette.red)
          }.padding(.top, 5)
          if store.showSaved && recipes.isEmpty {
            VStack(spacing: 20) {
              Image(systemName: "bookmark").font(.system(size: 36, weight: .ultraLight))
              Text("Keep the good ones.").font(.system(size: 31, design: .serif))
              Text("Tap the bookmark on any recipe to keep it here for another evening.")
                .font(.system(size: 16)).foregroundStyle(Palette.muted).multilineTextAlignment(
                  .center)
              PrimaryButton(title: "Explore the collection") { store.showSaved = false }
            }.padding(.vertical, 60)
          }
          if let first = recipes.first {
            Button {
              store.open(first)
            } label: {
              VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                  FoodArtwork(kind: first.id).frame(height: 270).clipped()
                  Text(store.showSaved ? "SAVED FOR LATER" : "TONIGHT’S LITTLE RITUAL")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Palette.paper, in: Capsule()).padding(17)
                }
                VStack(alignment: .leading, spacing: 10) {
                  HStack(alignment: .top) {
                    Text(first.title).font(.system(size: 38, weight: .regular, design: .serif))
                      .tracking(-1.5).lineSpacing(-2)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 17))
                      .frame(width: 42, height: 42).overlay(Circle().stroke(Palette.line))
                  }
                  Text(first.subtitle).font(.system(size: 13)).foregroundStyle(Palette.muted)
                  HStack(spacing: 15) {
                    Label("\(first.minutes) min", systemImage: "clock")
                    Text("•").foregroundStyle(Palette.line)
                    Text("\(first.ingredients.count) ingredients")
                    Spacer()
                    Text("LET’S COOK").tracking(1).font(.system(size: 9, weight: .bold))
                  }.font(.system(size: 11)).foregroundStyle(Palette.green).padding(.top, 6)
                }.padding(20)
              }
              .background(Color(hex: 0xFDFBF6), in: RoundedRectangle(cornerRadius: 24))
              .clipShape(RoundedRectangle(cornerRadius: 24))
              .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.line.opacity(0.7)))
            }.buttonStyle(.plain).accessibilityLabel(
              "Open \(first.title.replacingOccurrences(of: "\n", with: " "))")
          }
          if recipes.count > 1 {
            HStack {
              Text("More to make").font(.system(size: 25, design: .serif))
              Spacer()
              Eyebrow(text: "\(recipes.count - 1) RECIPES")
            }.padding(.top, 5)
            ForEach(recipes.dropFirst()) { recipe in
              Button {
                store.open(recipe)
              } label: {
                HStack(spacing: 16) {
                  FoodArtwork(kind: recipe.id).frame(width: 96, height: 102)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                  VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title.replacingOccurrences(of: "\n", with: " "))
                      .font(.system(size: 22, design: .serif)).multilineTextAlignment(.leading)
                    Text("\(recipe.minutes) MIN  /  \(recipe.baseServings) SERVINGS")
                      .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1)
                      .foregroundStyle(Palette.muted)
                  }
                  Spacer(minLength: 0)
                  Image(systemName: "chevron.right").font(.system(size: 11))
                }
              }.buttonStyle(.plain)
              Rectangle().fill(Palette.line).frame(height: 1)
            }
          }
          HStack {
            Spacer()
            Text("Made with care. Cooked with love.").font(.system(size: 13, design: .serif))
              .italic()
              .foregroundStyle(Palette.muted)
            Spacer()
          }.padding(.vertical, 15)
        }.padding(.horizontal, 24).padding(.bottom, 12)
      }.scrollIndicators(.hidden)
      HStack {
        tab("The collection", symbol: "square.grid.2x2", selected: !store.showSaved) {
          store.showSaved = false
        }
        tab("Saved recipes", symbol: "bookmark", selected: store.showSaved) {
          store.showSaved = true
        }
      }
      .padding(.top, 12).padding(.bottom, 4)
      .background(Palette.paper.shadow(color: .black.opacity(0.04), radius: 8, y: -4))
    }
  }

  private func tab(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: selected ? symbol + ".fill" : symbol).font(.system(size: 18))
        Text(title).font(.system(size: 10, weight: selected ? .semibold : .regular))
      }.foregroundStyle(selected ? Palette.red : Palette.muted).frame(maxWidth: .infinity).frame(
        minHeight: 44)
    }.buttonStyle(.plain)
  }
}

struct RecipeView: View {
  @Environment(KitchenStore.self) private var store
  let recipe: Recipe
  @State private var showReset = false
  @State private var section = "Ingredients"
  var session: CookingSession { store.session(recipe) }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        RoundButton(symbol: "arrow.left", label: "Back to collection") { store.home() }
        Spacer()
        Eyebrow(text: "THE RECIPE")
        Spacer()
        RoundButton(
          symbol: store.state.favorites.contains(recipe.id) ? "bookmark.fill" : "bookmark",
          label: store.state.favorites.contains(recipe.id) ? "Unsave recipe" : "Save recipe"
        ) { store.favorite(recipe) }
        ShareLink(item: store.export(recipe)) {
          Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
        }.accessibilityLabel("Share scaled recipe")
      }.padding(.horizontal, 22).padding(.bottom, 10)
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          FoodArtwork(kind: recipe.id).frame(height: 232)
            .clipShape(RoundedRectangle(cornerRadius: 22))
          HStack {
            Eyebrow(text: recipe.category, color: Palette.red)
            Spacer()
            Label("\(recipe.minutes) min", systemImage: "clock").font(.system(size: 12))
          }
          Text(recipe.title).font(.system(size: 42, design: .serif)).tracking(-1.7).lineSpacing(-2)
          Text(recipe.story).font(.system(size: 15)).lineSpacing(5).foregroundStyle(Palette.muted)
          HStack {
            VStack(alignment: .leading, spacing: 5) {
              Text("A place at the table").font(.system(size: 18, design: .serif))
              Text("Quantities scale with you").font(.system(size: 11)).foregroundStyle(
                Palette.muted)
            }
            Spacer()
            Button {
              store.edit(recipe) { $0.adjustServings(by: -1) }
            } label: {
              Image(systemName: "minus").frame(width: 40, height: 44)
            }.disabled(session.servings == 1).accessibilityLabel("Fewer servings")
            Text("\(session.servings)").font(.system(size: 22, weight: .medium, design: .serif))
              .frame(minWidth: 23)
              .accessibilityLabel("\(session.servings) servings")
            Button {
              store.edit(recipe) { $0.adjustServings(by: 1) }
            } label: {
              Image(systemName: "plus").frame(width: 40, height: 44)
            }.disabled(session.servings == 12).accessibilityLabel("More servings")
          }.padding(14).background(
            Palette.cream.opacity(0.65), in: RoundedRectangle(cornerRadius: 17))
          HStack(spacing: 0) {
            ForEach(["Ingredients", "Method", "Swaps"], id: \.self) { item in
              Button {
                section = item
              } label: {
                VStack(spacing: 12) {
                  Text(item).font(.system(size: 13, weight: section == item ? .semibold : .regular))
                    .foregroundStyle(section == item ? Palette.ink : Palette.muted)
                  Rectangle().fill(section == item ? Palette.red : Palette.line).frame(height: 2)
                }.frame(maxWidth: .infinity).padding(.top, 8)
              }.buttonStyle(.plain)
            }
          }
          if section == "Ingredients" {
            ingredients
          } else if section == "Method" {
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
              HStack(alignment: .top, spacing: 14) {
                Text(String(format: "%02d", index + 1)).font(.system(size: 15, design: .serif))
                  .foregroundStyle(Palette.red)
                VStack(alignment: .leading, spacing: 8) {
                  Text(step.title.replacingOccurrences(of: "\n", with: " ")).font(
                    .system(size: 19, design: .serif))
                  Text(step.instruction).font(.system(size: 14)).lineSpacing(5).foregroundStyle(
                    Palette.muted)
                }
              }.padding(.vertical, 7)
            }
          } else {
            ForEach(recipe.substitutions, id: \.original) { substitution in
              VStack(alignment: .leading, spacing: 10) {
                Label(substitution.original, systemImage: "arrow.triangle.swap").font(
                  .system(size: 19, design: .serif))
                Text(substitution.alternative).font(.system(size: 14)).foregroundStyle(
                  Palette.muted
                ).lineSpacing(5)
              }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.cream.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
            }
          }
        }.padding(.horizontal, 24).padding(.bottom, 26)
      }.scrollIndicators(.hidden)
      PrimaryButton(
        title: session.started && !session.completed ? "Return to cooking" : "Begin cooking"
      ) {
        store.begin(recipe)
      }.padding(.horizontal, 24).padding(.vertical, 12).background(Palette.paper)
    }
    .confirmationDialog(
      "Clear your ingredient checklist?", isPresented: $showReset, titleVisibility: .visible
    ) {
      Button("Reset preparation", role: .destructive) { store.resetPrep(recipe) }
    }
  }

  private var ingredients: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("\(session.prepared.count) of \(recipe.ingredients.count) ready").font(
          .system(size: 11, weight: .medium)
        ).foregroundStyle(Palette.green)
        Spacer()
        if store.prepUndo?.0 == recipe.id {
          Button("Undo reset") { store.undoPrep(recipe) }.font(.system(size: 12, weight: .semibold))
            .frame(minHeight: 40)
        } else {
          Button("Reset") { showReset = true }.font(.system(size: 12)).frame(minHeight: 40)
            .disabled(session.prepared.isEmpty)
        }
      }
      ForEach(recipe.ingredients) { ingredient in
        let checked = session.prepared.contains(ingredient.id)
        Button {
          store.toggleIngredient(ingredient, recipe: recipe)
        } label: {
          HStack(alignment: .center, spacing: 13) {
            ZStack {
              RoundedRectangle(cornerRadius: 7).fill(checked ? Palette.green : .clear)
              RoundedRectangle(cornerRadius: 7).stroke(
                checked ? Palette.green : Palette.line, lineWidth: 1.5)
              if checked {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                  .foregroundStyle(.white)
              }
            }.frame(width: 25, height: 25)
            VStack(alignment: .leading, spacing: 4) {
              Text(ingredient.name).font(.system(size: 15, weight: .medium)).strikethrough(checked)
                .foregroundStyle(checked ? Palette.muted : Palette.ink)
              if !ingredient.note.isEmpty {
                Text(ingredient.note).font(.system(size: 11)).foregroundStyle(Palette.muted)
                  .multilineTextAlignment(.leading)
              }
            }
            Spacer(minLength: 6)
            Text(ingredient.quantity(servings: session.servings, base: recipe.baseServings))
              .font(.system(size: 16, weight: .medium, design: .serif))
              .foregroundStyle(checked ? Palette.muted : Palette.ink)
          }.padding(.vertical, 15)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          "\(ingredient.name), \(ingredient.quantity(servings: session.servings, base: recipe.baseServings)), \(checked ? "prepared" : "not prepared")"
        )
        Rectangle().fill(Palette.line.opacity(0.65)).frame(height: 1)
      }
    }
  }
}

struct CookingView: View {
  @Environment(KitchenStore.self) private var store
  let recipe: Recipe
  @State private var shortTimer = false
  @State private var showRestart = false
  var session: CookingSession { store.session(recipe) }
  var step: CookingStep { recipe.steps[session.step] }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        RoundButton(symbol: "arrow.left", label: "Back to recipe") {
          store.state.isCooking = false
          store.save()
        }
        Spacer()
        VStack(spacing: 4) {
          Eyebrow(text: "IN YOUR KITCHEN", color: Palette.green)
          Text(recipe.title.replacingOccurrences(of: "\n", with: " ")).font(
            .system(size: 12, design: .serif))
        }
        Spacer()
        Menu {
          Button("Kitchen timers", systemImage: "timer") { store.showTimers = true }
          Button("Restart recipe", systemImage: "arrow.counterclockwise") { showRestart = true }
        } label: {
          Image(systemName: "ellipsis").frame(width: 44, height: 44)
            .background(Palette.cream, in: Circle())
        }.accessibilityLabel("Cooking options")
      }.padding(.horizontal, 24).padding(.bottom, 22)
      if session.completed {
        completion
      } else {
        HStack(spacing: 5) {
          ForEach(recipe.steps.indices, id: \.self) { index in
            Capsule().fill(index <= session.step ? Palette.green : Palette.line).frame(height: 3)
          }
        }.padding(.horizontal, 26)
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .bottom) {
              Text(String(format: "%02d", session.step + 1))
                .font(.system(size: 92, weight: .regular, design: .serif))
                .tracking(-6).foregroundStyle(Palette.red)
              Text("/ \(String(format: "%02d", recipe.steps.count))")
                .font(.system(size: 16, design: .serif)).foregroundStyle(Palette.muted).padding(
                  .bottom, 17)
              Spacer()
              Text("\(session.servings) AT THE TABLE")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1).foregroundStyle(Palette.muted).padding(.bottom, 19)
            }.padding(.top, 20)
            Text(step.title).font(.system(size: 37, design: .serif)).tracking(-1.3).lineSpacing(0)
              .fixedSize(horizontal: false, vertical: true)
            Text(step.instruction).font(.system(size: 17)).lineSpacing(8).fixedSize(
              horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: "leaf").font(.system(size: 15)).padding(.top, 2)
              Text(step.tip).font(.system(size: 13)).lineSpacing(5)
            }.foregroundStyle(Palette.green).padding(18).frame(
              maxWidth: .infinity, alignment: .leading
            )
            .background(Palette.green.opacity(0.065), in: RoundedRectangle(cornerRadius: 17))
            if let name = step.timerName, let seconds = step.timerSeconds {
              VStack(spacing: 12) {
                HStack {
                  Image(systemName: "timer").foregroundStyle(Palette.red)
                  VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.system(size: 15, weight: .medium))
                    Text(
                      shortTimer
                        ? "15-second practice timer" : "\(seconds / 60) minute cooking timer"
                    )
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                  }
                  Spacer()
                  Button {
                    store.addTimer(
                      recipe: recipe, name: shortTimer ? "\(name) · practice" : name,
                      seconds: shortTimer ? 15 : seconds)
                  } label: {
                    Label("Start", systemImage: "play.fill").font(
                      .system(size: 12, weight: .semibold)
                    )
                    .padding(.horizontal, 15).frame(height: 42)
                    .foregroundStyle(.white).background(Palette.red, in: Capsule())
                  }.buttonStyle(.plain).accessibilityLabel("Start \(name) timer")
                }
                Toggle("Use 15-second practice timer", isOn: $shortTimer)
                  .font(.system(size: 12)).tint(Palette.green)
                  .accessibilityIdentifier("practiceTimerToggle")
                if shortTimer {
                  Text("For trying the timer only. Follow the recipe’s real cooking time.")
                    .font(.system(size: 10)).foregroundStyle(Palette.red).frame(
                      maxWidth: .infinity, alignment: .leading)
                }
              }.padding(17).overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
            }
            Button {
              store.showTimers = true
            } label: {
              Label("Open kitchen timers", systemImage: "timer").font(
                .system(size: 12, weight: .medium)
              )
              .frame(maxWidth: .infinity).frame(minHeight: 44)
            }.buttonStyle(.plain).foregroundStyle(Palette.green)
          }.padding(.horizontal, 27).padding(.bottom, 14)
        }.scrollIndicators(.hidden).id(session.step)
        HStack(spacing: 12) {
          Button {
            store.edit(recipe) { $0.moveStep(by: -1, count: recipe.steps.count) }
          } label: {
            Image(systemName: "arrow.left").frame(width: 56, height: 56)
              .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
          }.disabled(session.step == 0).accessibilityLabel("Previous step")
          PrimaryButton(
            title: session.step == recipe.steps.count - 1 ? "Dinner is served" : "Next step"
          ) {
            if session.step == recipe.steps.count - 1 {
              store.edit(recipe) { $0.completed = true }
            } else {
              store.edit(recipe) { $0.moveStep(by: 1, count: recipe.steps.count) }
            }
          }
        }.padding(.horizontal, 24).padding(.vertical, 12).background(Palette.paper)
      }
    }
    .confirmationDialog(
      "Start again at step one? Your ingredients and timers will stay.", isPresented: $showRestart,
      titleVisibility: .visible
    ) {
      Button("Restart cooking") {
        store.edit(recipe) {
          $0.step = 0
          $0.completed = false
        }
      }
    }
  }

  private var completion: some View {
    ScrollView {
      VStack(spacing: 23) {
        FoodArtwork(kind: recipe.id).frame(height: 270).clipShape(Circle())
        Eyebrow(text: "THE BEST PART", color: Palette.red)
        Text("Dinner is served.").font(.system(size: 38, design: .serif)).tracking(-1)
        Text("Take a seat. You’ve made something lovely.")
          .font(.system(size: 15)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        PrimaryButton(
          title: store.state.favorites.contains(recipe.id)
            ? "Saved to your cookbook" : "Save this recipe", symbol: "bookmark"
        ) { store.favorite(recipe) }
        Button("Back to the collection") { store.home() }.font(.system(size: 14)).frame(
          minHeight: 44)
      }.padding(24)
    }
  }
}

struct TimerDock: View {
  @Environment(KitchenStore.self) private var store
  var body: some View {
    Button {
      store.showTimers = true
    } label: {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        HStack(spacing: 12) {
          Image(systemName: "timer").font(.system(size: 20))
          if let timer = store.state.timers.first {
            VStack(alignment: .leading, spacing: 4) {
              Text(timer.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
              Text(
                timer.isFinished(at: context.date)
                  ? "READY · Tap to manage"
                  : "\(store.state.timers.count) kitchen timer\(store.state.timers.count == 1 ? "" : "s")"
              )
              .font(.system(size: 9)).opacity(0.75)
            }
            Spacer()
            if store.state.timers.count > 1 {
              let second = store.state.timers[1]
              Text(
                second.isFinished(at: context.date)
                  ? "READY" : KitchenTimer.clock(second.remaining(at: context.date))
              )
              .font(.system(size: 13, weight: .medium, design: .monospaced)).opacity(0.75)
              Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 22)
            }
            Text(
              timer.isFinished(at: context.date)
                ? "READY" : KitchenTimer.clock(timer.remaining(at: context.date))
            )
            .font(.system(size: 18, weight: .medium, design: .monospaced))
          }
          Image(systemName: "chevron.up").font(.system(size: 10))
        }.foregroundStyle(.white).padding(.horizontal, 20).frame(minHeight: 60)
      }
      .background(Palette.green)
    }.buttonStyle(.plain).accessibilityLabel("Manage \(store.state.timers.count) kitchen timers")
  }
}

struct TimerBoard: View {
  @Environment(KitchenStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var duration = 60
  @State private var name = ""
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Eyebrow(text: "EVERYTHING IN ITS OWN TIME", color: Palette.red)
          Text("A calmer kitchen.").font(.system(size: 36, design: .serif)).tracking(-1)
          Text("Timers keep their time as you move between recipes, steps and visits.")
            .font(.system(size: 14)).lineSpacing(5).foregroundStyle(Palette.muted)
          if store.state.timers.isEmpty {
            Label("Nothing on the clock. Enjoy the quiet.", systemImage: "timer")
              .font(.system(size: 14)).padding(20).frame(maxWidth: .infinity)
              .background(Palette.cream, in: RoundedRectangle(cornerRadius: 18))
          }
          TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 12) {
              ForEach(store.state.timers) { timer in
                timerCard(timer, at: context.date)
              }
            }
          }
          VStack(alignment: .leading, spacing: 16) {
            Text("Set another timer").font(.system(size: 23, design: .serif))
            TextField("Timer name (optional)", text: $name)
              .font(.system(size: 15)).padding(14).background(
                Palette.paper, in: RoundedRectangle(cornerRadius: 12)
              )
              .accessibilityLabel("New timer name")
              .onChange(of: name) { _, value in name = String(value.prefix(50)) }
            Picker("Timer duration", selection: $duration) {
              Text("15 sec").tag(15)
              Text("1 min").tag(60)
              Text("5 min").tag(300)
              Text("10 min").tag(600)
            }.pickerStyle(.segmented)
            if duration == 15 {
              Text("A short timer for testing. Not a recipe cooking time.")
                .font(.system(size: 11)).foregroundStyle(Palette.red)
            }
            PrimaryButton(title: "Start timer", symbol: "play.fill") {
              let recipe = store.recipe ?? Recipes.all[0]
              store.addTimer(
                recipe: recipe,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  ? "Kitchen timer" : name.trimmingCharacters(in: .whitespacesAndNewlines),
                seconds: duration)
              name = ""
            }
          }.padding(20).background(
            Palette.cream.opacity(0.7), in: RoundedRectangle(cornerRadius: 22))
          Text(
            "Timers use the device clock and restore after relaunch. Mise shows completion in the app; it does not send background notifications or alarms."
          )
          .font(.system(size: 11)).lineSpacing(4).foregroundStyle(Palette.muted)
        }.padding(24)
      }
      .background(Palette.paper)
      .toolbar {
        ToolbarItem(placement: .principal) { Eyebrow(text: "KITCHEN TIMERS") }
        ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
      }
    }.tint(Palette.green)
  }

  private func timerCard(_ timer: KitchenTimer, at date: Date) -> some View {
    let finished = timer.isFinished(at: date)
    return VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(timer.name).font(.system(size: 16, weight: .medium))
          Text(finished ? "READY WHEN YOU ARE" : timer.isPaused ? "PAUSED" : "SIMMERING ALONG")
            .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.5)
            .foregroundStyle(finished ? Palette.red : Palette.muted)
        }
        Spacer()
        Text(KitchenTimer.clock(timer.remaining(at: date))).font(
          .system(size: 29, design: .monospaced)
        )
        .foregroundStyle(finished ? Palette.red : Palette.green)
      }
      ProgressView(value: 1 - timer.remaining(at: date) / timer.duration).tint(
        finished ? Palette.red : Palette.green)
      HStack(spacing: 10) {
        if !finished {
          Button {
            store.toggleTimer(timer.id)
          } label: {
            Label(
              timer.isPaused ? "Resume" : "Pause",
              systemImage: timer.isPaused ? "play.fill" : "pause.fill"
            )
            .font(.system(size: 12, weight: .medium)).frame(minHeight: 42).frame(
              maxWidth: .infinity
            )
            .background(Palette.cream, in: Capsule())
          }.accessibilityLabel("\(timer.isPaused ? "Resume" : "Pause") \(timer.name)")
        }
        Button {
          store.restartTimer(timer.id)
        } label: {
          Label("Restart", systemImage: "arrow.counterclockwise")
            .font(.system(size: 12, weight: .medium)).frame(minHeight: 42).frame(
              maxWidth: .infinity
            )
            .background(Palette.cream, in: Capsule())
        }.accessibilityLabel("Restart \(timer.name)")
        Button {
          store.removeTimer(timer.id)
        } label: {
          Image(systemName: finished ? "checkmark" : "xmark").frame(width: 42, height: 42)
            .background(Palette.cream, in: Circle())
        }.accessibilityLabel(finished ? "Dismiss \(timer.name)" : "Cancel \(timer.name)")
      }.buttonStyle(.plain)
    }.padding(18).background(Color(hex: 0xFFFDFA), in: RoundedRectangle(cornerRadius: 19))
      .overlay(
        RoundedRectangle(cornerRadius: 19).stroke(
          finished ? Palette.red.opacity(0.4) : Palette.line))
  }
}
