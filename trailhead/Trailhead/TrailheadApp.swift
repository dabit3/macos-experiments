import SwiftUI

@main
struct TrailheadApp: App {
  @StateObject private var store = TripStore()

  var body: some Scene {
    WindowGroup {
      ExpeditionView()
        .environmentObject(store)
        .preferredColorScheme(.light)
    }
  }
}

enum JournalTab: String, CaseIterable {
  case route = "Route"
  case gear = "Gear"
  case saved = "Saved"
}

enum EntryKind: String, Identifiable {
  case waypoint, gear, rename
  var id: String { rawValue }
  var title: String {
    switch self {
    case .waypoint: "Mark a moment"
    case .gear: "One more essential"
    case .rename: "Name your expedition"
    }
  }
  var prompt: String {
    switch self {
    case .waypoint: "Waypoint name"
    case .gear: "Gear item"
    case .rename: "Trip name"
    }
  }
}

struct ExpeditionView: View {
  @EnvironmentObject private var store: TripStore
  @State private var fraction = 0.48
  @State private var tab = JournalTab.route
  @State private var choosingRoute = false
  @State private var entry: EntryKind?
  @State private var confirmingReset = false
  @State private var export: ExportDocument?

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        header
        InteractiveMap(trail: store.trail, fraction: fraction, waypoints: store.trip.waypoints)
          .frame(minHeight: 160, maxHeight: .infinity)
        journal
          .frame(height: min(448, geometry.size.height * 0.57))
      }
      .background(Field.paper)
      .foregroundStyle(Field.ink)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    .sheet(isPresented: $choosingRoute) {
      RoutePicker { trail in
        store.select(trail)
        fraction = 0.48
        tab = .route
        choosingRoute = false
      }
      .presentationDragIndicator(.visible)
    }
    .sheet(item: $entry) { kind in
      EntrySheet(kind: kind, initial: kind == .rename ? store.trip.name : "") { name in
        store.edit { trip in
          switch kind {
          case .waypoint: _ = trip.addWaypoint(name: name, fraction: fraction)
          case .gear: _ = trip.addGear(name: name)
          case .rename: trip.name = name
          }
        }
      }
      .presentationDetents([.medium])
      .presentationDragIndicator(.visible)
    }
    .sheet(item: $export) { PDFPreview(document: $0) }
    .alert("Start a fresh plan?", isPresented: $confirmingReset) {
      Button("Reset draft", role: .destructive) {
        store.reset()
        fraction = 0.48
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "This clears this route’s draft. Saved trips stay in your journal, and Undo can restore the draft."
      )
    }
    .alert(
      "Field journal",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
  }

  private var header: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 5) {
          Image(systemName: "mountain.2").font(.system(size: 12, weight: .semibold))
          Text("THE OUTSIDE IS CALLING").font(.system(size: 8, weight: .bold)).tracking(1.8)
        }
        Text("Trailhead").font(.system(size: 34, weight: .medium, design: .serif)).tracking(-1.5)
      }
      Spacer()
      Button {
        choosingRoute = true
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "square.grid.2x2")
          Text("Routes")
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 14).frame(height: 42)
        .overlay(Capsule().stroke(Field.ink.opacity(0.3)))
      }
      .accessibilityIdentifier("chooseRoute")
    }
    .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 13)
    .background(Field.paper)
  }

  private var journal: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text(
          "0\((Trails.all.firstIndex(where: { $0.id == store.trail.id }) ?? 0) + 1) / \(store.trail.region)"
        )
        .font(.system(size: 8, weight: .bold)).tracking(1.8)
        Spacer()
        Text(store.trail.difficulty.uppercased()).font(.system(size: 8, weight: .bold)).tracking(
          0.7
        )
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Field.ink.opacity(0.07), in: Capsule())
      }
      HStack(alignment: .firstTextBaseline) {
        Text(store.trail.name).font(.system(size: 29, weight: .medium, design: .serif)).tracking(
          -0.8)
        Spacer()
        Button {
          entry = .rename
        } label: {
          Image(systemName: "pencil.line").font(.system(size: 17)).frame(width: 32, height: 30)
        }.accessibilityLabel("Rename trip")
      }
      HStack(spacing: 0) {
        stat(String(format: "%.1f", store.trail.distance), unit: "KM", label: "DISTANCE")
        Divider().frame(height: 29).padding(.horizontal, 17)
        stat("\(Int(store.trail.ascent))", unit: "M", label: "ELEVATION GAIN")
        Spacer(minLength: 8)
        stat(store.trail.duration, unit: "", label: "EST. MOVING TIME")
      }
      HStack(spacing: 4) {
        ForEach(JournalTab.allCases, id: \.self) { value in
          Button {
            withAnimation(.easeInOut(duration: 0.18)) { tab = value }
          } label: {
            HStack(spacing: 5) {
              Text(value.rawValue)
              if value == .gear {
                Text("\(store.trip.gear.filter(\.packed).count)/\(store.trip.gear.count)").opacity(
                  0.7)
              }
              if value == .saved { Text("\(store.archive.saved.count)").opacity(0.7) }
            }
            .font(.system(size: 11, weight: .semibold))
            .frame(maxWidth: .infinity).frame(height: 34)
            .background(tab == value ? Field.ink : .clear, in: Capsule())
            .foregroundStyle(tab == value ? Field.paper : Field.ink)
          }.accessibilityIdentifier("tab\(value.rawValue)")
        }
      }
      .padding(3).background(Field.ink.opacity(0.055), in: Capsule())
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          switch tab {
          case .route: routeDetails
          case .gear: gearDetails
          case .saved: savedDetails
          }
        }
        .padding(.bottom, 6)
      }
      .id("\(store.trail.id)-\(tab.rawValue)")
      .scrollIndicators(.visible)
      .scrollIndicatorsFlash(trigger: tab)
    }
    .padding(.horizontal, 22).padding(.top, 18)
    .background(Field.paper)
    .overlay(alignment: .top) { Rectangle().fill(Field.line).frame(height: 1) }
  }

  private var routeDetails: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Label("\(Int(store.trail.point(at: fraction).elevation)) m", systemImage: "mountain.2")
          .font(.system(size: 12, weight: .semibold))
        Text("at \(store.trail.distance * fraction, specifier: "%.1f") km")
          .font(.system(size: 11)).foregroundStyle(Field.muted)
        Spacer()
        Button {
          entry = .waypoint
        } label: {
          Label("Add stop", systemImage: "plus").font(.system(size: 11, weight: .bold))
            .padding(.vertical, 9).padding(.horizontal, 11)
            .background(Field.orange.opacity(0.09), in: Capsule())
        }
        .foregroundStyle(Field.orange)
        .accessibilityIdentifier("addWaypoint")
      }
      ElevationProfile(trail: store.trail, fraction: $fraction)
      HStack {
        Text("YOUR WAYPOINTS").font(.system(size: 8, weight: .bold)).tracking(1.5)
        Spacer()
        Label("\(store.trip.waypoints.count) stops · scroll", systemImage: "chevron.down")
          .font(.system(size: 9)).foregroundStyle(Field.muted)
      }
      ForEach(Array(store.trip.waypoints.enumerated()), id: \.element.id) { index, waypoint in
        HStack(spacing: 9) {
          Text("\(index + 1)").font(.system(size: 10, weight: .bold))
            .frame(width: 23, height: 23).background(Field.ink, in: Circle()).foregroundStyle(
              Field.paper)
          Button {
            fraction = waypoint.fraction
          } label: {
            HStack {
              Text(waypoint.name).font(.system(size: 12, weight: .medium)).lineLimit(2)
              Spacer()
              Text("\(store.trail.distance * waypoint.fraction, specifier: "%.1f") km")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(Field.muted)
            }.frame(minHeight: 34)
          }
          Button {
            store.edit { $0.waypoints.removeAll { $0.id == waypoint.id } }
          } label: {
            Image(systemName: "xmark").font(.system(size: 10)).frame(width: 30, height: 34)
          }.accessibilityLabel("Remove \(waypoint.name)")
        }
      }
      Text(store.trail.description).font(.system(size: 12)).foregroundStyle(Field.muted)
        .lineSpacing(4)
      Label("Illustrative fixtures. Never use for navigation.", systemImage: "info.circle")
        .font(.system(size: 10)).foregroundStyle(Field.muted)
    }
  }

  private var gearDetails: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text("PACK LIGHT. GO PREPARED.").font(.system(size: 8, weight: .bold)).tracking(1)
        Spacer()
        Button {
          entry = .gear
        } label: {
          Label("Add", systemImage: "plus").font(.system(size: 12, weight: .semibold)).frame(
            height: 36)
        }.accessibilityLabel("Add gear item")
      }
      ForEach(store.trip.gear) { item in
        HStack {
          Button {
            store.edit { trip in
              if let index = trip.gear.firstIndex(where: { $0.id == item.id }) {
                trip.gear[index].packed.toggle()
              }
            }
          } label: {
            HStack(spacing: 10) {
              Image(systemName: item.packed ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20)).foregroundStyle(item.packed ? Field.ink : Field.line)
              Text(item.name).font(.system(size: 13))
                .strikethrough(item.packed).foregroundStyle(item.packed ? Field.muted : Field.ink)
              Spacer()
            }.frame(minHeight: 42).contentShape(Rectangle())
          }
          .accessibilityLabel("\(item.name), \(item.packed ? "packed" : "not packed")")
          Button {
            store.edit { $0.gear.removeAll { $0.id == item.id } }
          } label: {
            Image(systemName: "minus").font(.system(size: 12)).frame(width: 32, height: 40)
          }.accessibilityLabel("Remove \(item.name)")
        }
        Divider().overlay(Field.line.opacity(0.3))
      }
      if store.trip.gear.isEmpty {
        Text("A lighter pack starts here. Add your first essential.").font(.system(size: 13))
          .padding(.vertical)
      }
    }
  }

  private var savedDetails: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("YOUR FIELD JOURNAL").font(.system(size: 8, weight: .bold)).tracking(1.5)
      if store.archive.saved.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Image(systemName: "book.closed").font(.system(size: 25))
          Text("Good days begin with a plan.").font(.system(size: 21, design: .serif))
          Text("Save this expedition to keep your waypoints and packing list together.")
            .font(.system(size: 12)).foregroundStyle(Field.muted)
        }.padding(.vertical, 10)
      }
      ForEach(store.archive.saved) { trip in
        HStack(alignment: .center) {
          Button {
            store.reopen(trip)
            fraction = 0.48
            tab = .route
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 5) {
                Text(trip.name).font(.system(size: 18, design: .serif)).multilineTextAlignment(
                  .leading)
                Text(
                  "\(trip.waypoints.count) stops · \(trip.gear.filter(\.packed).count)/\(trip.gear.count) packed"
                )
                .font(.system(size: 10)).foregroundStyle(Field.muted)
              }
              Spacer()
              Image(systemName: "arrow.up.right").font(.system(size: 14))
            }.padding(13)
          }.accessibilityLabel("Reopen \(trip.name)")
        }
        .background(Field.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
      }
    }
  }

  private var footer: some View {
    VStack(spacing: 8) {
      HStack(spacing: 6) {
        Text(store.notice ?? store.trip.name).font(.system(size: 10))
          .lineLimit(1).foregroundStyle(Field.muted)
        Spacer(minLength: 4)
        Button {
          store.undo()
        } label: {
          Image(systemName: "arrow.uturn.backward").frame(width: 30, height: 28)
        }.disabled(store.previous == nil).accessibilityLabel("Undo last change")
        Button {
          confirmingReset = true
        } label: {
          Image(systemName: "arrow.counterclockwise").frame(width: 30, height: 28)
        }.accessibilityLabel("Reset draft")
      }
      HStack(spacing: 10) {
        Button {
          store.save()
        } label: {
          HStack {
            Image(systemName: store.isSaved ? "checkmark" : "bookmark")
            Text(store.isSaved ? "Trip saved" : "Save expedition")
            Spacer()
            Image(systemName: "arrow.right")
          }
          .font(.system(size: 14, weight: .semibold))
          .padding(.horizontal, 18).frame(height: 48)
          .background(Field.ink, in: RoundedRectangle(cornerRadius: 14))
          .foregroundStyle(Field.paper)
        }.accessibilityIdentifier("saveTrip")
        Button {
          do { export = try ItineraryExporter.create(trip: store.trip, trail: store.trail) } catch {
            store.error = "Could not create your itinerary. \(error.localizedDescription)"
          }
        } label: {
          Image(systemName: "square.and.arrow.up").font(.system(size: 18))
            .frame(width: 52, height: 48)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Field.ink.opacity(0.25)))
        }
        .accessibilityLabel("Export itinerary PDF").accessibilityIdentifier("exportPDF")
      }
    }
    .foregroundStyle(Field.ink)
    .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 10)
    .background(Field.paper)
  }

  private func stat(_ value: String, unit: String, label: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value).font(.system(size: 19, weight: .medium, design: .serif))
        Text(unit).font(.system(size: 8, weight: .bold))
      }
      Text(label).font(.system(size: 7, weight: .bold)).tracking(0.7).foregroundStyle(Field.muted)
    }
  }
}

struct EntrySheet: View {
  @Environment(\.dismiss) private var dismiss
  let kind: EntryKind
  let initial: String
  let onSave: (String) -> Void
  @State private var text = ""
  @FocusState private var focused: Bool

  var clean: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Text(kind.title).font(Field.serif)
        Spacer()
        Button("Cancel") { dismiss() }.font(.system(size: 13))
      }
      TextField(kind.prompt, text: $text)
        .textFieldStyle(.plain).padding(16)
        .background(Field.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .focused($focused).submitLabel(.done)
        .accessibilityIdentifier("entryName")
        .onSubmit { save() }
      Text(
        clean.count > 60
          ? "Please use 60 characters or fewer." : "A small detail for a memorable day."
      )
      .font(.system(size: 12)).foregroundStyle(clean.count > 60 ? Field.orange : Field.muted)
      Button(action: save) {
        Text("Add to expedition").font(.system(size: 14, weight: .semibold))
          .frame(maxWidth: .infinity).frame(height: 50)
          .background(Field.ink, in: RoundedRectangle(cornerRadius: 13)).foregroundStyle(
            Field.paper)
      }
      .disabled(clean.isEmpty || clean.count > 60)
      .opacity(clean.isEmpty || clean.count > 60 ? 0.4 : 1)
      Spacer(minLength: 0)
    }
    .padding(24).padding(.top, 12).background(Field.paper).foregroundStyle(Field.ink)
    .onAppear {
      text = initial
      focused = true
    }
  }

  private func save() {
    guard !clean.isEmpty, clean.count <= 60 else { return }
    onSave(clean)
    dismiss()
  }
}

struct RoutePicker: View {
  @Environment(\.dismiss) private var dismiss
  let select: (Trail) -> Void
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          Text("THE OFFLINE COLLECTION").font(.system(size: 9, weight: .bold)).tracking(1.7)
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark").frame(width: 36, height: 36)
          }
          .accessibilityLabel("Close route collection")
        }
        Text("Find your\nnext outside.").font(.system(size: 38, weight: .medium, design: .serif))
          .tracking(-1)
        Text(
          "Three landscapes. A little room to wander.\nIllustrative trail studies, always available offline."
        )
        .font(.system(size: 13)).foregroundStyle(Field.muted).lineSpacing(4)
        ForEach(Trails.all) { trail in
          Button {
            select(trail)
          } label: {
            VStack(alignment: .leading, spacing: 0) {
              TopoArtwork(trail: trail, labels: false).frame(height: 135).clipped()
              VStack(alignment: .leading, spacing: 8) {
                Text(trail.region).font(.system(size: 8, weight: .bold)).tracking(1.5)
                HStack {
                  Text(trail.name).font(.system(size: 26, design: .serif))
                  Spacer()
                  Image(systemName: "arrow.up.right").font(.system(size: 19))
                }
                Text(
                  "\(trail.distance, specifier: "%.1f") km  /  \(Int(trail.ascent)) m gain  /  \(trail.difficulty)"
                )
                .font(.system(size: 11)).foregroundStyle(Field.muted)
              }.padding(17).background(Field.paper)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Field.line))
          }.buttonStyle(.plain).accessibilityLabel("Choose \(trail.name)")
        }
      }.padding(24).padding(.top, 10)
    }
    .background(Field.paper).foregroundStyle(Field.ink)
  }
}
