import SwiftUI

/// The "globe" hub: map with waterway pins, current location card and menu rail.
struct HomeView: View {
  @EnvironmentObject var store: GameStore
  @State private var selected: String?

  private var selectedWaterway: Waterway {
    WaterwayCatalog.find(selected ?? store.profile.currentWaterwayID)
  }

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.03, green: 0.10, blue: 0.20), Color(red: 0.01, green: 0.04, blue: 0.10)],
        startPoint: .top, endPoint: .bottom
      ).ignoresSafeArea()

      VStack(spacing: 10) {
        HStack {
          Text("REEL HORIZON").font(Theme.display(26)).kerning(2).foregroundStyle(Theme.ink)
            .lineLimit(1).fixedSize()
            .shadow(color: Theme.cyan.opacity(0.6), radius: 6)
          Text("DAY \(store.profile.gameDay)").font(Theme.mono(12)).foregroundStyle(Theme.gold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Theme.panelLight)).overlay(Capsule().strokeBorder(Theme.panelStroke))
          Spacer()
          PlayerStrip()
        }
        HStack(spacing: 14) {
          MapView(
            waterways: WaterwayCatalog.all, profile: store.profile, selected: selected ?? store.profile.currentWaterwayID
          ) { waterway in
            withAnimation(.spring(response: 0.3)) { selected = waterway.id }
          }
          .panel(padding: 6, radius: 12)
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier("home.map")

          VStack(spacing: 10) {
            WaterwayCard(waterway: selectedWaterway)
            Spacer(minLength: 0)
            MenuRail()
          }
          .frame(width: 300)
        }
      }
      .padding(14)
    }
  }
}

struct WaterwayCard: View {
  @EnvironmentObject var store: GameStore
  let waterway: Waterway

  var body: some View {
    let locked = store.profile.level < waterway.requiredLevel
    let license = store.profile.license(for: waterway.id)
    VStack(alignment: .leading, spacing: 8) {
      ZStack(alignment: .bottomLeading) {
        SceneryView(waterway: waterway, weather: waterway.forecast.kind, dayProgress: 0.32, session: nil, splash: nil)
          .frame(height: 96)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        VStack(alignment: .leading, spacing: 0) {
          Text(waterway.name).font(Theme.display(20)).textCase(.uppercase).foregroundStyle(.white)
          Text("\(waterway.region), \(waterway.country)").font(Theme.body(11)).foregroundStyle(Theme.inkDim)
        }
        .padding(8)
        if locked {
          HStack(spacing: 4) {
            Image(systemName: "lock.fill"); Text("LEVEL \(waterway.requiredLevel)")
          }
          .font(Theme.display(12)).foregroundStyle(.black)
          .padding(.horizontal, 8).padding(.vertical, 4)
          .background(Capsule().fill(Theme.gold))
          .padding(8)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
      }
      HStack(spacing: 14) {
        stat("thermometer.medium", "\(waterway.forecast.airTempF)°F")
        stat("wind", "\(Int(waterway.forecast.windMph)) mph")
        stat("cloud.sun.fill", waterway.forecast.kind.label)
      }
      HStack {
        Text("Travel").capsLabel(11)
        Spacer()
        if waterway.travelFee == 0 { Text("FREE").font(Theme.mono(12)).foregroundStyle(Theme.green) } else { CurrencyChip(kind: .credits, amount: waterway.travelFee, size: 12) }
      }
      HStack {
        Text("License").capsLabel(11)
        Spacer()
        if let license {
          Text("\(license.advanced ? "ADVANCED" : "BASIC") · \(license.daysRemaining)d").font(Theme.mono(12)).foregroundStyle(Theme.green)
        } else {
          Text("NONE").font(Theme.mono(12)).foregroundStyle(Theme.red)
        }
      }
      HStack(spacing: 4) {
        ForEach(waterway.species.prefix(6)) { species in
          FishIllustration(coloring: species.coloring).frame(width: 36, height: 20)
        }
        if waterway.species.count > 6 {
          Text("+\(waterway.species.count - 6)").font(Theme.mono(11)).foregroundStyle(Theme.inkDim)
        }
      }
      ChromeButton(title: locked ? "Locked" : "Waterway info", icon: locked ? "lock.fill" : "info.circle", tone: locked ? .slate : .cyan, minWidth: 0, disabled: locked) {
        store.go(.location(waterway.id))
      }
      .frame(maxWidth: .infinity)
      .accessibilityIdentifier("home.waterwayInfo")
    }
    .panel(padding: 10, radius: 12)
  }

  private func stat(_ icon: String, _ text: String) -> some View {
    HStack(spacing: 4) {
      Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.cyan)
      Text(text).font(Theme.body(11)).foregroundStyle(Theme.ink)
    }
  }
}

struct MenuRail: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    HStack(spacing: 8) {
      railButton("cart.fill", "Shop", "home.shop") { store.go(.shop) }
      railButton("flag.checkered", "Missions", "home.missions", badge: store.profile.claimableMissionCount) { store.go(.missions) }
      railButton("person.fill", "Angler", "home.profile") { store.go(.profile) }
    }
  }

  private func railButton(_ icon: String, _ title: String, _ id: String, badge: Int = 0, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.cyan)
        Text(title).font(Theme.display(12)).textCase(.uppercase).foregroundStyle(Theme.ink)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(RoundedRectangle(cornerRadius: 8).fill(Theme.panel))
      .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.panelStroke))
      .overlay(alignment: .topTrailing) {
        if badge > 0 {
          Text("\(badge)").font(Theme.mono(10)).foregroundStyle(.white).padding(4)
            .background(Circle().fill(Theme.red)).offset(x: 4, y: -4)
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
        .blur(radius: 3)
      Color.black.opacity(0.45).ignoresSafeArea()
      VStack(spacing: 12) {
        HeaderBar(title: waterway.displayTitle)
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 10) {
            Text(waterway.description).font(Theme.body(13, weight: .medium)).foregroundStyle(Theme.ink)
              .fixedSize(horizontal: false, vertical: true)
            forecastRow
            Text("Fish species").capsLabel(12, color: Theme.cyan)
            ScrollView {
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 6)], spacing: 6) {
                ForEach(waterway.species) { species in
                  SpeciesRow(species: species, caught: store.profile.stats.speciesCaught.contains(species.id), restricted: waterway.mustReleaseBasic.contains(species.id))
                }
              }
            }
          }
          .panel(padding: 12, radius: 12)

          VStack(alignment: .leading, spacing: 10) {
            Text("Licenses").capsLabel(12, color: Theme.cyan)
            if let license = store.profile.license(for: waterway.id) {
              HStack {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.green)
                Text("\(license.advanced ? "Advanced" : "Basic") license · \(license.daysRemaining) day\(license.daysRemaining == 1 ? "" : "s") left")
                  .font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.ink)
              }
            }
            ScrollView {
              VStack(alignment: .leading, spacing: 8) {
                ForEach(waterway.licenses) { option in
                  LicenseRow(option: option, waterway: waterway)
                }
                Text("Advanced licenses lift the release rule on \(waterway.mustReleaseBasic.map { SpeciesCatalog.find($0).name }.joined(separator: ", ")).")
                  .font(Theme.body(10)).foregroundStyle(Theme.inkDim)
              }
            }
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text("Trip cost").capsLabel(11)
                if waterway.travelFee == 0 { Text("FREE").font(Theme.mono(14)).foregroundStyle(Theme.green) } else { CurrencyChip(kind: .credits, amount: waterway.travelFee) }
                Text("Rig: \(store.profile.rig.lure.name)").font(Theme.body(11)).foregroundStyle(Theme.inkDim).lineLimit(1)
              }
              Spacer()
              ChromeButton(title: "Go fishing", icon: "figure.fishing", tone: .green, size: 17) {
                store.travelAndFish(waterway)
              }
              .accessibilityIdentifier("location.goFishing")
            }
          }
          .frame(width: 330)
          .panel(padding: 12, radius: 12)
        }
      }
      .padding(14)
    }
  }

  private var forecastRow: some View {
    let f = waterway.forecast
    return HStack(spacing: 14) {
      forecast("cloud.sun.fill", f.kind.label)
      forecast("thermometer.medium", "Air \(f.airTempF)°F")
      forecast("drop.fill", "Water \(f.waterTempF)°F")
      forecast("wind", "\(f.windDirection) \(Int(f.windMph)) mph")
      forecast("barometer", String(format: "%.2f inHg", f.pressureInHg))
    }
  }

  private func forecast(_ icon: String, _ text: String) -> some View {
    HStack(spacing: 4) {
      Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold)
      Text(text).font(Theme.body(11, weight: .bold)).foregroundStyle(Theme.ink)
    }
  }
}

struct SpeciesRow: View {
  let species: Species
  let caught: Bool
  let restricted: Bool

  var body: some View {
    HStack(spacing: 8) {
      FishIllustration(coloring: species.coloring).frame(width: 46, height: 26)
        .saturation(caught ? 1 : 0.2)
      VStack(alignment: .leading, spacing: 1) {
        Text(species.name).font(Theme.body(12, weight: .bold)).foregroundStyle(caught ? Theme.ink : Theme.inkDim)
        Text("\(species.minWeightLb.lbOz) – \(species.maxWeightLb.lbOz)").font(Theme.mono(9)).foregroundStyle(Theme.inkDim)
      }
      Spacer(minLength: 0)
      if restricted { Image(systemName: "arrow.uturn.backward.circle").font(.system(size: 12)).foregroundStyle(Theme.orange) }
    }
    .padding(6)
    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
  }
}

struct LicenseRow: View {
  @EnvironmentObject var store: GameStore
  let option: LicenseOption
  let waterway: Waterway

  var body: some View {
    HStack {
      Image(systemName: option.advanced ? "star.circle.fill" : "doc.text.fill").foregroundStyle(option.advanced ? Theme.gold : Theme.cyan)
      Text("\(option.advanced ? "Advanced" : "Basic") · \(option.durationLabel)").font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.ink)
      Spacer()
      CurrencyChip(kind: .credits, amount: option.price, size: 12)
      ChromeButton(title: "Buy", tone: .gold, size: 11, minWidth: 54, disabled: store.profile.credits < option.price) {
        store.buyLicense(option, for: waterway)
      }
      .accessibilityIdentifier("license.\(option.id)")
    }
  }
}
