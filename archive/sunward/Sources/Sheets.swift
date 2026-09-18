import SwiftUI

struct LocationSheet: View {
  let planner: Planner
  @Environment(\.dismiss) private var dismiss
  @State private var search = ""
  @State private var manual = false
  @State private var name = ""
  @State private var latitude = ""
  @State private var longitude = ""
  @State private var zone = "Etc/UTC"
  @State private var error = ""
  @FocusState private var focus: Field?
  private enum Field { case name, latitude, longitude }

  var body: some View {
    NavigationStack {
      List {
        if !manual {
          Section {
            HStack {
              Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
              TextField("Find a city", text: $search).accessibilityLabel("Find a city")
            }
          }.listRowBackground(Palette.line)
          Section {
            ForEach(
              Place.presets.filter {
                search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
              }
            ) { place in
              Button {
                planner.select(place)
                dismiss()
              } label: {
                HStack {
                  VStack(alignment: .leading, spacing: 7) {
                    Text(place.name).font(.system(.title3, design: .serif)).foregroundStyle(
                      Palette.cream)
                    Text(place.coordinates).font(.system(.caption, design: .monospaced))
                      .foregroundStyle(Palette.muted)
                  }
                  Spacer()
                  if place == planner.place {
                    Image(systemName: "checkmark").foregroundStyle(Palette.copper)
                  }
                }.padding(.vertical, 7)
              }
            }
            if !search.isEmpty
              && !Place.presets.contains(where: { $0.name.localizedCaseInsensitiveContains(search) }
              )
            {
              Text("No matching city. Enter coordinates below to plan anywhere.")
                .foregroundStyle(Palette.muted)
            }
          } header: {
            Text("A world of light")
          }.listRowBackground(Color.clear)
          Section {
            Button {
              manual = true
            } label: {
              Label("Enter coordinates", systemImage: "location.viewfinder")
            }
          } footer: {
            Text("All calculations happen on your iPhone. No location permission needed.")
          }
        } else {
          Section("Your location") {
            VStack(alignment: .leading, spacing: 8) {
              Text("LOCATION NAME").technical(10).foregroundStyle(Palette.muted)
              TextField("Your viewpoint", text: $name).textInputAutocapitalization(.words)
                .focused($focus, equals: .name).accessibilityLabel("Location name")
            }.padding(.vertical, 6)
            VStack(alignment: .leading, spacing: 8) {
              Text("LATITUDE · −90° TO 90°").technical(10).foregroundStyle(Palette.muted)
              TextField("e.g. 37.7749", text: $latitude).keyboardType(.numbersAndPunctuation)
                .focused($focus, equals: .latitude).accessibilityLabel("Latitude")
            }.padding(.vertical, 6)
            VStack(alignment: .leading, spacing: 8) {
              Text("LONGITUDE · −180° TO 180°").technical(10).foregroundStyle(Palette.muted)
              TextField("e.g. −122.4194", text: $longitude).keyboardType(.numbersAndPunctuation)
                .focused($focus, equals: .longitude).accessibilityLabel("Longitude")
            }.padding(.vertical, 6)
          }.listRowBackground(Palette.line)
          Section {
            NavigationLink {
              TimeZoneSheet(selection: $zone)
            } label: {
              VStack(alignment: .leading, spacing: 8) {
                Text("TIME ZONE").technical(10).foregroundStyle(Palette.muted)
                Text(zone.replacingOccurrences(of: "_", with: " "))
                  .font(.subheadline).foregroundStyle(Palette.cream)
              }
            }
          } footer: {
            Text(
              "Choose the time zone used at this location. Coordinates alone do not determine civil time."
            )
          }.listRowBackground(Palette.line)
          if !error.isEmpty {
            Section {
              Text(error).foregroundStyle(Palette.copper).accessibilityLabel("Error: \(error)")
            }
          }
          Section {
            Button("Use these coordinates") { submit() }
            Button("Back to cities") { manual = false }.foregroundStyle(Palette.muted)
          }
        }
      }
      .scrollContentBackground(.hidden).background(Palette.ink)
      .scrollDismissesKeyboard(.interactively)
      .onChange(of: latitude) { error = "" }
      .onChange(of: longitude) { error = "" }
      .navigationTitle(manual ? "Coordinates" : "Find your light")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focus = nil }
        }
      }
    }.tint(Palette.copper)
  }

  private func submit() {
    focus = nil
    guard
      let lat = Double(
        latitude.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "−", with: "-")),
      lat.isFinite, (-90...90).contains(lat)
    else {
      error = "Latitude must be a number from −90 to 90."
      return
    }
    guard
      let lon = Double(
        longitude.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "−", with: "-")),
      lon.isFinite, (-180...180).contains(lon)
    else {
      error = "Longitude must be a number from −180 to 180."
      return
    }
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    planner.select(
      Place(
        name: title.isEmpty ? "Custom location" : title, latitude: lat, longitude: lon, zoneID: zone
      ))
    dismiss()
  }
}

struct TimeZoneSheet: View {
  @Binding var selection: String
  @Environment(\.dismiss) private var dismiss
  @State private var search = ""
  private var zones: [String] {
    Array(Set(["Etc/UTC"] + TimeZone.knownTimeZoneIdentifiers)).sorted()
      .filter {
        search.isEmpty
          || $0.replacingOccurrences(of: "_", with: " ").localizedCaseInsensitiveContains(search)
      }
  }
  var body: some View {
    List {
      ForEach(zones, id: \.self) { zone in
        Button {
          selection = zone
          dismiss()
        } label: {
          HStack {
            Text(zone.replacingOccurrences(of: "_", with: " ")).foregroundStyle(Palette.cream)
            Spacer()
            if selection == zone { Image(systemName: "checkmark") }
          }.padding(.vertical, 6)
        }.listRowBackground(Color.clear)
      }
      if zones.isEmpty {
        Text("No matching time zone. Try a city or region.").foregroundStyle(Palette.muted)
      }
    }
    .searchable(text: $search, prompt: "City, region or UTC")
    .scrollContentBackground(.hidden).background(Palette.ink)
    .navigationTitle("Time zone").navigationBarTitleDisplayMode(.inline)
  }
}

struct DateSheet: View {
  let planner: Planner
  @Environment(\.dismiss) private var dismiss
  @State private var selection: Date
  init(planner: Planner) {
    self.planner = planner
    _selection = State(initialValue: planner.date)
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Every day has\nits own light.").font(.system(.largeTitle, design: .serif))
            .foregroundStyle(Palette.cream)
          DatePicker("Shoot date", selection: $selection, in: dateRange, displayedComponents: .date)
            .datePickerStyle(.graphical).tint(Palette.copper)
            .environment(\.timeZone, planner.place.zone)
            .environment(\.calendar, planner.place.calendar)
          Button("Today in \(planner.place.name)") { selection = Date() }.frame(minHeight: 44)
          Text(
            "Dates and times use \(planner.place.zoneID). Daylight saving time is included automatically."
          )
          .font(.subheadline).foregroundStyle(Palette.muted)
        }.padding(24)
      }.background(Palette.ink)
        .navigationTitle("Choose a date").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
              planner.selectDate(selection)
              dismiss()
            }
          }
        }
    }
  }
  private var dateRange: ClosedRange<Date> {
    let calendar = planner.place.calendar
    let first = calendar.date(from: DateComponents(year: 1900, month: 1, day: 1))!
    let last = calendar.date(from: DateComponents(year: 2100, month: 12, day: 31))!
    return first...last
  }
}

struct SaveShootSheet: View {
  let planner: Planner
  var editing: Shoot?
  var onSave: () -> Void = {}
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var notes = ""
  @FocusState private var fieldFocused: Bool

  var body: some View {
    NavigationStack {
      Form {
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text(editing?.place.name ?? planner.place.name).font(.system(.title2, design: .serif))
            Text(
              Solar.dateLabel(editing?.date ?? planner.date, in: editing?.place ?? planner.place)
                + " · "
                + Solar.time(editing?.date ?? planner.date, in: editing?.place ?? planner.place)
            )
            .font(.system(.subheadline, design: .monospaced)).foregroundStyle(Palette.copper)
            let place = editing?.place ?? planner.place
            let position = Solar.position(at: editing?.date ?? planner.date, place: place)
            Text("\(position.phase) · \(String(format: "%+.1f°", position.altitude)) altitude")
              .font(.subheadline).foregroundStyle(Palette.muted)
          }.padding(.vertical, 12)
        }.listRowBackground(Color.clear)
        Section("Shoot name") {
          TextField("Name this shoot", text: $title).focused($fieldFocused)
        }.listRowBackground(Palette.line)
        Section("Field notes") {
          TextField("Lens, composition, a place to meet…", text: $notes, axis: .vertical)
            .lineLimit(4...8).focused($fieldFocused)
        }.listRowBackground(Palette.line)
        Section {
          Text("Saved on this iPhone, ready whenever the light is.")
            .font(.subheadline).foregroundStyle(Palette.muted)
        }.listRowBackground(Color.clear)
      }
      .scrollContentBackground(.hidden).background(Palette.ink)
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle(editing == nil ? "Keep this light" : "Edit shoot")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { fieldFocused = false }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            if var shoot = editing {
              shoot.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
              shoot.notes = notes
              planner.update(shoot)
            } else {
              planner.save(title: title, notes: notes)
            }
            onSave()
            dismiss()
          }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }.onAppear {
        title = editing?.title ?? "\(planner.place.name) light study"
        notes = editing?.notes ?? ""
      }
    }
  }
}

struct ShootsSheet: View {
  let planner: Planner
  @Environment(\.dismiss) private var dismiss
  @State private var editing: Shoot?
  var body: some View {
    NavigationStack {
      Group {
        if planner.shoots.isEmpty {
          ContentUnavailableView {
            Label("Light worth keeping", systemImage: "bookmark")
          } description: {
            Text(
              "Find your location, choose a moment, then save a shoot. Your field notes will live here."
            )
          } actions: {
            Button("Explore the dial") { dismiss() }
          }
        } else {
          List {
            Section {
              ForEach(planner.shoots) { shoot in
                Button {
                  planner.open(shoot)
                  dismiss()
                } label: {
                  VStack(alignment: .leading, spacing: 8) {
                    Text(shoot.title).font(.system(.title3, design: .serif)).foregroundStyle(
                      Palette.cream)
                    Text(shoot.place.name + " · " + Solar.time(shoot.date, in: shoot.place))
                      .font(.subheadline).foregroundStyle(Palette.copper)
                    Text(Solar.dateLabel(shoot.date, in: shoot.place)).font(.caption)
                      .foregroundStyle(Palette.muted)
                    if !shoot.notes.isEmpty {
                      Text(shoot.notes).font(.subheadline).foregroundStyle(Palette.muted).lineLimit(
                        2)
                    }
                  }.padding(.vertical, 10)
                }
                .swipeActions(edge: .trailing) {
                  Button("Delete", role: .destructive) { planner.delete(shoot.id) }
                  Button("Edit") { editing = shoot }.tint(Palette.copper)
                }
                .contextMenu {
                  Button("Edit shoot") { editing = shoot }
                  Button("Delete shoot", role: .destructive) { planner.delete(shoot.id) }
                }
              }
            } footer: {
              Text("Tap to return to this moment. Swipe to edit or delete.")
            }
          }.scrollContentBackground(.hidden)
        }
      }
      .background(Palette.ink)
      .navigationTitle("Saved shoots")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .sheet(item: $editing) { shoot in SaveShootSheet(planner: planner, editing: shoot) }
    }
  }
}

struct GuideSheet: View {
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("A little closer\nto the sun.").font(.system(size: 36, design: .serif))
          guide(
            "Read the sky",
            "The dial looks up at the sky: north at the top, east to the right. The inner disk is the visible sky; its rim is the 0° horizon and its center is 90° overhead. The blue outer band compresses below-horizon positions to keep the whole day visible. Hold near the path, then drag to scrub. A ring and caption confirm scrubbing. Or use the time slider."
          )
          guide(
            "Find the softer light",
            "Golden windows use the sun’s geometric center between −4° and +6° altitude. Tap a window to jump to its midpoint. Blue hour is −6° to −4°. These are photographic conventions, not weather forecasts."
          )
          guide(
            "Precision, with perspective",
            "Sunward computes solar position locally using NOAA’s solar equations (Julian centuries, equation of time and solar declination). Sunrise and sunset cross −0.833°, approximating refraction and the sun’s radius. Events are solved numerically within the selected location’s civil day."
          )
          guide(
            "Know the limits",
            "Times are estimates for an unobstructed, sea-level horizon. Mountains, buildings, elevation, refraction and weather can change what you see. Near the poles, the sun may never rise or set; golden light may span midnight or disappear entirely."
          )
          guide(
            "Private by design",
            "No GPS, network, account or analytics. Locations and saved shoots stay in this app’s local storage. Deleting the app removes them."
          )
        }.padding(24)
      }.background(Palette.ink).foregroundStyle(Palette.cream)
        .navigationTitle("Field guide").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
  private func guide(_ title: String, _ body: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline).foregroundStyle(Palette.copper)
      Text(body).font(.body).foregroundStyle(Palette.muted).lineSpacing(4)
    }
  }
}
