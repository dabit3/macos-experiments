import SwiftUI

struct RecipeShelf: View {
  @EnvironmentObject private var library: LibraryStore
  @Environment(\.dismiss) private var dismiss
  @State private var managing: Recipe?
  @State private var previews: [UUID: UIImage] = [:]
  var negative: Negative?
  var onApply: ((Recipe) -> Void)?

  var body: some View {
    VStack(spacing: 0) {
      SheetHeader(title: "Recipes") { dismiss() }
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          if library.state.recipes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("No recipes yet").font(TypeStyle.title)
              Text("Edit a photo, then save its look from the Recipes tool to reuse it here.")
                .font(TypeStyle.body).foregroundStyle(Palette.muted)
            }
            .padding(.top, 24)
          } else if onApply != nil {
            Text("Tap a recipe to apply it. Crop and rotation stay as they are.")
              .font(TypeStyle.caption).foregroundStyle(Palette.muted).padding(.bottom, 16)
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
                  try? ImageEngine().render(data, settings: settings, maxPixel: 400)
                }.value
              }
          }
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 30)
      }
    }
    .foregroundStyle(Palette.ink).presentationBackground(Palette.background)
    .presentationDragIndicator(.visible)
    .sheet(item: $managing) { recipe in
      RecipeNameSheet(
        title: "Edit recipe", initialName: recipe.name,
        onSave: { library.renameRecipe(recipe, name: $0) },
        onDelete: { library.deleteRecipe(recipe) })
    }
  }

  private func recipeRow(_ recipe: Recipe) -> some View {
    HStack(alignment: .center, spacing: 14) {
      Button {
        if let onApply { onApply(recipe) } else { managing = recipe }
      } label: {
        HStack(alignment: .center, spacing: 14) {
          Group {
            if let preview = previews[recipe.id] {
              Image(uiImage: preview).resizable().scaledToFill()
            } else {
              Palette.panel
            }
          }
          .frame(width: 64, height: 80).clipped()
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
          .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 4) {
            Text(recipe.name).font(TypeStyle.heading)
              .fixedSize(horizontal: false, vertical: true)
            summary(recipe)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(onApply == nil ? "Edit \(recipe.name)" : "Apply \(recipe.name)")
      IconButton(symbol: "ellipsis", label: "Edit \(recipe.name)", size: 17, filled: true) {
        managing = recipe
      }
    }
    .padding(.vertical, 12)
    .overlay(alignment: .bottom) { Hairline() }
  }

  private func summary(_ recipe: Recipe) -> some View {
    let settings = recipe.settings
    var parts = [settings.film.title]
    if settings.exposure != 0 { parts.append(String(format: "Exposure %+.2f", settings.exposure)) }
    if settings.contrast != 1 {
      parts.append(String(format: "Contrast %+.0f", (settings.contrast - 1) * 100))
    }
    if settings.warmth != 0 { parts.append(String(format: "Warmth %+.0f", settings.warmth * 100)) }
    return Text(parts.joined(separator: " · "))
      .font(TypeStyle.caption).foregroundStyle(Palette.muted).monospacedDigit()
      .fixedSize(horizontal: false, vertical: true)
  }
}
