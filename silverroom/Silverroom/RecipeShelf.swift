import SwiftUI

struct RecipeShelf: View {
  @EnvironmentObject private var library: LibraryStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var renaming: Recipe?
  @State private var deleting: Recipe?
  @State private var newName = ""
  @State private var previews: [UUID: UIImage] = [:]
  var negative: Negative?
  var onApply: ((Recipe) -> Void)?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Eyebrow(text: "Your signature looks").padding(.top, 18)
          Text("Good light,\nremembered.")
            .font(.system(size: 36, design: .serif)).foregroundStyle(Palette.silver)
          Text(
            onApply == nil
              ? "A collection of the looks you’ve made."
              : "Choose a recipe to develop this photograph."
          )
          .font(.subheadline).foregroundStyle(Palette.muted)
          Hairline()
          if library.state.recipes.isEmpty {
            VStack(alignment: .leading, spacing: 15) {
              Image(systemName: "bookmark").font(.title).foregroundStyle(Palette.amber)
              Text("Your first recipe starts\nwith a photograph.")
                .font(.system(.title2, design: .serif)).foregroundStyle(Palette.silver)
              Text(
                "Open a negative, find a look you love, then tap Save recipe. We’ll keep the look and adjustments here."
              )
              .font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(4)
            }
            .padding(.vertical, 25)
          }
          ForEach(library.state.recipes) { recipe in
            recipeRow(recipe)
              .task(id: recipe.settings) {
                guard
                  let example = negative ?? library.state.negatives.first(where: { $0.isSample }),
                  let data = try? library.data(for: example)
                else { return }
                let settings = recipe.settings
                previews[recipe.id] = await Task.detached(priority: .utility) {
                  try? ImageEngine().render(data, settings: settings, maxPixel: 220)
                }.value
              }
          }
          if !library.state.recipes.isEmpty {
            Text(
              negative == nil
                ? "Previews shown on The cove sample." : "Previews shown on this photograph."
            )
            .font(.caption).foregroundStyle(Palette.muted)
          }
        }
        .padding(.horizontal, 26).padding(.bottom, 30)
      }
      .background(Palette.background)
      .navigationTitle("Recipes").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .alert(
        "Rename recipe",
        isPresented: Binding(
          get: { renaming != nil }, set: { if !$0 { renaming = nil } })
      ) {
        TextField("Recipe name", text: $newName)
        Button("Cancel", role: .cancel) { renaming = nil }
        Button("Save") {
          if let renaming { library.renameRecipe(renaming, name: newName) }
          renaming = nil
        }
        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      .confirmationDialog(
        "Delete this recipe?",
        isPresented: Binding(
          get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
        titleVisibility: .visible
      ) {
        Button("Delete recipe", role: .destructive) {
          if let deleting { library.deleteRecipe(deleting) }
          deleting = nil
        }
      } message: {
        Text("Edits already applied to photographs will be kept.")
      }
    }
  }

  private func recipeRow(_ recipe: Recipe) -> some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack(alignment: .top, spacing: 14) {
        Group {
          if let preview = previews[recipe.id] {
            Image(uiImage: preview).resizable().scaledToFill()
          } else {
            Palette.panel
          }
        }
        .frame(width: 66, height: 88).clipped()
        .overlay { Rectangle().stroke(Palette.line, lineWidth: 1) }
        .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 6) {
          Text(recipe.name).font(.system(.title2, design: .serif)).foregroundStyle(Palette.silver)
            .fixedSize(horizontal: false, vertical: true)
          if !typeSize.isAccessibilitySize { recipeSummary(recipe) }
        }
        Spacer(minLength: 0)
        Menu {
          Button("Rename", systemImage: "pencil") {
            newName = recipe.name
            renaming = recipe
          }
          Button("Delete recipe", systemImage: "trash", role: .destructive) {
            deleting = recipe
          }
        } label: {
          Image(systemName: "ellipsis").frame(width: 44, height: 44).foregroundStyle(Palette.muted)
        }
        .accessibilityLabel("Manage \(recipe.name)")
      }
      if typeSize.isAccessibilitySize { recipeSummary(recipe) }
      if let onApply {
        Button {
          onApply(recipe)
        } label: {
          HStack {
            Text("Apply recipe")
            Spacer()
            Image(systemName: "arrow.right")
          }
          .font(.subheadline).foregroundStyle(Palette.amber).frame(minHeight: 44)
        }
        .accessibilityLabel("Apply \(recipe.name)")
      }
      Hairline()
    }
  }

  private func recipeSummary(_ recipe: Recipe) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(
        recipe.settings.film.title + " / "
          + String(format: "%+.2f EV", recipe.settings.exposure)
      )
      .font(.system(.caption, design: .monospaced))
      Text(
        String(
          format: "Contrast %.2f · Warmth %+.0f", recipe.settings.contrast,
          recipe.settings.warmth * 100)
      )
      .font(.caption)
    }
    .foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
  }
}
