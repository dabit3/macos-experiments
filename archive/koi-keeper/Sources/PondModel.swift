import Foundation

struct PondPoint: Codable, Equatable {
  var x: Double
  var y: Double

  func distance(to other: PondPoint) -> Double {
    hypot(x - other.x, y - other.y)
  }

  var isInside: Bool {
    x.isFinite && y.isFinite && (0.1...0.9).contains(x) && (0.2...0.78).contains(y)
  }
}

enum KoiKind: String, CaseIterable, Codable, Identifiable {
  case kohaku, yamabuki, showa, asagi

  var id: String { rawValue }
  var name: String { rawValue.capitalized }
  var subtitle: String {
    switch self {
    case .kohaku: return "Snow & vermilion"
    case .yamabuki: return "A little piece of sunlight"
    case .showa: return "Ink, ivory & fire"
    case .asagi: return "The blue of a quiet morning"
    }
  }
  var price: Int {
    switch self {
    case .kohaku: return 12
    case .yamabuki: return 16
    case .showa: return 18
    case .asagi: return 32
    }
  }
  var story: String {
    switch self {
    case .kohaku:
      return
        "Bright red islands drift across an ivory body. A classic companion for your first pond."
    case .yamabuki:
      return
        "Golden scales catch every ripple of light. This gentle swimmer brings warmth to the water."
    case .showa:
      return
        "Bold charcoal markings meet red and white. No two turns reveal quite the same pattern."
    case .asagi:
      return "Slate-blue scales and soft coral fins. A small, moving reflection of the morning sky."
    }
  }
}

struct Koi: Codable, Identifiable {
  var id = UUID()
  let kind: KoiKind
  var meals = 0
}

enum GardenKind: String, Codable, CaseIterable, Identifiable {
  case lily, stone, iris
  var id: String { rawValue }
  var title: String {
    switch self {
    case .lily: return "Water lily"
    case .stone: return "River stone"
    case .iris: return "Water iris"
    }
  }
  var price: Int {
    switch self {
    case .lily: return 8
    case .stone: return 10
    case .iris: return 12
    }
  }
  var detail: String {
    switch self {
    case .lily: return "A little shade, a soft pink bloom."
    case .stone: return "A quiet anchor in moving water."
    case .iris: return "Violet flowers above slender reeds."
    }
  }
}

struct GardenItem: Codable, Identifiable {
  var id = UUID()
  let kind: GardenKind
  let point: PondPoint
  var paid: Int
}

struct Food: Identifiable {
  var id = UUID()
  var point: PondPoint
  var age: Double = 0
}

struct PondSave: Codable {
  var version = 1
  var pearls = 12
  var fish = [Koi(kind: .kohaku), Koi(kind: .yamabuki)]
  var garden = [
    GardenItem(kind: .lily, point: PondPoint(x: 0.22, y: 0.29), paid: 0),
    GardenItem(kind: .lily, point: PondPoint(x: 0.78, y: 0.67), paid: 0),
    GardenItem(kind: .stone, point: PondPoint(x: 0.81, y: 0.25), paid: 0),
  ]
  var totalMeals = 0
  var haptics = true

  var isValid: Bool {
    version == 1 && (0...9999).contains(pearls)
      && (2...6).contains(fish.count) && Set(fish.map(\.id)).count == fish.count
      && fish.allSatisfy { $0.meals >= 0 }
      && garden.count <= 16 && Set(garden.map(\.id)).count == garden.count
      && garden.allSatisfy { $0.point.isInside && (0...$0.kind.price).contains($0.paid) }
      && totalMeals >= 0
  }
}

@MainActor
final class PondModel: ObservableObject {
  @Published private(set) var save: PondSave
  @Published private(set) var food: [Food] = []
  @Published var notice = "Tap the water. Make a little joy."
  private let defaults: UserDefaults
  private let key = "koi-keeper.pond.v1"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: key),
      let restored = try? JSONDecoder().decode(PondSave.self, from: data),
      restored.isValid
    {
      save = restored
      notice = "Your little world, just as you left it."
    } else {
      save = PondSave()
    }
  }

  func persist() {
    guard let data = try? JSONEncoder().encode(save) else { return }
    defaults.set(data, forKey: key)
  }

  @discardableResult
  func feed(at point: PondPoint) -> Bool {
    guard point.isInside else {
      notice = "Tap open water inside the garden."
      return false
    }
    guard food.count < 8 else {
      notice = "Let your koi finish their little feast."
      return false
    }
    let count = min(3, 8 - food.count)
    for index in 0..<count {
      food.append(
        Food(
          point: PondPoint(
            x: min(0.9, max(0.1, point.x + Double(index - 1) * 0.018)),
            y: point.y + (index == 1 ? 0.008 : -0.008))))
    }
    notice = "A pearl for every bite. Watch them gather."
    return true
  }

  @discardableResult
  func consume(foodID: UUID, fishID: UUID) -> Bool {
    guard let foodIndex = food.firstIndex(where: { $0.id == foodID }),
      let fishIndex = save.fish.firstIndex(where: { $0.id == fishID })
    else { return false }
    food.remove(at: foodIndex)
    save.fish[fishIndex].meals = min(999_999, save.fish[fishIndex].meals + 1)
    save.totalMeals = min(999_999, save.totalMeals + 1)
    save.pearls = min(9999, save.pearls + 1)
    notice = food.isEmpty ? "Happy koi. +1 pearl for each bite." : "A little care goes a long way."
    persist()
    return true
  }

  func ageFood(by delta: Double) {
    guard !food.isEmpty else { return }
    for index in food.indices { food[index].age += delta }
    food.removeAll { $0.age > 45 }
  }

  @discardableResult
  func addFish(_ kind: KoiKind) -> Bool {
    guard save.fish.count < 6 else {
      notice = "Six koi is a happy, spacious pond."
      return false
    }
    guard save.pearls >= kind.price else {
      notice = "Feed your koi to earn \(kind.price - save.pearls) more pearls."
      return false
    }
    save.pearls -= kind.price
    save.fish.append(Koi(kind: kind))
    notice = "\(kind.name) has found a home in your pond."
    persist()
    return true
  }

  @discardableResult
  func place(_ kind: GardenKind, at point: PondPoint) -> Bool {
    if let issue = placementIssue(kind, at: point) {
      notice = issue
      return false
    }
    save.pearls -= kind.price
    save.garden.append(GardenItem(kind: kind, point: point, paid: kind.price))
    notice = "\(kind.title) planted. Your pond is saved."
    persist()
    return true
  }

  func placementIssue(_ kind: GardenKind, at point: PondPoint) -> String? {
    guard point.isInside else { return "Choose open water, away from the edges." }
    guard save.garden.count < 16 else { return "Your garden is full. Lift an item to make room." }
    guard save.garden.allSatisfy({ $0.point.distance(to: point) > 0.12 }) else {
      return "A little more room. Try a clear patch of water."
    }
    guard save.pearls >= kind.price else { return "Feed your koi to earn a few more pearls." }
    return nil
  }

  @discardableResult
  func remove(at point: PondPoint) -> Bool {
    guard
      let index = save.garden.indices.min(by: {
        save.garden[$0].point.distance(to: point) < save.garden[$1].point.distance(to: point)
      }), save.garden[index].point.distance(to: point) < 0.09
    else {
      notice = "Tap a lily, stone or iris to lift it."
      return false
    }
    let item = save.garden.remove(at: index)
    save.pearls = min(9999, save.pearls + item.paid)
    notice =
      item.paid > 0 ? "\(item.paid) pearls returned. Space to grow." : "A little more open water."
    persist()
    return true
  }

  func setHaptics(_ enabled: Bool) {
    save.haptics = enabled
    persist()
  }

  func reset() {
    save = PondSave()
    food = []
    notice = "A fresh pond. A new beginning."
    persist()
  }
}
