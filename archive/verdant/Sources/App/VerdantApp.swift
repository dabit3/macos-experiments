import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor @Observable
final class GardenStore {
  var garden: Garden
  var error: String?
  private let url: URL
  private var canSave = true

  init() {
    url = URL.documentsDirectory.appending(path: "Verdant/garden.json")
    if FileManager.default.fileExists(atPath: url.path) {
      do {
        garden = try Garden.load(from: url)
      } catch {
        garden = .sample()
        self.error = GardenError.invalidFile.localizedDescription
        canSave = false
      }
    } else {
      garden = .sample()
      do { try garden.save(to: url) } catch { self.error = error.localizedDescription }
    }
  }

  @discardableResult
  func perform(_ change: (inout Garden) throws -> Void) -> Bool {
    guard canSave else {
      error = GardenError.invalidFile.localizedDescription
      return false
    }
    do {
      var updated = garden
      try change(&updated)
      try updated.save(to: url)
      withAnimation(.easeInOut(duration: 0.25)) { garden = updated }
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }

  func export() -> URL? {
    let destination = URL.documentsDirectory.appending(path: "Verdant/verdant-journal.md")
    do {
      try garden.markdown().write(to: destination, atomically: true, encoding: .utf8)
      return destination
    } catch {
      self.error = error.localizedDescription
      return nil
    }
  }
}

@main
struct VerdantApp: App {
  @State private var store = GardenStore()
  var body: some Scene {
    WindowGroup {
      GardenHome(store: store)
        .preferredColorScheme(.light)
        .tint(Palette.ink)
        .alert(
          "Your garden is safe",
          isPresented: Binding(
            get: { store.error != nil }, set: { if !$0 { store.error = nil } }
          )
        ) {
          Button("OK", role: .cancel) { store.error = nil }
        } message: {
          Text(store.error ?? "")
        }
    }
  }
}

private enum GardenTab: String, CaseIterable {
  case garden = "My garden"
  case care = "Care"
  case journal = "Journal"
  var symbol: String {
    switch self {
    case .garden: "leaf"
    case .care: "drop"
    case .journal: "book.closed"
    }
  }
}

private struct JournalExport: Identifiable {
  let id = UUID()
  let url: URL
}

struct GardenHome: View {
  @Bindable var store: GardenStore
  @State private var tab: GardenTab = .garden
  @State private var filter = "All plants"
  @State private var showAdd = false
  @State private var search = ""
  @State private var journalExport: JournalExport?
  private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

  var body: some View {
    NavigationStack {
      TimelineView(.periodic(from: .now, by: 60)) { context in
        let due = store.garden.plants.filter { $0.daysUntilDue(at: context.date) <= 0 }
        ScrollView {
          VStack(alignment: .leading, spacing: 25) {
            header
            if tab == .garden {
              gardenContent(now: context.date, due: due)
            } else if tab == .care {
              careContent(now: context.date, due: due)
            } else {
              journalContent
            }
          }
          .padding(.horizontal, 24)
          .padding(.top, 12)
          .padding(.bottom, 22)
        }
        .background(Palette.paper)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          VStack(spacing: 0) {
            if let undo = store.garden.undo {
              UndoBar(label: undo.label) { store.perform { $0.undoLastChange() } }
                .padding(.horizontal, 16).padding(.bottom, 8)
            }
            HStack(spacing: 0) {
              ForEach(GardenTab.allCases, id: \.self) { item in
                Button {
                  withAnimation(.easeInOut(duration: 0.2)) { tab = item }
                } label: {
                  VStack(spacing: 5) {
                    ZStack(alignment: .topTrailing) {
                      Image(systemName: item.symbol)
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 38, height: 26)
                      if item == .care && !due.isEmpty {
                        Circle().fill(Palette.gold).frame(width: 6, height: 6)
                      }
                    }
                    Text(item.rawValue).font(.system(size: 10, weight: .semibold))
                  }
                  .foregroundStyle(tab == item ? Palette.ink : Palette.secondary.opacity(0.8))
                  .frame(maxWidth: .infinity)
                  .padding(.top, 12).padding(.bottom, 8)
                  .background(alignment: .top) {
                    if tab == item {
                      Capsule().fill(Palette.ink).frame(width: 26, height: 2)
                    }
                  }
                }
                .accessibilityIdentifier("tab-\(item.rawValue)")
              }
            }
            .background(Palette.paper.shadow(color: .black.opacity(0.04), radius: 8, y: -3))
          }
          .background(Palette.paper.opacity(0.96))
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: UUID.self) { id in
        PlantDetail(store: store, plantID: id)
      }
      .sheet(isPresented: $showAdd) { PlantEditor(store: store, plant: nil) }
      .sheet(item: $journalExport) { export in
        ShareSheet(items: [export.url])
      }
    }
    .overlay(alignment: .top) {
      GeometryReader { geometry in
        Palette.paper
          .frame(height: geometry.safeAreaInsets.top)
          .offset(y: -geometry.safeAreaInsets.top)
      }
      .allowsHitTesting(false)
    }
  }

  private var header: some View {
    HStack {
      HStack(spacing: 7) {
        Image(systemName: "leaf.fill").font(.system(size: 14))
        Text("VERDANT").font(.system(size: 14, weight: .semibold, design: .serif)).tracking(3.5)
      }
      Spacer()
      Text("GROW SLOWLY").font(.system(size: 8, weight: .medium)).tracking(1.5)
        .foregroundStyle(Palette.secondary)
      Button {
        showAdd = true
      } label: {
        Image(systemName: "plus").font(.system(size: 18))
          .frame(width: 42, height: 42)
          .background(Palette.sage, in: Circle())
      }
      .accessibilityLabel("Add a plant").accessibilityIdentifier("add-plant")
      .padding(.leading, 5)
    }
    .foregroundStyle(Palette.ink)
  }

  @ViewBuilder
  private func gardenContent(now: Date, due: [Plant]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      eyebrow("YOUR PERSONAL CONSERVATORY")
      Text("A little care.\nA lot of growth.")
        .font(.system(size: 38, weight: .regular, design: .serif))
        .tracking(-1.2).lineSpacing(-3).foregroundStyle(Palette.ink)
    }
    Button {
      withAnimation { tab = .care }
    } label: {
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 23).fill(Palette.sage)
        Circle().fill(Color.white.opacity(0.22)).frame(width: 180)
          .offset(x: 195, y: -37)
        HStack(spacing: 0) {
          VStack(alignment: .leading, spacing: 10) {
            Label("THE DAILY RITUAL", systemImage: "sun.max")
              .font(.system(size: 8, weight: .semibold)).tracking(1)
            Text(
              due.isEmpty
                ? "All is\nwell."
                : "\(due.count) \(due.count == 1 ? "plant" : "plants"),\na little thirsty."
            )
            .font(.system(size: 25, design: .serif)).tracking(-0.5)
            .multilineTextAlignment(.leading)
            HStack(spacing: 8) {
              Text(due.isEmpty ? "Enjoy your garden" : "Tend your garden")
                .font(.system(size: 10, weight: .semibold))
              Image(systemName: "arrow.up.right").font(.system(size: 10))
            }
            .padding(.top, 4)
          }
          .padding(.leading, 22).frame(maxWidth: .infinity, alignment: .leading)
          BotanicalArt(specimen: .monstera)
            .frame(width: 185, height: 216).padding(.trailing, -10)
        }
      }
      .frame(height: 198).clipped().clipShape(RoundedRectangle(cornerRadius: 23))
      .foregroundStyle(Palette.ink)
    }
    .buttonStyle(.plain).accessibilityLabel("Tend your garden, \(due.count) plants due")
    VStack(spacing: 17) {
      HStack(alignment: .firstTextBaseline) {
        Text("The collection").font(.system(size: 25, design: .serif)).tracking(-0.5)
        Spacer()
        Text("\(store.garden.plants.count) PLANTS").font(.system(size: 9, weight: .medium))
          .tracking(1.5)
          .foregroundStyle(Palette.secondary)
      }
      HStack(spacing: 8) {
        ForEach(["All plants", "Needs care", "Bright light"], id: \.self) { name in
          Button {
            withAnimation { filter = name }
          } label: {
            Text(name).font(.system(size: 11, weight: .medium))
              .padding(.horizontal, 14).padding(.vertical, 11)
              .foregroundStyle(filter == name ? Palette.paper : Palette.secondary)
              .background(filter == name ? Palette.ink : Palette.sage.opacity(0.5), in: Capsule())
          }
          .accessibilityIdentifier("filter-\(name)")
        }
        Spacer(minLength: 0)
      }
      HStack {
        Image(systemName: "magnifyingglass").font(.system(size: 12))
        TextField("Find a plant or a room", text: $search)
          .font(.system(size: 12)).accessibilityIdentifier("plant-search")
        if !search.isEmpty {
          Button {
            search = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
          }
          .accessibilityLabel("Clear search")
        }
      }
      .foregroundStyle(Palette.secondary)
      .padding(12).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
      let plants = filteredPlants(now: now)
      if plants.isEmpty {
        EmptyGarden(
          title: "Room to grow",
          subtitle: search.isEmpty
            ? "No plants match this filter. Your garden is doing well."
            : "Try another plant name or room.",
          symbol: "leaf"
        )
      } else {
        LazyVGrid(columns: columns, spacing: 19) {
          ForEach(plants) { plant in
            NavigationLink(value: plant.id) { PlantCard(plant: plant, now: now) }
              .buttonStyle(.plain)
          }
        }
      }
    }
    .foregroundStyle(Palette.ink)
    HStack {
      Rectangle().frame(height: 1).opacity(0.15)
      Text("GOOD THINGS TAKE THYME").font(.system(size: 8)).tracking(1)
        .fixedSize().padding(.horizontal, 8)
      Rectangle().frame(height: 1).opacity(0.15)
    }
    .foregroundStyle(Palette.secondary).padding(.vertical, 10)
  }

  private func filteredPlants(now: Date) -> [Plant] {
    store.garden.plants.filter { plant in
      (filter != "Needs care" || plant.daysUntilDue(at: now) <= 0)
        && (filter != "Bright light" || plant.light == .bright)
        && (search.isEmpty
          || "\(plant.nickname) \(plant.location) \(plant.specimen.name)"
            .localizedCaseInsensitiveContains(search))
    }
  }

  private func careContent(now: Date, due: [Plant]) -> some View {
    VStack(alignment: .leading, spacing: 22) {
      VStack(alignment: .leading, spacing: 8) {
        eyebrow("MAKE A MOMENT OF IT")
        Text("The daily ritual").font(.system(size: 37, design: .serif)).tracking(-1)
        Text("Check the soil. Slow down. Let things grow.")
          .font(.system(size: 13)).foregroundStyle(Palette.secondary)
      }
      HStack(alignment: .firstTextBaseline) {
        Text(due.isEmpty ? "Everything is tended" : "Ready for a drink")
          .font(.system(size: 22, design: .serif))
        Spacer()
        Text("\(due.count) DUE").font(.system(size: 10, weight: .semibold)).tracking(1)
          .foregroundStyle(Palette.gold)
      }
      if due.isEmpty {
        EmptyGarden(
          title: "A happy little jungle",
          subtitle: "All caught up. Come back when the soil is ready.", symbol: "sun.max")
      } else {
        ForEach(due.sorted { $0.dueDate() < $1.dueDate() }) { plant in
          careRow(plant, now: now, canWater: true)
        }
      }
      Text("ON THE HORIZON").font(.system(size: 10, weight: .semibold)).tracking(2)
        .foregroundStyle(Palette.secondary).padding(.top, 12)
      ForEach(
        store.garden.plants.filter { $0.daysUntilDue(at: now) > 0 }.sorted {
          $0.dueDate() < $1.dueDate()
        }
      ) { plant in
        careRow(plant, now: now, canWater: false)
      }
      Text("A schedule is a gentle reminder. Always feel the soil before watering.")
        .font(.system(size: 12)).foregroundStyle(Palette.secondary).lineSpacing(4)
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.sage.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
    }
    .foregroundStyle(Palette.ink)
  }

  private func careRow(_ plant: Plant, now: Date, canWater: Bool) -> some View {
    HStack(spacing: 12) {
      NavigationLink(value: plant.id) {
        HStack(spacing: 10) {
          BotanicalArt(specimen: plant.specimen).frame(width: 71, height: 89)
            .background(Palette.sage.opacity(0.6), in: RoundedRectangle(cornerRadius: 13))
          VStack(alignment: .leading, spacing: 6) {
            Text(plant.nickname).font(.system(size: 17, design: .serif))
              .multilineTextAlignment(.leading)
            Text(plant.location).font(.system(size: 10)).foregroundStyle(Palette.secondary)
            Text(plant.careLabel(at: now)).font(.system(size: 10, weight: .semibold))
              .foregroundStyle(canWater ? Palette.gold : Palette.fern)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
      if canWater {
        Button {
          store.perform { try $0.water(plant.id, at: Date()) }
        } label: {
          Image(systemName: "drop.fill").font(.system(size: 17))
            .foregroundStyle(Palette.paper).frame(width: 44, height: 44)
            .background(Palette.ink, in: Circle())
        }
        .accessibilityLabel("Water \(plant.nickname)")
      } else {
        Image(systemName: "chevron.right").font(.system(size: 10))
          .foregroundStyle(Palette.secondary)
      }
    }
    .padding(12).background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
  }

  private var journalContent: some View {
    VStack(alignment: .leading, spacing: 24) {
      VStack(alignment: .leading, spacing: 8) {
        eyebrow("LITTLE MOMENTS, TAKING ROOT")
        HStack {
          Text("Field notes").font(.system(size: 38, design: .serif)).tracking(-1)
          Spacer()
          Button {
            if let url = store.export() { journalExport = JournalExport(url: url) }
          } label: {
            Image(systemName: "square.and.arrow.up").font(.system(size: 18))
              .frame(width: 44, height: 44).background(Palette.sage, in: Circle())
          }
          .accessibilityLabel("Export garden journal")
        }
        Text("A living record of your growing collection.")
          .font(.system(size: 13)).foregroundStyle(Palette.secondary)
      }
      HStack(spacing: 14) {
        Image(systemName: "book").font(.system(size: 24, weight: .ultraLight))
        VStack(alignment: .leading, spacing: 5) {
          Text("\(store.garden.entries.count) moments of care").font(
            .system(size: 20, design: .serif))
          Text("Open any plant to leave a new observation.").font(.system(size: 11))
            .foregroundStyle(Palette.secondary)
        }
      }
      .padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette.sage, in: RoundedRectangle(cornerRadius: 18))
      ForEach(store.garden.sortedEntries()) { entry in
        if let plant = store.garden.plants.first(where: { $0.id == entry.plantID }) {
          NavigationLink(value: plant.id) {
            TimelineRow(entry: entry, plantName: plant.nickname)
          }.buttonStyle(.plain)
        }
      }
    }
    .foregroundStyle(Palette.ink)
  }
}

struct PlantCard: View {
  let plant: Plant
  let now: Date
  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 19).fill(
          Palette.sage.opacity(plant.specimen == .rubber ? 0.4 : 0.68))
        BotanicalArt(specimen: plant.specimen).padding(.top, 5).padding(.horizontal, 5)
        if plant.daysUntilDue(at: now) <= 0 {
          Circle().fill(Palette.paper).frame(width: 25, height: 25)
            .overlay(
              Image(systemName: "drop.fill").font(.system(size: 10)).foregroundStyle(Palette.gold)
            )
            .padding(10)
        }
      }
      .frame(height: 178)
      Text(plant.nickname).font(.system(size: 18, design: .serif)).lineLimit(2)
      Text(plant.location.uppercased()).font(.system(size: 8, weight: .medium)).tracking(1.2)
        .foregroundStyle(Palette.secondary)
      HStack(spacing: 4) {
        Circle().fill(plant.daysUntilDue(at: now) <= 0 ? Palette.gold : Palette.fern).frame(
          width: 4, height: 4)
        Text(plant.careLabel(at: now)).font(.system(size: 10))
      }
      .foregroundStyle(plant.daysUntilDue(at: now) <= 0 ? Palette.gold : Palette.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .combine)
  }
}

struct PlantDetail: View {
  @Bindable var store: GardenStore
  let plantID: UUID
  @Environment(\.dismiss) private var dismiss
  @State private var showEdit = false
  @State private var showNote = false
  private var plant: Plant? { store.garden.plants.first { $0.id == plantID } }

  var body: some View {
    Group {
      if let plant {
        ScrollView {
          VStack(alignment: .leading, spacing: 23) {
            HStack {
              Button {
                dismiss()
              } label: {
                Image(systemName: "arrow.left").frame(width: 44, height: 44)
                  .background(.white.opacity(0.6), in: Circle())
              }.accessibilityLabel("Back to garden")
              Spacer()
              Text("SPECIMEN STUDY").font(.system(size: 9, weight: .medium)).tracking(2)
              Spacer()
              Button {
                showEdit = true
              } label: {
                Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                  .background(.white.opacity(0.6), in: Circle())
              }.accessibilityLabel("Edit care plan")
            }
            .padding(.horizontal, 24).padding(.top, 10)
            ZStack {
              Circle().fill(Color.white.opacity(0.32)).frame(width: 248, height: 248)
                .offset(x: 40, y: -4)
              Ellipse().fill(Palette.gold.opacity(0.06)).frame(width: 270, height: 70)
                .rotationEffect(.degrees(-22)).offset(x: 70, y: 115)
              BotanicalArt(specimen: plant.specimen).frame(width: 276, height: 323)
            }
            .frame(maxWidth: .infinity).frame(height: 290)
            VStack(alignment: .leading, spacing: 22) {
              VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                  Image(systemName: "mappin").font(.system(size: 9))
                  eyebrow(plant.location.uppercased())
                }
                Text(plant.nickname).font(.system(size: 36, design: .serif)).tracking(-1)
                  .fixedSize(horizontal: false, vertical: true)
                Text(plant.specimen.latin).font(.system(size: 15, design: .serif)).italic()
                  .foregroundStyle(Palette.secondary)
              }
              HStack {
                Label(plant.light.rawValue, systemImage: "sun.max")
                Spacer(minLength: 5)
                Label("Every \(plant.interval) days", systemImage: "drop")
              }
              .font(.system(size: 11)).foregroundStyle(Palette.secondary)
              .padding(.vertical, 15)
              .overlay(alignment: .top) {
                Rectangle().fill(Palette.secondary.opacity(0.2)).frame(height: 0.5)
              }
              .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.secondary.opacity(0.2)).frame(height: 0.5)
              }
              VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                  Text(plant.careLabel(at: Date())).font(.system(size: 23, design: .serif))
                  Spacer()
                  Text("WATERING").font(.system(size: 8, weight: .semibold)).tracking(1.5)
                    .foregroundStyle(Palette.secondary)
                }
                Text(plant.specimen.advice).font(.system(size: 12)).lineSpacing(4)
                  .foregroundStyle(Palette.secondary)
                let watered = Calendar.current.isDateInToday(plant.lastWatered)
                Button {
                  store.perform { try $0.water(plant.id, at: Date()) }
                } label: {
                  Label(
                    watered ? "Watered today" : "Water this plant",
                    systemImage: watered ? "checkmark" : "drop.fill")
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(watered)
                .accessibilityIdentifier("water-plant")
                Text(
                  "Last watered \(plant.lastWatered.formatted(date: .abbreviated, time: .omitted))"
                )
                .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                .frame(maxWidth: .infinity)
              }
              .padding(20).background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 20))
              HStack {
                Text("Growth diary").font(.system(size: 25, design: .serif))
                Spacer()
                Button {
                  showNote = true
                } label: {
                  Label("Add note", systemImage: "plus").font(.system(size: 11, weight: .semibold))
                    .padding(.vertical, 13).padding(.horizontal, 14)
                    .background(Palette.sage, in: Capsule())
                }.accessibilityIdentifier("add-note")
              }
              ForEach(store.garden.sortedEntries(for: plantID)) { entry in
                TimelineRow(entry: entry, plantName: nil)
              }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
          }
        }
        .background(
          LinearGradient(
            colors: [Palette.sage, Palette.paper, Palette.paper], startPoint: .top,
            endPoint: .bottom)
        )
        .safeAreaInset(edge: .bottom) {
          if let undo = store.garden.undo {
            UndoBar(label: undo.label) { store.perform { $0.undoLastChange() } }
              .padding(.horizontal, 20).padding(.bottom, 8)
          }
        }
        .sheet(isPresented: $showEdit) { PlantEditor(store: store, plant: plant) }
        .sheet(isPresented: $showNote) { NoteEditor(store: store, plant: plant) }
      } else {
        VStack(spacing: 20) {
          EmptyGarden(
            title: "Back to your garden", subtitle: "This addition was undone.", symbol: "leaf")
          Button("Return to garden") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }.padding(24).frame(maxHeight: .infinity).background(Palette.paper)
      }
    }
    .foregroundStyle(Palette.ink)
    .toolbar(.hidden, for: .navigationBar)
  }
}

struct PlantEditor: View {
  let store: GardenStore
  let plant: Plant?
  @Environment(\.dismiss) private var dismiss
  @State private var specimen: Specimen = .monstera
  @State private var nickname = ""
  @State private var location = "Living room"
  @State private var light = Light.bright
  @State private var interval = 7
  @State private var lastWatered = Date()
  @State private var initialized = false
  private var valid: Bool {
    (1...40).contains(nickname.trimmingCharacters(in: .whitespacesAndNewlines).count)
      && (1...40).contains(location.trimmingCharacters(in: .whitespacesAndNewlines).count)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 23) {
          SheetHeader(
            kicker: plant == nil ? "A NEW BEGINNING" : "A LITTLE FINE-TUNING",
            title: plant == nil ? "Make room to grow." : "Your care plan."
          ) { dismiss() }
          if plant == nil {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 10) {
                ForEach(Specimen.allCases) { item in
                  Button {
                    specimen = item
                    nickname = item.name
                    light = item.light
                    interval = item.interval
                  } label: {
                    VStack(spacing: 4) {
                      BotanicalArt(specimen: item).frame(width: 108, height: 116)
                      Text(item.name).font(.system(size: 10, weight: .medium))
                    }
                    .frame(width: 122).padding(.vertical, 10)
                    .background(
                      specimen == item ? Palette.sage : .white.opacity(0.7),
                      in: RoundedRectangle(cornerRadius: 18)
                    )
                    .overlay(
                      RoundedRectangle(cornerRadius: 18).stroke(
                        specimen == item ? Palette.fern : .clear, lineWidth: 1))
                  }
                  .accessibilityLabel("Choose \(item.name)")
                }
              }
            }
            .contentMargins(.trailing, 1)
          } else {
            HStack(spacing: 18) {
              BotanicalArt(specimen: specimen).frame(width: 70, height: 90)
              VStack(alignment: .leading, spacing: 5) {
                Text(specimen.name).font(.system(size: 23, design: .serif))
                Text(specimen.latin).font(.system(size: 12, design: .serif)).italic()
                  .foregroundStyle(Palette.secondary)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10).background(Palette.sage, in: RoundedRectangle(cornerRadius: 18))
          }
          editorField("PLANT NAME", text: $nickname, identifier: "plant-name")
          editorField("LOCATION", text: $location, identifier: "plant-location")
          VStack(alignment: .leading, spacing: 10) {
            eyebrow("LIGHT")
            HStack(spacing: 6) {
              ForEach(Light.allCases, id: \.self) { value in
                Button {
                  light = value
                } label: {
                  VStack(spacing: 8) {
                    Image(systemName: value == .low ? "cloud.sun" : "sun.max").font(
                      .system(size: 18))
                    Text(value.rawValue).font(.system(size: 10, weight: .medium))
                  }
                  .frame(maxWidth: .infinity).padding(.vertical, 14)
                  .background(
                    light == value ? Palette.sage : Color.white.opacity(0.7),
                    in: RoundedRectangle(cornerRadius: 12)
                  )
                  .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(
                      light == value ? Palette.fern : .clear, lineWidth: 1))
                }
              }
            }
          }
          VStack(alignment: .leading, spacing: 10) {
            eyebrow("WATERING RHYTHM")
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Every \(interval) days").font(.system(size: 24, design: .serif))
                Text("Adjust with the season").font(.system(size: 11)).foregroundStyle(
                  Palette.secondary)
              }
              Spacer()
              Button {
                interval = max(1, interval - 1)
              } label: {
                Image(systemName: "minus").frame(width: 44, height: 44).background(
                  Palette.sage, in: Circle())
              }.disabled(interval <= 1).accessibilityLabel("Decrease watering interval")
              Button {
                interval = min(60, interval + 1)
              } label: {
                Image(systemName: "plus").frame(width: 44, height: 44).background(
                  Palette.sage, in: Circle())
              }.disabled(interval >= 60).accessibilityLabel("Increase watering interval")
            }
            .padding(15).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
          }
          if plant == nil {
            DatePicker(
              "Last watered", selection: $lastWatered, in: ...Date(), displayedComponents: .date
            )
            .font(.system(size: 13)).tint(Palette.fern)
            Text("Use the last actual watering date to set the first reminder.")
              .font(.system(size: 11)).foregroundStyle(Palette.secondary)
          }
        }
        .padding(24)
      }
      .scrollDismissesKeyboard(.interactively)
      .background(Palette.paper)
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 7) {
          if !valid {
            Text("Name and location are required (up to 40 characters).").font(.system(size: 10))
              .foregroundStyle(Palette.gold)
          }
          Button(plant == nil ? "Add to my garden" : "Save care plan") { save() }
            .buttonStyle(PrimaryButtonStyle()).disabled(!valid)
            .accessibilityIdentifier("save-plant")
        }
        .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 12)
        .background(Palette.paper)
      }
      .toolbar(.hidden, for: .navigationBar)
      .onAppear {
        guard !initialized else { return }
        initialized = true
        if let plant {
          specimen = plant.specimen
          nickname = plant.nickname
          location = plant.location
          light = plant.light
          interval = plant.interval
          lastWatered = plant.lastWatered
        } else {
          nickname = specimen.name
        }
      }
    }
    .foregroundStyle(Palette.ink)
  }

  private func editorField(_ name: String, text: Binding<String>, identifier: String) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      eyebrow(name)
      TextField(name.capitalized, text: text).font(.system(size: 16))
        .padding(16).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 13))
        .accessibilityIdentifier(identifier).autocorrectionDisabled()
    }
  }

  private func save() {
    let now = Date()
    let updated = Plant(
      id: plant?.id ?? UUID(), specimen: specimen,
      nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
      location: location.trimmingCharacters(in: .whitespacesAndNewlines), light: light,
      interval: interval, lastWatered: plant?.lastWatered ?? lastWatered, added: plant?.added ?? now
    )
    if store.perform({ garden in
      if plant == nil {
        try garden.add(updated, at: now)
      } else {
        try garden.edit(updated, at: now)
      }
    }) {
      dismiss()
    }
  }
}

struct NoteEditor: View {
  let store: GardenStore
  let plant: Plant
  @Environment(\.dismiss) private var dismiss
  @State private var text = ""
  var body: some View {
    VStack(alignment: .leading, spacing: 23) {
      SheetHeader(kicker: "NOTICE THE LITTLE THINGS", title: "A moment of growth.") { dismiss() }
      HStack(spacing: 12) {
        BotanicalArt(specimen: plant.specimen).frame(width: 67, height: 86)
        VStack(alignment: .leading, spacing: 5) {
          Text(plant.nickname).font(.system(size: 23, design: .serif))
          Text(Date().formatted(date: .abbreviated, time: .omitted)).font(.system(size: 11))
            .foregroundStyle(Palette.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading).padding(12)
      .background(Palette.sage, in: RoundedRectangle(cornerRadius: 18))
      ZStack(alignment: .topLeading) {
        TextEditor(text: $text).scrollContentBackground(.hidden)
          .padding(10).frame(minHeight: 150, maxHeight: 260)
          .accessibilityIdentifier("note-text")
        if text.isEmpty {
          Text("A new leaf? A sunnier spot?\nWhat did you notice today?")
            .font(.system(size: 16, design: .serif)).lineSpacing(6)
            .foregroundStyle(Palette.secondary.opacity(0.7)).padding(18)
            .allowsHitTesting(false)
        }
      }
      .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 17))
      Text("\(text.count) / 1,000 characters").font(.system(size: 10))
        .foregroundStyle(text.count > 1000 ? Palette.gold : Palette.secondary)
      Spacer(minLength: 0)
      Button("Save to growth diary") {
        if store.perform({ try $0.note(text, for: plant.id, at: Date()) }) { dismiss() }
      }
      .buttonStyle(PrimaryButtonStyle())
      .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 1000)
      .accessibilityIdentifier("save-note")
    }
    .padding(24).background(Palette.paper).foregroundStyle(Palette.ink)
  }
}

struct TimelineRow: View {
  let entry: Entry
  let plantName: String?
  private var title: String {
    switch entry.kind {
    case .watering: "A little refresh"
    case .note: "Field observation"
    case .added: "Taking root"
    case .schedule: "Care, refined"
    }
  }
  private var symbol: String {
    switch entry.kind {
    case .watering: "drop"
    case .note: "pencil.line"
    case .added: "leaf"
    case .schedule: "slider.horizontal.3"
    }
  }
  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(spacing: 10) {
        Image(systemName: symbol).font(.system(size: 13))
          .frame(width: 33, height: 33).background(Palette.sage, in: Circle())
        Rectangle().fill(Palette.secondary.opacity(0.18)).frame(width: 1).frame(minHeight: 34)
      }
      VStack(alignment: .leading, spacing: 7) {
        Text(entry.date.formatted(date: .abbreviated, time: .shortened).uppercased())
          .font(.system(size: 8, weight: .medium)).tracking(0.8).foregroundStyle(Palette.secondary)
        Text(plantName.map { "\(title) · \($0)" } ?? title)
          .font(.system(size: 18, design: .serif)).multilineTextAlignment(.leading)
        Text(entry.text).font(.system(size: 12)).foregroundStyle(Palette.secondary)
          .lineSpacing(4).fixedSize(horizontal: false, vertical: true).multilineTextAlignment(
            .leading)
      }
      Spacer(minLength: 0)
    }
    .foregroundStyle(Palette.ink)
  }
}

struct UndoBar: View {
  let label: String
  let action: () -> Void
  var body: some View {
    HStack {
      Image(systemName: "checkmark.circle").font(.system(size: 14))
      Text(label).font(.system(size: 12, weight: .medium))
      Spacer()
      Button(action: action) {
        Text("Undo").font(.system(size: 12, weight: .semibold))
          .padding(.horizontal, 12).frame(minHeight: 44)
      }.accessibilityIdentifier("undo")
    }
    .padding(.leading, 16).padding(.trailing, 4)
    .foregroundStyle(Palette.paper).background(Palette.ink, in: RoundedRectangle(cornerRadius: 14))
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.system(size: 13, weight: .semibold))
      .frame(maxWidth: .infinity).padding(.vertical, 17)
      .foregroundStyle(enabled ? Palette.paper : Palette.secondary)
      .background(enabled ? Palette.ink : Palette.sage, in: Capsule())
      .opacity(configuration.isPressed ? 0.75 : 1)
  }
}

struct SheetHeader: View {
  let kicker: String
  let title: String
  let close: () -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        eyebrow(kicker)
        Spacer()
        Button(action: close) {
          Image(systemName: "xmark").font(.system(size: 14)).frame(width: 40, height: 40)
            .background(Palette.sage, in: Circle())
        }.accessibilityLabel("Close")
      }
      Text(title).font(.system(size: 32, design: .serif)).tracking(-1)
    }
  }
}

struct EmptyGarden: View {
  let title: String
  let subtitle: String
  let symbol: String
  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: symbol).font(.system(size: 35, weight: .ultraLight))
      Text(title).font(.system(size: 25, design: .serif))
      Text(subtitle).font(.system(size: 12)).lineSpacing(4).multilineTextAlignment(.center)
        .foregroundStyle(Palette.secondary)
    }
    .foregroundStyle(Palette.ink).padding(32).frame(maxWidth: .infinity)
    .background(Palette.sage.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
  }
}

@MainActor
private func eyebrow(_ text: String) -> some View {
  Text(text).font(.system(size: 9, weight: .medium)).tracking(1.8).foregroundStyle(
    Palette.secondary)
}

struct ShareSheet: UIViewControllerRepresentable {
  let items: [URL]
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
