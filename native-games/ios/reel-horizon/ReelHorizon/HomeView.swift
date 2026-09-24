import SwiftUI

/// The "globe" hub: map with waterway pins, current location card and menu rail.
struct HomeView: View {
  @EnvironmentObject var store: GameStore
  @State private var selected: String?

  private var selectedWaterway: Waterway {
    WaterwayCatalog.find(selected ?? store.profile.currentWaterwayID)
  }

  var body: some View {
    let unlocked = WaterwayCatalog.all.filter { store.profile.level >= $0.requiredLevel }.count
    ZStack {
      ScreenBackground()

      VStack(spacing: 10) {
        HStack(spacing: 12) {
          AppMark(size: 40)
          VStack(alignment: .leading, spacing: 0) {
            Text("REEL HORIZON").font(Theme.display(26)).kerning(2.5).foregroundStyle(Theme.ink)
              .lineLimit(1).fixedSize()
              .shadow(color: Theme.cyan.opacity(0.5), radius: 8)
            HStack(spacing: 6) {
              Text("DAY \(store.profile.gameDay)").font(Theme.mono(10)).foregroundStyle(Theme.gold)
              Circle().fill(Theme.inkDim.opacity(0.5)).frame(width: 3, height: 3)
              Text("\(unlocked) of \(WaterwayCatalog.all.count) waterways open").font(Theme.body(10)).foregroundStyle(Theme.inkDim)
            }
            .lineLimit(1).fixedSize()
          }
          Spacer()
          PlayerStrip()
        }
        .frame(height: 46)

        HStack(spacing: 12) {
          ZStack(alignment: .topLeading) {
            MapView(
              waterways: WaterwayCatalog.all, profile: store.profile, selected: selected ?? store.profile.currentWaterwayID
            ) { waterway in
              withAnimation(.spring(response: 0.3)) { selected = waterway.id }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.map")
            mapLegend.padding(10).allowsHitTesting(false)
          }
          .panel(padding: 6, radius: 18)

          VStack(spacing: 10) {
            WaterwayCard(waterway: selectedWaterway)
              .id(selectedWaterway.id)
              .transition(.opacity.combined(with: .move(edge: .trailing)))
            Spacer(minLength: 0)
            MenuRail()
          }
          .frame(width: 300)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
    }
  }

  private var mapLegend: some View {
    HStack(spacing: 10) {
      legendDot(Theme.gold, "You")
      legendDot(Theme.cyan, "Open")
      legendDot(Color(red: 0.4, green: 0.43, blue: 0.48), "Locked")
    }
    .font(Theme.body(9, weight: .bold))
    .foregroundStyle(Theme.inkDim)
    .padding(.horizontal, 10).padding(.vertical, 5)
    .background(Capsule().fill(Theme.night.opacity(0.7)))
    .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
  }

  private func legendDot(_ color: Color, _ label: String) -> some View {
    HStack(spacing: 4) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(label.uppercased())
    }
  }
}

struct WaterwayCard: View {
  @EnvironmentObject var store: GameStore
  let waterway: Waterway

  var body: some View {
    let locked = store.profile.level < waterway.requiredLevel
    let license = store.profile.license(for: waterway.id)
    VStack(alignment: .leading, spacing: 7) {
      ZStack(alignment: .bottomLeading) {
        SceneryView(waterway: waterway, weather: waterway.forecast.kind, dayProgress: 0.32, session: nil, splash: nil)
          .frame(height: 84)
          .saturation(locked ? 0.35 : 1)
        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
        VStack(alignment: .leading, spacing: 1) {
          Text(waterway.name).font(Theme.display(21)).textCase(.uppercase).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
          HStack(spacing: 4) {
            Image(systemName: "mappin.and.ellipse").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.cyan)
            Text("\(waterway.region), \(waterway.country)").font(Theme.body(10)).foregroundStyle(Theme.ink.opacity(0.85)).lineLimit(1)
          }
        }
        .padding(10)
        HStack(spacing: 4) {
          Image(systemName: locked ? "lock.fill" : "checkmark.circle.fill")
          Text(locked ? "LEVEL \(waterway.requiredLevel)" : "OPEN")
        }
        .font(Theme.display(11)).foregroundStyle(locked ? .black : Theme.night)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(locked ? Theme.gold : Theme.green))
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
      }
      .frame(height: 84)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.12)))

      HStack(spacing: 6) {
        miniStat("thermometer.medium", "\(waterway.forecast.airTempF)°F")
        miniStat("wind", "\(Int(waterway.forecast.windMph)) mph")
        miniStat("cloud.sun.fill", waterway.forecast.kind.label)
      }

      HStack(spacing: 8) {
        infoPill("Travel") {
          if waterway.travelFee == 0 { Text("FREE").font(Theme.mono(11)).foregroundStyle(Theme.green) } else { CurrencyChip(kind: .credits, amount: waterway.travelFee, size: 11) }
        }
        infoPill("License") {
          if let license {
            Text("\(license.advanced ? "ADV" : "BASIC") · \(license.daysRemaining)d").font(Theme.mono(11)).foregroundStyle(Theme.green)
          } else {
            Text("NONE").font(Theme.mono(11)).foregroundStyle(Theme.orange)
          }
        }
      }

      HStack(spacing: 2) {
        ForEach(waterway.species.prefix(6)) { species in
          FishIllustration(coloring: species.coloring).frame(width: 30, height: 16)
        }
        Spacer(minLength: 0)
        Text("\(waterway.species.count) species").font(Theme.mono(9)).foregroundStyle(Theme.inkDim)
      }

      ChromeButton(title: locked ? "Locked" : "Waterway info", icon: locked ? "lock.fill" : "arrow.right.circle.fill", tone: locked ? .slate : .cyan, minWidth: 0, disabled: locked) {
        store.go(.location(waterway.id))
      }
      .frame(maxWidth: .infinity)
      .accessibilityIdentifier("home.waterwayInfo")
    }
    .panel(padding: 10, radius: 18)
  }

  private func miniStat(_ icon: String, _ text: String) -> some View {
    HStack(spacing: 4) {
      Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.cyan)
      Text(text).font(Theme.body(10, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
    }
    .padding(.horizontal, 7).padding(.vertical, 4)
    .background(Capsule().fill(Color.white.opacity(0.06)))
  }

  private func infoPill<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
    HStack {
      Text(label).capsLabel(9)
      Spacer(minLength: 2)
      value()
    }
    .padding(.horizontal, 8).padding(.vertical, 6)
    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.045)))
  }
}

struct MenuRail: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    HStack(spacing: 8) {
      railButton("cart.fill", "Shop", "home.shop", tint: Theme.gold) { store.go(.shop) }
      railButton("flag.checkered", "Missions", "home.missions", tint: Theme.green, badge: store.profile.claimableMissionCount) { store.go(.missions) }
      railButton("person.crop.circle.fill", "Angler", "home.profile", tint: Theme.cyan) { store.go(.profile) }
    }
  }

  private func railButton(_ icon: String, _ title: String, _ id: String, tint: Color, badge: Int = 0, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(tint)
          .frame(width: 32, height: 32)
          .background(Circle().fill(tint.opacity(0.14)))
        Text(title).font(Theme.display(12)).textCase(.uppercase).kerning(0.8).foregroundStyle(Theme.ink)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 7)
      .panel(padding: 0, radius: 14)
      .overlay(alignment: .topTrailing) {
        if badge > 0 {
          Text("\(badge)").font(Theme.mono(10)).foregroundStyle(.white).frame(minWidth: 18, minHeight: 18)
            .background(Circle().fill(Theme.red)).overlay(Circle().strokeBorder(.white.opacity(0.6)))
            .offset(x: 4, y: -4)
        }
      }
    }
    .buttonStyle(PressStyle())
    .accessibilityIdentifier(id)
  }
}

// MARK: - Location detail

struct LocationView: View {
  @EnvironmentObject var store: GameStore
  let waterway: Waterway

  var body: some View {
    ZStack {
      SceneryView(waterway: waterway, weather: waterway.forecast.kind, dayProgress: 0.28, session: nil, splash: nil)
        .blur(radius: 6)
        .ignoresSafeArea()
      LinearGradient(colors: [Theme.night.opacity(0.55), Theme.night.opacity(0.85)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
      VStack(spacing: 10) {
        HeaderBar(title: waterway.name, subtitle: "\(waterway.region), \(waterway.country)")
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 10) {
            Text(waterway.description).font(Theme.body(12, weight: .medium)).foregroundStyle(Theme.ink.opacity(0.9))
              .lineLimit(3)
              .fixedSize(horizontal: false, vertical: true)
            forecastRow
            SectionHeader(title: "Fish species", icon: "fish.fill", trailing: "\(waterway.species.filter { store.profile.stats.speciesCaught.contains($0.id) }.count)/\(waterway.species.count) caught")
            ScrollView {
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 6)], spacing: 6) {
                ForEach(waterway.species) { species in
                  SpeciesRow(species: species, caught: store.profile.stats.speciesCaught.contains(species.id), restricted: waterway.mustReleaseBasic.contains(species.id))
                }
              }
            }
          }
          .panel(padding: 12, radius: 18)

          VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Licenses", icon: "doc.text.fill", tint: Theme.gold)
            if let license = store.profile.license(for: waterway.id) {
              HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.green)
                Text("\(license.advanced ? "Advanced" : "Basic") license").font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(license.daysRemaining) day\(license.daysRemaining == 1 ? "" : "s") left").font(Theme.mono(10)).foregroundStyle(Theme.green)
              }
              .padding(8)
              .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.green.opacity(0.12)))
              .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.green.opacity(0.35)))
            }
            ScrollView {
              VStack(alignment: .leading, spacing: 6) {
                ForEach(waterway.licenses) { option in
                  LicenseRow(option: option, waterway: waterway)
                }
                if !waterway.mustReleaseBasic.isEmpty {
                  Label("Advanced licenses let you keep \(waterway.mustReleaseBasic.map { SpeciesCatalog.find($0).name }.joined(separator: ", ")).", systemImage: "info.circle")
                    .font(Theme.body(10)).foregroundStyle(Theme.inkDim)
                    .padding(.top, 2)
                }
              }
            }
            HStack(spacing: 10) {
              VStack(alignment: .leading, spacing: 2) {
                Text("Trip cost").capsLabel(10)
                if waterway.travelFee == 0 { Text("FREE").font(Theme.mono(15)).foregroundStyle(Theme.green) } else { CurrencyChip(kind: .credits, amount: waterway.travelFee, size: 15) }
                HStack(spacing: 3) {
                  Image(systemName: "sparkle").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.gold)
                  Text(store.profile.rig.lure.name).font(Theme.body(10)).foregroundStyle(Theme.inkDim).lineLimit(1)
                }
              }
              Spacer(minLength: 0)
              ChromeButton(title: "Go fishing", icon: "figure.fishing", tone: .green, size: 17, minWidth: 150) {
                store.travelAndFish(waterway)
              }
              .accessibilityIdentifier("location.goFishing")
            }
            .padding(.top, 8)
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
          }
          .frame(width: 330)
          .panel(padding: 12, radius: 18)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
    }
  }

  private var forecastRow: some View {
    let f = waterway.forecast
    return HStack(spacing: 6) {
      forecastTile("cloud.sun.fill", "Sky", f.kind.label, Theme.gold)
      forecastTile("thermometer.medium", "Air", "\(f.airTempF)°F", Theme.orange)
      forecastTile("drop.fill", "Water", "\(f.waterTempF)°F", Theme.cyan)
      forecastTile("wind", "Wind", "\(f.windDirection) \(Int(f.windMph)) mph", Theme.ink)
      forecastTile("barometer", "Pressure", String(format: "%.2f", f.pressureInHg), Theme.green)
    }
  }

  private func forecastTile(_ icon: String, _ label: String, _ value: String, _ tint: Color) -> some View {
    VStack(spacing: 3) {
      Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
      Text(value).font(Theme.body(11, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
      Text(label).capsLabel(8).lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 7)
    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.045)))
  }
}

struct SpeciesRow: View {
  let species: Species
  let caught: Bool
  let restricted: Bool

  var body: some View {
    HStack(spacing: 8) {
      FishIllustration(coloring: species.coloring).frame(width: 44, height: 24)
        .saturation(caught ? 1 : 0.35)
        .opacity(caught ? 1 : 0.8)
      VStack(alignment: .leading, spacing: 1) {
        Text(species.name).font(Theme.body(11, weight: .bold)).foregroundStyle(caught ? Theme.ink : Theme.ink.opacity(0.8)).lineLimit(1).minimumScaleFactor(0.8)
        Text("up to \(species.maxWeightLb.lbOz)").font(Theme.mono(9, weight: .medium)).foregroundStyle(Theme.inkDim).lineLimit(1)
      }
      Spacer(minLength: 0)
      if caught { Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.green) }
      if restricted { Image(systemName: "arrow.uturn.backward.circle.fill").font(.system(size: 11)).foregroundStyle(Theme.orange) }
    }
    .padding(.horizontal, 6).padding(.vertical, 5)
    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.045)))
    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(caught ? Theme.green.opacity(0.3) : .white.opacity(0.05)))
  }
}

struct LicenseRow: View {
  @EnvironmentObject var store: GameStore
  let option: LicenseOption
  let waterway: Waterway

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: option.advanced ? "star.circle.fill" : "doc.text.fill")
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(option.advanced ? Theme.gold : Theme.cyan)
        .frame(width: 26, height: 26)
        .background(Circle().fill((option.advanced ? Theme.gold : Theme.cyan).opacity(0.14)))
      VStack(alignment: .leading, spacing: 0) {
        Text(option.advanced ? "Advanced" : "Basic").font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.ink)
        Text(option.durationLabel).font(Theme.mono(9, weight: .medium)).foregroundStyle(Theme.inkDim)
      }
      Spacer()
      CurrencyChip(kind: .credits, amount: option.price, size: 12)
      ChromeButton(title: "Buy", tone: .gold, size: 11, minWidth: 54, disabled: store.profile.credits < option.price) {
        store.buyLicense(option, for: waterway)
      }
      .accessibilityIdentifier("license.\(option.id)")
    }
    .padding(6)
    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
  }
}
