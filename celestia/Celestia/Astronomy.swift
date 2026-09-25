import Foundation

struct Star: Identifiable, Codable, Equatable {
  let id: String
  let name: String
  let designation: String
  let constellation: String
  let ra: Double
  let dec: Double
  let magnitude: Double
  let distance: String
  let story: String
}

struct ObservingSite: Identifiable, Codable, Equatable {
  let id: String
  let name: String
  let region: String
  let latitude: Double
  let longitude: Double
  let timeZone: String

  static let all: [ObservingSite] = [
    .init(
      id: "joshua", name: "Joshua Tree", region: "California · United States",
      latitude: 33.8734, longitude: -115.901, timeZone: "America/Los_Angeles"),
    .init(
      id: "mauna", name: "Mauna Kea", region: "Hawaiʻi · United States",
      latitude: 19.8207, longitude: -155.4681, timeZone: "Pacific/Honolulu"),
    .init(
      id: "atacama", name: "Atacama Desert", region: "Antofagasta · Chile",
      latitude: -23.8634, longitude: -69.1328, timeZone: "America/Santiago"),
    .init(
      id: "namib", name: "NamibRand", region: "Hardap · Namibia",
      latitude: -25.1, longitude: 16.0, timeZone: "Africa/Windhoek"),
    .init(
      id: "london", name: "Greenwich", region: "London · United Kingdom",
      latitude: 51.4769, longitude: 0, timeZone: "Europe/London"),
  ]
}

struct Horizontal: Equatable {
  let altitude: Double
  let azimuth: Double
}

enum Astronomy {
  static func wrap(_ angle: Double) -> Double {
    let result = angle.truncatingRemainder(dividingBy: 360)
    let wrapped = result < 0 ? result + 360 : result
    return wrapped == 360 ? 0 : wrapped
  }

  static func julianDate(_ date: Date) -> Double {
    date.timeIntervalSince1970 / 86400 + 2440587.5
  }

  static func siderealDegrees(date: Date, longitude: Double) -> Double {
    let days = julianDate(date) - 2_451_545
    let centuries = days / 36525
    return wrap(
      280.46061837 + 360.98564736629 * days
        + 0.000387933 * centuries * centuries
        - centuries * centuries * centuries / 38_710_000 + longitude)
  }

  static func horizontal(ra: Double, dec: Double, date: Date, site: ObservingSite) -> Horizontal {
    let radians = Double.pi / 180
    let hourAngle = (siderealDegrees(date: date, longitude: site.longitude) - ra * 15) * radians
    let latitude = site.latitude * radians
    let declination = dec * radians
    let sinAltitude =
      sin(declination) * sin(latitude)
      + cos(declination) * cos(latitude) * cos(hourAngle)
    let altitude = asin(min(1, max(-1, sinAltitude)))
    let east = -cos(declination) * sin(hourAngle)
    let north =
      sin(declination) * cos(latitude)
      - cos(declination) * cos(hourAngle) * sin(latitude)
    return Horizontal(altitude: altitude / radians, azimuth: wrap(atan2(east, north) / radians))
  }

  static func position(_ star: Star, at date: Date, site: ObservingSite) -> Horizontal {
    horizontal(ra: star.ra, dec: star.dec, date: date, site: site)
  }

  static func compass(_ azimuth: Double) -> String {
    let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    return names[Int((wrap(azimuth) + 22.5) / 45) % 8]
  }

  static func formatted(_ date: Date, site: ObservingSite, pattern: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: site.timeZone)
    formatter.dateFormat = pattern
    return formatter.string(from: date)
  }
}

enum Catalog {
  static let stars: [Star] = [
    .init(
      id: "vega", name: "Vega", designation: "α Lyrae", constellation: "Lyra", ra: 18.61565,
      dec: 38.7837, magnitude: 0.03, distance: "25 light-years",
      story:
        "The sapphire beacon of the summer sky. Vega anchors the little harp of Lyra and the great Summer Triangle."
    ),
    .init(
      id: "deneb", name: "Deneb", designation: "α Cygni", constellation: "Cygnus", ra: 20.69053,
      dec: 45.2803, magnitude: 1.25, distance: "≈2,600 light-years",
      story:
        "A distant blue-white supergiant at the tail of the Swan, sailing through the northern Milky Way."
    ),
    .init(
      id: "altair", name: "Altair", designation: "α Aquilae", constellation: "Aquila", ra: 19.84639,
      dec: 8.8683, magnitude: 0.77, distance: "17 light-years",
      story:
        "The bright eye of the Eagle. Its rapid spin flattens this nearby star, the southern point of the Summer Triangle."
    ),
    .init(
      id: "arcturus", name: "Arcturus", designation: "α Boötis", constellation: "Boötes",
      ra: 14.26103, dec: 19.1824, magnitude: -0.05, distance: "37 light-years",
      story:
        "Follow the arc of the Big Dipper to this warm orange giant, a bright sentinel of the western sky."
    ),
    .init(
      id: "antares", name: "Antares", designation: "α Scorpii", constellation: "Scorpius",
      ra: 16.49013, dec: -26.432, magnitude: 1.06, distance: "≈550 light-years",
      story: "The ruby heart of the Scorpion. This enormous red supergiant rivals Mars in color."),
    .init(
      id: "polaris", name: "Polaris", designation: "α Ursae Minoris", constellation: "Ursa Minor",
      ra: 2.5303, dec: 89.2641, magnitude: 1.98, distance: "≈450 light-years",
      story:
        "The North Star sits close to the celestial pole. Its height above the horizon nearly gives your northern latitude."
    ),
    .init(
      id: "fomalhaut", name: "Fomalhaut", designation: "α Piscis Austrini",
      constellation: "Piscis Austrinus", ra: 22.96085, dec: -29.6222, magnitude: 1.16,
      distance: "25 light-years",
      story:
        "The lonely star of autumn glows in the southern sky, surrounded by a vast dusty debris ring."
    ),
    .init(
      id: "capella", name: "Capella", designation: "α Aurigae", constellation: "Auriga",
      ra: 5.27816, dec: 45.998, magnitude: 0.08, distance: "43 light-years",
      story:
        "A golden pair of giant stars whose combined light marks the shoulder of the Charioteer."),
    .init(
      id: "sirius", name: "Sirius", designation: "α Canis Majoris", constellation: "Canis Major",
      ra: 6.75248, dec: -16.7161, magnitude: -1.46, distance: "8.6 light-years",
      story:
        "The brightest star in our night sky. Its fierce sparkle comes from Earth's turbulent atmosphere."
    ),
    .init(
      id: "betelgeuse", name: "Betelgeuse", designation: "α Orionis", constellation: "Orion",
      ra: 5.91953, dec: 7.4071, magnitude: 0.5, distance: "≈550 light-years",
      story:
        "Orion's copper-red shoulder is a variable supergiant. Its brightness and estimated distance are uncertain."
    ),
    .init(
      id: "rigel", name: "Rigel", designation: "β Orionis", constellation: "Orion", ra: 5.2423,
      dec: -8.2016, magnitude: 0.13, distance: "≈860 light-years",
      story: "A brilliant blue-white supergiant at Orion's foot, contrasting with red Betelgeuse."),
    .init(
      id: "aldebaran", name: "Aldebaran", designation: "α Tauri", constellation: "Taurus",
      ra: 4.59868, dec: 16.5093, magnitude: 0.85, distance: "65 light-years",
      story:
        "The orange eye of Taurus appears among the Hyades, although it lies much closer to us."),
    .init(
      id: "spica", name: "Spica", designation: "α Virginis", constellation: "Virgo", ra: 13.41988,
      dec: -11.1613, magnitude: 0.98, distance: "250 light-years",
      story:
        "A close pair of hot stars, seen as a single blue-white point in the constellation Virgo."),
    .init(
      id: "regulus", name: "Regulus", designation: "α Leonis", constellation: "Leo", ra: 10.13953,
      dec: 11.9672, magnitude: 1.35, distance: "79 light-years",
      story:
        "The little king marks the heart of the Lion, close to the path of the Sun across the sky."),
    .init(
      id: "achernar", name: "Achernar", designation: "α Eridani", constellation: "Eridanus",
      ra: 1.62857, dec: -57.2368, magnitude: 0.46, distance: "139 light-years",
      story:
        "A rapidly rotating blue star at the end of the celestial river, best seen from southern latitudes."
    ),
    .init(
      id: "canopus", name: "Canopus", designation: "α Carinae", constellation: "Carina",
      ra: 6.39919, dec: -52.6957, magnitude: -0.74, distance: "310 light-years",
      story:
        "The second-brightest night star, guiding southern observers from the keel of the great celestial ship."
    ),
    .init(
      id: "acrux", name: "Acrux", designation: "α Crucis", constellation: "Crux", ra: 12.4433,
      dec: -63.0991, magnitude: 0.76, distance: "321 light-years",
      story: "The brilliant foot of the Southern Cross, a multiple system of hot blue stars."),
    .init(
      id: "alphecca", name: "Alphecca", designation: "α Coronae Borealis",
      constellation: "Corona Borealis", ra: 15.57813, dec: 26.7147, magnitude: 2.23,
      distance: "75 light-years",
      story: "The jewel in the Northern Crown, a small arc of stars east of Boötes."),
    .init(
      id: "alderamin", name: "Alderamin", designation: "α Cephei", constellation: "Cepheus",
      ra: 21.30966, dec: 62.5856, magnitude: 2.45, distance: "49 light-years",
      story:
        "A bright marker of the house-shaped constellation of Cepheus near the northern Milky Way."),
    .init(
      id: "schedar", name: "Schedar", designation: "α Cassiopeiae", constellation: "Cassiopeia",
      ra: 0.67512, dec: 56.5373, magnitude: 2.24, distance: "228 light-years",
      story: "An orange giant in Cassiopeia's familiar W, circling the northern celestial pole."),
    .init(
      id: "caph", name: "Caph", designation: "β Cassiopeiae", constellation: "Cassiopeia",
      ra: 0.15297, dec: 59.1498, magnitude: 2.28, distance: "55 light-years",
      story: "The western end of Cassiopeia's W-shaped asterism."),
    .init(
      id: "gamma-cas", name: "Navi", designation: "γ Cassiopeiae", constellation: "Cassiopeia",
      ra: 0.94514, dec: 60.7167, magnitude: 2.47, distance: "550 light-years",
      story: "A variable star at the center of Cassiopeia's W."),
    .init(
      id: "ruchbah", name: "Ruchbah", designation: "δ Cassiopeiae", constellation: "Cassiopeia",
      ra: 1.43026, dec: 60.2353, magnitude: 2.68, distance: "99 light-years",
      story: "One of the five bright stars that trace the queen's celestial throne."),
    .init(
      id: "segin", name: "Segin", designation: "ε Cassiopeiae", constellation: "Cassiopeia",
      ra: 1.90659, dec: 63.67, magnitude: 3.35, distance: "410 light-years",
      story: "The eastern tip of Cassiopeia's W."),
    .init(
      id: "sadr", name: "Sadr", designation: "γ Cygni", constellation: "Cygnus", ra: 20.37047,
      dec: 40.2567, magnitude: 2.23, distance: "≈1,800 light-years",
      story: "The heart of the Swan sits at the crossing of the Northern Cross."),
    .init(
      id: "albireo", name: "Albireo", designation: "β Cygni", constellation: "Cygnus", ra: 19.51202,
      dec: 27.9597, magnitude: 3.05, distance: "≈430 light-years",
      story: "A celebrated gold-and-blue telescopic double at the head of the Swan."),
    .init(
      id: "gienah", name: "Gienah", designation: "ε Cygni", constellation: "Cygnus", ra: 20.77018,
      dec: 33.9703, magnitude: 2.48, distance: "73 light-years",
      story: "An orange giant on the Swan's eastern wing."),
    .init(
      id: "delta-cyg", name: "Fawaris", designation: "δ Cygni", constellation: "Cygnus",
      ra: 19.74957, dec: 45.1308, magnitude: 2.87, distance: "165 light-years",
      story: "The opposite wing of the Swan's great cross."),
    .init(
      id: "sheliak", name: "Sheliak", designation: "β Lyrae", constellation: "Lyra", ra: 18.83466,
      dec: 33.3627, magnitude: 3.52, distance: "960 light-years",
      story: "An eclipsing binary at the base of Lyra's small parallelogram."),
    .init(
      id: "sulafat", name: "Sulafat", designation: "γ Lyrae", constellation: "Lyra", ra: 18.9824,
      dec: 32.6896, magnitude: 3.25, distance: "620 light-years",
      story: "The Ring Nebula lies between Sulafat and Sheliak, beyond this bright-star atlas."),
    .init(
      id: "delta-lyr", name: "Delta Lyrae", designation: "δ² Lyrae", constellation: "Lyra",
      ra: 18.90841, dec: 36.8986, magnitude: 4.3, distance: "740 light-years",
      story: "A reddish giant marking one corner of the celestial harp."),
    .init(
      id: "zeta-lyr", name: "Zeta Lyrae", designation: "ζ Lyrae", constellation: "Lyra",
      ra: 18.74621, dec: 37.6051, magnitude: 4.36, distance: "156 light-years",
      story: "A double star near Vega that completes the harp's outline."),
    .init(
      id: "tarazed", name: "Tarazed", designation: "γ Aquilae", constellation: "Aquila",
      ra: 19.77099, dec: 10.6133, magnitude: 2.72, distance: "395 light-years",
      story: "A warm giant flanking Altair in the Eagle."),
    .init(
      id: "alshain", name: "Alshain", designation: "β Aquilae", constellation: "Aquila",
      ra: 19.92189, dec: 6.4068, magnitude: 3.71, distance: "45 light-years",
      story: "Altair's fainter southern companion in a line of three stars."),
    .init(
      id: "dubhe", name: "Dubhe", designation: "α Ursae Majoris", constellation: "Ursa Major",
      ra: 11.06213, dec: 61.7508, magnitude: 1.79, distance: "123 light-years",
      story: "One of the Big Dipper's two pointer stars that lead toward Polaris."),
    .init(
      id: "merak", name: "Merak", designation: "β Ursae Majoris", constellation: "Ursa Major",
      ra: 11.03068, dec: 56.3824, magnitude: 2.37, distance: "80 light-years",
      story: "The lower pointer star at the outer edge of the Big Dipper's bowl."),
    .init(
      id: "phecda", name: "Phecda", designation: "γ Ursae Majoris", constellation: "Ursa Major",
      ra: 11.89717, dec: 53.6948, magnitude: 2.44, distance: "83 light-years",
      story: "The inner bottom corner of the Big Dipper's bowl."),
    .init(
      id: "megrez", name: "Megrez", designation: "δ Ursae Majoris", constellation: "Ursa Major",
      ra: 12.2571, dec: 57.0326, magnitude: 3.31, distance: "80 light-years",
      story: "The faintest principal Dipper star joins its bowl to its handle."),
    .init(
      id: "alioth", name: "Alioth", designation: "ε Ursae Majoris", constellation: "Ursa Major",
      ra: 12.90049, dec: 55.9598, magnitude: 1.77, distance: "81 light-years",
      story: "The brightest star of Ursa Major shines in the Dipper's handle."),
    .init(
      id: "mizar", name: "Mizar", designation: "ζ Ursae Majoris", constellation: "Ursa Major",
      ra: 13.39875, dec: 54.9254, magnitude: 2.27, distance: "83 light-years",
      story: "A famous multiple system beside the naked-eye companion Alcor."),
    .init(
      id: "alkaid", name: "Alkaid", designation: "η Ursae Majoris", constellation: "Ursa Major",
      ra: 13.79234, dec: 49.3133, magnitude: 1.86, distance: "104 light-years",
      story: "The blue-white tip of the Big Dipper's curved handle."),
    .init(
      id: "bellatrix", name: "Bellatrix", designation: "γ Orionis", constellation: "Orion",
      ra: 5.41885, dec: 6.3497, magnitude: 1.64, distance: "250 light-years",
      story: "Orion's western shoulder, opposite red Betelgeuse."),
    .init(
      id: "alnitak", name: "Alnitak", designation: "ζ Orionis", constellation: "Orion", ra: 5.67931,
      dec: -1.9426, magnitude: 1.74, distance: "≈1,260 light-years",
      story: "The easternmost star of Orion's unmistakable belt."),
    .init(
      id: "alnilam", name: "Alnilam", designation: "ε Orionis", constellation: "Orion", ra: 5.60356,
      dec: -1.2019, magnitude: 1.69, distance: "≈2,000 light-years",
      story: "A very luminous supergiant at the center of Orion's belt."),
    .init(
      id: "mintaka", name: "Mintaka", designation: "δ Orionis", constellation: "Orion", ra: 5.53344,
      dec: -0.2991, magnitude: 2.23, distance: "≈1,200 light-years",
      story: "The western star of Orion's belt lies almost on the celestial equator."),
    .init(
      id: "saiph", name: "Saiph", designation: "κ Orionis", constellation: "Orion", ra: 5.79594,
      dec: -9.6696, magnitude: 2.07, distance: "650 light-years",
      story: "A hot supergiant at Orion's other foot."),
    .init(
      id: "dschubba", name: "Dschubba", designation: "δ Scorpii", constellation: "Scorpius",
      ra: 16.00556, dec: -22.6217, magnitude: 2.32, distance: "490 light-years",
      story: "A variable hot star in the Scorpion's head."),
    .init(
      id: "shaula", name: "Shaula", designation: "λ Scorpii", constellation: "Scorpius",
      ra: 17.56015, dec: -37.1038, magnitude: 1.62, distance: "570 light-years",
      story: "A brilliant multiple star at the Scorpion's sting."),
    .init(
      id: "sargas", name: "Sargas", designation: "θ Scorpii", constellation: "Scorpius",
      ra: 17.62198, dec: -42.9978, magnitude: 1.86, distance: "270 light-years",
      story: "A yellow-white giant along the curving tail of the Scorpion."),
    .init(
      id: "epsilon-sco", name: "Larawag", designation: "ε Scorpii", constellation: "Scorpius",
      ra: 16.83608, dec: -34.2933, magnitude: 2.29, distance: "64 light-years",
      story: "A nearby orange giant at the bend of the Scorpion."),
  ]

  static let paths: [[String]] = [
    ["vega", "zeta-lyr", "delta-lyr", "sulafat", "sheliak", "zeta-lyr"],
    ["deneb", "sadr", "albireo"], ["delta-cyg", "sadr", "gienah"],
    ["tarazed", "altair", "alshain"],
    ["caph", "schedar", "gamma-cas", "ruchbah", "segin"],
    ["dubhe", "merak", "phecda", "megrez", "dubhe"],
    ["megrez", "alioth", "mizar", "alkaid"],
    ["betelgeuse", "bellatrix", "mintaka", "rigel", "saiph", "alnitak", "betelgeuse"],
    ["mintaka", "alnilam", "alnitak"],
    ["dschubba", "antares", "epsilon-sco", "sargas", "shaula"],
  ]

  static func star(_ id: String) -> Star? { stars.first { $0.id == id } }
}
