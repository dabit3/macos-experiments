import Combine
import Foundation

struct Swimmer: Identifiable {
  let id: UUID
  let kind: KoiKind
  var point: PondPoint
  var heading: Double
  var phase: Double
}

@MainActor
final class PondEngine: ObservableObject {
  @Published var swimmers: [Swimmer] = []
  @Published var time: Double = 0
  private var timer: AnyCancellable?
  private var lastFoodAge: Double = 0

  func start(model: PondModel, reduceMotion: Bool) {
    timer?.cancel()
    timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect().sink {
      [weak self] _ in
      self?.step(model: model, delta: 1.0 / 30, reduceMotion: reduceMotion)
    }
  }

  func stop() { timer?.cancel() }

  func step(model: PondModel, delta: Double, reduceMotion: Bool) {
    time += delta
    let ids = Set(model.save.fish.map(\.id))
    swimmers.removeAll { !ids.contains($0.id) }
    for (index, koi) in model.save.fish.enumerated()
    where !swimmers.contains(where: { $0.id == koi.id }) {
      swimmers.append(
        Swimmer(
          id: koi.id, kind: koi.kind,
          point: PondPoint(x: 0.38 + Double(index % 3) * 0.13, y: 0.42 + Double(index % 2) * 0.15),
          heading: Double(index) * 2.2, phase: Double(index) * 1.7))
    }
    for index in swimmers.indices {
      var swimmer = swimmers[index]
      let targetFood = model.food.min {
        $0.point.distance(to: swimmer.point) < $1.point.distance(to: swimmer.point)
      }
      let target: PondPoint
      if let targetFood {
        target = targetFood.point
      } else {
        let t = time * 0.085 + swimmer.phase
        target = PondPoint(x: 0.5 + sin(t * 1.17) * 0.30, y: 0.48 + cos(t * 0.93) * 0.22)
      }
      let desired = atan2((target.y - swimmer.point.y) * 1.9, target.x - swimmer.point.x)
      let difference = atan2(sin(desired - swimmer.heading), cos(desired - swimmer.heading))
      swimmer.heading += max(-delta * 2.4, min(delta * 2.4, difference))
      let speed = (targetFood == nil ? 0.040 : 0.115) * (reduceMotion ? 0.6 : 1)
      swimmer.point.x = max(0.09, min(0.91, swimmer.point.x + cos(swimmer.heading) * speed * delta))
      swimmer.point.y = max(
        0.21, min(0.77, swimmer.point.y + sin(swimmer.heading) * speed * delta / 1.9))
      if let targetFood, swimmer.point.distance(to: targetFood.point) < 0.034 {
        model.consume(foodID: targetFood.id, fishID: swimmer.id)
      }
      swimmers[index] = swimmer
    }
    if time - lastFoodAge >= 1 {
      model.ageFood(by: 1)
      lastFoodAge = time
    }
  }
}
