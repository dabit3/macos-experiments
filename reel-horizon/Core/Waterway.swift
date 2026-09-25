import Foundation

public enum WeatherKind: String, Codable, CaseIterable, Hashable {
  case sunny, partlyCloudy, overcast, rain, fog

  public var label: String {
    switch self {
    case .sunny: return "Sunny"
    case .partlyCloudy: return "Partly Cloudy"
    case .overcast: return "Overcast"
    case .rain: return "Light Rain"
    case .fog: return "Morning Fog"
    }
  }

  /// Multiplier on bite frequency.
  public var biteFactor: Double {
    switch self {
    case .sunny: return 0.9
    case .partlyCloudy: return 1.05
    case .overcast: return 1.15
    case .rain: return 1.2
    case .fog: return 1.0
    }
  }
}

public struct WeatherForecast: Codable, Hashable {
  public let kind: WeatherKind
  public let airTempF: Int
  public let waterTempF: Int
  public let windMph: Double
  public let windDirection: String
  public let pressureInHg: Double

  public init(
    kind: WeatherKind, airTempF: Int, waterTempF: Int, windMph: Double, windDirection: String,
    pressureInHg: Double
  ) {
    self.kind = kind
    self.airTempF = airTempF
    self.waterTempF = waterTempF
    self.windMph = windMph
    self.windDirection = windDirection
    self.pressureInHg = pressureInHg
  }
}

public struct LicenseOption: Codable, Hashable, Identifiable {
  public var id: String { "\(days)-\(advanced)" }
  public let days: Int
  public let price: Int
  public let advanced: Bool

  public var durationLabel: String {
    switch days {
    case 1: return "1 Day"
    case 3: return "3 Days"
    case 7: return "Week"
    case 30: return "Month"
    default: return "\(days) Days"
    }
  }
}

public struct Waterway: Identifiable, Codable, Hashable {
  public let id: String
  public let name: String
  public let region: String
  public let country: String
  public let requiredLevel: Int
  public let travelFee: Int
  public let dailyFishingFee: Int
  public let speciesIDs: [String]
  /// Globe position in degrees.
  public let latitude: Double
  public let longitude: Double
  public let description: String
  public let forecast: WeatherForecast
  public let waterTint: WaterTint
  public let basicLicensePerDay: Int
  public let advancedLicensePerDay: Int
  /// Species that a basic license forces the angler to release.
  public let mustReleaseBasic: [String]

  public var species: [Species] { speciesIDs.map(SpeciesCatalog.find) }

  public var displayTitle: String { "\(name.uppercased()) - \(region.uppercased())" }

  public var licenses: [LicenseOption] {
    [
      LicenseOption(days: 1, price: basicLicensePerDay, advanced: false),
      LicenseOption(days: 3, price: Int(Double(basicLicensePerDay) * 2.8), advanced: false),
      LicenseOption(days: 7, price: Int(Double(basicLicensePerDay) * 6.3), advanced: false),
      LicenseOption(days: 1, price: advancedLicensePerDay, advanced: true),
      LicenseOption(days: 3, price: Int(Double(advancedLicensePerDay) * 2.85), advanced: true),
      LicenseOption(days: 7, price: Int(Double(advancedLicensePerDay) * 6.3), advanced: true),
    ]
  }
}

public enum WaterTint: String, Codable, Hashable {
  case warmGreen, muddyBrown, coldBlue, deepTeal, blackwater, turquoise, glacial
}

public enum WaterwayCatalog {
  public static let all: [Waterway] = [
    Waterway(
      id: "lonePineLake", name: "Lone Pine Lake", region: "Texas", country: "USA",
      requiredLevel: 1, travelFee: 0, dailyFishingFee: 0,
      speciesIDs: [
        "bluegill", "redearSunfish", "goldenShiner", "whiteCrappie", "largemouthBass",
        "spottedBass", "channelCatfish", "commonCarp", "walleye", "freshwaterDrum",
      ],
      latitude: 31.4, longitude: -98.7,
      description:
        "A warm reservoir ringed by pines and boat docks. Panfish crowd the shallows at dawn while bass patrol the weed edges.",
      forecast: WeatherForecast(
        kind: .partlyCloudy, airTempF: 69, waterTempF: 66, windMph: 3.8, windDirection: "NW",
        pressureInHg: 30.02),
      waterTint: .warmGreen, basicLicensePerDay: 100, advancedLicensePerDay: 200,
      mustReleaseBasic: ["spottedBass"]),
    Waterway(
      id: "willowCreekPond", name: "Willow Creek Pond", region: "Georgia", country: "USA",
      requiredLevel: 2, travelFee: 60, dailyFishingFee: 30,
      speciesIDs: [
        "bluegill", "pumpkinseed", "greenSunfish", "warmouth", "longearSunfish", "blackCrappie",
        "largemouthBass", "brownBullhead", "goldenShiner",
      ],
      latitude: 33.2, longitude: -83.4,
      description:
        "A farm pond under weeping willows, thick with lily pads. Sunfish of every colour bite on anything small at midday.",
      forecast: WeatherForecast(
        kind: .sunny, airTempF: 76, waterTempF: 72, windMph: 2.4, windDirection: "S",
        pressureInHg: 30.10),
      waterTint: .warmGreen, basicLicensePerDay: 120, advancedLicensePerDay: 240,
      mustReleaseBasic: ["largemouthBass"]),
    Waterway(
      id: "muddyForkRiver", name: "Muddy Fork River", region: "Missouri", country: "USA",
      requiredLevel: 4, travelFee: 120, dailyFishingFee: 60,
      speciesIDs: [
        "smallmouthBass", "rockBass", "channelCatfish", "flatheadCatfish", "longnoseGar",
        "commonCarp", "freshwaterDrum", "walleye",
      ],
      latitude: 38.4, longitude: -92.4,
      description:
        "Slow chocolate current under sycamores and a rusted railway bridge. Catfish hold in the deep bends after sunset.",
      forecast: WeatherForecast(
        kind: .overcast, airTempF: 61, waterTempF: 58, windMph: 6.2, windDirection: "SW",
        pressureInHg: 29.88),
      waterTint: .muddyBrown, basicLicensePerDay: 160, advancedLicensePerDay: 320,
      mustReleaseBasic: ["flatheadCatfish"]),
    Waterway(
      id: "birchHollowLake", name: "Birch Hollow Lake", region: "Michigan", country: "USA",
      requiredLevel: 6, travelFee: 180, dailyFishingFee: 70,
      speciesIDs: [
        "yellowPerch", "bluegill", "pumpkinseed", "rockBass", "blackCrappie", "whiteBass",
        "smallmouthBass", "walleye", "northernPike",
      ],
      latitude: 44.8, longitude: -85.3,
      description:
        "A clear kettle lake fringed with white birch. Perch school over the sand flats and pike ambush along the reed beds.",
      forecast: WeatherForecast(
        kind: .partlyCloudy, airTempF: 63, waterTempF: 60, windMph: 5.5, windDirection: "NW",
        pressureInHg: 30.06),
      waterTint: .coldBlue, basicLicensePerDay: 190, advancedLicensePerDay: 380,
      mustReleaseBasic: ["walleye"]),
    Waterway(
      id: "emeraldTarn", name: "Emerald Tarn", region: "New York", country: "USA",
      requiredLevel: 8, travelFee: 260, dailyFishingFee: 90,
      speciesIDs: [
        "yellowPerch", "brookTrout", "rainbowTrout", "chainPickerel", "rockBass",
        "smallmouthBass", "northernPike",
      ],
      latitude: 43.9, longitude: -74.4,
      description:
        "Glass-clear Adirondack water with granite shelves. Trout rise at first light; pike lurk under the lily pads.",
      forecast: WeatherForecast(
        kind: .fog, airTempF: 52, waterTempF: 49, windMph: 2.1, windDirection: "N",
        pressureInHg: 30.15),
      waterTint: .coldBlue, basicLicensePerDay: 220, advancedLicensePerDay: 440,
      mustReleaseBasic: ["northernPike"]),
    Waterway(
      id: "saltmarshFlats", name: "Saltmarsh Flats", region: "Florida", country: "USA",
      requiredLevel: 10, travelFee: 300, dailyFishingFee: 100,
      speciesIDs: [
        "redDrum", "blackDrum", "snook", "spottedSeatrout", "tarpon", "stripedBass",
        "peacockBass", "tilapia", "oscar",
      ],
      latitude: 26.1, longitude: -81.0,
      description:
        "Brackish mangrove channels opening onto turtle-grass flats. Redfish tail at dawn and snook hunt the culverts after dark.",
      forecast: WeatherForecast(
        kind: .sunny, airTempF: 84, waterTempF: 79, windMph: 9.2, windDirection: "E",
        pressureInHg: 29.98),
      waterTint: .turquoise, basicLicensePerDay: 240, advancedLicensePerDay: 480,
      mustReleaseBasic: ["tarpon", "snook"]),
    Waterway(
      id: "cypressBayou", name: "Cypress Bayou", region: "Louisiana", country: "USA",
      requiredLevel: 12, travelFee: 340, dailyFishingFee: 110,
      speciesIDs: [
        "largemouthBass", "bluegill", "redearSunfish", "whiteCrappie", "channelCatfish",
        "longnoseGar", "freshwaterDrum", "commonCarp",
      ],
      latitude: 30.6, longitude: -91.6,
      description:
        "Blackwater sloughs beneath Spanish moss. Gar roll at noon; crappie stack against the cypress knees at dusk.",
      forecast: WeatherForecast(
        kind: .rain, airTempF: 77, waterTempF: 74, windMph: 4.4, windDirection: "SE",
        pressureInHg: 29.76),
      waterTint: .blackwater, basicLicensePerDay: 260, advancedLicensePerDay: 520,
      mustReleaseBasic: ["longnoseGar"]),
    Waterway(
      id: "thunderBayReservoir", name: "Thunder Bay Reservoir", region: "Ontario",
      country: "Canada", requiredLevel: 14, travelFee: 420, dailyFishingFee: 130,
      speciesIDs: [
        "walleye", "northernPike", "muskellunge", "smallmouthBass", "lakeTrout", "yellowPerch",
        "lakeSturgeon", "whiteBass",
      ],
      latitude: 48.6, longitude: -89.4,
      description:
        "Boreal shield water with sheer granite banks and cold depths. Muskie follow lures to the boat; sturgeon feed after dark.",
      forecast: WeatherForecast(
        kind: .overcast, airTempF: 55, waterTempF: 52, windMph: 7.8, windDirection: "N",
        pressureInHg: 29.92),
      waterTint: .coldBlue, basicLicensePerDay: 290, advancedLicensePerDay: 580,
      mustReleaseBasic: ["muskellunge", "lakeSturgeon"]),
    Waterway(
      id: "graniteFjord", name: "Granite Fjord", region: "Oregon", country: "USA",
      requiredLevel: 16, travelFee: 480, dailyFishingFee: 140,
      speciesIDs: [
        "rainbowTrout", "brookTrout", "smallmouthBass", "yellowPerch", "walleye", "northernPike",
      ],
      latitude: 44.1, longitude: -121.8,
      description:
        "Cold Cascade water pooled behind a basalt sill. Long casts with spoons reach the trophy trout holding off the drop.",
      forecast: WeatherForecast(
        kind: .sunny, airTempF: 58, waterTempF: 51, windMph: 8.9, windDirection: "W",
        pressureInHg: 30.24),
      waterTint: .deepTeal, basicLicensePerDay: 320, advancedLicensePerDay: 640,
      mustReleaseBasic: ["rainbowTrout"]),
    Waterway(
      id: "avonMeadows", name: "Avon Meadows", region: "Wiltshire", country: "England",
      requiredLevel: 18, travelFee: 900, dailyFishingFee: 160,
      speciesIDs: [
        "roach", "rudd", "chub", "commonBream", "tench", "barbel", "europeanPerch",
        "northernPike", "commonCarp", "mirrorCarp",
      ],
      latitude: 51.1, longitude: -1.8,
      description:
        "A slow chalk stream winding through hay meadows and old mills. Float fishing for roach by day, barbel in the weir pool at dusk.",
      forecast: WeatherForecast(
        kind: .overcast, airTempF: 59, waterTempF: 56, windMph: 6.0, windDirection: "SW",
        pressureInHg: 29.85),
      waterTint: .muddyBrown, basicLicensePerDay: 340, advancedLicensePerDay: 680,
      mustReleaseBasic: ["barbel", "mirrorCarp"]),
    Waterway(
      id: "lochGarve", name: "Loch Garve", region: "Highlands", country: "Scotland",
      requiredLevel: 20, travelFee: 980, dailyFishingFee: 170,
      speciesIDs: ["brownTrout", "atlanticSalmon", "arcticChar", "europeanPerch", "northernPike"],
      latitude: 57.6, longitude: -4.7,
      description:
        "Peat-dark loch beneath heather hills. Salmon rest in the outflow after autumn rain; big ferox trout hunt the deep.",
      forecast: WeatherForecast(
        kind: .rain, airTempF: 51, waterTempF: 48, windMph: 11.4, windDirection: "W",
        pressureInHg: 29.62),
      waterTint: .blackwater, basicLicensePerDay: 360, advancedLicensePerDay: 720,
      mustReleaseBasic: ["atlanticSalmon"]),
    Waterway(
      id: "danubeBackwaters", name: "Danube Backwaters", region: "Lower Austria",
      country: "Austria", requiredLevel: 22, travelFee: 1_050, dailyFishingFee: 180,
      speciesIDs: [
        "welsCatfish", "zander", "europeanPerch", "commonCarp", "grassCarp", "barbel",
        "commonBream", "chub", "northernPike",
      ],
      latitude: 48.2, longitude: 16.7,
      description:
        "Oxbow lagoons and gravel side-arms of a great river. Zander hold on the drop-offs; wels stir in the deep holes at night.",
      forecast: WeatherForecast(
        kind: .partlyCloudy, airTempF: 66, waterTempF: 62, windMph: 4.6, windDirection: "E",
        pressureInHg: 30.00),
      waterTint: .deepTeal, basicLicensePerDay: 380, advancedLicensePerDay: 760,
      mustReleaseBasic: ["welsCatfish"]),
    Waterway(
      id: "lakeBiwa", name: "Lake Biwa", region: "Shiga", country: "Japan",
      requiredLevel: 24, travelFee: 1_400, dailyFishingFee: 190,
      speciesIDs: [
        "largemouthBass", "bluegill", "commonCarp", "mirrorCarp", "grassCarp", "channelCatfish",
        "whiteCrappie",
      ],
      latitude: 35.3, longitude: 136.1,
      description:
        "Japan's ancient lake with reed beds and temple shores. Finesse tactics tempt heavyweight bass along the rocky points.",
      forecast: WeatherForecast(
        kind: .fog, airTempF: 64, waterTempF: 61, windMph: 3.0, windDirection: "NE",
        pressureInHg: 30.12),
      waterTint: .warmGreen, basicLicensePerDay: 400, advancedLicensePerDay: 800,
      mustReleaseBasic: ["largemouthBass"]),
    Waterway(
      id: "rioTapajos", name: "Rio Tapajos", region: "Para", country: "Brazil",
      requiredLevel: 26, travelFee: 1_600, dailyFishingFee: 210,
      speciesIDs: [
        "peacockBass", "redtailCatfish", "arapaima", "tambaqui", "payara", "oscar", "tilapia",
      ],
      latitude: -3.1, longitude: -55.4,
      description:
        "Clear Amazon tributary with white sand beaches. Peacock bass explode on poppers; arapaima roll in the flooded lagoons.",
      forecast: WeatherForecast(
        kind: .sunny, airTempF: 90, waterTempF: 84, windMph: 3.6, windDirection: "NE",
        pressureInHg: 29.88),
      waterTint: .turquoise, basicLicensePerDay: 440, advancedLicensePerDay: 880,
      mustReleaseBasic: ["arapaima"]),
    Waterway(
      id: "gaulaRiver", name: "Gaula River", region: "Trondelag", country: "Norway",
      requiredLevel: 28, travelFee: 1_500, dailyFishingFee: 220,
      speciesIDs: ["atlanticSalmon", "brownTrout", "arcticChar", "arcticGrayling", "northernPike"],
      latitude: 63.0, longitude: 10.3,
      description:
        "Fast, gin-clear salmon river dropping through birch valleys. Long fly casts across the pools during the midnight sun.",
      forecast: WeatherForecast(
        kind: .partlyCloudy, airTempF: 54, waterTempF: 47, windMph: 5.2, windDirection: "N",
        pressureInHg: 30.08),
      waterTint: .glacial, basicLicensePerDay: 480, advancedLicensePerDay: 960,
      mustReleaseBasic: ["atlanticSalmon"]),
    Waterway(
      id: "ebroDelta", name: "Ebro Delta", region: "Catalonia", country: "Spain",
      requiredLevel: 30, travelFee: 1_450, dailyFishingFee: 220,
      speciesIDs: [
        "welsCatfish", "commonCarp", "mirrorCarp", "zander", "largemouthBass", "europeanPerch",
        "commonBream",
      ],
      latitude: 40.7, longitude: 0.7,
      description:
        "Rice paddies, canals and the wide lower river. Giant wels take bait at night and carp cruise the warm shallows.",
      forecast: WeatherForecast(
        kind: .sunny, airTempF: 79, waterTempF: 74, windMph: 7.0, windDirection: "SE",
        pressureInHg: 30.02),
      waterTint: .muddyBrown, basicLicensePerDay: 500, advancedLicensePerDay: 1_000,
      mustReleaseBasic: ["welsCatfish"]),
    Waterway(
      id: "kenaiRiver", name: "Kenai River", region: "Alaska", country: "USA",
      requiredLevel: 32, travelFee: 1_700, dailyFishingFee: 240,
      speciesIDs: [
        "chinookSalmon", "cohoSalmon", "sockeyeSalmon", "rainbowTrout", "steelhead", "arcticChar",
        "lakeTrout",
      ],
      latitude: 60.5, longitude: -150.9,
      description:
        "Glacier-fed turquoise river between spruce banks. Salmon run in waves; the rainbows behind them grow enormous.",
      forecast: WeatherForecast(
        kind: .overcast, airTempF: 56, waterTempF: 46, windMph: 6.4, windDirection: "SW",
        pressureInHg: 29.90),
      waterTint: .glacial, basicLicensePerDay: 540, advancedLicensePerDay: 1_080,
      mustReleaseBasic: ["chinookSalmon"]),
    Waterway(
      id: "lakeNasser", name: "Lake Nasser", region: "Aswan", country: "Egypt",
      requiredLevel: 34, travelFee: 1_800, dailyFishingFee: 250,
      speciesIDs: ["nilePerch", "tigerfish", "tilapia", "commonCarp", "grassCarp"],
      latitude: 22.8, longitude: 32.5,
      description:
        "A desert sea of drowned wadis and rocky islands. Nile perch the size of a man patrol the submerged cliffs.",
      forecast: WeatherForecast(
        kind: .sunny, airTempF: 97, waterTempF: 82, windMph: 8.5, windDirection: "N",
        pressureInHg: 29.80),
      waterTint: .turquoise, basicLicensePerDay: 560, advancedLicensePerDay: 1_120,
      mustReleaseBasic: ["nilePerch"]),
    Waterway(
      id: "upperZambezi", name: "Upper Zambezi", region: "Western Province", country: "Zambia",
      requiredLevel: 36, travelFee: 1_950, dailyFishingFee: 260,
      speciesIDs: ["tigerfish", "tilapia", "barbel", "largemouthBass", "commonCarp"],
      latitude: -15.8, longitude: 23.1,
      description:
        "Broad, swift floodplain river above the falls. Tigerfish hit drifted baits like freight trains in the fast channels.",
      forecast: WeatherForecast(
        kind: .partlyCloudy, airTempF: 88, waterTempF: 78, windMph: 5.0, windDirection: "E",
        pressureInHg: 29.86),
      waterTint: .muddyBrown, basicLicensePerDay: 580, advancedLicensePerDay: 1_160,
      mustReleaseBasic: ["tigerfish"]),
    Waterway(
      id: "bungSamRan", name: "Bung Sam Ran", region: "Bangkok", country: "Thailand",
      requiredLevel: 38, travelFee: 2_000, dailyFishingFee: 270,
      speciesIDs: [
        "giantSnakehead", "redtailCatfish", "arapaima", "tambaqui", "alligatorGar", "tilapia",
        "grassCarp",
      ],
      latitude: 13.7, longitude: 100.6,
      description:
        "A legendary stocked lake ringed by bamboo bungalows. Every bite here could be a monster from another continent.",
      forecast: WeatherForecast(
        kind: .rain, airTempF: 89, waterTempF: 85, windMph: 3.2, windDirection: "SW",
        pressureInHg: 29.74),
      waterTint: .warmGreen, basicLicensePerDay: 600, advancedLicensePerDay: 1_200,
      mustReleaseBasic: ["arapaima", "alligatorGar"]),
    Waterway(
      id: "cauveryRiver", name: "Cauvery River", region: "Karnataka", country: "India",
      requiredLevel: 40, travelFee: 2_100, dailyFishingFee: 280,
      speciesIDs: ["mahseer", "welsCatfish", "commonCarp", "tilapia", "giantSnakehead", "barbel"],
      latitude: 12.3, longitude: 77.2,
      description:
        "Boulder-strewn rapids and deep green pools in the jungle. Golden mahseer smash spoons swung through the white water.",
      forecast: WeatherForecast(
        kind: .fog, airTempF: 82, waterTempF: 76, windMph: 2.8, windDirection: "S",
        pressureInHg: 29.82),
      waterTint: .deepTeal, basicLicensePerDay: 620, advancedLicensePerDay: 1_240,
      mustReleaseBasic: ["mahseer"]),
    Waterway(
      id: "murrayRiver", name: "Murray River", region: "Victoria", country: "Australia",
      requiredLevel: 42, travelFee: 2_400, dailyFishingFee: 290,
      speciesIDs: ["murrayCod", "goldenPerch", "commonCarp", "europeanPerch", "tench"],
      latitude: -35.9, longitude: 143.3,
      description:
        "Red gums lean over a slow brown river full of snags. Cod live under the timber; golden perch cruise the eddies.",
      forecast: WeatherForecast(
        kind: .sunny, airTempF: 74, waterTempF: 68, windMph: 6.6, windDirection: "NW",
        pressureInHg: 30.04),
      waterTint: .muddyBrown, basicLicensePerDay: 640, advancedLicensePerDay: 1_280,
      mustReleaseBasic: ["murrayCod"]),
    Waterway(
      id: "daintreeEstuary", name: "Daintree Estuary", region: "Queensland", country: "Australia",
      requiredLevel: 44, travelFee: 2_500, dailyFishingFee: 300,
      speciesIDs: ["barramundi", "snook", "tarpon", "tilapia", "giantSnakehead"],
      latitude: -16.3, longitude: 145.4,
      description:
        "Tidal mangrove creeks where rainforest meets the reef. Barramundi boof on the surface as the tide pushes in.",
      forecast: WeatherForecast(
        kind: .rain, airTempF: 86, waterTempF: 82, windMph: 10.2, windDirection: "SE",
        pressureInHg: 29.78),
      waterTint: .turquoise, basicLicensePerDay: 660, advancedLicensePerDay: 1_320,
      mustReleaseBasic: ["barramundi"]),
    Waterway(
      id: "lakeTaupo", name: "Lake Taupo", region: "Waikato", country: "New Zealand",
      requiredLevel: 46, travelFee: 2_700, dailyFishingFee: 310,
      speciesIDs: ["rainbowTrout", "brownTrout", "goldenTrout", "chinookSalmon", "europeanPerch"],
      latitude: -38.8, longitude: 175.9,
      description:
        "A vast volcanic caldera lake with pumice beaches. Trout stack at the stream mouths on cold evenings.",
      forecast: WeatherForecast(
        kind: .partlyCloudy, airTempF: 57, waterTempF: 53, windMph: 8.0, windDirection: "W",
        pressureInHg: 30.14),
      waterTint: .coldBlue, basicLicensePerDay: 680, advancedLicensePerDay: 1_360,
      mustReleaseBasic: ["brownTrout"]),
    Waterway(
      id: "amurRiver", name: "Amur River", region: "Khabarovsk", country: "Russia",
      requiredLevel: 48, travelFee: 2_900, dailyFishingFee: 320,
      speciesIDs: [
        "taimen", "northernPike", "grassCarp", "northernSnakehead", "arcticGrayling", "commonCarp",
        "welsCatfish",
      ],
      latitude: 50.5, longitude: 137.0,
      description:
        "An enormous far-eastern river between taiga and steppe. Taimen, the river wolf, guards the fastest, deepest runs.",
      forecast: WeatherForecast(
        kind: .overcast, airTempF: 52, waterTempF: 49, windMph: 9.4, windDirection: "N",
        pressureInHg: 29.94),
      waterTint: .coldBlue, basicLicensePerDay: 720, advancedLicensePerDay: 1_440,
      mustReleaseBasic: ["taimen"]),
    Waterway(
      id: "fraserRiver", name: "Fraser River", region: "British Columbia", country: "Canada",
      requiredLevel: 50, travelFee: 3_000, dailyFishingFee: 330,
      speciesIDs: [
        "whiteSturgeon", "chinookSalmon", "sockeyeSalmon", "cohoSalmon", "steelhead",
        "cutthroatTrout", "rainbowTrout",
      ],
      latitude: 49.2, longitude: -122.0,
      description:
        "Silty green water sliding past gravel bars and cottonwoods. White sturgeon older than the bridges feed in the eddies.",
      forecast: WeatherForecast(
        kind: .rain, airTempF: 58, waterTempF: 52, windMph: 7.2, windDirection: "W",
        pressureInHg: 29.84),
      waterTint: .glacial, basicLicensePerDay: 760, advancedLicensePerDay: 1_520,
      mustReleaseBasic: ["whiteSturgeon"]),
    Waterway(
      id: "volgaDelta", name: "Volga Delta", region: "Astrakhan", country: "Russia",
      requiredLevel: 52, travelFee: 3_100, dailyFishingFee: 340,
      speciesIDs: [
        "welsCatfish", "zander", "northernPike", "commonCarp", "commonBream", "roach", "rudd",
        "europeanPerch",
      ],
      latitude: 46.0, longitude: 48.5,
      description:
        "A maze of reed channels and lotus fields at the edge of the Caspian. Everything grows huge in the warm, food-rich water.",
      forecast: WeatherForecast(
        kind: .sunny, airTempF: 78, waterTempF: 72, windMph: 6.8, windDirection: "SE",
        pressureInHg: 30.06),
      waterTint: .muddyBrown, basicLicensePerDay: 780, advancedLicensePerDay: 1_560,
      mustReleaseBasic: ["welsCatfish", "zander"]),
    Waterway(
      id: "yellowstoneLake", name: "Yellowstone Lake", region: "Wyoming", country: "USA",
      requiredLevel: 54, travelFee: 3_200, dailyFishingFee: 350,
      speciesIDs: ["cutthroatTrout", "lakeTrout", "arcticGrayling", "brownTrout", "goldenTrout"],
      latitude: 44.5, longitude: -110.4,
      description:
        "High alpine water under snow peaks, steaming from lakeside geysers. Native cutthroat rise to dry flies along the shore.",
      forecast: WeatherForecast(
        kind: .sunny, airTempF: 50, waterTempF: 44, windMph: 9.8, windDirection: "W",
        pressureInHg: 30.20),
      waterTint: .coldBlue, basicLicensePerDay: 800, advancedLicensePerDay: 1_600,
      mustReleaseBasic: ["cutthroatTrout"]),
    Waterway(
      id: "paranaRiver", name: "Parana River", region: "Corrientes", country: "Argentina",
      requiredLevel: 56, travelFee: 3_400, dailyFishingFee: 360,
      speciesIDs: ["dorado", "tambaqui", "redtailCatfish", "payara", "tilapia", "oscar"],
      latitude: -27.5, longitude: -58.8,
      description:
        "A mile-wide river of islands and sandbars. Golden dorado leap clear of the current when they feel the hook.",
      forecast: WeatherForecast(
        kind: .partlyCloudy, airTempF: 83, waterTempF: 77, windMph: 5.8, windDirection: "NE",
        pressureInHg: 29.92),
      waterTint: .muddyBrown, basicLicensePerDay: 840, advancedLicensePerDay: 1_680,
      mustReleaseBasic: ["dorado"]),
    Waterway(
      id: "trinityRiver", name: "Trinity River", region: "Texas", country: "USA",
      requiredLevel: 58, travelFee: 3_600, dailyFishingFee: 380,
      speciesIDs: [
        "alligatorGar", "blueCatfish", "flatheadCatfish", "spottedGar", "bowfin", "paddlefish",
        "freshwaterDrum", "stripedBass", "whiteBass", "guadalupeBass", "commonCarp",
      ],
      latitude: 31.0, longitude: -95.4,
      description:
        "Murky, log-choked river bends where the biggest alligator gar in the world roll in the noon heat.",
      forecast: WeatherForecast(
        kind: .sunny, airTempF: 93, waterTempF: 84, windMph: 4.2, windDirection: "S",
        pressureInHg: 29.96),
      waterTint: .muddyBrown, basicLicensePerDay: 880, advancedLicensePerDay: 1_760,
      mustReleaseBasic: ["alligatorGar", "paddlefish"]),
  ]

  public static func find(_ id: String) -> Waterway {
    guard let waterway = all.first(where: { $0.id == id }) else {
      fatalError("Unknown waterway \(id)")
    }
    return waterway
  }
}
