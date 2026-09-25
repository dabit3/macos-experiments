import SwiftUI

private enum ObservatorySheet: String, Identifiable {
  case location, library, save, date, about
  var id: String { rawValue }
}

struct ObservatoryView: View {
  @EnvironmentObject private var store: Observatory
  @State private var tab = 0
  @State private var search = ""
  @State private var aboveOnly = true
  @State private var constellation = "All constellations"
  @State private var showLines = true
  @State private var sheet: ObservatorySheet?
  @State private var saveName = ""
  @State private var exportURL: URL?
  @State private var scrubAnchor: Date?

  private var filtered: [Star] {
    Catalog.stars.filter { star in
      (!aboveOnly
        || Astronomy.position(star, at: store.plan.date, site: store.plan.site).altitude >= 0)
        && (constellation == "All constellations" || star.constellation == constellation)
        && (search.isEmpty
          || "\(star.name) \(star.constellation)".localizedCaseInsensitiveContains(search))
    }
  }

  var body: some View {
    GeometryReader { geometry in
      let narrow = geometry.size.width < 1050
      VStack(spacing: 0) {
        header
        Rectangle().fill(Palette.line).frame(height: 1)
        HStack(spacing: 0) {
          sidebar.frame(width: narrow ? 228 : 262)
          Rectangle().fill(Palette.line).frame(width: 1)
          VStack(spacing: 0) {
            mapToolbar
            HStack(spacing: 0) {
              AtlasView(constellation: constellation, lines: showLines)
              inspector.frame(width: narrow ? 202 : 240).padding(.trailing, 20)
            }
            timeline
          }
        }
        footer
      }
      .background(Palette.ink)
      .foregroundStyle(Palette.ivory)
      .sheet(item: $sheet) { sheetContent($0) }
      .alert(
        "Observatory notice",
        isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
      ) {
        Button("OK") { store.error = nil }
      } message: {
        Text(store.error ?? "")
      }
      .onChange(of: store.plan) { _, _ in exportURL = nil }
    }
  }

  private var header: some View {
    HStack(spacing: 22) {
      HStack(spacing: 12) {
        ZStack {
          Circle().stroke(Palette.gold.opacity(0.55), lineWidth: 1).frame(width: 34, height: 34)
          Image(systemName: "sparkle").font(.system(size: 23, weight: .ultraLight)).foregroundStyle(
            Palette.gold)
        }
        VStack(alignment: .leading, spacing: 3) {
          Text("Celestia").font(.system(size: 32, weight: .regular, design: .serif)).tracking(-1)
          Text("THE NIGHT, WITHIN REACH")
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .tracking(1.2).foregroundStyle(Palette.muted).lineLimit(1).fixedSize()
        }
      }.frame(width: 230, alignment: .leading)
      Button {
        sheet = .location
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "location.circle").font(.system(size: 23, weight: .ultraLight))
            .foregroundStyle(Palette.gold)
          VStack(alignment: .leading, spacing: 4) {
            Text(store.plan.site.name).font(.system(size: 14, weight: .medium))
            Text(
              String(
                format: "%.2f° %@  /  %.2f° %@", abs(store.plan.site.latitude),
                store.plan.site.latitude >= 0 ? "N" : "S", abs(store.plan.site.longitude),
                store.plan.site.longitude >= 0 ? "E" : "W")
            )
            .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
          }
          Image(systemName: "chevron.down").font(.system(size: 10)).foregroundStyle(Palette.muted)
        }.padding(.vertical, 8)
      }.buttonStyle(.plain).accessibilityIdentifier("locationPicker")
      Spacer(minLength: 4)
      Button {
        sheet = .library
      } label: {
        Label("Saved plans", systemImage: "square.stack")
      }
      .buttonStyle(InstrumentButton()).accessibilityIdentifier("savedPlans")
      Button {
        saveName = store.plan.name
        sheet = .save
      } label: {
        Label("Save evening", systemImage: "bookmark")
      }
      .buttonStyle(InstrumentButton(active: true)).accessibilityIdentifier("saveEvening")
    }.padding(.horizontal, 25).padding(.vertical, 19)
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 0) {
        tabButton("Explore", number: nil, value: 0)
        tabButton("My evening", number: store.plan.targets.count, value: 1)
      }.padding(.horizontal, 14).padding(.top, 18)
      if tab == 0 {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
            TextField("Find a star", text: $search).font(.system(size: 13)).autocorrectionDisabled()
              .accessibilityIdentifier("starSearch")
            if !search.isEmpty {
              Button {
                search = ""
              } label: {
                Image(systemName: "xmark.circle.fill")
              }
              .accessibilityLabel("Clear search")
            }
          }.padding(11).background(Palette.ink).clipShape(RoundedRectangle(cornerRadius: 8))
          Toggle(isOn: $aboveOnly) { Text("Above horizon only").font(.system(size: 12)) }
            .tint(Palette.mint).controlSize(.mini).accessibilityIdentifier("aboveHorizonFilter")
          HStack {
            Eyebrow(text: "Bright star catalog")
            Spacer()
            Text("\(filtered.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(
              Palette.gold)
          }
        }.padding(18)
        ScrollView {
          LazyVStack(spacing: 3) {
            ForEach(filtered) { star in starRow(star) }
            if filtered.isEmpty {
              VStack(spacing: 12) {
                Image(systemName: "sparkle.magnifyingglass").font(.title2).foregroundStyle(
                  Palette.gold)
                Text("No stars in this view").font(.system(size: 15, design: .serif))
                Text(
                  "Try another constellation, clear your search, or include stars below the horizon."
                )
                .font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(
                  .center)
                Button("Clear filters") {
                  search = ""
                  constellation = "All constellations"
                  aboveOnly = false
                }.buttonStyle(InstrumentButton())
              }.padding(20)
            }
          }.padding(.horizontal, 10)
        }
        Text("J2000 CATALOG  /  \(Catalog.stars.count) STARS").font(
          .system(size: 9, design: .monospaced)
        ).tracking(1.2)
          .foregroundStyle(Palette.muted).padding(20)
      } else {
        planSidebar
      }
    }.background(Palette.panel)
  }

  private func tabButton(_ title: String, number: Int?, value: Int) -> some View {
    Button {
      tab = value
    } label: {
      HStack(spacing: 5) {
        Text(title)
        if let number {
          Text("\(number)").font(.system(size: 10, design: .monospaced)).foregroundStyle(
            Palette.gold)
        }
      }.font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity).frame(height: 38)
        .background(tab == value ? Palette.raised : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .foregroundStyle(tab == value ? Palette.ivory : Palette.muted)
    }.buttonStyle(.plain)
  }

  private func starRow(_ star: Star) -> some View {
    let position = Astronomy.position(star, at: store.plan.date, site: store.plan.site)
    let selected = star.id == store.selectedID
    return Button {
      store.selectedID = star.id
    } label: {
      HStack(spacing: 11) {
        ZStack {
          Circle().fill(Palette.ivory.opacity(0.06)).frame(width: 28, height: 28)
          Circle().fill(selected ? Palette.gold : Palette.ivory).frame(
            width: max(3, 6 - star.magnitude), height: max(3, 6 - star.magnitude))
        }
        VStack(alignment: .leading, spacing: 4) {
          Text(star.name).font(.system(size: 14, weight: .medium, design: .serif))
          Text(star.constellation).font(.system(size: 10)).foregroundStyle(Palette.muted)
        }
        Spacer(minLength: 0)
        VStack(alignment: .trailing, spacing: 5) {
          Text(String(format: "%.0f°", position.altitude)).font(
            .system(size: 12, design: .monospaced)
          )
          .foregroundStyle(position.altitude > 0 ? Palette.mint : Palette.muted)
          if store.plan.targets.contains(star.id) {
            Image(systemName: "bookmark.fill").font(.system(size: 8)).foregroundStyle(Palette.gold)
          } else {
            Text(Astronomy.compass(position.azimuth)).font(.system(size: 8, design: .monospaced))
              .foregroundStyle(Palette.muted)
          }
        }
      }.padding(.horizontal, 10).padding(.vertical, 12)
        .background(selected ? Palette.gold.opacity(0.10) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8).stroke(
            selected ? Palette.gold.opacity(0.25) : .clear, lineWidth: 1)
        )
        .opacity(position.altitude >= 0 ? 1 : 0.6)
    }.buttonStyle(.plain).accessibilityLabel(
      "\(star.name), \(star.constellation), altitude \(Int(position.altitude)) degrees"
    )
    .accessibilityIdentifier("star-\(star.id)")
  }

  private var planSidebar: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 7) {
          Eyebrow(text: "Your observing list")
          Text(store.plan.name).font(.system(size: 22, design: .serif))
          Text("\(store.plan.targets.count) targets · \(store.plan.site.name)").font(
            .system(size: 11)
          ).foregroundStyle(Palette.muted)
        }.padding(.top, 18)
        if store.plan.targets.isEmpty {
          Text("An open sky, a fresh page.\nChoose a star and add it to your evening.")
            .font(.system(size: 14, design: .serif)).foregroundStyle(Palette.muted).padding(
              .vertical, 12)
        }
        ForEach(Array(store.plan.resolvedTargets.enumerated()), id: \.element.id) { index, star in
          HStack(spacing: 7) {
            Text(String(format: "%02d", index + 1)).font(.system(size: 10, design: .monospaced))
              .foregroundStyle(Palette.gold)
            Button {
              store.selectedID = star.id
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(star.name).font(.system(size: 15, design: .serif))
                let altitude = Astronomy.position(star, at: store.plan.date, site: store.plan.site)
                  .altitude
                Text(altitude > 0 ? "\(Int(altitude))° above horizon" : "Below the horizon")
                  .font(.system(size: 10)).foregroundStyle(
                    altitude > 0 ? Palette.mint : Palette.muted)
              }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            Button {
              store.toggleTarget(star)
            } label: {
              Image(systemName: "minus.circle").foregroundStyle(Palette.muted).frame(
                width: 34, height: 44)
            }.accessibilityLabel("Remove \(star.name)")
          }
          Rectangle().fill(Palette.line).frame(height: 1)
        }
        Eyebrow(text: "Field notes")
        TextEditor(
          text: Binding(
            get: { store.plan.notes },
            set: { store.archive.working.notes = String($0.prefix(5000)) })
        )
        .font(.system(size: 13)).lineSpacing(4).scrollContentBackground(.hidden)
        .autocorrectionDisabled().textInputAutocapitalization(.never)
        .padding(8).frame(minHeight: 130).background(Palette.ink)
        .clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityIdentifier("fieldNotes")
        Text("Notes autosave on this iPad. Save evening to update the library copy.")
          .font(.system(size: 10)).foregroundStyle(Palette.muted)
        Button {
          exportURL = store.export()
        } label: {
          Label("Export field guide", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(InstrumentButton()).accessibilityIdentifier("exportPlan")
        if let exportURL {
          ShareLink(item: exportURL) { Label("Share Markdown", systemImage: "arrow.up.doc") }
            .font(.system(size: 12)).foregroundStyle(Palette.gold)
          Text("Export ready in Files › On My iPad › Celestia.")
            .font(.system(size: 10)).foregroundStyle(Palette.mint)
        }
        Button {
          store.newPlan()
        } label: {
          Label("New evening", systemImage: "plus")
        }
        .buttonStyle(InstrumentButton())
      }.padding(.horizontal, 19).padding(.bottom, 20)
    }
  }

  private var mapToolbar: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Eyebrow(text: "01 / Sky atlas")
        Text("A window into tonight").font(.system(size: 22, design: .serif))
      }
      Spacer()
      Menu {
        Button("All constellations") { constellation = "All constellations" }
        ForEach(Array(Set(Catalog.stars.map(\.constellation))).sorted(), id: \.self) { name in
          Button(name) { constellation = name }
        }
      } label: {
        HStack(spacing: 7) {
          Text(constellation)
          Image(systemName: "chevron.down").font(.system(size: 8))
        }
        .font(.system(size: 11)).foregroundStyle(Palette.gold)
      }.accessibilityIdentifier("constellationFilter")
      Button {
        showLines.toggle()
      } label: {
        Image(systemName: "point.3.connected.trianglepath.dotted").foregroundStyle(
          showLines ? Palette.gold : Palette.muted
        )
        .frame(width: 42, height: 42).background(Palette.raised).clipShape(
          RoundedRectangle(cornerRadius: 8))
      }.accessibilityLabel(showLines ? "Hide constellation lines" : "Show constellation lines")
    }.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 4)
  }

  private var inspector: some View {
    let star = store.selected
    let position = Astronomy.position(star, at: store.plan.date, site: store.plan.site)
    let queued = store.plan.targets.contains(star.id)
    return ScrollView {
      VStack(alignment: .leading, spacing: 17) {
        HStack {
          Eyebrow(text: "Selected object")
          Spacer()
          Image(systemName: "scope").foregroundStyle(Palette.gold)
        }
        VStack(alignment: .leading, spacing: 5) {
          Text(star.name).font(.system(size: 34, design: .serif)).minimumScaleFactor(0.7).lineLimit(
            1)
          Text("\(star.designation)  ·  \(star.constellation)").font(.system(size: 11))
            .foregroundStyle(Palette.gold)
        }
        HStack(spacing: 6) {
          Circle().fill(position.altitude >= 0 ? Palette.mint : Palette.muted).frame(
            width: 5, height: 5)
          Text(position.altitude >= 0 ? "ABOVE THE HORIZON" : "BELOW THE HORIZON").font(
            .system(size: 8, design: .monospaced)
          ).tracking(1)
        }.foregroundStyle(position.altitude >= 0 ? Palette.mint : Palette.muted)
        HStack {
          metric("ALTITUDE", value: String(format: "%.1f°", position.altitude))
          Spacer()
          metric(
            "AZIMUTH",
            value: String(format: "%.0f° %@", position.azimuth, Astronomy.compass(position.azimuth))
          )
        }
        Rectangle().fill(Palette.line).frame(height: 1)
        Text(star.story).font(.system(size: 12)).lineSpacing(4).foregroundStyle(Palette.muted)
          .fixedSize(horizontal: false, vertical: true)
        HStack {
          Text("MAG \(String(format: "%.2f", star.magnitude))")
          Spacer()
          Text(star.distance)
        }.font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.ivory.opacity(0.8))
        VStack(alignment: .leading, spacing: 12) {
          Eyebrow(text: "Altitude / ±6 hours")
          AltitudePlot(star: star, date: store.plan.date, site: store.plan.site)
        }
        Button {
          store.toggleTarget(star)
        } label: {
          Label(
            queued ? "Remove from evening" : "Add to evening",
            systemImage: queued ? "bookmark.fill" : "plus"
          )
          .frame(maxWidth: .infinity)
        }.buttonStyle(InstrumentButton(active: !queued)).accessibilityIdentifier("toggleTarget")
        Text(String(format: "RA %.3fh  /  DEC %+.2f°", star.ra, star.dec))
          .font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
      }.padding(17)
    }.background(Palette.panel.opacity(0.88)).clipShape(RoundedRectangle(cornerRadius: 13))
      .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.line, lineWidth: 1))
      .padding(.vertical, 20)
  }

  private func metric(_ label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.system(size: 8, design: .monospaced)).tracking(1.4).foregroundStyle(
        Palette.muted)
      Text(value).font(.system(size: 21, weight: .light, design: .monospaced)).minimumScaleFactor(
        0.7
      ).lineLimit(1)
    }
  }

  private var timeline: some View {
    let start = Date(
      timeIntervalSince1970: floor(store.plan.date.timeIntervalSince1970 / 86400) * 86400)
    let anchor = scrubAnchor ?? start
    return HStack(spacing: 20) {
      ZStack {
        Circle().stroke(Palette.line, lineWidth: 1)
        ForEach(0..<48) { tick in
          Rectangle().fill(tick.isMultiple(of: 6) ? Palette.gold : Palette.line)
            .frame(width: 1, height: tick.isMultiple(of: 6) ? 6 : 3)
            .offset(y: -37).rotationEffect(.degrees(Double(tick) * 7.5))
        }
        Image(systemName: "moon.stars").font(.system(size: 23, weight: .ultraLight))
          .foregroundStyle(Palette.gold)
        Circle().fill(Palette.gold).frame(width: 5, height: 5).offset(y: -37)
          .rotationEffect(.degrees(store.plan.date.timeIntervalSince(start) / 86400 * 360))
      }.frame(width: 80, height: 80)
      VStack(alignment: .leading, spacing: 9) {
        HStack {
          Button {
            sheet = .date
          } label: {
            VStack(alignment: .leading, spacing: 3) {
              Text(
                Astronomy.formatted(
                  store.plan.date, site: store.plan.site, pattern: "EEEE, d MMMM yyyy")
              )
              .font(.system(size: 12, design: .serif)).foregroundStyle(Palette.ivory)
              Text(
                Astronomy.formatted(store.plan.date, site: store.plan.site, pattern: "HH:mm zzz")
              )
              .font(.system(size: 26, weight: .light, design: .monospaced)).foregroundStyle(
                Palette.gold)
            }
          }.buttonStyle(.plain).accessibilityLabel("Choose observing date and time")
          Spacer()
          Button {
            store.change { $0.date = $0.date.addingTimeInterval(-3600) }
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "chevron.left")
              Text("1h")
            }
          }
          .buttonStyle(InstrumentButton()).accessibilityLabel("One hour earlier")
          Button {
            store.change { $0.date = $0.date.addingTimeInterval(3600) }
          } label: {
            HStack(spacing: 8) {
              Text("1h")
              Image(systemName: "chevron.right")
            }
          }
          .buttonStyle(InstrumentButton()).accessibilityLabel("One hour later")
        }
        Slider(
          value: Binding(
            get: { store.plan.date.timeIntervalSince(anchor) },
            set: { store.archive.working.date = anchor.addingTimeInterval($0) }), in: 0...86399,
          step: 300
        ) { editing in
          if editing {
            store.checkpoint()
            scrubAnchor = start
          } else {
            scrubAnchor = nil
          }
        }.tint(Palette.gold).accessibilityLabel("Scrub time over a UTC day")
          .accessibilityIdentifier("timeScrubber")
        HStack {
          Text("00 UTC")
          Spacer()
          Text("06")
          Spacer()
          Text("12")
          Spacer()
          Text("18")
          Spacer()
          Text("24 UTC")
        }.font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
      }
    }.padding(.horizontal, 25).padding(.vertical, 16)
      .background(Palette.panel)
      .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
  }

  private var footer: some View {
    HStack(spacing: 15) {
      Text("CELESTIA  /  FIELD EDITION").font(.system(size: 8, design: .monospaced)).tracking(1.5)
      Rectangle().fill(Palette.line).frame(width: 1, height: 12)
      Text(store.notice ?? "Offline by design. Made for unhurried nights.").font(.system(size: 10))
        .lineLimit(1)
      Spacer()
      Button {
        store.undo()
      } label: {
        Label("Undo", systemImage: "arrow.uturn.backward")
      }
      .disabled(!store.canUndo).accessibilityIdentifier("undoChange")
      Button {
        sheet = .about
      } label: {
        Label("Sky conventions", systemImage: "info.circle")
      }
    }.font(.system(size: 10)).foregroundStyle(Palette.muted)
      .padding(.horizontal, 23).frame(height: 37)
      .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
  }

  @ViewBuilder private func sheetContent(_ item: ObservatorySheet) -> some View {
    NavigationStack {
      Group {
        switch item {
        case .location:
          List(ObservingSite.all) { site in
            Button {
              store.change { $0.siteID = site.id }
              sheet = nil
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 7) {
                  Text(site.name).font(.system(size: 23, design: .serif)).foregroundStyle(
                    Palette.ivory)
                  Text(site.region).font(.system(size: 12)).foregroundStyle(Palette.muted)
                  Text(
                    String(
                      format: "%+.4f° latitude   %+.4f° longitude", site.latitude, site.longitude)
                  )
                  .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.gold)
                }.padding(.vertical, 10)
                Spacer()
                if store.plan.siteID == site.id {
                  Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.gold)
                }
              }
            }.listRowBackground(Palette.panel)
          }.navigationTitle("Choose your horizon")
        case .library:
          List {
            Section("Saved on this iPad") {
              ForEach(store.archive.saved) { plan in
                Button {
                  store.open(plan)
                  tab = 1
                  sheet = nil
                } label: {
                  VStack(alignment: .leading, spacing: 8) {
                    Text(plan.name).font(.system(size: 23, design: .serif)).foregroundStyle(
                      Palette.ivory)
                    Text(
                      "\(plan.site.name) · \(plan.targets.count) targets · \(Astronomy.formatted(plan.date, site: plan.site, pattern: "d MMM yyyy"))"
                    )
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
                    Text(plan.notes).lineLimit(2).font(.system(size: 12)).foregroundStyle(
                      Palette.gold)
                  }.padding(.vertical, 12)
                }.listRowBackground(Palette.panel)
              }
            }
            Section {
              Text(
                "Open a plan to restore its site, time, targets and notes. Undo returns to the evening you left."
              )
              .font(.system(size: 13)).foregroundStyle(Palette.muted)
            }.listRowBackground(Palette.panel)
          }.navigationTitle("Your saved evenings")
        case .save:
          Form {
            Section("Evening name") {
              TextField("Name your evening", text: $saveName)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .accessibilityIdentifier("planName")
            }.listRowBackground(Palette.panel)
            Section {
              Text(
                "\(store.plan.targets.count) targets, field notes, location and observing time will be saved together."
              )
              Button("Save evening") {
                store.save(named: saveName)
                if !saveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { sheet = nil }
              }.foregroundStyle(Palette.gold).accessibilityIdentifier("confirmSave")
                .disabled(saveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.listRowBackground(Palette.panel)
          }.navigationTitle("Keep this evening")
        case .date:
          Form {
            Section("Observing time · \(store.plan.site.timeZone)") {
              DatePicker(
                "Local date & time",
                selection: Binding(
                  get: { store.plan.date }, set: { date in store.change { $0.date = date } })
              )
              .environment(\.timeZone, TimeZone(identifier: store.plan.site.timeZone) ?? .gmt)
              Button("Use current time") {
                store.change { $0.date = Date() }
                sheet = nil
              }
              Button("Restore sample evening") {
                store.change { $0.date = ObservingPlan.sample.date }
                sheet = nil
              }
            }.listRowBackground(Palette.panel)
            Section {
              Text(
                "The slider spans one UTC day in five-minute increments. The large clock always shows local time at your observing site; local dates may cross midnight. Positions also update in daylight: a star above the horizon may still be invisible."
              )
            }.listRowBackground(Palette.panel)
          }.navigationTitle("Travel through the night")
        case .about:
          ScrollView {
            VStack(alignment: .leading, spacing: 22) {
              Text("A little observatory,\nwherever you are.").font(
                .system(size: 34, design: .serif))
              aboutSection(
                "READING THE ATLAS",
                "An azimuthal equidistant view of the visible hemisphere: zenith at the center, horizon at the rim, north up and east left as you look overhead. Drag to pan; pinch or use + / − to zoom. The scope button recenters the view."
              )
              aboutSection(
                "A REAL, SMALL SKY",
                "\(Catalog.stars.count) recognizable stars with rounded J2000 right ascension and declination. Fine gold lines connect selected constellations; the dashed triangle links Vega, Deneb and Altair. Only catalog stars are drawn. Distances and variable magnitudes are approximate."
              )
              aboutSection(
                "TIME & POSITION",
                "Greenwich mean sidereal time and spherical trigonometry produce geometric altitude and azimuth. Azimuth is measured clockwise eastward from north. This V1 omits precession, nutation, proper motion, atmospheric refraction, terrain, weather, the Sun, Moon and planets. It is a visual planning aid, not telescope-pointing software."
              )
              aboutSection(
                "VISIBILITY IS NOT DARKNESS",
                "Above horizon means altitude ≥ 0°. It does not predict a dark sky or naked-eye visibility. The horizon glow is art direction, not a twilight simulation. The plot spans ±6 hours and −90° to +90°, with the dashed line at the horizon."
              )
              aboutSection(
                "YOUR EVENING, KEPT LOCALLY",
                "Your working plan autosaves. Save evening updates the library copy; New evening creates a separate plan. Undo restores changes for this session, including removed targets and reopened plans. Notes autosave as you type. Export produces real Markdown in the app’s Documents folder, available in Files."
              )
            }.padding(30)
          }.navigationTitle("Sky conventions")
        }
      }
      .scrollContentBackground(.hidden).background(Palette.ink)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { sheet = nil }.foregroundStyle(Palette.gold)
        }
      }
      .toolbarBackground(Palette.panel, for: .navigationBar)
    }.tint(Palette.gold).preferredColorScheme(.dark)
  }

  private func aboutSection(_ title: String, _ body: String) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      Eyebrow(text: title)
      Text(body).font(.system(size: 14)).lineSpacing(5).foregroundStyle(Palette.muted)
    }
  }
}
