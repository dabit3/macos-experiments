import Foundation

/// What is tied to the end of the line. Baits sit still under a float; lures are retrieved.
public enum TackleKind: String, Codable, CaseIterable, Hashable {
  case redWorm, doughBall, cricket, corn, minnow, cutBait, boilie, shrimp, leech
  case spoon, spinner, crankbait, softGrub, popper, jig, spinnerbait, swimbait, fly

  public var isBait: Bool {
    switch self {
    case .redWorm, .doughBall, .cricket, .corn, .minnow, .cutBait, .boilie, .shrimp, .leech:
      return true
    default: return false
    }
  }

  public var displayName: String {
    switch self {
    case .redWorm: return "Red Worms"
    case .doughBall: return "Dough Balls"
    case .cricket: return "Crickets"
    case .corn: return "Corn"
    case .minnow: return "Minnows"
    case .cutBait: return "Cut Bait"
    case .boilie: return "Boilies"
    case .shrimp: return "Shrimp"
    case .leech: return "Leeches"
    case .spoon: return "Casting Spoon"
    case .spinner: return "Spinner"
    case .crankbait: return "Crankbait"
    case .softGrub: return "Soft Grub"
    case .popper: return "Popper"
    case .jig: return "Jig Head"
    case .spinnerbait: return "Spinnerbait"
    case .swimbait: return "Swimbait"
    case .fly: return "Streamer Fly"
    }
  }
}

public enum FishColoring: String, Codable, Hashable {
  case sunfish, bass, shiner, crappie, catfish, carp, walleye, gar, trout, pike, perch, drum
  case salmon, sturgeon, snakehead, cichlid
}

public struct Species: Identifiable, Codable, Hashable {
  public let id: String
  public let name: String
  public let latinName: String
  public let minWeightLb: Double
  public let maxWeightLb: Double
  public let trophyWeightLb: Double
  public let uniqueWeightLb: Double
  public let minLengthIn: Double
  public let maxLengthIn: Double
  /// Credits per pound when sold.
  public let pricePerLb: Double
  public let xpPerLb: Double
  public let baseXP: Double
  /// Relative abundance in a waterway (higher means more common).
  public let abundance: Double
  /// Pulling strength per pound; 1.0 is a typical panfish, bass fight much harder.
  public let fightStrength: Double
  public let preferredTackle: Set<TackleKind>
  /// Hours (0-23) where bite activity is highest.
  public let peakHours: Set<Int>
  public let coloring: FishColoring

  public func lengthFor(weightLb: Double) -> Double {
    let span = max(0.0001, maxWeightLb - minWeightLb)
    let t = ((weightLb - minWeightLb) / span).clamped(0, 1)
    return minLengthIn + (maxLengthIn - minLengthIn) * pow(t, 0.42)
  }

  public func activity(atHour hour: Int) -> Double {
    if peakHours.contains(hour) { return 1.0 }
    let dist = peakHours.map { min(abs($0 - hour), 24 - abs($0 - hour)) }.min() ?? 12
    return max(0.25, 1.0 - Double(dist) * 0.18)
  }

  public func lureAffinity(_ kind: TackleKind) -> Double {
    preferredTackle.contains(kind) ? 1.0 : 0.22
  }

  public func grade(weightLb: Double) -> CatchGrade {
    if weightLb >= uniqueWeightLb { return .unique }
    if weightLb >= trophyWeightLb { return .trophy }
    if weightLb < minWeightLb + (trophyWeightLb - minWeightLb) * 0.12 { return .young }
    return .common
  }
}

public enum CatchGrade: String, Codable, Hashable {
  case young, common, trophy, unique

  public var label: String {
    switch self {
    case .young: return "YOUNG"
    case .common: return "COMMON"
    case .trophy: return "TROPHY"
    case .unique: return "UNIQUE"
    }
  }

  public var xpMultiplier: Double {
    switch self {
    case .young: return 0.6
    case .common: return 1
    case .trophy: return 3
    case .unique: return 8
    }
  }
}

extension Comparable {
  public func clamped(_ lo: Self, _ hi: Self) -> Self {
    min(max(self, lo), hi)
  }
}

public enum SpeciesCatalog {
  public static let all: [Species] = [
    Species(
      id: "bluegill", name: "Bluegill", latinName: "Lepomis macrochirus",
      minWeightLb: 0.15, maxWeightLb: 2.9, trophyWeightLb: 1.4, uniqueWeightLb: 2.6,
      minLengthIn: 4.2, maxLengthIn: 14.5, pricePerLb: 38, xpPerLb: 30, baseXP: 9,
      abundance: 1.6, fightStrength: 0.9,
      preferredTackle: [.redWorm, .cricket, .doughBall, .softGrub, .spinner],
      peakHours: [6, 7, 8, 17, 18, 19], coloring: .sunfish),
    Species(
      id: "redearSunfish", name: "Redear Sunfish", latinName: "Lepomis microlophus",
      minWeightLb: 0.2, maxWeightLb: 4.4, trophyWeightLb: 2.2, uniqueWeightLb: 4.0,
      minLengthIn: 4.5, maxLengthIn: 16.2, pricePerLb: 44, xpPerLb: 34, baseXP: 11,
      abundance: 1.1, fightStrength: 1.0,
      preferredTackle: [.redWorm, .cricket, .corn, .softGrub],
      peakHours: [7, 8, 9, 16, 17, 18], coloring: .sunfish),
    Species(
      id: "goldenShiner", name: "Golden Shiner", latinName: "Notemigonus crysoleucas",
      minWeightLb: 0.05, maxWeightLb: 1.3, trophyWeightLb: 0.7, uniqueWeightLb: 1.2,
      minLengthIn: 3.3, maxLengthIn: 12.4, pricePerLb: 24, xpPerLb: 22, baseXP: 6,
      abundance: 1.5, fightStrength: 0.6,
      preferredTackle: [.redWorm, .doughBall, .corn],
      peakHours: [5, 6, 7, 19, 20], coloring: .shiner),
    Species(
      id: "whiteCrappie", name: "White Crappie", latinName: "Pomoxis annularis",
      minWeightLb: 0.3, maxWeightLb: 4.8, trophyWeightLb: 2.4, uniqueWeightLb: 4.4,
      minLengthIn: 6.0, maxLengthIn: 19.5, pricePerLb: 52, xpPerLb: 40, baseXP: 14,
      abundance: 0.9, fightStrength: 1.0,
      preferredTackle: [.minnow, .softGrub, .jig, .spinner],
      peakHours: [5, 6, 19, 20, 21], coloring: .crappie),
    Species(
      id: "largemouthBass", name: "Largemouth Bass", latinName: "Micropterus salmoides",
      minWeightLb: 0.8, maxWeightLb: 22.0, trophyWeightLb: 9.0, uniqueWeightLb: 18.0,
      minLengthIn: 9.5, maxLengthIn: 29.0, pricePerLb: 74, xpPerLb: 60, baseXP: 30,
      abundance: 0.7, fightStrength: 1.5,
      preferredTackle: [.crankbait, .spinner, .popper, .softGrub, .minnow],
      peakHours: [6, 7, 8, 18, 19, 20], coloring: .bass),
    Species(
      id: "spottedBass", name: "Spotted Bass", latinName: "Micropterus punctulatus",
      minWeightLb: 0.6, maxWeightLb: 10.4, trophyWeightLb: 5.0, uniqueWeightLb: 9.4,
      minLengthIn: 8.5, maxLengthIn: 25.0, pricePerLb: 70, xpPerLb: 58, baseXP: 26,
      abundance: 0.5, fightStrength: 1.45,
      preferredTackle: [.crankbait, .spinner, .spoon, .softGrub],
      peakHours: [7, 8, 17, 18, 19], coloring: .bass),
    Species(
      id: "channelCatfish", name: "Channel Catfish", latinName: "Ictalurus punctatus",
      minWeightLb: 1.2, maxWeightLb: 58.0, trophyWeightLb: 20.0, uniqueWeightLb: 48.0,
      minLengthIn: 12.0, maxLengthIn: 52.0, pricePerLb: 48, xpPerLb: 46, baseXP: 34,
      abundance: 0.45, fightStrength: 1.3,
      preferredTackle: [.cutBait, .redWorm, .doughBall, .minnow],
      peakHours: [20, 21, 22, 5, 6], coloring: .catfish),
    Species(
      id: "commonCarp", name: "Common Carp", latinName: "Cyprinus carpio",
      minWeightLb: 2.0, maxWeightLb: 68.0, trophyWeightLb: 30.0, uniqueWeightLb: 60.0,
      minLengthIn: 14.0, maxLengthIn: 48.0, pricePerLb: 40, xpPerLb: 42, baseXP: 36,
      abundance: 0.4, fightStrength: 1.35,
      preferredTackle: [.corn, .doughBall, .redWorm],
      peakHours: [6, 7, 8, 9, 18, 19], coloring: .carp),
    Species(
      id: "walleye", name: "Walleye", latinName: "Sander vitreus",
      minWeightLb: 0.9, maxWeightLb: 24.0, trophyWeightLb: 10.0, uniqueWeightLb: 21.0,
      minLengthIn: 10.0, maxLengthIn: 40.0, pricePerLb: 86, xpPerLb: 66, baseXP: 40,
      abundance: 0.35, fightStrength: 1.4,
      preferredTackle: [.minnow, .jig, .crankbait, .spoon],
      peakHours: [5, 6, 20, 21, 22], coloring: .walleye),
    Species(
      id: "smallmouthBass", name: "Smallmouth Bass", latinName: "Micropterus dolomieu",
      minWeightLb: 0.6, maxWeightLb: 11.8, trophyWeightLb: 5.5, uniqueWeightLb: 10.6,
      minLengthIn: 8.0, maxLengthIn: 26.0, pricePerLb: 80, xpPerLb: 64, baseXP: 30,
      abundance: 0.7, fightStrength: 1.7,
      preferredTackle: [.crankbait, .spinner, .softGrub, .jig],
      peakHours: [6, 7, 8, 17, 18], coloring: .bass),
    Species(
      id: "longnoseGar", name: "Longnose Gar", latinName: "Lepisosteus osseus",
      minWeightLb: 1.5, maxWeightLb: 50.0, trophyWeightLb: 22.0, uniqueWeightLb: 44.0,
      minLengthIn: 20.0, maxLengthIn: 72.0, pricePerLb: 44, xpPerLb: 50, baseXP: 40,
      abundance: 0.3, fightStrength: 1.5,
      preferredTackle: [.minnow, .cutBait, .spoon],
      peakHours: [11, 12, 13, 14, 15], coloring: .gar),
    Species(
      id: "flatheadCatfish", name: "Flathead Catfish", latinName: "Pylodictis olivaris",
      minWeightLb: 2.5, maxWeightLb: 123.0, trophyWeightLb: 45.0, uniqueWeightLb: 100.0,
      minLengthIn: 15.0, maxLengthIn: 61.0, pricePerLb: 56, xpPerLb: 52, baseXP: 60,
      abundance: 0.25, fightStrength: 1.4,
      preferredTackle: [.cutBait, .minnow],
      peakHours: [21, 22, 23, 4, 5], coloring: .catfish),
    Species(
      id: "rockBass", name: "Rock Bass", latinName: "Ambloplites rupestris",
      minWeightLb: 0.2, maxWeightLb: 3.0, trophyWeightLb: 1.5, uniqueWeightLb: 2.7,
      minLengthIn: 4.5, maxLengthIn: 17.0, pricePerLb: 36, xpPerLb: 30, baseXP: 9,
      abundance: 1.2, fightStrength: 0.95,
      preferredTackle: [.redWorm, .cricket, .spinner, .softGrub],
      peakHours: [6, 7, 8, 17, 18], coloring: .sunfish),
    Species(
      id: "yellowPerch", name: "Yellow Perch", latinName: "Perca flavescens",
      minWeightLb: 0.2, maxWeightLb: 4.2, trophyWeightLb: 2.0, uniqueWeightLb: 3.8,
      minLengthIn: 5.0, maxLengthIn: 21.0, pricePerLb: 46, xpPerLb: 36, baseXP: 12,
      abundance: 1.4, fightStrength: 0.9,
      preferredTackle: [.redWorm, .minnow, .jig, .spinner],
      peakHours: [7, 8, 9, 16, 17], coloring: .perch),
    Species(
      id: "brookTrout", name: "Brook Trout", latinName: "Salvelinus fontinalis",
      minWeightLb: 0.3, maxWeightLb: 14.5, trophyWeightLb: 5.0, uniqueWeightLb: 12.0,
      minLengthIn: 7.0, maxLengthIn: 34.0, pricePerLb: 96, xpPerLb: 74, baseXP: 24,
      abundance: 0.8, fightStrength: 1.6,
      preferredTackle: [.spinner, .spoon, .redWorm, .cricket],
      peakHours: [5, 6, 7, 19, 20], coloring: .trout),
    Species(
      id: "rainbowTrout", name: "Rainbow Trout", latinName: "Oncorhynchus mykiss",
      minWeightLb: 0.5, maxWeightLb: 42.0, trophyWeightLb: 12.0, uniqueWeightLb: 36.0,
      minLengthIn: 8.0, maxLengthIn: 45.0, pricePerLb: 92, xpPerLb: 72, baseXP: 30,
      abundance: 0.6, fightStrength: 1.75,
      preferredTackle: [.spinner, .spoon, .crankbait, .corn],
      peakHours: [6, 7, 8, 18, 19], coloring: .trout),
    Species(
      id: "chainPickerel", name: "Chain Pickerel", latinName: "Esox niger",
      minWeightLb: 0.7, maxWeightLb: 9.6, trophyWeightLb: 4.5, uniqueWeightLb: 8.6,
      minLengthIn: 10.0, maxLengthIn: 31.0, pricePerLb: 66, xpPerLb: 58, baseXP: 24,
      abundance: 0.5, fightStrength: 1.55,
      preferredTackle: [.spoon, .spinner, .minnow, .crankbait],
      peakHours: [8, 9, 10, 15, 16, 17], coloring: .pike),
    Species(
      id: "northernPike", name: "Northern Pike", latinName: "Esox lucius",
      minWeightLb: 2.0, maxWeightLb: 55.0, trophyWeightLb: 22.0, uniqueWeightLb: 48.0,
      minLengthIn: 16.0, maxLengthIn: 58.0, pricePerLb: 90, xpPerLb: 70, baseXP: 60,
      abundance: 0.3, fightStrength: 1.9,
      preferredTackle: [.spoon, .crankbait, .minnow, .cutBait],
      peakHours: [7, 8, 9, 17, 18, 19], coloring: .pike),
    Species(
      id: "freshwaterDrum", name: "Freshwater Drum", latinName: "Aplodinotus grunniens",
      minWeightLb: 1.0, maxWeightLb: 54.0, trophyWeightLb: 20.0, uniqueWeightLb: 46.0,
      minLengthIn: 11.0, maxLengthIn: 37.0, pricePerLb: 38, xpPerLb: 40, baseXP: 30,
      abundance: 0.4, fightStrength: 1.25,
      preferredTackle: [.redWorm, .cutBait, .jig, .minnow],
      peakHours: [19, 20, 21, 22], coloring: .drum),

    // Panfish
    Species(
      id: "pumpkinseed", name: "Pumpkinseed", latinName: "Lepomis gibbosus",
      minWeightLb: 0.12, maxWeightLb: 2.2, trophyWeightLb: 1.0, uniqueWeightLb: 2.0,
      minLengthIn: 4.0, maxLengthIn: 13.0, pricePerLb: 36, xpPerLb: 30, baseXP: 8,
      abundance: 1.5, fightStrength: 0.85,
      preferredTackle: [.redWorm, .cricket, .corn, .fly],
      peakHours: [7, 8, 9, 17, 18], coloring: .sunfish),
    Species(
      id: "greenSunfish", name: "Green Sunfish", latinName: "Lepomis cyanellus",
      minWeightLb: 0.1, maxWeightLb: 2.4, trophyWeightLb: 1.1, uniqueWeightLb: 2.2,
      minLengthIn: 3.8, maxLengthIn: 12.5, pricePerLb: 32, xpPerLb: 28, baseXP: 8,
      abundance: 1.6, fightStrength: 0.9,
      preferredTackle: [.redWorm, .cricket, .softGrub, .spinner],
      peakHours: [8, 9, 10, 16, 17], coloring: .sunfish),
    Species(
      id: "warmouth", name: "Warmouth", latinName: "Lepomis gulosus",
      minWeightLb: 0.15, maxWeightLb: 2.6, trophyWeightLb: 1.2, uniqueWeightLb: 2.4,
      minLengthIn: 4.2, maxLengthIn: 13.5, pricePerLb: 34, xpPerLb: 30, baseXP: 9,
      abundance: 1.0, fightStrength: 0.95,
      preferredTackle: [.redWorm, .minnow, .cricket, .jig],
      peakHours: [6, 7, 18, 19, 20], coloring: .sunfish),
    Species(
      id: "longearSunfish", name: "Longear Sunfish", latinName: "Lepomis megalotis",
      minWeightLb: 0.1, maxWeightLb: 1.9, trophyWeightLb: 0.9, uniqueWeightLb: 1.7,
      minLengthIn: 3.5, maxLengthIn: 11.5, pricePerLb: 40, xpPerLb: 30, baseXP: 8,
      abundance: 1.3, fightStrength: 0.85,
      preferredTackle: [.redWorm, .cricket, .fly, .spinner],
      peakHours: [7, 8, 9, 16, 17, 18], coloring: .sunfish),
    Species(
      id: "blackCrappie", name: "Black Crappie", latinName: "Pomoxis nigromaculatus",
      minWeightLb: 0.3, maxWeightLb: 5.6, trophyWeightLb: 2.6, uniqueWeightLb: 5.0,
      minLengthIn: 6.0, maxLengthIn: 20.0, pricePerLb: 54, xpPerLb: 40, baseXP: 14,
      abundance: 0.9, fightStrength: 1.0,
      preferredTackle: [.minnow, .jig, .softGrub, .spinner],
      peakHours: [5, 6, 7, 19, 20], coloring: .crappie),
    Species(
      id: "whiteBass", name: "White Bass", latinName: "Morone chrysops",
      minWeightLb: 0.5, maxWeightLb: 7.0, trophyWeightLb: 3.2, uniqueWeightLb: 6.4,
      minLengthIn: 8.0, maxLengthIn: 22.0, pricePerLb: 50, xpPerLb: 44, baseXP: 18,
      abundance: 1.0, fightStrength: 1.3,
      preferredTackle: [.spoon, .jig, .minnow, .spinner],
      peakHours: [6, 7, 8, 18, 19], coloring: .crappie),

    // Bass and perch-like predators
    Species(
      id: "stripedBass", name: "Striped Bass", latinName: "Morone saxatilis",
      minWeightLb: 2.0, maxWeightLb: 80.0, trophyWeightLb: 30.0, uniqueWeightLb: 70.0,
      minLengthIn: 14.0, maxLengthIn: 60.0, pricePerLb: 88, xpPerLb: 66, baseXP: 60,
      abundance: 0.3, fightStrength: 1.8,
      preferredTackle: [.swimbait, .cutBait, .crankbait, .spoon, .minnow],
      peakHours: [5, 6, 7, 19, 20, 21], coloring: .bass),
    Species(
      id: "guadalupeBass", name: "Guadalupe Bass", latinName: "Micropterus treculii",
      minWeightLb: 0.4, maxWeightLb: 4.0, trophyWeightLb: 2.0, uniqueWeightLb: 3.6,
      minLengthIn: 7.0, maxLengthIn: 18.0, pricePerLb: 78, xpPerLb: 60, baseXP: 22,
      abundance: 0.6, fightStrength: 1.5,
      preferredTackle: [.softGrub, .spinner, .crankbait, .fly],
      peakHours: [7, 8, 9, 17, 18], coloring: .bass),
    Species(
      id: "europeanPerch", name: "European Perch", latinName: "Perca fluviatilis",
      minWeightLb: 0.2, maxWeightLb: 7.0, trophyWeightLb: 3.0, uniqueWeightLb: 6.2,
      minLengthIn: 5.0, maxLengthIn: 24.0, pricePerLb: 48, xpPerLb: 38, baseXP: 13,
      abundance: 1.3, fightStrength: 1.0,
      preferredTackle: [.redWorm, .minnow, .jig, .spinner, .softGrub],
      peakHours: [7, 8, 9, 16, 17, 18], coloring: .perch),
    Species(
      id: "zander", name: "Zander", latinName: "Sander lucioperca",
      minWeightLb: 1.0, maxWeightLb: 44.0, trophyWeightLb: 16.0, uniqueWeightLb: 38.0,
      minLengthIn: 12.0, maxLengthIn: 48.0, pricePerLb: 90, xpPerLb: 68, baseXP: 42,
      abundance: 0.35, fightStrength: 1.45,
      preferredTackle: [.softGrub, .jig, .minnow, .swimbait],
      peakHours: [4, 5, 21, 22, 23], coloring: .walleye),
    Species(
      id: "goldenPerch", name: "Golden Perch", latinName: "Macquaria ambigua",
      minWeightLb: 0.8, maxWeightLb: 50.0, trophyWeightLb: 15.0, uniqueWeightLb: 42.0,
      minLengthIn: 10.0, maxLengthIn: 30.0, pricePerLb: 70, xpPerLb: 56, baseXP: 30,
      abundance: 0.6, fightStrength: 1.4,
      preferredTackle: [.shrimp, .redWorm, .spinnerbait, .crankbait],
      peakHours: [6, 7, 8, 17, 18, 19], coloring: .perch),
    Species(
      id: "dorado", name: "Golden Dorado", latinName: "Salminus brasiliensis",
      minWeightLb: 2.0, maxWeightLb: 68.0, trophyWeightLb: 25.0, uniqueWeightLb: 60.0,
      minLengthIn: 14.0, maxLengthIn: 51.0, pricePerLb: 120, xpPerLb: 90, baseXP: 80,
      abundance: 0.3, fightStrength: 2.1,
      preferredTackle: [.fly, .swimbait, .spoon, .minnow],
      peakHours: [7, 8, 9, 10, 16, 17], coloring: .perch),

    // Catfish
    Species(
      id: "blueCatfish", name: "Blue Catfish", latinName: "Ictalurus furcatus",
      minWeightLb: 2.0, maxWeightLb: 143.0, trophyWeightLb: 50.0, uniqueWeightLb: 120.0,
      minLengthIn: 14.0, maxLengthIn: 65.0, pricePerLb: 50, xpPerLb: 50, baseXP: 60,
      abundance: 0.3, fightStrength: 1.45,
      preferredTackle: [.cutBait, .shrimp, .minnow],
      peakHours: [20, 21, 22, 23, 4, 5], coloring: .catfish),
    Species(
      id: "brownBullhead", name: "Brown Bullhead", latinName: "Ameiurus nebulosus",
      minWeightLb: 0.3, maxWeightLb: 7.0, trophyWeightLb: 3.0, uniqueWeightLb: 6.2,
      minLengthIn: 6.0, maxLengthIn: 21.0, pricePerLb: 30, xpPerLb: 30, baseXP: 10,
      abundance: 1.2, fightStrength: 1.0,
      preferredTackle: [.redWorm, .cutBait, .doughBall, .shrimp],
      peakHours: [21, 22, 23, 0, 5], coloring: .catfish),
    Species(
      id: "welsCatfish", name: "Wels Catfish", latinName: "Silurus glanis",
      minWeightLb: 5.0, maxWeightLb: 300.0, trophyWeightLb: 110.0, uniqueWeightLb: 250.0,
      minLengthIn: 24.0, maxLengthIn: 110.0, pricePerLb: 44, xpPerLb: 48, baseXP: 120,
      abundance: 0.2, fightStrength: 1.6,
      preferredTackle: [.cutBait, .boilie, .leech, .swimbait],
      peakHours: [22, 23, 0, 1, 2, 3], coloring: .catfish),
    Species(
      id: "redtailCatfish", name: "Redtail Catfish", latinName: "Phractocephalus hemioliopterus",
      minWeightLb: 4.0, maxWeightLb: 130.0, trophyWeightLb: 50.0, uniqueWeightLb: 110.0,
      minLengthIn: 20.0, maxLengthIn: 63.0, pricePerLb: 60, xpPerLb: 56, baseXP: 90,
      abundance: 0.25, fightStrength: 1.7,
      preferredTackle: [.cutBait, .shrimp, .boilie],
      peakHours: [19, 20, 21, 22, 5], coloring: .catfish),
    Species(
      id: "murrayCod", name: "Murray Cod", latinName: "Maccullochella peelii",
      minWeightLb: 3.0, maxWeightLb: 250.0, trophyWeightLb: 70.0, uniqueWeightLb: 200.0,
      minLengthIn: 18.0, maxLengthIn: 72.0, pricePerLb: 84, xpPerLb: 70, baseXP: 110,
      abundance: 0.2, fightStrength: 1.75,
      preferredTackle: [.swimbait, .spinnerbait, .shrimp, .cutBait],
      peakHours: [5, 6, 19, 20, 21], coloring: .catfish),

    // Carp family and coarse fish
    Species(
      id: "mirrorCarp", name: "Mirror Carp", latinName: "Cyprinus carpio carpio",
      minWeightLb: 2.5, maxWeightLb: 72.0, trophyWeightLb: 32.0, uniqueWeightLb: 64.0,
      minLengthIn: 14.0, maxLengthIn: 47.0, pricePerLb: 46, xpPerLb: 44, baseXP: 38,
      abundance: 0.35, fightStrength: 1.4,
      preferredTackle: [.boilie, .corn, .doughBall],
      peakHours: [5, 6, 7, 19, 20, 21], coloring: .carp),
    Species(
      id: "grassCarp", name: "Grass Carp", latinName: "Ctenopharyngodon idella",
      minWeightLb: 3.0, maxWeightLb: 90.0, trophyWeightLb: 38.0, uniqueWeightLb: 80.0,
      minLengthIn: 16.0, maxLengthIn: 55.0, pricePerLb: 36, xpPerLb: 42, baseXP: 40,
      abundance: 0.3, fightStrength: 1.5,
      preferredTackle: [.corn, .doughBall, .boilie],
      peakHours: [8, 9, 10, 11, 16, 17], coloring: .carp),
    Species(
      id: "commonBream", name: "Common Bream", latinName: "Abramis brama",
      minWeightLb: 0.5, maxWeightLb: 15.0, trophyWeightLb: 7.0, uniqueWeightLb: 13.5,
      minLengthIn: 8.0, maxLengthIn: 32.0, pricePerLb: 34, xpPerLb: 34, baseXP: 14,
      abundance: 1.0, fightStrength: 0.9,
      preferredTackle: [.redWorm, .corn, .doughBall, .boilie],
      peakHours: [4, 5, 6, 20, 21, 22], coloring: .carp),
    Species(
      id: "tench", name: "Tench", latinName: "Tinca tinca",
      minWeightLb: 0.8, maxWeightLb: 16.0, trophyWeightLb: 7.0, uniqueWeightLb: 14.0,
      minLengthIn: 9.0, maxLengthIn: 30.0, pricePerLb: 42, xpPerLb: 38, baseXP: 16,
      abundance: 0.7, fightStrength: 1.2,
      preferredTackle: [.redWorm, .corn, .boilie],
      peakHours: [4, 5, 6, 7, 20], coloring: .carp),
    Species(
      id: "barbel", name: "Barbel", latinName: "Barbus barbus",
      minWeightLb: 1.0, maxWeightLb: 26.0, trophyWeightLb: 12.0, uniqueWeightLb: 23.0,
      minLengthIn: 12.0, maxLengthIn: 42.0, pricePerLb: 52, xpPerLb: 46, baseXP: 24,
      abundance: 0.6, fightStrength: 1.55,
      preferredTackle: [.boilie, .redWorm, .cutBait, .corn],
      peakHours: [19, 20, 21, 22, 23], coloring: .carp),
    Species(
      id: "mahseer", name: "Golden Mahseer", latinName: "Tor putitora",
      minWeightLb: 2.0, maxWeightLb: 120.0, trophyWeightLb: 40.0, uniqueWeightLb: 100.0,
      minLengthIn: 14.0, maxLengthIn: 70.0, pricePerLb: 110, xpPerLb: 84, baseXP: 90,
      abundance: 0.25, fightStrength: 2.0,
      preferredTackle: [.spoon, .swimbait, .doughBall, .fly],
      peakHours: [6, 7, 8, 17, 18, 19], coloring: .carp),
    Species(
      id: "tambaqui", name: "Tambaqui", latinName: "Colossoma macropomum",
      minWeightLb: 2.0, maxWeightLb: 90.0, trophyWeightLb: 35.0, uniqueWeightLb: 78.0,
      minLengthIn: 12.0, maxLengthIn: 43.0, pricePerLb: 58, xpPerLb: 52, baseXP: 50,
      abundance: 0.4, fightStrength: 1.6,
      preferredTackle: [.corn, .doughBall, .boilie, .cutBait],
      peakHours: [7, 8, 9, 16, 17, 18], coloring: .carp),
    Species(
      id: "roach", name: "Roach", latinName: "Rutilus rutilus",
      minWeightLb: 0.1, maxWeightLb: 4.0, trophyWeightLb: 1.8, uniqueWeightLb: 3.6,
      minLengthIn: 4.0, maxLengthIn: 20.0, pricePerLb: 26, xpPerLb: 24, baseXP: 7,
      abundance: 1.7, fightStrength: 0.65,
      preferredTackle: [.redWorm, .doughBall, .corn],
      peakHours: [6, 7, 8, 18, 19, 20], coloring: .shiner),
    Species(
      id: "rudd", name: "Rudd", latinName: "Scardinius erythrophthalmus",
      minWeightLb: 0.15, maxWeightLb: 4.4, trophyWeightLb: 2.0, uniqueWeightLb: 4.0,
      minLengthIn: 4.5, maxLengthIn: 20.0, pricePerLb: 28, xpPerLb: 26, baseXP: 8,
      abundance: 1.3, fightStrength: 0.7,
      preferredTackle: [.doughBall, .corn, .fly, .redWorm],
      peakHours: [9, 10, 11, 15, 16, 17], coloring: .shiner),
    Species(
      id: "chub", name: "Chub", latinName: "Squalius cephalus",
      minWeightLb: 0.4, maxWeightLb: 10.0, trophyWeightLb: 5.0, uniqueWeightLb: 9.0,
      minLengthIn: 7.0, maxLengthIn: 28.0, pricePerLb: 32, xpPerLb: 32, baseXP: 12,
      abundance: 1.0, fightStrength: 1.0,
      preferredTackle: [.doughBall, .cutBait, .crankbait, .redWorm],
      peakHours: [7, 8, 9, 17, 18, 19], coloring: .shiner),
    Species(
      id: "tarpon", name: "Tarpon", latinName: "Megalops atlanticus",
      minWeightLb: 5.0, maxWeightLb: 280.0, trophyWeightLb: 100.0, uniqueWeightLb: 240.0,
      minLengthIn: 24.0, maxLengthIn: 100.0, pricePerLb: 70, xpPerLb: 80, baseXP: 150,
      abundance: 0.2, fightStrength: 2.4,
      preferredTackle: [.fly, .swimbait, .shrimp, .cutBait],
      peakHours: [5, 6, 7, 18, 19, 20], coloring: .shiner),

    // Trout, char and grayling
    Species(
      id: "brownTrout", name: "Brown Trout", latinName: "Salmo trutta",
      minWeightLb: 0.4, maxWeightLb: 42.0, trophyWeightLb: 12.0, uniqueWeightLb: 36.0,
      minLengthIn: 8.0, maxLengthIn: 44.0, pricePerLb: 94, xpPerLb: 72, baseXP: 28,
      abundance: 0.7, fightStrength: 1.7,
      preferredTackle: [.fly, .spinner, .spoon, .minnow],
      peakHours: [5, 6, 7, 19, 20, 21], coloring: .trout),
    Species(
      id: "cutthroatTrout", name: "Cutthroat Trout", latinName: "Oncorhynchus clarkii",
      minWeightLb: 0.4, maxWeightLb: 41.0, trophyWeightLb: 10.0, uniqueWeightLb: 34.0,
      minLengthIn: 8.0, maxLengthIn: 39.0, pricePerLb: 92, xpPerLb: 72, baseXP: 28,
      abundance: 0.7, fightStrength: 1.6,
      preferredTackle: [.fly, .spinner, .spoon, .redWorm],
      peakHours: [6, 7, 8, 18, 19], coloring: .trout),
    Species(
      id: "lakeTrout", name: "Lake Trout", latinName: "Salvelinus namaycush",
      minWeightLb: 1.5, maxWeightLb: 72.0, trophyWeightLb: 25.0, uniqueWeightLb: 62.0,
      minLengthIn: 12.0, maxLengthIn: 50.0, pricePerLb: 88, xpPerLb: 70, baseXP: 50,
      abundance: 0.4, fightStrength: 1.65,
      preferredTackle: [.spoon, .swimbait, .jig, .minnow],
      peakHours: [5, 6, 7, 8, 19, 20], coloring: .trout),
    Species(
      id: "goldenTrout", name: "Golden Trout", latinName: "Oncorhynchus aguabonita",
      minWeightLb: 0.2, maxWeightLb: 11.0, trophyWeightLb: 4.0, uniqueWeightLb: 9.5,
      minLengthIn: 6.0, maxLengthIn: 28.0, pricePerLb: 130, xpPerLb: 86, baseXP: 26,
      abundance: 0.4, fightStrength: 1.5,
      preferredTackle: [.fly, .spinner, .cricket],
      peakHours: [7, 8, 9, 16, 17, 18], coloring: .trout),
    Species(
      id: "arcticChar", name: "Arctic Char", latinName: "Salvelinus alpinus",
      minWeightLb: 0.6, maxWeightLb: 32.0, trophyWeightLb: 12.0, uniqueWeightLb: 28.0,
      minLengthIn: 9.0, maxLengthIn: 42.0, pricePerLb: 100, xpPerLb: 76, baseXP: 32,
      abundance: 0.5, fightStrength: 1.7,
      preferredTackle: [.spoon, .fly, .spinner, .minnow],
      peakHours: [4, 5, 6, 20, 21, 22], coloring: .trout),
    Species(
      id: "steelhead", name: "Steelhead", latinName: "Oncorhynchus mykiss irideus",
      minWeightLb: 2.0, maxWeightLb: 44.0, trophyWeightLb: 16.0, uniqueWeightLb: 38.0,
      minLengthIn: 16.0, maxLengthIn: 46.0, pricePerLb: 104, xpPerLb: 80, baseXP: 50,
      abundance: 0.4, fightStrength: 2.0,
      preferredTackle: [.fly, .spoon, .spinner, .shrimp],
      peakHours: [6, 7, 8, 9, 17, 18], coloring: .trout),
    Species(
      id: "arcticGrayling", name: "Arctic Grayling", latinName: "Thymallus arcticus",
      minWeightLb: 0.3, maxWeightLb: 6.0, trophyWeightLb: 2.6, uniqueWeightLb: 5.4,
      minLengthIn: 7.0, maxLengthIn: 30.0, pricePerLb: 96, xpPerLb: 70, baseXP: 18,
      abundance: 0.9, fightStrength: 1.2,
      preferredTackle: [.fly, .spinner, .redWorm],
      peakHours: [9, 10, 11, 12, 15, 16], coloring: .trout),
    Species(
      id: "spottedSeatrout", name: "Spotted Seatrout", latinName: "Cynoscion nebulosus",
      minWeightLb: 0.8, maxWeightLb: 17.0, trophyWeightLb: 7.0, uniqueWeightLb: 15.0,
      minLengthIn: 10.0, maxLengthIn: 39.0, pricePerLb: 82, xpPerLb: 62, baseXP: 26,
      abundance: 0.8, fightStrength: 1.4,
      preferredTackle: [.shrimp, .popper, .softGrub, .swimbait],
      peakHours: [5, 6, 7, 19, 20], coloring: .trout),

    // Salmon
    Species(
      id: "chinookSalmon", name: "Chinook Salmon", latinName: "Oncorhynchus tshawytscha",
      minWeightLb: 5.0, maxWeightLb: 97.0, trophyWeightLb: 40.0, uniqueWeightLb: 85.0,
      minLengthIn: 22.0, maxLengthIn: 58.0, pricePerLb: 110, xpPerLb: 84, baseXP: 90,
      abundance: 0.3, fightStrength: 2.2,
      preferredTackle: [.spoon, .swimbait, .fly, .shrimp],
      peakHours: [5, 6, 7, 8, 20, 21], coloring: .salmon),
    Species(
      id: "cohoSalmon", name: "Coho Salmon", latinName: "Oncorhynchus kisutch",
      minWeightLb: 2.5, maxWeightLb: 33.0, trophyWeightLb: 14.0, uniqueWeightLb: 29.0,
      minLengthIn: 16.0, maxLengthIn: 42.0, pricePerLb: 104, xpPerLb: 80, baseXP: 50,
      abundance: 0.45, fightStrength: 2.0,
      preferredTackle: [.spinner, .spoon, .fly, .swimbait],
      peakHours: [6, 7, 8, 18, 19, 20], coloring: .salmon),
    Species(
      id: "atlanticSalmon", name: "Atlantic Salmon", latinName: "Salmo salar",
      minWeightLb: 3.0, maxWeightLb: 79.0, trophyWeightLb: 30.0, uniqueWeightLb: 70.0,
      minLengthIn: 18.0, maxLengthIn: 60.0, pricePerLb: 120, xpPerLb: 88, baseXP: 80,
      abundance: 0.3, fightStrength: 2.1,
      preferredTackle: [.fly, .spoon, .spinner],
      peakHours: [5, 6, 7, 20, 21, 22], coloring: .salmon),
    Species(
      id: "sockeyeSalmon", name: "Sockeye Salmon", latinName: "Oncorhynchus nerka",
      minWeightLb: 2.5, maxWeightLb: 15.5, trophyWeightLb: 8.0, uniqueWeightLb: 14.0,
      minLengthIn: 16.0, maxLengthIn: 33.0, pricePerLb: 112, xpPerLb: 78, baseXP: 40,
      abundance: 0.6, fightStrength: 1.9,
      preferredTackle: [.fly, .spinner, .shrimp],
      peakHours: [6, 7, 8, 9, 19], coloring: .salmon),
    Species(
      id: "taimen", name: "Siberian Taimen", latinName: "Hucho taimen",
      minWeightLb: 6.0, maxWeightLb: 230.0, trophyWeightLb: 80.0, uniqueWeightLb: 200.0,
      minLengthIn: 26.0, maxLengthIn: 83.0, pricePerLb: 150, xpPerLb: 100, baseXP: 160,
      abundance: 0.15, fightStrength: 2.5,
      preferredTackle: [.swimbait, .fly, .spoon, .popper],
      peakHours: [6, 7, 8, 19, 20, 21], coloring: .salmon),

    // Pike and toothy predators
    Species(
      id: "muskellunge", name: "Muskellunge", latinName: "Esox masquinongy",
      minWeightLb: 4.0, maxWeightLb: 70.0, trophyWeightLb: 30.0, uniqueWeightLb: 62.0,
      minLengthIn: 22.0, maxLengthIn: 72.0, pricePerLb: 100, xpPerLb: 78, baseXP: 90,
      abundance: 0.15, fightStrength: 2.1,
      preferredTackle: [.swimbait, .spinnerbait, .crankbait, .cutBait],
      peakHours: [6, 7, 8, 18, 19, 20], coloring: .pike),
    Species(
      id: "tigerfish", name: "Tigerfish", latinName: "Hydrocynus vittatus",
      minWeightLb: 1.5, maxWeightLb: 35.0, trophyWeightLb: 14.0, uniqueWeightLb: 30.0,
      minLengthIn: 12.0, maxLengthIn: 41.0, pricePerLb: 116, xpPerLb: 86, baseXP: 60,
      abundance: 0.35, fightStrength: 2.3,
      preferredTackle: [.spoon, .cutBait, .swimbait, .fly],
      peakHours: [8, 9, 10, 15, 16, 17], coloring: .pike),
    Species(
      id: "payara", name: "Payara", latinName: "Hydrolycus scomberoides",
      minWeightLb: 2.0, maxWeightLb: 40.0, trophyWeightLb: 16.0, uniqueWeightLb: 35.0,
      minLengthIn: 14.0, maxLengthIn: 46.0, pricePerLb: 118, xpPerLb: 86, baseXP: 64,
      abundance: 0.3, fightStrength: 2.2,
      preferredTackle: [.swimbait, .spoon, .cutBait, .fly],
      peakHours: [17, 18, 19, 20, 21], coloring: .pike),

    // Gar, bowfin and river giants
    Species(
      id: "alligatorGar", name: "Alligator Gar", latinName: "Atractosteus spatula",
      minWeightLb: 8.0, maxWeightLb: 327.0, trophyWeightLb: 120.0, uniqueWeightLb: 280.0,
      minLengthIn: 30.0, maxLengthIn: 110.0, pricePerLb: 48, xpPerLb: 60, baseXP: 180,
      abundance: 0.15, fightStrength: 1.9,
      preferredTackle: [.cutBait, .minnow],
      peakHours: [10, 11, 12, 13, 14, 15], coloring: .gar),
    Species(
      id: "spottedGar", name: "Spotted Gar", latinName: "Lepisosteus oculatus",
      minWeightLb: 1.0, maxWeightLb: 12.0, trophyWeightLb: 5.5, uniqueWeightLb: 10.5,
      minLengthIn: 16.0, maxLengthIn: 44.0, pricePerLb: 42, xpPerLb: 46, baseXP: 28,
      abundance: 0.5, fightStrength: 1.4,
      preferredTackle: [.minnow, .cutBait, .spinnerbait],
      peakHours: [10, 11, 12, 13, 16], coloring: .gar),
    Species(
      id: "bowfin", name: "Bowfin", latinName: "Amia calva",
      minWeightLb: 1.0, maxWeightLb: 21.5, trophyWeightLb: 9.0, uniqueWeightLb: 19.0,
      minLengthIn: 14.0, maxLengthIn: 43.0, pricePerLb: 40, xpPerLb: 46, baseXP: 30,
      abundance: 0.45, fightStrength: 1.6,
      preferredTackle: [.cutBait, .minnow, .softGrub, .spinnerbait],
      peakHours: [9, 10, 11, 15, 16, 17], coloring: .gar),
    Species(
      id: "arapaima", name: "Arapaima", latinName: "Arapaima gigas",
      minWeightLb: 10.0, maxWeightLb: 440.0, trophyWeightLb: 150.0, uniqueWeightLb: 380.0,
      minLengthIn: 34.0, maxLengthIn: 118.0, pricePerLb: 62, xpPerLb: 70, baseXP: 220,
      abundance: 0.12, fightStrength: 2.4,
      preferredTackle: [.cutBait, .swimbait, .shrimp],
      peakHours: [6, 7, 8, 17, 18, 19], coloring: .gar),

    // Sturgeon and paddlefish
    Species(
      id: "whiteSturgeon", name: "White Sturgeon", latinName: "Acipenser transmontanus",
      minWeightLb: 10.0, maxWeightLb: 1100.0, trophyWeightLb: 300.0, uniqueWeightLb: 900.0,
      minLengthIn: 36.0, maxLengthIn: 160.0, pricePerLb: 40, xpPerLb: 60, baseXP: 300,
      abundance: 0.1, fightStrength: 2.2,
      preferredTackle: [.cutBait, .shrimp, .leech],
      peakHours: [5, 6, 7, 20, 21, 22], coloring: .sturgeon),
    Species(
      id: "lakeSturgeon", name: "Lake Sturgeon", latinName: "Acipenser fulvescens",
      minWeightLb: 5.0, maxWeightLb: 240.0, trophyWeightLb: 90.0, uniqueWeightLb: 210.0,
      minLengthIn: 28.0, maxLengthIn: 96.0, pricePerLb: 44, xpPerLb: 60, baseXP: 200,
      abundance: 0.12, fightStrength: 2.0,
      preferredTackle: [.cutBait, .redWorm, .leech],
      peakHours: [20, 21, 22, 23, 4, 5], coloring: .sturgeon),
    Species(
      id: "paddlefish", name: "American Paddlefish", latinName: "Polyodon spathula",
      minWeightLb: 5.0, maxWeightLb: 150.0, trophyWeightLb: 60.0, uniqueWeightLb: 130.0,
      minLengthIn: 28.0, maxLengthIn: 87.0, pricePerLb: 46, xpPerLb: 56, baseXP: 120,
      abundance: 0.15, fightStrength: 1.8,
      preferredTackle: [.jig, .spoon, .swimbait],
      peakHours: [8, 9, 10, 11, 12], coloring: .sturgeon),

    // Snakeheads
    Species(
      id: "northernSnakehead", name: "Northern Snakehead", latinName: "Channa argus",
      minWeightLb: 1.0, maxWeightLb: 19.0, trophyWeightLb: 9.0, uniqueWeightLb: 17.0,
      minLengthIn: 12.0, maxLengthIn: 40.0, pricePerLb: 66, xpPerLb: 60, baseXP: 34,
      abundance: 0.45, fightStrength: 1.8,
      preferredTackle: [.popper, .swimbait, .spinnerbait, .minnow],
      peakHours: [7, 8, 9, 17, 18, 19], coloring: .snakehead),
    Species(
      id: "giantSnakehead", name: "Giant Snakehead", latinName: "Channa micropeltes",
      minWeightLb: 2.0, maxWeightLb: 44.0, trophyWeightLb: 18.0, uniqueWeightLb: 38.0,
      minLengthIn: 14.0, maxLengthIn: 51.0, pricePerLb: 84, xpPerLb: 72, baseXP: 60,
      abundance: 0.3, fightStrength: 2.2,
      preferredTackle: [.popper, .swimbait, .spinnerbait, .cutBait],
      peakHours: [6, 7, 8, 16, 17, 18], coloring: .snakehead),

    // Cichlids
    Species(
      id: "peacockBass", name: "Peacock Bass", latinName: "Cichla ocellaris",
      minWeightLb: 1.0, maxWeightLb: 29.0, trophyWeightLb: 12.0, uniqueWeightLb: 26.0,
      minLengthIn: 10.0, maxLengthIn: 39.0, pricePerLb: 108, xpPerLb: 80, baseXP: 40,
      abundance: 0.5, fightStrength: 2.1,
      preferredTackle: [.popper, .swimbait, .jig, .minnow],
      peakHours: [8, 9, 10, 11, 15, 16], coloring: .cichlid),
    Species(
      id: "tilapia", name: "Blue Tilapia", latinName: "Oreochromis aureus",
      minWeightLb: 0.4, maxWeightLb: 10.0, trophyWeightLb: 4.5, uniqueWeightLb: 9.0,
      minLengthIn: 6.0, maxLengthIn: 21.0, pricePerLb: 44, xpPerLb: 36, baseXP: 14,
      abundance: 1.2, fightStrength: 1.1,
      preferredTackle: [.corn, .doughBall, .redWorm, .boilie],
      peakHours: [9, 10, 11, 12, 15, 16], coloring: .cichlid),
    Species(
      id: "oscar", name: "Oscar", latinName: "Astronotus ocellatus",
      minWeightLb: 0.3, maxWeightLb: 3.5, trophyWeightLb: 1.6, uniqueWeightLb: 3.1,
      minLengthIn: 5.0, maxLengthIn: 18.0, pricePerLb: 56, xpPerLb: 40, baseXP: 12,
      abundance: 1.0, fightStrength: 1.2,
      preferredTackle: [.redWorm, .cricket, .softGrub, .jig],
      peakHours: [8, 9, 10, 16, 17], coloring: .cichlid),

    // Estuary and brackish species
    Species(
      id: "redDrum", name: "Red Drum", latinName: "Sciaenops ocellatus",
      minWeightLb: 1.5, maxWeightLb: 94.0, trophyWeightLb: 35.0, uniqueWeightLb: 82.0,
      minLengthIn: 12.0, maxLengthIn: 61.0, pricePerLb: 80, xpPerLb: 66, baseXP: 50,
      abundance: 0.5, fightStrength: 1.9,
      preferredTackle: [.shrimp, .cutBait, .spoon, .softGrub],
      peakHours: [5, 6, 7, 18, 19, 20], coloring: .drum),
    Species(
      id: "blackDrum", name: "Black Drum", latinName: "Pogonias cromis",
      minWeightLb: 2.0, maxWeightLb: 113.0, trophyWeightLb: 40.0, uniqueWeightLb: 100.0,
      minLengthIn: 14.0, maxLengthIn: 67.0, pricePerLb: 52, xpPerLb: 52, baseXP: 50,
      abundance: 0.45, fightStrength: 1.6,
      preferredTackle: [.shrimp, .cutBait, .redWorm],
      peakHours: [19, 20, 21, 22, 6], coloring: .drum),
    Species(
      id: "snook", name: "Common Snook", latinName: "Centropomus undecimalis",
      minWeightLb: 1.5, maxWeightLb: 53.0, trophyWeightLb: 20.0, uniqueWeightLb: 47.0,
      minLengthIn: 12.0, maxLengthIn: 55.0, pricePerLb: 98, xpPerLb: 74, baseXP: 44,
      abundance: 0.45, fightStrength: 2.0,
      preferredTackle: [.swimbait, .shrimp, .popper, .minnow],
      peakHours: [20, 21, 22, 23, 5, 6], coloring: .bass),
    Species(
      id: "barramundi", name: "Barramundi", latinName: "Lates calcarifer",
      minWeightLb: 2.0, maxWeightLb: 100.0, trophyWeightLb: 40.0, uniqueWeightLb: 88.0,
      minLengthIn: 14.0, maxLengthIn: 71.0, pricePerLb: 102, xpPerLb: 78, baseXP: 60,
      abundance: 0.4, fightStrength: 2.1,
      preferredTackle: [.swimbait, .popper, .shrimp, .crankbait],
      peakHours: [5, 6, 7, 18, 19, 20], coloring: .bass),
    Species(
      id: "nilePerch", name: "Nile Perch", latinName: "Lates niloticus",
      minWeightLb: 4.0, maxWeightLb: 440.0, trophyWeightLb: 150.0, uniqueWeightLb: 380.0,
      minLengthIn: 20.0, maxLengthIn: 78.0, pricePerLb: 74, xpPerLb: 70, baseXP: 200,
      abundance: 0.15, fightStrength: 2.2,
      preferredTackle: [.swimbait, .cutBait, .crankbait, .minnow],
      peakHours: [5, 6, 7, 19, 20, 21], coloring: .bass),
  ]

  public static let byID: [String: Species] = Dictionary(
    uniqueKeysWithValues: all.map { ($0.id, $0) })

  public static func find(_ id: String) -> Species {
    guard let species = byID[id] else { fatalError("Unknown species \(id)") }
    return species
  }
}
