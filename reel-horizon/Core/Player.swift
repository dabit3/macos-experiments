import Foundation

public enum Leveling {
  public static let maxLevel = 60

  /// Total XP needed to reach `level`.
  public static func xpRequired(forLevel level: Int) -> Int {
    guard level > 1 else { return 0 }
    let l = Double(level - 1)
    return Int(90 * l * l + 60 * l)
  }

  public static func level(forXP xp: Int) -> Int {
    var level = 1
    while level < maxLevel && xp >= xpRequired(forLevel: level + 1) { level += 1 }
    return level
  }

  /// Progress within the current level, 0...1.
  public static func progress(forXP xp: Int) -> Double {
    let level = level(forXP: xp)
    guard level < maxLevel else { return 1 }
    let lo = xpRequired(forLevel: level)
    let hi = xpRequired(forLevel: level + 1)
    return Double(xp - lo) / Double(hi - lo)
  }
}

public struct CatchRecord: Identifiable, Codable, Hashable {
  public let id: UUID
  public let speciesID: String
  public let waterwayID: String
  public let weightLb: Double
  public let lengthIn: Double
  public let grade: CatchGrade
  public let gameDay: Int
  public let gameMinute: Int
  public let date: Date
  public var kept: Bool

  public init(
    id: UUID = UUID(), speciesID: String, waterwayID: String, weightLb: Double, lengthIn: Double,
    grade: CatchGrade, gameDay: Int, gameMinute: Int, date: Date, kept: Bool
  ) {
    self.id = id
    self.speciesID = speciesID
    self.waterwayID = waterwayID
    self.weightLb = weightLb
    self.lengthIn = lengthIn
    self.grade = grade
    self.gameDay = gameDay
    self.gameMinute = gameMinute
    self.date = date
    self.kept = kept
  }

  public var species: Species { SpeciesCatalog.find(speciesID) }
  public var waterway: Waterway { WaterwayCatalog.find(waterwayID) }

  public var sellPrice: Int {
    Int((species.pricePerLb * weightLb * grade.xpMultiplier.squareRoot()).rounded())
  }

  public var xpValue: Int {
    Int(((species.baseXP + species.xpPerLb * weightLb) * grade.xpMultiplier).rounded())
  }
}

public struct OwnedLicense: Codable, Hashable {
  public var waterwayID: String
  public var advanced: Bool
  public var daysRemaining: Int
}

public struct InventoryEntry: Codable, Hashable, Identifiable {
  public var id: String { itemID }
  public var itemID: String
  public var quantity: Int
  public var item: TackleItem { TackleCatalog.find(itemID) }
}

public struct MissionState: Codable, Hashable, Identifiable {
  public let id: String
  public var progress: Int
  public var claimed: Bool
}

public struct Mission: Identifiable, Hashable {
  public enum Goal: Hashable {
    case catchAny(count: Int)
    case catchSpecies(id: String, count: Int)
    case keepWeight(lb: Double)
    case reachLevel(Int)
    case sellFish(count: Int)
    case buyItem(category: TackleCategory)
    case catchGrade(CatchGrade)
  }

  public let id: String
  public let title: String
  public let detail: String
  public let goal: Goal
  public let rewardCredits: Int
  public let rewardXP: Int
  public let rewardBaitcoins: Int

  public var target: Int {
    switch goal {
    case .catchAny(let count), .catchSpecies(_, let count), .sellFish(let count): return count
    case .keepWeight(let lb): return Int(lb)
    case .reachLevel(let level): return level
    case .buyItem, .catchGrade: return 1
    }
  }
}

public enum MissionCatalog {
  public static let all: [Mission] = [
    Mission(
      id: "tightLines", title: "Tight Lines", detail: "Land your first fish at Lone Pine Lake.",
      goal: .catchAny(count: 1), rewardCredits: 80, rewardXP: 40, rewardBaitcoins: 1),
    Mission(
      id: "panfishParade", title: "Panfish Parade", detail: "Catch three Bluegill.",
      goal: .catchSpecies(id: "bluegill", count: 3), rewardCredits: 120, rewardXP: 90,
      rewardBaitcoins: 0),
    Mission(
      id: "fullNet", title: "Full Net", detail: "Sell five fish from your keepnet.",
      goal: .sellFish(count: 5), rewardCredits: 150, rewardXP: 120, rewardBaitcoins: 1),
    Mission(
      id: "gearUp", title: "Gear Up", detail: "Buy any lure in the shop.",
      goal: .buyItem(category: .lures), rewardCredits: 60, rewardXP: 50, rewardBaitcoins: 0),
    Mission(
      id: "bassMaster", title: "Bass Beginnings", detail: "Catch a Largemouth Bass.",
      goal: .catchSpecies(id: "largemouthBass", count: 1), rewardCredits: 220, rewardXP: 180,
      rewardBaitcoins: 2),
    Mission(
      id: "levelFour", title: "Rising Angler", detail: "Reach level 4 to unlock Muddy Fork River.",
      goal: .reachLevel(4), rewardCredits: 300, rewardXP: 0, rewardBaitcoins: 3),
    Mission(
      id: "trophyHunter", title: "Trophy Hunter", detail: "Land a trophy-grade fish.",
      goal: .catchGrade(.trophy), rewardCredits: 500, rewardXP: 400, rewardBaitcoins: 5),
    Mission(
      id: "heavyHaul", title: "Heavy Haul", detail: "Keep 20 lb of fish in a single trip.",
      goal: .keepWeight(lb: 20), rewardCredits: 260, rewardXP: 200, rewardBaitcoins: 2),
  ]
}

public struct Statistics: Codable, Hashable {
  public var totalCatches = 0
  public var totalReleased = 0
  public var heaviestLb = 0.0
  public var heaviestSpeciesID: String?
  public var lineBreaks = 0
  public var fishLost = 0
  public var casts = 0
  public var creditsEarned = 0
  public var daysFished = 0
  public var speciesCaught: Set<String> = []
}

/// Everything persisted for the angler.
public struct PlayerProfile: Codable, Hashable {
  public static let keepnetMaxCount = 12
  public static let keepnetMaxWeightLb = 330.7

  public var name: String
  public var xp: Int
  public var credits: Int
  public var baitcoins: Int
  public var inventory: [InventoryEntry]
  public var rig: RigSetup
  public var keepnet: [CatchRecord]
  public var catchLog: [CatchRecord]
  public var licenses: [OwnedLicense]
  public var missions: [MissionState]
  public var stats: Statistics
  public var currentWaterwayID: String
  public var rodDurability: Double
  public var reelDurability: Double
  public var lineDurability: Double
  public var gameDay: Int
  public var soundEnabled: Bool
  public var hapticsEnabled: Bool
  public var tutorialSeen: Bool

  public var level: Int { Leveling.level(forXP: xp) }
  public var levelProgress: Double { Leveling.progress(forXP: xp) }
  public var currentWaterway: Waterway { WaterwayCatalog.find(currentWaterwayID) }

  public var keepnetWeightLb: Double { keepnet.reduce(0) { $0 + $1.weightLb } }
  public var keepnetValue: Int { keepnet.reduce(0) { $0 + $1.sellPrice } }
  public var keepnetHasRoom: Bool {
    keepnet.count < Self.keepnetMaxCount && keepnetWeightLb < Self.keepnetMaxWeightLb
  }

  public static func newAngler(name: String = "Player1") -> PlayerProfile {
    PlayerProfile(
      name: name, xp: 0, credits: 400, baitcoins: 20,
      inventory: [
        InventoryEntry(itemID: "rod.valuecast", quantity: 1),
        InventoryEntry(itemID: "reel.minispin", quantity: 1),
        InventoryEntry(itemID: "line.mono18", quantity: 1),
        InventoryEntry(itemID: "lure.spoon5", quantity: 1),
        InventoryEntry(itemID: "bait.redworm", quantity: 25),
      ],
      rig: .starter, keepnet: [], catchLog: [],
      licenses: [OwnedLicense(waterwayID: "lonePineLake", advanced: false, daysRemaining: 3)],
      missions: MissionCatalog.all.map { MissionState(id: $0.id, progress: 0, claimed: false) },
      stats: Statistics(), currentWaterwayID: "lonePineLake", rodDurability: 1, reelDurability: 1,
      lineDurability: 1, gameDay: 1, soundEnabled: true, hapticsEnabled: true,
      tutorialSeen: false)
  }

  // MARK: Inventory

  public func quantity(of itemID: String) -> Int {
    inventory.first(where: { $0.itemID == itemID })?.quantity ?? 0
  }

  public func owns(_ itemID: String) -> Bool { quantity(of: itemID) > 0 }

  public mutating func add(_ itemID: String, quantity: Int) {
    if let index = inventory.firstIndex(where: { $0.itemID == itemID }) {
      inventory[index].quantity += quantity
    } else {
      inventory.append(InventoryEntry(itemID: itemID, quantity: quantity))
    }
  }

  @discardableResult
  public mutating func consume(_ itemID: String, quantity: Int = 1) -> Bool {
    guard let index = inventory.firstIndex(where: { $0.itemID == itemID }),
      inventory[index].quantity >= quantity
    else { return false }
    inventory[index].quantity -= quantity
    if inventory[index].quantity == 0 { inventory.remove(at: index) }
    return true
  }

  public enum PurchaseError: Error, Equatable {
    case insufficientCredits, levelTooLow, alreadyOwned
  }

  public mutating func buy(_ item: TackleItem) -> Result<Void, PurchaseError> {
    if level < item.requiredLevel { return .failure(.levelTooLow) }
    if !item.isConsumable && owns(item.id) { return .failure(.alreadyOwned) }
    if credits < item.price { return .failure(.insufficientCredits) }
    credits -= item.price
    add(item.id, quantity: item.quantityPerPack)
    if item.category == .lures { advanceMission(matching: { $0 == .buyItem(category: .lures) }) }
    return .success(())
  }

  public enum EquipError: Error, Equatable { case notOwned, wrongSlot }

  public mutating func equip(_ item: TackleItem) -> Result<Void, EquipError> {
    guard owns(item.id) else { return .failure(.notOwned) }
    switch item.category {
    case .rods:
      rig.rodID = item.id
      rodDurability = 1
    case .reels:
      rig.reelID = item.id
      reelDurability = 1
    case .lines:
      rig.lineID = item.id
      lineDurability = 1
    case .lures, .baits: rig.lureID = item.id
    case .terminalTackle: return .failure(.wrongSlot)
    }
    return .success(())
  }

  /// Baits are used up one per bite; lures are permanent.
  public mutating func useBaitIfNeeded() {
    if rig.lure.isConsumable {
      consume(rig.lureID)
      if !owns(rig.lureID) {
        if let fallback = inventory.first(where: {
          $0.item.category == .lures || $0.item.category == .baits
        }) {
          rig.lureID = fallback.itemID
        }
      }
    }
  }

  // MARK: Licenses & travel

  public func license(for waterwayID: String) -> OwnedLicense? {
    licenses.first(where: { $0.waterwayID == waterwayID && $0.daysRemaining > 0 })
  }

  public enum TravelError: Error, Equatable {
    case levelTooLow, insufficientCredits, noLicense
  }

  public mutating func buyLicense(_ option: LicenseOption, for waterway: Waterway) -> Bool {
    guard credits >= option.price else { return false }
    credits -= option.price
    if let index = licenses.firstIndex(where: {
      $0.waterwayID == waterway.id && $0.advanced == option.advanced
    }) {
      licenses[index].daysRemaining += option.days
    } else {
      licenses.append(
        OwnedLicense(waterwayID: waterway.id, advanced: option.advanced, daysRemaining: option.days))
    }
    return true
  }

  public func canTravel(to waterway: Waterway) -> Result<Void, TravelError> {
    if level < waterway.requiredLevel { return .failure(.levelTooLow) }
    if license(for: waterway.id) == nil { return .failure(.noLicense) }
    let cost = waterway.id == currentWaterwayID ? waterway.dailyFishingFee : waterway.travelFee
    if credits < cost { return .failure(.insufficientCredits) }
    return .success(())
  }

  public mutating func travel(to waterway: Waterway) -> Result<Void, TravelError> {
    if case .failure(let error) = canTravel(to: waterway) { return .failure(error) }
    credits -= waterway.id == currentWaterwayID ? waterway.dailyFishingFee : waterway.travelFee
    currentWaterwayID = waterway.id
    return .success(())
  }

  /// Called when a fishing day ends.
  public mutating func endDay() {
    for index in licenses.indices where licenses[index].waterwayID == currentWaterwayID {
      licenses[index].daysRemaining = max(0, licenses[index].daysRemaining - 1)
    }
    gameDay += 1
    stats.daysFished += 1
  }

  // MARK: Catches

  public mutating func record(_ catchRecord: CatchRecord) {
    var record = catchRecord
    catchLog.insert(record, at: 0)
    if catchLog.count > 200 { catchLog.removeLast(catchLog.count - 200) }
    stats.totalCatches += 1
    stats.speciesCaught.insert(record.speciesID)
    if record.weightLb > stats.heaviestLb {
      stats.heaviestLb = record.weightLb
      stats.heaviestSpeciesID = record.speciesID
    }
    xp += record.xpValue
    if record.kept {
      keepnet.append(record)
    } else {
      stats.totalReleased += 1
      xp += record.xpValue / 4
      record.kept = false
    }
    advanceMission(matching: { if case .catchAny = $0 { return true } else { return false } })
    advanceMission(matching: {
      if case .catchSpecies(let id, _) = $0 { return id == record.speciesID }
      return false
    })
    if record.grade == .trophy || record.grade == .unique {
      advanceMission(matching: { $0 == .catchGrade(.trophy) })
    }
    if record.kept {
      setMission(
        matching: { if case .keepWeight = $0 { return true } else { return false } },
        progress: Int(keepnetWeightLb))
    }
    setMission(
      matching: { if case .reachLevel = $0 { return true } else { return false } },
      progress: level)
  }

  /// Must the current license force this species back into the water?
  public func mustRelease(_ species: Species) -> Bool {
    let waterway = currentWaterway
    guard let license = license(for: waterway.id) else { return true }
    return !license.advanced && waterway.mustReleaseBasic.contains(species.id)
  }

  @discardableResult
  public mutating func sellKeepnet() -> Int {
    let total = keepnetValue
    credits += total
    stats.creditsEarned += total
    advanceMission(
      matching: { if case .sellFish = $0 { return true } else { return false } },
      by: keepnet.count)
    keepnet.removeAll()
    return total
  }

  // MARK: Missions

  public func missionState(_ id: String) -> MissionState? {
    missions.first(where: { $0.id == id })
  }

  private mutating func advanceMission(matching: (Mission.Goal) -> Bool, by amount: Int = 1) {
    for mission in MissionCatalog.all where matching(mission.goal) {
      guard let index = missions.firstIndex(where: { $0.id == mission.id }) else { continue }
      missions[index].progress = min(mission.target, missions[index].progress + amount)
    }
  }

  private mutating func setMission(matching: (Mission.Goal) -> Bool, progress: Int) {
    for mission in MissionCatalog.all where matching(mission.goal) {
      guard let index = missions.firstIndex(where: { $0.id == mission.id }) else { continue }
      missions[index].progress = min(mission.target, max(missions[index].progress, progress))
    }
  }

  public func isMissionComplete(_ mission: Mission) -> Bool {
    (missionState(mission.id)?.progress ?? 0) >= mission.target
  }

  @discardableResult
  public mutating func claimMission(_ mission: Mission) -> Bool {
    guard let index = missions.firstIndex(where: { $0.id == mission.id }),
      !missions[index].claimed, isMissionComplete(mission)
    else { return false }
    missions[index].claimed = true
    credits += mission.rewardCredits
    baitcoins += mission.rewardBaitcoins
    xp += mission.rewardXP
    setMission(
      matching: { if case .reachLevel = $0 { return true } else { return false } },
      progress: level)
    return true
  }

  public var claimableMissionCount: Int {
    MissionCatalog.all.filter { isMissionComplete($0) && !(missionState($0.id)?.claimed ?? true) }
      .count
  }

  // MARK: Tackle wear

  public mutating func repairAll() -> Int {
    let wear = (1 - rodDurability) + (1 - reelDurability) + (1 - lineDurability)
    let cost = Int((wear * 60).rounded(.up))
    guard credits >= cost else { return -1 }
    credits -= cost
    rodDurability = 1
    reelDurability = 1
    lineDurability = 1
    return cost
  }
}
