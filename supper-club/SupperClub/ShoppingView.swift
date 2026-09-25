import SwiftUI

struct ShoppingView: View {
  @EnvironmentObject private var store: KitchenStore
  @State private var showExtra = false
  @State private var editing: CustomItem?
  @State private var showClear = false
  @State private var showRecipes = false

  private var checkedCount: Int {
    store.shopping.filter { store.state.checked.contains($0.id) }.count
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 23) {
        HStack {
          PlateMark()
          Spacer()
          Button {
            showExtra = true
          } label: {
            Label("Add extra", systemImage: "plus").font(.subheadline.weight(.semibold)).frame(
              minHeight: 44)
          }
        }
        Eyebrow(text: "Good dinner starts here").foregroundStyle(Palette.red)
        Text("A little list.\nA lovely supper.").font(.editorial(44)).lineSpacing(-3)
        if store.shopping.isEmpty {
          VStack(alignment: .leading, spacing: 20) {
            FoodArt(style: 3).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 20))
            Text("Your basket is waiting.").font(.editorial(29))
            Text(
              "Add ingredients from a recipe, or jot down an extra. Your list stays here, even offline."
            )
            .foregroundStyle(Palette.muted).lineSpacing(4)
            MainButton(title: "Add your first extra", symbol: "plus") { showExtra = true }
          }
        } else {
          HStack {
            Text("\(checkedCount) of \(store.shopping.count) in the basket")
              .font(.subheadline.weight(.medium))
            Spacer()
            Text("\(Int(Double(checkedCount) / Double(store.shopping.count) * 100))%")
              .font(.caption.monospacedDigit()).foregroundStyle(Palette.red)
          }
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Capsule().fill(Palette.line.opacity(0.5))
              Capsule().fill(Palette.green).frame(
                width: geometry.size.width * Double(checkedCount)
                  / Double(max(1, store.shopping.count)))
            }
          }.frame(height: 5).accessibilityHidden(true)
          if checkedCount == store.shopping.count {
            Label("All packed. See you in the kitchen.", systemImage: "checkmark.seal")
              .font(.subheadline.weight(.medium)).foregroundStyle(Palette.green)
          }
          if !store.state.shoppingRecipes.isEmpty {
            Button {
              showRecipes = true
            } label: {
              HStack {
                Text(
                  "For \(store.state.shoppingRecipes.count) \(store.state.shoppingRecipes.count == 1 ? "recipe" : "recipes")"
                )
                Spacer()
                Text("Manage").fontWeight(.medium)
                Image(systemName: "chevron.right").font(.caption)
              }.font(.subheadline).frame(minHeight: 44)
            }
          }
          VStack(spacing: 0) {
            ForEach(store.shopping) { item in
              let checked = store.state.checked.contains(item.id)
              HStack(alignment: .center, spacing: 0) {
                Button {
                  UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                  store.toggleChecked(item.id)
                } label: {
                  HStack(spacing: 16) {
                    ZStack {
                      RoundedRectangle(cornerRadius: 8)
                        .stroke(checked ? Palette.green : Palette.line, lineWidth: 1.5)
                        .background(
                          checked ? Palette.green : Color.clear,
                          in: RoundedRectangle(cornerRadius: 8))
                      if checked {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                          .foregroundStyle(.white)
                      }
                    }.frame(width: 29, height: 29)
                    VStack(alignment: .leading, spacing: 4) {
                      Text(item.ingredient.name).font(.body.weight(.medium))
                        .strikethrough(checked).foregroundStyle(
                          checked ? Palette.muted : Palette.ink)
                      Text(item.customID == nil ? item.ingredient.amount : "Your extra")
                        .font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                  }.frame(minHeight: 76).contentShape(Rectangle())
                }.buttonStyle(.plain)
                  .accessibilityLabel(
                    "\(item.ingredient.name), \(item.customID == nil ? item.ingredient.amount : "extra"), \(checked ? "in basket" : "to buy")"
                  )
                  .accessibilityHint("Double tap to \(checked ? "uncheck" : "check off")")
                if let id = item.customID {
                  Button {
                    editing = store.state.custom.first { $0.id == id }
                  } label: {
                    Image(systemName: "pencil").frame(width: 44, height: 44)
                  }.accessibilityLabel("Edit \(item.ingredient.name)")
                }
              }
              Rectangle().fill(Palette.line).frame(height: 0.7)
            }
          }
          HStack {
            Button("Uncheck all") { store.state.checked = [] }.frame(minHeight: 44)
              .disabled(checkedCount == 0)
            Spacer()
            Button("Clear list", role: .destructive) { showClear = true }.frame(minHeight: 44)
          }.font(.subheadline)
        }
      }.padding(24)
    }
    .background(Palette.paper).foregroundStyle(Palette.ink)
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $showExtra) { ExtraView() }
    .sheet(item: $editing) { ExtraView(item: $0) }
    .sheet(isPresented: $showRecipes) { ShoppingRecipesView() }
    .confirmationDialog(
      "Clear your shopping list?", isPresented: $showClear, titleVisibility: .visible
    ) {
      Button("Clear list", role: .destructive) { store.clearShopping() }
      Button("Keep my list", role: .cancel) {}
    } message: {
      Text("This removes all ingredients, extras and checkmarks. Your saved recipes stay.")
    }
  }
}

struct ExtraView: View {
  @EnvironmentObject private var store: KitchenStore
  @Environment(\.dismiss) private var dismiss
  var item: CustomItem?
  @State private var name = ""
  @FocusState private var focused: Bool

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Eyebrow(text: "The little things").foregroundStyle(Palette.red)
          Text(item == nil ? "Anything else?" : "Make it yours.").font(.editorial(36))
            .fixedSize(horizontal: false, vertical: true)
          Text(
            "A loaf of bread, something to drink, flowers for the table. Add quantities in the name if useful."
          )
          .foregroundStyle(Palette.muted).lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
          TextField("e.g. 1 loaf of sourdough", text: $name)
            .textFieldStyle(.roundedBorder).focused($focused)
            .submitLabel(.done).onSubmit(save)
            .accessibilityLabel("Extra item")
          if let item {
            Button("Delete extra", role: .destructive) {
              store.deleteCustom(item.id)
              dismiss()
            }.frame(minHeight: 44)
          }
        }.padding(24)
      }.scrollDismissesKeyboard(.interactively)
        .background(Palette.paper).foregroundStyle(Palette.ink)
        .safeAreaInset(edge: .bottom) {
          MainButton(
            title: item == nil ? "Add to the list" : "Save extra", symbol: "checkmark", action: save
          )
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
          .padding(.horizontal, 24).padding(.vertical, 12).background(Palette.paper)
        }
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } }
        }
        .onAppear {
          name = item?.name ?? ""
          focused = true
        }
    }.preferredColorScheme(.light)
  }

  private func save() {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    store.saveCustom(name, id: item?.id)
    dismiss()
  }
}

struct ShoppingRecipesView: View {
  @EnvironmentObject private var store: KitchenStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(Recipes.all.filter { store.state.shoppingRecipes[$0.id] != nil }) { recipe in
            HStack {
              VStack(alignment: .leading, spacing: 7) {
                Text(recipe.title.replacingOccurrences(of: "\n", with: " ")).font(.headline)
                Text("\(store.state.shoppingRecipes[recipe.id] ?? recipe.servings) servings").font(
                  .caption)
              }
              Spacer()
              Button(role: .destructive) {
                store.state.shoppingRecipes.removeValue(forKey: recipe.id)
              } label: {
                Image(systemName: "minus.circle").frame(width: 44, height: 44)
              }.accessibilityLabel(
                "Remove \(recipe.title.replacingOccurrences(of: "\n", with: " ")) ingredients")
            }
          }
        } footer: {
          Text(
            "Removing a recipe subtracts its ingredients. Ingredients needed by another recipe stay on your list."
          )
        }
      }
      .scrollContentBackground(.hidden).background(Palette.paper)
      .navigationTitle("On the menu").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
  }
}

struct AboutView: View {
  @EnvironmentObject private var store: KitchenStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 23) {
          PlateMark()
          Text("Dinner is a\nsmall occasion.").font(.editorial(42))
          Text(
            "Supper Club is a collection of ten original recipes, written for everyday kitchens. No account. No connection. Just something good to cook."
          )
          .lineSpacing(5)
          Divider()
          Eyebrow(text: "Your kitchen")
          Text(
            "\(store.state.mealsCooked) \(store.state.mealsCooked == 1 ? "supper" : "suppers") cooked"
          )
          .font(.editorial(28))
          Text(
            "Saved recipes, serving sizes, your shopping list, cooking progress and timers live on this device. Deleting the app removes them. Nothing is sent to a server."
          )
          .foregroundStyle(Palette.muted).lineSpacing(4)
          Eyebrow(text: "A note on timers")
          Text(
            "Timers keep elapsed time if you leave or close the app. Pause, reset or change a timer in the timer room. Timer alerts are visual and haptic while the app is open; there are no background notifications or sounds."
          )
          .foregroundStyle(Palette.muted).lineSpacing(4)
          Eyebrow(text: "Make it work for you")
          Text(
            "Servings scale from 1–12. Water mentioned in the method should scale too. Use extra pans for bigger batches. Cooking times are guides; check doneness. For fractional whole ingredients, use the stated portion or round to taste."
          )
          .foregroundStyle(Palette.muted).lineSpacing(4)
          Text(
            "Dietary tags describe the written ingredients. Check product labels and your own allergy requirements; the app does not filter allergens."
          )
          .font(.footnote).foregroundStyle(Palette.muted)
          Text("SUPPER CLUB  /  VOLUME 01").font(.caption.weight(.medium)).tracking(2)
            .foregroundStyle(Palette.red)
        }.padding(24)
      }.background(Palette.paper).foregroundStyle(Palette.ink)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
    }
  }
}
