import SwiftUI

@main
struct SupperClubApp: App {
  @StateObject private var store = KitchenStore()
  var body: some Scene {
    WindowGroup {
      RootView().environmentObject(store)
        .tint(Palette.red).preferredColorScheme(.light)
    }
  }
}

struct RootView: View {
  @State private var selection = 0
  var body: some View {
    TabView(selection: $selection) {
      NavigationStack { BrowseView() }
        .tabItem { Label("Recipes", systemImage: "book.closed") }.tag(0)
      NavigationStack { ShoppingView() }
        .tabItem { Label("Shopping", systemImage: "basket") }.tag(1)
      NavigationStack { BrowseView(savedOnly: true) }
        .tabItem { Label("Saved", systemImage: "bookmark") }.tag(2)
    }
  }
}

struct BrowseView: View {
  @EnvironmentObject private var store: KitchenStore
  var savedOnly = false
  @State private var query = ""
  @State private var filter = "All"
  @State private var showAbout = false
  @State private var showTimers = false
  @State private var resume: Recipe?

  private var recipes: [Recipe] {
    Recipes.all.filter {
      (!savedOnly || store.state.favorites.contains($0.id))
        && $0.matches(query)
        && (filter != "Under 25 min" || $0.minutes <= 25)
        && (filter != "Plant-based" || $0.label == "Vegan")
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 10) {
          PlateMark()
          Text("supper club").font(.system(size: 25, design: .serif))
          Spacer()
          Button {
            showTimers = true
          } label: {
            Image(systemName: "timer").frame(width: 44, height: 44)
          }.accessibilityLabel("Kitchen timers")
          Button {
            showAbout = true
          } label: {
            Image(systemName: "info.circle").frame(width: 44, height: 44)
          }.accessibilityLabel("About Supper Club")
        }
        .foregroundStyle(Palette.ink)
        VStack(alignment: .leading, spacing: 8) {
          Eyebrow(
            text: savedOnly ? "Your personal collection" : "Volume 01 / Ten original recipes"
          )
          .foregroundStyle(Palette.red)
          Text(savedOnly ? "Your favorites." : "Good food. Any night.")
            .font(.editorial(31)).fixedSize(horizontal: false, vertical: true)
        }
        if let id = store.state.cookRecipeID, let recipe = Recipes.all.first(where: { $0.id == id })
        {
          Button {
            resume = recipe
          } label: {
            HStack {
              Image(systemName: "flame")
              VStack(alignment: .leading, spacing: 4) {
                Text("Back to the kitchen").font(.headline)
                Text(recipe.title.replacingOccurrences(of: "\n", with: " "))
                  .font(.caption)
              }
              Spacer()
              Image(systemName: "arrow.right")
            }.padding(17).foregroundStyle(Palette.paper)
              .background(Palette.ink, in: RoundedRectangle(cornerRadius: 16))
          }.buttonStyle(.plain)
        }
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass").foregroundStyle(Palette.red)
          TextField(
            "Find a recipe or ingredient", text: $query,
            prompt: Text("Find a recipe or ingredient").foregroundStyle(Palette.muted)
          )
          .autocorrectionDisabled().textInputAutocapitalization(.never)
          .accessibilityLabel("Find a recipe or ingredient")
          if !query.isEmpty {
            Button {
              query = ""
            } label: {
              Image(systemName: "xmark.circle.fill").frame(width: 32, height: 40)
            }.accessibilityLabel("Clear search")
          }
        }.padding(.horizontal, 16).frame(minHeight: 56)
          .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
          .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 0.8))
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 9) {
            ForEach(["All", "Under 25 min", "Plant-based"], id: \.self) { name in
              Button {
                filter = name
              } label: {
                Text(name).font(.subheadline.weight(.medium))
                  .padding(.horizontal, 17).frame(minHeight: 44)
                  .foregroundStyle(filter == name ? Palette.paper : Palette.ink)
                  .background(filter == name ? Palette.ink : Color.clear, in: Capsule())
                  .overlay(Capsule().stroke(Palette.line, lineWidth: filter == name ? 0 : 1))
              }.buttonStyle(.plain).accessibilityAddTraits(filter == name ? .isSelected : [])
            }
          }
        }
        if recipes.isEmpty {
          VStack(alignment: .leading, spacing: 14) {
            Text(
              savedOnly && store.state.favorites.isEmpty
                ? "A place for your\nnew favorites." : "Nothing in the pot.\nYet."
            )
            .font(.editorial(32))
            Text(
              savedOnly && store.state.favorites.isEmpty
                ? "Tap the bookmark on any recipe to save it here."
                : "Try a single ingredient, like tomato, lemon or chickpeas. All search words must match."
            )
            .foregroundStyle(Palette.muted)
            if !query.isEmpty || filter != "All" {
              Button("Reset filters") {
                query = ""
                filter = "All"
              }.frame(minHeight: 44)
            }
          }.padding(.vertical, 20)
        } else {
          if !savedOnly && query.isEmpty && filter == "All" {
            NavigationLink {
              RecipeView(recipe: recipes[0])
            } label: {
              VStack(alignment: .leading, spacing: 0) {
                FoodArt(style: recipes[0].style).scaleEffect(1.16)
                  .frame(height: 222).clipped()
                VStack(alignment: .leading, spacing: 10) {
                  Eyebrow(text: "Tonight’s pick").foregroundStyle(Palette.red)
                  Text(recipes[0].title).font(.editorial(30)).multilineTextAlignment(.leading)
                  HStack {
                    Text("25 MIN  /  VEGETARIAN").font(.caption.weight(.semibold)).tracking(1)
                      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.title3)
                  }.foregroundStyle(Palette.red)
                }.padding(20)
              }.background(Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }.buttonStyle(.plain)
          }
          HStack {
            Eyebrow(text: query.isEmpty ? "The recipe collection" : "For your pantry")
            Spacer()
            Text("\(recipes.count) \(recipes.count == 1 ? "recipe" : "recipes")")
              .font(.caption).foregroundStyle(Palette.muted)
          }.padding(.top, 5)
          ForEach(recipes) { recipe in
            NavigationLink {
              RecipeView(recipe: recipe)
            } label: {
              RecipeRow(recipe: recipe)
            }.buttonStyle(.plain)
            Rectangle().fill(Palette.line).frame(height: 1)
          }
          Text("Made for your kitchen.\nOriginal recipes. Always offline.")
            .font(.caption).foregroundStyle(Palette.muted)
            .lineSpacing(5).padding(.vertical, 20)
        }
      }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 24)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(Palette.paper).foregroundStyle(Palette.ink)
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $showAbout) { AboutView() }
    .sheet(isPresented: $showTimers) { TimerRoomView() }
    .fullScreenCover(item: $resume) { CookView(recipe: $0) }
  }
}

struct RecipeRow: View {
  let recipe: Recipe
  var body: some View {
    HStack(spacing: 17) {
      FoodArt(style: recipe.style).frame(width: 96, height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 13))
      VStack(alignment: .leading, spacing: 10) {
        Text(recipe.title).font(.editorial(23)).multilineTextAlignment(.leading)
        Text("\(recipe.minutes) min · \(recipe.label)")
          .font(.caption.weight(.medium)).foregroundStyle(Palette.red)
      }
      Spacer(minLength: 0)
    }.contentShape(Rectangle())
  }
}

struct RecipeView: View {
  let recipe: Recipe
  @EnvironmentObject private var store: KitchenStore
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var cook = false
  @State private var added = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        FoodArt(style: recipe.style).frame(height: 205)
          .clipShape(RoundedRectangle(cornerRadius: 20))
        VStack(alignment: .leading, spacing: 14) {
          Eyebrow(text: "\(recipe.minutes) minutes  /  \(recipe.label)").foregroundStyle(
            Palette.red)
          Text(recipe.title).font(.editorial(37)).lineSpacing(-3)
          Text(recipe.subtitle).foregroundStyle(Palette.muted).font(.body).lineSpacing(4)
        }
        let servingLayout =
          typeSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
          : AnyLayout(HStackLayout())
        servingLayout {
          VStack(alignment: .leading, spacing: 5) {
            Text("Servings").font(.editorial(26))
            Text("Made for your table").font(.caption).foregroundStyle(Palette.muted)
          }
          if !typeSize.isAccessibilitySize { Spacer() }
          HStack(spacing: 12) {
            Button {
              store.setServings(store.servings(for: recipe) - 1, for: recipe)
              added = false
            } label: {
              Image(systemName: "minus").frame(width: 44, height: 44)
            }.disabled(store.servings(for: recipe) == 1).accessibilityLabel("Fewer servings")
            Text("\(store.servings(for: recipe))").font(.title3.weight(.semibold))
              .monospacedDigit().accessibilityLabel("\(store.servings(for: recipe)) servings")
            Button {
              store.setServings(store.servings(for: recipe) + 1, for: recipe)
              added = false
            } label: {
              Image(systemName: "plus").frame(width: 44, height: 44)
            }.disabled(store.servings(for: recipe) == 12).accessibilityLabel("More servings")
          }.background(.white.opacity(0.8), in: Capsule())
        }
        Button {
          store.addIngredients(recipe)
          added = true
          UINotificationFeedbackGenerator().notificationOccurred(.success)
        } label: {
          HStack {
            Image(systemName: added ? "checkmark.circle.fill" : "basket").font(.title3)
            Text(added ? "On your list" : "Add to list")
              .font(.headline)
            Spacer()
          }.padding(.horizontal, 18).padding(.vertical, 15).frame(minHeight: 56)
            .foregroundStyle(added ? Palette.green : Palette.red)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line, lineWidth: 1))
        }.buttonStyle(.plain)
        Text("Ingredients").font(.editorial(29)).padding(.top, 4)
        VStack(spacing: 0) {
          ForEach(recipe.ingredients) { ingredient in
            let scaled = ingredient.scaled(store.servings(for: recipe), from: recipe.servings)
            HStack(alignment: .firstTextBaseline, spacing: 16) {
              VStack(alignment: .leading, spacing: 4) {
                Text(ingredient.name).font(.body)
                if !ingredient.note.isEmpty {
                  Text(ingredient.note).font(.caption).foregroundStyle(Palette.muted)
                }
              }
              Spacer()
              Text(scaled.amount).font(.body.weight(.medium)).foregroundStyle(Palette.red)
                .multilineTextAlignment(.trailing)
            }.padding(.vertical, 14)
            Rectangle().fill(Palette.line).frame(height: 0.7)
          }
        }
        Text(
          "Adding again updates this recipe’s quantities. Shared ingredients combine automatically."
        )
        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(3)
        VStack(alignment: .leading, spacing: 18) {
          Text("The method").font(.editorial(31))
          ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .top, spacing: 14) {
              Text(String(format: "%02d", index + 1)).font(.caption.weight(.bold))
                .foregroundStyle(Palette.red).padding(.top, 4)
              VStack(alignment: .leading, spacing: 7) {
                Text(step.title).font(.headline)
                Text(step.instruction).font(.subheadline).foregroundStyle(Palette.muted)
                  .lineSpacing(4)
              }
            }
          }
        }
      }.padding(24)
    }
    .background(Palette.paper).foregroundStyle(Palette.ink)
    .navigationTitle("The recipe").navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .tabBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          store.toggleFavorite(recipe)
        } label: {
          Image(
            systemName: store.state.favorites.contains(recipe.id) ? "bookmark.fill" : "bookmark")
        }.accessibilityLabel(
          store.state.favorites.contains(recipe.id) ? "Unsave recipe" : "Save recipe")
      }
    }
    .safeAreaInset(edge: .bottom) {
      MainButton(
        title: store.state.cookRecipeID == recipe.id ? "Continue cooking" : "Let’s cook",
        symbol: "flame"
      ) {
        store.beginCooking(recipe)
        cook = true
      }.padding(.horizontal, 24).padding(.vertical, 12).background(Palette.paper)
    }
    .fullScreenCover(isPresented: $cook) { CookView(recipe: recipe) }
  }
}
