import SwiftUI

@main
struct FieldnotesApp: App {
  @State private var store = JournalStore()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(store)
        .tint(FieldStyle.ink)
        .preferredColorScheme(.light)
    }
  }
}

struct RootView: View {
  @Environment(JournalStore.self) private var store
  @State private var tab = 0

  var body: some View {
    TabView(selection: $tab) {
      JournalView(openCollection: { tab = 2 })
        .tabItem { Label("Journal", systemImage: "book.closed") }.tag(0)
      GuideView()
        .tabItem { Label("Field guide", systemImage: "leaf") }.tag(1)
      CollectionView()
        .tabItem { Label("Collection", systemImage: "square.grid.2x2") }.tag(2)
    }
    .alert(
      "Journal needs attention",
      isPresented: Binding(
        get: { store.storageError != nil }, set: { if !$0 { store.storageError = nil } }
      )
    ) {
      Button("OK") { store.storageError = nil }
    } message: {
      Text(store.storageError ?? "")
    }
  }
}

struct Eyebrow: View {
  let text: String
  var body: some View {
    Text(text.uppercased()).font(.system(.caption, design: .monospaced))
      .tracking(2).foregroundStyle(FieldStyle.rust)
  }
}

struct EditorialHeading: View {
  let text: String
  @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 36

  init(_ text: String, size: CGFloat) {
    self.text = text
    _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
  }

  var body: some View {
    Text(text).font(FieldStyle.serif(size))
      .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
  }
}

struct JournalView: View {
  @Environment(JournalStore.self) private var store
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var adding = false
  @State private var about = false
  let openCollection: () -> Void

  var body: some View {
    NavigationStack {
      ZStack {
        Paper()
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Eyebrow(text: "A pocket naturalist’s journal")
              Spacer(minLength: 0)
              Button {
                about = true
              } label: {
                Image(systemName: "info.circle").frame(width: 44, height: 44)
              }
              .accessibilityLabel("About your journal")
            }
            VStack(alignment: .leading, spacing: 8) {
              EditorialHeading("Fieldnotes", size: 44)
              if typeSize.isAccessibilitySize { recordButton }
              Text("There is a whole world\nin the little things.")
                .font(.system(.title3, design: .serif)).foregroundStyle(FieldStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            NavigationLink {
              GuideDetail(subject: GuideSubject.all[0])
            } label: {
              VStack(spacing: 0) {
                HStack {
                  Eyebrow(text: "The art of noticing")
                  Spacer()
                  Text("PL. 01").font(.system(.caption2, design: .monospaced))
                }.padding(18)
                SpecimenArt(kind: "fern").frame(height: 166)
                HStack(alignment: .bottom) {
                  VStack(alignment: .leading, spacing: 5) {
                    Text("A quiet unfurling").font(.system(.title2, design: .serif))
                    Text("Lady fern · Athyrium filix-femina")
                      .font(.system(.caption, design: .serif)).italic()
                  }
                  Spacer()
                  Image(systemName: "arrow.up.right").font(.title3)
                }.padding(18)
              }.background(FieldStyle.wash.opacity(0.5))
                .overlay(Rectangle().stroke(FieldStyle.rule, lineWidth: 0.7))
            }.buttonStyle(.plain).accessibilityLabel("Explore lady fern in the field guide")
            if !typeSize.isAccessibilitySize { recordButton }
            ViewThatFits(in: .horizontal) {
              HStack {
                Text("From your notebook").font(.system(.title2, design: .serif))
                Spacer()
                Button("View all", action: openCollection).font(.subheadline).frame(minHeight: 44)
              }
              VStack(alignment: .leading, spacing: 8) {
                Text("From your notebook").font(.system(.title2, design: .serif))
                Button("View all", action: openCollection).font(.subheadline).frame(minHeight: 44)
              }
            }
            if store.entries.isEmpty {
              EmptyJournal(
                title: "Your first page awaits",
                message: "A leaf, a bird, a moment outside.\nStart with whatever catches your eye.")
            } else {
              ForEach(store.entries.prefix(3)) { entry in
                NavigationLink {
                  ObservationDetail(id: entry.id)
                } label: {
                  ObservationRow(entry: entry)
                }.buttonStyle(.plain)
              }
            }
            Text("LOOK CLOSELY. TREAD LIGHTLY.")
              .font(.system(.caption2, design: .monospaced)).tracking(2)
              .foregroundStyle(FieldStyle.muted).frame(maxWidth: .infinity).padding(.vertical, 10)
          }.padding(.horizontal, 24).padding(.bottom, 24)
        }.clipped()
      }.foregroundStyle(FieldStyle.ink)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $adding) { ObservationEditor() }
        .sheet(isPresented: $about) { AboutView() }
    }
  }

  private var recordButton: some View {
    Button {
      adding = true
    } label: {
      Label("Record an observation", systemImage: "plus")
        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 18)
        .background(FieldStyle.ink).foregroundStyle(FieldStyle.paper)
    }.buttonStyle(.plain)
  }
}

struct ObservationRow: View {
  let entry: ObservationEntry
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    VStack(spacing: 16) {
      let layout =
        typeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
        : AnyLayout(HStackLayout(spacing: 16))
      layout {
        EntryImage(entry: entry)
          .frame(
            width: typeSize.isAccessibilitySize ? 120 : 86,
            height: typeSize.isAccessibilitySize ? 120 : 98
          ).clipped()
          .background(FieldStyle.wash.opacity(0.6))
        VStack(alignment: .leading, spacing: 7) {
          HStack {
            Eyebrow(text: entry.category.rawValue)
            if entry.isFavorite {
              Image(systemName: "heart.fill").font(.caption).foregroundStyle(FieldStyle.rust)
                .accessibilityLabel("Favorite")
            }
          }
          Text(entry.title).font(.system(.title3, design: .serif)).multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
          Text(
            entry.isSample
              ? "SAMPLE OBSERVATION" : entry.date.formatted(date: .abbreviated, time: .omitted)
          )
          .font(.caption2).foregroundStyle(FieldStyle.muted)
        }
        if !typeSize.isAccessibilitySize {
          Spacer(minLength: 0)
          Image(systemName: "chevron.right").font(.caption)
        }
      }
      Rectangle().fill(FieldStyle.rule).frame(height: 0.5)
    }.accessibilityElement(children: .combine)
  }
}

struct EntryImage: View {
  let entry: ObservationEntry
  var body: some View {
    if let data = entry.photo, let image = UIImage(data: data) {
      Image(uiImage: image).resizable().scaledToFill()
        .accessibilityLabel("Observation photo")
    } else {
      SpecimenArt(kind: entry.guideID ?? defaultArt)
    }
  }
  private var defaultArt: String {
    switch entry.category {
    case .plants: "fern"
    case .birds: "robin"
    case .insects: "butterfly"
    case .fungi: "mushroom"
    case .other: "snail"
    }
  }
}

struct EmptyJournal: View {
  let title: String
  let message: String
  var body: some View {
    VStack(spacing: 12) {
      SpecimenArt(kind: "daisy").frame(height: 130)
      Text(title).font(.system(.title2, design: .serif))
      Text(message).font(.body).foregroundStyle(FieldStyle.muted).multilineTextAlignment(.center)
    }.frame(maxWidth: .infinity).padding(.vertical, 24)
  }
}

struct CollectionView: View {
  @Environment(JournalStore.self) private var store
  @State private var query = ""
  @State private var category: SpecimenCategory?
  @State private var favorites = false
  @State private var adding = false

  private var filtered: [ObservationEntry] {
    store.entries.filter { $0.matches(query: query, category: category, favoritesOnly: favorites) }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Paper()
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            Eyebrow(text: "Collected with curiosity")
            HStack {
              EditorialHeading("Collection", size: 38)
              Spacer()
              Button {
                adding = true
              } label: {
                Image(systemName: "plus").frame(width: 44, height: 44).background(
                  FieldStyle.wash, in: Circle())
              }
              .accessibilityLabel("Add observation")
            }
            HStack {
              Image(systemName: "magnifyingglass")
              TextField(
                "Search notes, places, tags", text: $query,
                prompt: Text("Search notes, places, tags").foregroundStyle(FieldStyle.muted)
              )
              .autocorrectionDisabled()
              if !query.isEmpty {
                Button {
                  query = ""
                } label: {
                  Image(systemName: "xmark.circle.fill").frame(minWidth: 32, minHeight: 44)
                }
                .accessibilityLabel("Clear search")
              }
            }.padding(.horizontal, 14).frame(minHeight: 50).background(.white.opacity(0.55))
              .overlay(Rectangle().stroke(FieldStyle.rule, lineWidth: 0.5))
            CategoryFilter(selection: $category)
            HStack {
              Text("\(filtered.count) \(filtered.count == 1 ? "observation" : "observations")")
                .font(.subheadline).foregroundStyle(FieldStyle.muted)
              Spacer()
              Button {
                favorites.toggle()
              } label: {
                Label("Favorites", systemImage: favorites ? "heart.fill" : "heart")
                  .font(.subheadline).padding(.vertical, 10)
              }.foregroundStyle(favorites ? FieldStyle.rust : FieldStyle.ink)
                .accessibilityAddTraits(favorites ? .isSelected : [])
            }
            if filtered.isEmpty {
              EmptyJournal(
                title: store.entries.isEmpty ? "Nothing collected. Yet." : "No observations found",
                message: store.entries.isEmpty
                  ? "Record your first discovery with the + above."
                  : "Try another word or let your\ncollection roam beyond these filters.")
              if category != nil || favorites || !query.isEmpty {
                Button("Clear all filters") {
                  query = ""
                  category = nil
                  favorites = false
                }
                .frame(maxWidth: .infinity, minHeight: 44)
              }
            } else {
              LazyVStack(spacing: 20) {
                ForEach(filtered) { entry in
                  NavigationLink {
                    ObservationDetail(id: entry.id)
                  } label: {
                    ObservationRow(entry: entry)
                  }
                  .buttonStyle(.plain)
                }
              }
            }
          }.padding(24)
        }.scrollDismissesKeyboard(.interactively).clipped()
      }.foregroundStyle(FieldStyle.ink)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $adding) { ObservationEditor() }
    }
  }
}

struct FilterChip: View {
  let text: String
  let selected: Bool
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Text(text).font(.subheadline).padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44)
        .foregroundStyle(selected ? FieldStyle.paper : FieldStyle.ink)
        .background(selected ? FieldStyle.ink : FieldStyle.wash.opacity(0.6), in: Capsule())
    }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
  }
}

struct CategoryFilter: View {
  @Binding var selection: SpecimenCategory?
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    LazyVGrid(
      columns: Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: typeSize.isAccessibilitySize ? 2 : 3), spacing: 8
    ) {
      FilterChip(text: "All", selected: selection == nil) { selection = nil }
      ForEach(SpecimenCategory.allCases) { item in
        FilterChip(text: item.rawValue, selected: selection == item) { selection = item }
      }
    }.accessibilityElement(children: .contain).accessibilityLabel("Category filters")
  }
}

struct GuideView: View {
  @State private var category: SpecimenCategory?
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    NavigationStack {
      ZStack {
        Paper()
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            Eyebrow(text: "Twelve familiar wonders")
            EditorialHeading("The field guide", size: 38)
            Text("A little knowledge.\nA deeper kind of looking.")
              .font(.system(.title3, design: .serif)).foregroundStyle(FieldStyle.muted)
            CategoryFilter(selection: $category)
            LazyVGrid(
              columns: Array(
                repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
                count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 26
            ) {
              ForEach(GuideSubject.all.filter { category == nil || $0.category == category }) {
                subject in
                NavigationLink {
                  GuideDetail(subject: subject)
                } label: {
                  VStack(alignment: .leading, spacing: 8) {
                    SpecimenArt(kind: subject.id).frame(height: 172)
                      .frame(maxWidth: .infinity).background(FieldStyle.wash.opacity(0.5))
                    Eyebrow(text: subject.category.rawValue)
                    Text(subject.name).font(.system(.title3, design: .serif))
                      .multilineTextAlignment(.leading)
                      .lineLimit(2, reservesSpace: !typeSize.isAccessibilitySize)
                      .fixedSize(horizontal: false, vertical: true)
                    Text(subject.latin).font(.system(.caption, design: .serif)).italic()
                      .foregroundStyle(FieldStyle.muted).multilineTextAlignment(.leading)
                  }.frame(maxWidth: .infinity, alignment: .topLeading)
                }.buttonStyle(.plain)
              }
            }
            Text(
              "An offline companion for observation, not definitive identification. Illustrations are stylized. Never eat or handle a species based on this guide."
            )
            .font(.footnote).foregroundStyle(FieldStyle.muted).padding(.top, 8)
          }.padding(24)
        }.clipped()
      }.foregroundStyle(FieldStyle.ink).toolbar(.hidden, for: .navigationBar)
    }
  }
}

struct GuideDetail: View {
  let subject: GuideSubject
  @State private var observing = false
  var body: some View {
    ZStack {
      Paper()
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HStack {
            Eyebrow(text: subject.category.rawValue)
            Spacer()
            Text(
              "FIELD GUIDE / \(String(format: "%02d", (GuideSubject.all.firstIndex { $0.id == subject.id } ?? 0) + 1))"
            )
            .font(.system(.caption2, design: .monospaced)).foregroundStyle(FieldStyle.muted)
          }
          SpecimenArt(kind: subject.id).frame(height: 280).frame(maxWidth: .infinity)
            .background(FieldStyle.wash.opacity(0.5))
          VStack(alignment: .leading, spacing: 8) {
            EditorialHeading(subject.name, size: 36)
            Text(subject.latin).font(.system(.title3, design: .serif)).italic().foregroundStyle(
              FieldStyle.muted)
          }
          detailSection("Look for", subject.marks)
          detailSection("Where to wander", "\(subject.habitat)\n\n\(subject.range).")
          VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "A moment of attention")
            Text(subject.invitation).font(.system(.title3, design: .serif)).lineSpacing(4)
          }.padding(22).frame(maxWidth: .infinity, alignment: .leading).background(FieldStyle.wash)
          if subject.category == .fungi {
            Label(
              "Observe only. Never use this guide to decide whether a mushroom is safe to eat.",
              systemImage: "exclamationmark.triangle"
            )
            .font(.footnote).foregroundStyle(FieldStyle.rust)
          }
          Text("Stylized illustration · Offline field guide").font(.caption).foregroundStyle(
            FieldStyle.muted)
        }.padding(24)
      }
    }.foregroundStyle(FieldStyle.ink).navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(FieldStyle.paper, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .safeAreaInset(edge: .bottom) {
        Button {
          observing = true
        } label: {
          Label("I noticed this", systemImage: "plus").font(.headline)
            .frame(maxWidth: .infinity).padding(18).background(FieldStyle.ink)
            .foregroundStyle(FieldStyle.paper)
        }.buttonStyle(.plain).padding(.horizontal, 24).padding(.vertical, 12)
          .background(FieldStyle.paper)
      }
      .sheet(isPresented: $observing) {
        ObservationEditor(
          initial: ObservationEntry(
            title: subject.name, category: subject.category, guideID: subject.id))
      }
  }

  private func detailSection(_ title: String, _ text: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Eyebrow(text: title)
      Text(text).font(.body).lineSpacing(5)
    }
  }
}

struct ObservationDetail: View {
  @Environment(JournalStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let id: UUID
  @State private var editing = false
  @State private var deleting = false
  @State private var error: String?
  @State private var favoriteFeedback = 0
  private var entry: ObservationEntry? { store.entries.first { $0.id == id } }

  var body: some View {
    ZStack {
      Paper()
      if let entry {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            HStack {
              Eyebrow(text: entry.category.rawValue)
              Spacer()
              Button {
                do {
                  try store.toggleFavorite(id)
                  favoriteFeedback += 1
                } catch { self.error = error.localizedDescription }
              } label: {
                Image(systemName: entry.isFavorite ? "heart.fill" : "heart").font(.title3)
                  .foregroundStyle(FieldStyle.rust).frame(width: 44, height: 44)
              }.accessibilityLabel(entry.isFavorite ? "Remove from favorites" : "Add to favorites")
            }
            if let data = entry.photo, let image = UIImage(data: data) {
              Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity)
                .background(FieldStyle.wash.opacity(0.55))
                .accessibilityLabel("Full observation photograph")
            } else {
              EntryImage(entry: entry).frame(height: 270).frame(maxWidth: .infinity)
                .background(FieldStyle.wash.opacity(0.55))
            }
            if entry.photo == nil {
              Text("ILLUSTRATION · NOT A PHOTO").font(.system(.caption2, design: .monospaced))
                .foregroundStyle(FieldStyle.muted)
            }
            VStack(alignment: .leading, spacing: 12) {
              if entry.isSample { Eyebrow(text: "Sample observation") }
              EditorialHeading(entry.title, size: 35)
              Text(entry.date.formatted(date: .long, time: .shortened)).font(.subheadline)
                .foregroundStyle(FieldStyle.muted)
              if !entry.location.isEmpty {
                Label(entry.location, systemImage: "mappin").font(.subheadline)
              }
            }
            Rectangle().fill(FieldStyle.rule).frame(height: 0.5)
            if !entry.notes.isEmpty {
              Text(entry.notes).font(.system(.title3, design: .serif)).lineSpacing(7)
            } else {
              Text("No notes yet. Edit this observation to add what caught your eye.")
                .font(.body).foregroundStyle(FieldStyle.muted)
            }
            if !entry.tags.isEmpty {
              Text(entry.tags.map { "#\($0)" }.joined(separator: "   "))
                .font(.subheadline).foregroundStyle(FieldStyle.rust).lineSpacing(8)
            }
            if let subject = GuideSubject.find(entry.guideID) {
              NavigationLink {
                GuideDetail(subject: subject)
              } label: {
                HStack {
                  VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "From the field guide")
                    Text(subject.name).font(.system(.title3, design: .serif))
                  }
                  Spacer()
                  Image(systemName: "arrow.up.right")
                }.padding(20).background(FieldStyle.wash)
              }.buttonStyle(.plain)
            }
            Button(role: .destructive) {
              deleting = true
            } label: {
              Label("Delete observation", systemImage: "trash").font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 48)
            }.padding(.top, 16)
          }.padding(24)
        }
      }
    }.foregroundStyle(FieldStyle.ink).navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(FieldStyle.paper, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } } }
      .sensoryFeedback(.selection, trigger: favoriteFeedback)
      .sheet(isPresented: $editing) {
        if let entry { ObservationEditor(initial: entry, isEditing: true) }
      }
      .confirmationDialog(
        "Delete this observation?", isPresented: $deleting, titleVisibility: .visible
      ) {
        Button("Delete observation", role: .destructive) {
          do {
            try store.delete(id)
            dismiss()
          } catch { self.error = error.localizedDescription }
        }
      } message: {
        Text("This removes the notes and photo from this device. It cannot be undone.")
      }
      .alert(
        "Couldn’t save your change",
        isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
      ) {
        Button("OK") { error = nil }
      } message: {
        Text(error ?? "")
      }
  }
}

struct AboutView: View {
  @Environment(JournalStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var confirming = false
  @State private var error: String?
  var body: some View {
    NavigationStack {
      ZStack {
        Paper()
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            SpecimenArt(kind: "daisy").frame(height: 170).frame(maxWidth: .infinity)
            EditorialHeading("Keep a little wonder.", size: 34)
            Text(
              "Fieldnotes is a quiet place for the things you notice outside. Your notes and imported photos stay in this app on this device. There are no accounts, identification services or location tracking."
            )
            .lineSpacing(5)
            Eyebrow(text: "A few things to know")
            Text(
              "The three first-launch observations are labeled samples. You can edit or delete them like any entry. Your own observations never need a species name—“an unfamiliar leaf” is a perfect place to start."
            )
            .lineSpacing(5)
            Text(
              "The guide includes common subjects from different regions. It is an invitation to look, not a definitive identification tool. Never forage from this guide."
            )
            .font(.footnote).foregroundStyle(FieldStyle.muted)
            if store.entries.contains(where: \.isSample) {
              Button("Remove sample observations", role: .destructive) { confirming = true }
                .frame(minHeight: 44)
            }
            Text("Made for slower walks.\nFIELDNOTES · VOLUME 01")
              .font(.system(.caption, design: .monospaced)).foregroundStyle(FieldStyle.muted)
          }.padding(24)
        }
      }.foregroundStyle(FieldStyle.ink)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .confirmationDialog(
          "Remove all sample observations?", isPresented: $confirming, titleVisibility: .visible
        ) {
          Button("Remove samples", role: .destructive) {
            do { try store.removeSamples() } catch { self.error = error.localizedDescription }
          }
        } message: {
          Text("Your own observations will be kept.")
        }
        .alert(
          "Couldn’t remove samples",
          isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
        ) {
          Button("OK") { error = nil }
        } message: {
          Text(error ?? "")
        }
    }
  }
}
