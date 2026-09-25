import Foundation

public enum TackleCategory: String, Codable, CaseIterable, Hashable {
  case rods, reels, lines, terminalTackle, lures, baits

  public var label: String {
    switch self {
    case .rods: return "RODS"
    case .reels: return "REELS"
    case .lines: return "LINES"
    case .terminalTackle: return "TERMINAL TACKLE"
    case .lures: return "LURES"
    case .baits: return "BAITS"
    }
  }
}

public enum RodStyle: String, Codable, Hashable {
  case spinning, float, bottom

  public var label: String {
    switch self {
    case .spinning: return "Spinning"
    case .float: return "Float"
    case .bottom: return "Bottom"
    }
  }
}

/// Everything sold in the shop. Stats not relevant to an item are zero.
public struct TackleItem: Identifiable, Codable, Hashable {
  public let id: String
  public let name: String
  public let brand: String
  public let category: TackleCategory
  public let price: Int
  public let requiredLevel: Int
  /// Rods
  public let rodStyle: RodStyle?
  public let lengthFt: Double
  public let castWeightMinOz: Double
  public let castWeightMaxOz: Double
  public let rodLineWeightLb: Double
  /// Reels
  public let maxDragLb: Double
  public let gearRatio: Double
  public let lineCapacityYd: Int
  /// Lines
  public let testLb: Double
  public let diameterMm: Double
  public let spoolYd: Int
  /// Lures / baits / terminal tackle
  public let tackleKind: TackleKind?
  public let weightOz: Double
  public let hookSize: Int
  public let quantityPerPack: Int

  public var isConsumable: Bool { category == .baits }

  public static func rod(
    id: String, name: String, brand: String, price: Int, level: Int, style: RodStyle,
    lengthFt: Double, castOz: ClosedRange<Double>, lineLb: Double
  ) -> TackleItem {
    TackleItem(
      id: id, name: name, brand: brand, category: .rods, price: price, requiredLevel: level,
      rodStyle: style, lengthFt: lengthFt, castWeightMinOz: castOz.lowerBound,
      castWeightMaxOz: castOz.upperBound, rodLineWeightLb: lineLb, maxDragLb: 0, gearRatio: 0,
      lineCapacityYd: 0, testLb: 0, diameterMm: 0, spoolYd: 0, tackleKind: nil, weightOz: 0,
      hookSize: 0, quantityPerPack: 1)
  }

  public static func reel(
    id: String, name: String, brand: String, price: Int, level: Int, drag: Double,
    ratio: Double, capacity: Int
  ) -> TackleItem {
    TackleItem(
      id: id, name: name, brand: brand, category: .reels, price: price, requiredLevel: level,
      rodStyle: nil, lengthFt: 0, castWeightMinOz: 0, castWeightMaxOz: 0, rodLineWeightLb: 0,
      maxDragLb: drag, gearRatio: ratio, lineCapacityYd: capacity, testLb: 0, diameterMm: 0,
      spoolYd: 0, tackleKind: nil, weightOz: 0, hookSize: 0, quantityPerPack: 1)
  }

  public static func line(
    id: String, name: String, brand: String, price: Int, level: Int, testLb: Double,
    diameter: Double, yards: Int
  ) -> TackleItem {
    TackleItem(
      id: id, name: name, brand: brand, category: .lines, price: price, requiredLevel: level,
      rodStyle: nil, lengthFt: 0, castWeightMinOz: 0, castWeightMaxOz: 0, rodLineWeightLb: 0,
      maxDragLb: 0, gearRatio: 0, lineCapacityYd: 0, testLb: testLb, diameterMm: diameter,
      spoolYd: yards, tackleKind: nil, weightOz: 0, hookSize: 0, quantityPerPack: 1)
  }

  public static func lure(
    id: String, name: String, brand: String, price: Int, level: Int, kind: TackleKind,
    weightOz: Double, hook: Int
  ) -> TackleItem {
    TackleItem(
      id: id, name: name, brand: brand, category: .lures, price: price, requiredLevel: level,
      rodStyle: nil, lengthFt: 0, castWeightMinOz: 0, castWeightMaxOz: 0, rodLineWeightLb: 0,
      maxDragLb: 0, gearRatio: 0, lineCapacityYd: 0, testLb: 0, diameterMm: 0, spoolYd: 0,
      tackleKind: kind, weightOz: weightOz, hookSize: hook, quantityPerPack: 1)
  }

  public static func bait(
    id: String, name: String, brand: String, price: Int, level: Int, kind: TackleKind,
    hook: Int, pack: Int
  ) -> TackleItem {
    TackleItem(
      id: id, name: name, brand: brand, category: .baits, price: price, requiredLevel: level,
      rodStyle: nil, lengthFt: 0, castWeightMinOz: 0, castWeightMaxOz: 0, rodLineWeightLb: 0,
      maxDragLb: 0, gearRatio: 0, lineCapacityYd: 0, testLb: 0, diameterMm: 0, spoolYd: 0,
      tackleKind: kind, weightOz: 0.15, hookSize: hook, quantityPerPack: pack)
  }

  public static func terminal(
    id: String, name: String, brand: String, price: Int, level: Int, kind: TackleKind,
    weightOz: Double, hook: Int, pack: Int
  ) -> TackleItem {
    TackleItem(
      id: id, name: name, brand: brand, category: .terminalTackle, price: price,
      requiredLevel: level, rodStyle: nil, lengthFt: 0, castWeightMinOz: 0, castWeightMaxOz: 0,
      rodLineWeightLb: 0, maxDragLb: 0, gearRatio: 0, lineCapacityYd: 0, testLb: 0,
      diameterMm: 0, spoolYd: 0, tackleKind: kind, weightOz: weightOz, hookSize: hook,
      quantityPerPack: pack)
  }

  /// Short spec line shown under the item name in the shop and inventory.
  public var specLine: String {
    switch category {
    case .rods:
      return String(
        format: "%@ • %@ • %.2g-%.2g oz • %.0f lb", rodStyle?.label ?? "", Self.feetInches(lengthFt),
        castWeightMinOz, castWeightMaxOz, rodLineWeightLb)
    case .reels:
      return String(
        format: "Drag %.1f lb • %.1f:1 • %d yd", maxDragLb, gearRatio, lineCapacityYd)
    case .lines:
      return String(format: "%.0f lb • %.2f mm • %d yd", testLb, diameterMm, spoolYd)
    case .lures:
      return String(format: "%@ • %.2g oz • #%d", tackleKind?.displayName ?? "", weightOz, hookSize)
    case .baits:
      return "\(tackleKind?.displayName ?? "") • Hook #\(hookSize) • \(quantityPerPack) pcs"
    case .terminalTackle:
      return "\(tackleKind?.displayName ?? "") • \(quantityPerPack) pcs"
    }
  }

  public static func feetInches(_ feet: Double) -> String {
    let whole = Int(feet)
    let inches = Int(((feet - Double(whole)) * 12).rounded())
    return inches == 0 ? "\(whole)'" : "\(whole)' \(inches)\""
  }
}

public enum TackleCatalog {
  public static let all: [TackleItem] = [
    // Rods
    .rod(
      id: "rod.valuecast", name: "ValueCast 6' 3\"", brand: "Rivertex", price: 0, level: 1,
      style: .spinning, lengthFt: 6.25, castOz: 0.1...0.5, lineLb: 8),
    .rod(
      id: "rod.floatlight", name: "Featherfloat 13'", brand: "Hagman", price: 150, level: 1,
      style: .float, lengthFt: 13, castOz: 0.05...0.4, lineLb: 6),
    .rod(
      id: "rod.elemental", name: "Elemental 6' 7\"", brand: "MagFin", price: 280, level: 3,
      style: .spinning, lengthFt: 6.58, castOz: 0.2...0.9, lineLb: 12),
    .rod(
      id: "rod.bottomline", name: "Bottomline 9' 10\"", brand: "Rivertex", price: 380, level: 4,
      style: .bottom, lengthFt: 9.83, castOz: 1...3.5, lineLb: 20),
    .rod(
      id: "rod.argo", name: "Argo 7' 3\"", brand: "Hagman", price: 620, level: 6,
      style: .spinning, lengthFt: 7.25, castOz: 0.3...1.4, lineLb: 16),
    .rod(
      id: "rod.titan", name: "Titan Heavy 8'", brand: "MagFin", price: 1450, level: 10,
      style: .spinning, lengthFt: 8, castOz: 0.7...3, lineLb: 30),
    .rod(
      id: "rod.driftmaster", name: "Driftmaster 11' 6\"", brand: "Hagman", price: 780, level: 12,
      style: .float, lengthFt: 11.5, castOz: 0.1...0.9, lineLb: 12),
    .rod(
      id: "rod.flycaster", name: "Riverfly 9' 8wt", brand: "MagFin", price: 1_100, level: 14,
      style: .spinning, lengthFt: 9, castOz: 0.05...0.6, lineLb: 14),
    .rod(
      id: "rod.carpstalker", name: "Carp Stalker 12'", brand: "Rivertex", price: 1_650, level: 18,
      style: .bottom, lengthFt: 12, castOz: 2...5, lineLb: 30),
    .rod(
      id: "rod.stormbreaker", name: "Stormbreaker 8' 6\"", brand: "MagFin", price: 2_900, level: 24,
      style: .spinning, lengthFt: 8.5, castOz: 1...5, lineLb: 50),
    .rod(
      id: "rod.leviathan", name: "Leviathan 10' Surf", brand: "Hagman", price: 4_800, level: 32,
      style: .bottom, lengthFt: 10, castOz: 3...10, lineLb: 80),
    .rod(
      id: "rod.colossus", name: "Colossus XH 7' 6\"", brand: "MagFin", price: 8_500, level: 44,
      style: .spinning, lengthFt: 7.5, castOz: 2...12, lineLb: 130),
    // Reels
    .reel(
      id: "reel.minispin", name: "MiniSpin 1200", brand: "Rivertex", price: 0, level: 1,
      drag: 6.5, ratio: 5.2, capacity: 110),
    .reel(
      id: "reel.inspirecast", name: "InspireCast 2000", brand: "MagFin", price: 210, level: 3,
      drag: 9.9, ratio: 5.6, capacity: 150),
    .reel(
      id: "reel.attorney", name: "Attorney 3000", brand: "Hagman", price: 540, level: 6,
      drag: 15.4, ratio: 6.2, capacity: 220),
    .reel(
      id: "reel.hardline", name: "Hardline 4500", brand: "MagFin", price: 1300, level: 10,
      drag: 26.5, ratio: 5.8, capacity: 300),
    .reel(
      id: "reel.centrepin", name: "Centrepin 4.5\"", brand: "Hagman", price: 1_900, level: 14,
      drag: 8.8, ratio: 1.0, capacity: 250),
    .reel(
      id: "reel.bigpit", name: "Big Pit 8000", brand: "Rivertex", price: 2_600, level: 20,
      drag: 33.0, ratio: 4.9, capacity: 420),
    .reel(
      id: "reel.saltguard", name: "Saltguard 10000", brand: "MagFin", price: 4_400, level: 30,
      drag: 48.5, ratio: 5.3, capacity: 500),
    .reel(
      id: "reel.abyss", name: "Abyss 14000 XH", brand: "Hagman", price: 7_900, level: 42,
      drag: 77.0, ratio: 4.6, capacity: 600),
    // Lines
    .line(
      id: "line.mono18", name: "Mono .007\" (0.18 mm)", brand: "Rivertex", price: 0, level: 1,
      testLb: 6.6, diameter: 0.18, yards: 110),
    .line(
      id: "line.mono22", name: "Mono .009\" (0.22 mm)", brand: "Rivertex", price: 45, level: 2,
      testLb: 9.5, diameter: 0.22, yards: 150),
    .line(
      id: "line.braid12", name: "Braid .006\" (0.12 mm)", brand: "Hagman", price: 160, level: 5,
      testLb: 16.8, diameter: 0.12, yards: 220),
    .line(
      id: "line.fluoro30", name: "Fluoro .012\" (0.30 mm)", brand: "MagFin", price: 260, level: 8,
      testLb: 17.5, diameter: 0.30, yards: 220),
    .line(
      id: "line.braid20", name: "Braid .008\" (0.20 mm)", brand: "MagFin", price: 520, level: 10,
      testLb: 32.0, diameter: 0.20, yards: 300),
    .line(
      id: "line.fluoro40", name: "Fluoro .016\" (0.40 mm)", brand: "MagFin", price: 680, level: 14,
      testLb: 28.0, diameter: 0.40, yards: 250),
    .line(
      id: "line.braid30", name: "Braid .012\" (0.30 mm)", brand: "Hagman", price: 1_150, level: 20,
      testLb: 55.0, diameter: 0.30, yards: 400),
    .line(
      id: "line.mono60", name: "Mono .024\" (0.60 mm)", brand: "Rivertex", price: 1_300, level: 26,
      testLb: 45.0, diameter: 0.60, yards: 450),
    .line(
      id: "line.braid45", name: "Braid .018\" (0.45 mm)", brand: "MagFin", price: 2_400, level: 34,
      testLb: 100.0, diameter: 0.45, yards: 500),
    .line(
      id: "line.braid60", name: "Hollow Braid .024\" (0.60 mm)", brand: "Hagman", price: 4_200,
      level: 44, testLb: 170.0, diameter: 0.60, yards: 600),
    // Lures
    .lure(
      id: "lure.spoon5", name: "Casting Spoon 1/6 oz", brand: "MagFin", price: 0, level: 1,
      kind: .spoon, weightOz: 0.17, hook: 2),
    .lure(
      id: "lure.spinner4", name: "Inline Spinner 1/8 oz", brand: "Hagman", price: 38, level: 1,
      kind: .spinner, weightOz: 0.125, hook: 4),
    .lure(
      id: "lure.grub2", name: "Curly Grub 2\"", brand: "Rivertex", price: 24, level: 1,
      kind: .softGrub, weightOz: 0.1, hook: 6),
    .lure(
      id: "lure.jig8", name: "Jig Head 1/8 oz", brand: "Rivertex", price: 30, level: 2,
      kind: .jig, weightOz: 0.125, hook: 4),
    .lure(
      id: "lure.crank12", name: "Shallow Crank 1/2 oz", brand: "MagFin", price: 96, level: 3,
      kind: .crankbait, weightOz: 0.5, hook: 2),
    .lure(
      id: "lure.popper", name: "Topwater Popper 3/8 oz", brand: "Hagman", price: 110, level: 4,
      kind: .popper, weightOz: 0.375, hook: 1),
    .lure(
      id: "lure.spoon1", name: "Trolling Spoon 1 oz", brand: "MagFin", price: 150, level: 7,
      kind: .spoon, weightOz: 1.0, hook: 1),
    .lure(
      id: "lure.spinnerbait", name: "Willow Spinnerbait 1/2 oz", brand: "Hagman", price: 180,
      level: 8, kind: .spinnerbait, weightOz: 0.5, hook: 1),
    .lure(
      id: "lure.streamer", name: "Woolly Streamer #6", brand: "MagFin", price: 60, level: 9,
      kind: .fly, weightOz: 0.06, hook: 6),
    .lure(
      id: "lure.grub4", name: "Paddle Tail 4\"", brand: "Rivertex", price: 90, level: 10,
      kind: .softGrub, weightOz: 0.4, hook: 1),
    .lure(
      id: "lure.jig1", name: "Football Jig 1 oz", brand: "Rivertex", price: 140, level: 12,
      kind: .jig, weightOz: 1.0, hook: 1),
    .lure(
      id: "lure.deepcrank", name: "Deep Diver 1 oz", brand: "MagFin", price: 240, level: 14,
      kind: .crankbait, weightOz: 1.0, hook: 1),
    .lure(
      id: "lure.swimbait6", name: "Glide Swimbait 6\"", brand: "Hagman", price: 420, level: 18,
      kind: .swimbait, weightOz: 1.6, hook: 1),
    .lure(
      id: "lure.intruder", name: "Intruder Fly 4\"", brand: "MagFin", price: 160, level: 22,
      kind: .fly, weightOz: 0.12, hook: 2),
    .lure(
      id: "lure.walker", name: "Walking Popper 1 oz", brand: "Hagman", price: 380, level: 26,
      kind: .popper, weightOz: 1.0, hook: 1),
    .lure(
      id: "lure.bigspoon", name: "Musky Spoon 3 oz", brand: "MagFin", price: 520, level: 30,
      kind: .spoon, weightOz: 3.0, hook: 1),
    .lure(
      id: "lure.swimbait10", name: "Giant Swimbait 10\"", brand: "Hagman", price: 1_200,
      level: 38, kind: .swimbait, weightOz: 4.5, hook: 1),
    // Baits
    .bait(
      id: "bait.redworm", name: "Red Worms", brand: "Local", price: 20, level: 1, kind: .redWorm,
      hook: 4, pack: 25),
    .bait(
      id: "bait.dough", name: "Dough Balls", brand: "Local", price: 16, level: 1,
      kind: .doughBall, hook: 6, pack: 25),
    .bait(
      id: "bait.cricket", name: "Crickets", brand: "Local", price: 24, level: 1, kind: .cricket,
      hook: 6, pack: 20),
    .bait(
      id: "bait.corn", name: "Sweet Corn", brand: "Local", price: 18, level: 2, kind: .corn,
      hook: 6, pack: 30),
    .bait(
      id: "bait.minnow", name: "Live Minnows", brand: "Local", price: 42, level: 3, kind: .minnow,
      hook: 2, pack: 12),
    .bait(
      id: "bait.cutbait", name: "Cut Bait", brand: "Local", price: 36, level: 4, kind: .cutBait,
      hook: 1, pack: 12),
    .bait(
      id: "bait.leech", name: "Ribbon Leeches", brand: "Local", price: 30, level: 6, kind: .leech,
      hook: 4, pack: 15),
    .bait(
      id: "bait.boilie", name: "Fruit Boilies 20 mm", brand: "Hagman", price: 48, level: 8,
      kind: .boilie, hook: 4, pack: 30),
    .bait(
      id: "bait.shrimp", name: "Live Shrimp", brand: "Local", price: 54, level: 10, kind: .shrimp,
      hook: 1, pack: 12),
    .bait(
      id: "bait.bigminnow", name: "Jumbo Shiners", brand: "Local", price: 80, level: 16,
      kind: .minnow, hook: 1, pack: 8),
    .bait(
      id: "bait.chunk", name: "Carp Chunk Bait", brand: "Local", price: 110, level: 24,
      kind: .cutBait, hook: 1, pack: 8),
    // Terminal tackle
    .terminal(
      id: "term.float", name: "Waggler Float 3 g", brand: "Hagman", price: 22, level: 1,
      kind: .redWorm, weightOz: 0.1, hook: 0, pack: 1),
    .terminal(
      id: "term.hooks", name: "Hook Assortment #1-#8", brand: "Rivertex", price: 18, level: 1,
      kind: .redWorm, weightOz: 0, hook: 0, pack: 40),
    .terminal(
      id: "term.sinker", name: "Bell Sinker 1 oz", brand: "Rivertex", price: 14, level: 2,
      kind: .cutBait, weightOz: 1, hook: 0, pack: 10),
    .terminal(
      id: "term.swivels", name: "Ball-Bearing Swivels", brand: "MagFin", price: 26, level: 3,
      kind: .spoon, weightOz: 0, hook: 0, pack: 20),
    .terminal(
      id: "term.leader", name: "Wire Leaders 12\"", brand: "Hagman", price: 40, level: 6,
      kind: .spoon, weightOz: 0, hook: 0, pack: 6),
    .terminal(
      id: "term.slider", name: "Slider Float 8 g", brand: "Hagman", price: 34, level: 8,
      kind: .minnow, weightOz: 0.3, hook: 0, pack: 1),
    .terminal(
      id: "term.circlehooks", name: "Circle Hooks 8/0", brand: "Rivertex", price: 58, level: 20,
      kind: .cutBait, weightOz: 0, hook: 0, pack: 10),
  ]

  public static func find(_ id: String) -> TackleItem {
    guard let item = all.first(where: { $0.id == id }) else { fatalError("Unknown tackle \(id)") }
    return item
  }

  public static func items(in category: TackleCategory) -> [TackleItem] {
    all.filter { $0.category == category }
  }
}

/// The rod that is actually rigged and in the angler's hands.
public struct RigSetup: Codable, Hashable {
  public var rodID: String
  public var reelID: String
  public var lineID: String
  public var lureID: String

  public init(rodID: String, reelID: String, lineID: String, lureID: String) {
    self.rodID = rodID
    self.reelID = reelID
    self.lineID = lineID
    self.lureID = lureID
  }

  public var rod: TackleItem { TackleCatalog.find(rodID) }
  public var reel: TackleItem { TackleCatalog.find(reelID) }
  public var line: TackleItem { TackleCatalog.find(lineID) }
  public var lure: TackleItem { TackleCatalog.find(lureID) }

  public var tackleKind: TackleKind { lure.tackleKind ?? .redWorm }

  /// Total line on the spool, in feet, limited by reel capacity.
  public var lineLengthFt: Double {
    Double(min(line.spoolYd, reel.lineCapacityYd)) * 3
  }

  /// How far a full-power cast can travel, in feet.
  public var maxCastFt: Double {
    let lureOz = max(0.05, lure.weightOz)
    let idealMin = rod.castWeightMinOz
    let idealMax = rod.castWeightMaxOz
    var suitability = 1.0
    if lureOz < idealMin { suitability = max(0.35, lureOz / idealMin) }
    if lureOz > idealMax { suitability = max(0.3, idealMax / lureOz) }
    let base = 40 + rod.lengthFt * 10 + sqrt(lureOz) * 60
    return min(lineLengthFt - 10, base * suitability)
  }

  /// The weakest link in the rig, in pounds of pull.
  public var breakingStrainLb: Double {
    min(line.testLb, rod.rodLineWeightLb * 1.35, reel.maxDragLb * 1.9)
  }

  /// Feet retrieved per second at full reel speed.
  public var retrieveFtPerSec: Double {
    5.5 + reel.gearRatio * 1.15
  }

  public static let starter = RigSetup(
    rodID: "rod.valuecast", reelID: "reel.minispin", lineID: "line.mono18", lureID: "lure.spoon5")
}
