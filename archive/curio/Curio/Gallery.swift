import SwiftUI

struct CollectionGallery: View {
  @EnvironmentObject private var museum: MuseumStore
  @Environment(\.dismiss) private var dismiss
  var collectionID: UUID
  @State private var addObject = false
  @State private var editCollection = false
  @State private var confirmDelete = false

  var body: some View {
    if let collection = museum.collection(collectionID) {
      ObjectBrowser(
        title: collection.title, collectionID: collectionID, subtitle: collection.subtitle
      )
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button("Edit collection", systemImage: "pencil") { editCollection = true }
            Button("Delete collection", systemImage: "trash", role: .destructive) {
              confirmDelete = true
            }
          } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: 44)
          }.accessibilityLabel("Collection options")
        }
      }
      .safeAreaInset(edge: .bottom) {
        Button {
          addObject = true
        } label: {
          Label("Add an object", systemImage: "plus")
        }.buttonStyle(MuseumButton()).padding(.horizontal, 25).padding(.vertical, 12)
          .background(MuseumStyle.paper)
      }
      .sheet(isPresented: $addObject) { ObjectEditor(collectionID: collectionID) }
      .sheet(isPresented: $editCollection) { CollectionEditor(existing: collection) }
      .confirmationDialog(
        "Delete “\(collection.title)”?", isPresented: $confirmDelete, titleVisibility: .visible
      ) {
        Button(
          "Delete collection and \(museum.query(collectionID: collectionID).count) objects",
          role: .destructive
        ) {
          if museum.deleteCollection(collectionID) { dismiss() }
        }
      } message: {
        Text("This cannot be undone. Export any labels you want to keep first.")
      }
    }
  }
}

struct ObjectBrowser: View {
  @EnvironmentObject private var museum: MuseumStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  var title: String
  var collectionID: UUID? = nil
  var subtitle: String = ""
  var favoritesOnly = false
  var showClose = false
  @State private var search = ""
  @State private var selectedTag: String?
  @State private var favoriteFilter = false
  @AppStorage("curio.detailCards") private var detailed = false

  private var items: [MuseumObject] {
    museum.query(
      collectionID: collectionID, text: search, tag: selectedTag,
      favorites: favoritesOnly || favoriteFilter)
  }
  private var tags: [String] {
    Array(Set(museum.query(collectionID: collectionID, favorites: favoritesOnly).flatMap(\.tags)))
      .sorted()
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 8) {
          Eyebrow(
            text: collectionID.flatMap { museum.collection($0) }?.isSample == true
              ? "Sample exhibition · No. 01" : "Your private exhibition", color: MuseumStyle.cobalt)
          Text(title).font(MuseumStyle.serif(34)).tracking(-1)
            .fixedSize(horizontal: false, vertical: true)
          if !subtitle.isEmpty {
            Text(subtitle).font(.subheadline).foregroundStyle(MuseumStyle.muted)
          }
        }
        HStack(spacing: 9) {
          Image(systemName: "magnifyingglass").foregroundStyle(MuseumStyle.muted)
          TextField("Search objects, stories, tags", text: $search)
            .font(.subheadline).autocorrectionDisabled()
            .accessibilityIdentifier("objectSearch")
          if !search.isEmpty {
            Button {
              search = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
            }
            .accessibilityLabel("Clear search").frame(minWidth: 32, minHeight: 32)
          }
        }.padding(.horizontal, 13).frame(minHeight: 49)
          .background(.white.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 6))
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            filterChip("All objects", selected: selectedTag == nil && !favoriteFilter) {
              selectedTag = nil
              favoriteFilter = false
            }
            if !favoritesOnly {
              filterChip("Favorites", selected: favoriteFilter, icon: "heart") {
                favoriteFilter.toggle()
              }
            }
            ForEach(tags, id: \.self) { tag in
              filterChip(tag, selected: tag == selectedTag) {
                selectedTag = selectedTag == tag ? nil : tag
              }
            }
          }
        }
        HStack {
          Eyebrow(text: "\(items.count) \(items.count == 1 ? "object" : "objects") on view")
          Spacer()
          Button {
            detailed.toggle()
          } label: {
            Image(systemName: detailed ? "square.grid.2x2" : "rectangle.grid.1x2").frame(
              width: 44, height: 44)
          }
          .accessibilityLabel(detailed ? "Switch to gallery view" : "Switch to detailed cards")
        }
        if items.isEmpty {
          VStack(spacing: 14) {
            Text(
              search.isEmpty && selectedTag == nil && !favoriteFilter
                ? "Space for something special." : "Nothing on view. Yet."
            )
            .font(MuseumStyle.serif(29)).multilineTextAlignment(.center)
            Text(
              search.isEmpty && selectedTag == nil && !favoriteFilter
                ? "Add an object and give its story a home."
                : "Try another search or clear your filters."
            )
            .font(.subheadline).foregroundStyle(MuseumStyle.muted).multilineTextAlignment(.center)
            if !search.isEmpty || selectedTag != nil || favoriteFilter {
              Button("Clear search & filters") {
                search = ""
                selectedTag = nil
                favoriteFilter = false
              }
              .buttonStyle(MuseumButton(filled: false))
            }
          }.padding(.vertical, 44).frame(maxWidth: .infinity)
        } else {
          LazyVGrid(
            columns: Array(
              repeating: GridItem(.flexible(), spacing: 18),
              count: detailed || typeSize.isAccessibilitySize ? 1 : 2), alignment: .leading,
            spacing: 27
          ) {
            ForEach(items) { object in
              NavigationLink {
                ObjectDetail(objectID: object.id)
              } label: {
                ObjectTile(object: object, detailed: detailed || typeSize.isAccessibilitySize)
              }.buttonStyle(.plain)
            }
          }
        }
      }.padding(.horizontal, 25).padding(.top, 9).padding(.bottom, 30)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(MuseumStyle.paper).foregroundStyle(MuseumStyle.ink)
    .toolbar(.visible, for: .navigationBar)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(MuseumStyle.paper, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarColorScheme(.light, for: .navigationBar)
    .toolbar {
      ToolbarItem(placement: .principal) {
        HStack(spacing: 7) {
          BrandMark()
          Text("Curio").font(MuseumStyle.serif(20))
        }
      }
      if showClose { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }

  private func filterChip(
    _ title: String, selected: Bool, icon: String? = nil, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 5) {
        if let icon { Image(systemName: icon) }
        Text(title)
      }.font(.caption.weight(.medium)).padding(.horizontal, 14).frame(minHeight: 44)
        .background(selected ? MuseumStyle.ink : MuseumStyle.stone.opacity(0.45))
        .foregroundStyle(selected ? MuseumStyle.paper : MuseumStyle.ink)
        .clipShape(Capsule())
    }.accessibilityAddTraits(selected ? .isSelected : [])
  }
}

struct ObjectTile: View {
  var object: MuseumObject
  var detailed: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ZStack(alignment: .topTrailing) {
        ExhibitArtwork(artifact: object.artifact, photo: object.photo)
          .frame(height: detailed ? 260 : 170)
          .background(MuseumStyle.stone.opacity(0.42))
        if object.isFavorite {
          Image(systemName: "heart.fill").font(.caption)
            .foregroundStyle(MuseumStyle.cobalt).padding(11)
        }
      }
      HStack {
        Eyebrow(text: String(format: "OBJ / %03d", object.catalogNumber))
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(
          MuseumStyle.muted)
      }
      Text(object.title).font(detailed ? MuseumStyle.serif(28) : .system(.body, design: .serif))
        .fixedSize(horizontal: false, vertical: true)
      Text(object.maker.isEmpty ? "From your collection" : object.maker)
        .font(.footnote).foregroundStyle(MuseumStyle.muted)
        .fixedSize(horizontal: false, vertical: true)
      if detailed {
        Text(object.story).font(.subheadline).foregroundStyle(MuseumStyle.muted).lineLimit(3)
          .padding(.top, 4)
      }
    }.accessibilityElement(children: .combine)
      .accessibilityLabel(
        "\(object.title), object \(object.catalogNumber)\(object.isFavorite ? ", favorite" : ""), \(object.maker)"
      )
  }
}
