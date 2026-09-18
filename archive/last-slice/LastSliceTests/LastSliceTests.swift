import XCTest

@testable import LastSlice

final class LastSliceTests: XCTestCase {
  @MainActor
  func testServedPortionsRemainAvailableDuringRetryTransition() throws {
    let name = "LastSlice-retry-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let model = GameModel(defaults: defaults)
    model.haptics = false
    model.start(index: 0)
    model.previewCut(.line(angle: .pi / 2, offset: 0.5))
    model.commitCut()
    model.serve()
    let verdict = try XCTUnwrap(model.result)
    XCTAssertFalse(verdict.success)
    model.reset()
    XCTAssertEqual(model.portions.count, 1)
    XCTAssertEqual(verdict.portions.count, 2)
    for match in verdict.matches {
      let index = try XCTUnwrap(match.portionIndex)
      XCTAssertEqual(verdict.portions[index].fraction, match.fraction)
    }
  }

  func testAuthoredToppingsStaySeparatedAndInsideTheirSlice() {
    for dinner in Menu.dinners {
      for portion in Rules.portions(cuts: dinner.solution, toppings: dinner.toppings) {
        for topping in portion.toppings {
          XCTAssertTrue(portion.polygon.contains(topping.point, margin: 0.13), dinner.title)
          for other in dinner.toppings where other.id != topping.id {
            XCTAssertGreaterThan((topping.point - other.point).length, 0.27, dinner.title)
          }
        }
      }
    }
  }

  func testPortionLabelsNeverCoverToppingsAcrossBoardSizes() {
    for radius in [94.0, 120, 172] {
      for dinner in Menu.dinners {
        for piece in Rules.polygons(cuts: dinner.solution) {
          if let anchor = FoodLayout.labelPosition(
            in: piece, toppings: dinner.toppings, halfWidth: 20 / radius, halfHeight: 11 / radius)
          {
            for topping in dinner.toppings {
              let dx = max(0, abs(topping.point.x - anchor.x) - 20 / radius)
              let dy = max(0, abs(topping.point.y - anchor.y) - 11 / radius)
              XCTAssertGreaterThan(hypot(dx, dy), 0.16, dinner.title)
            }
          }
        }
      }
    }
    let first = Menu.dinners[0]
    for piece in Rules.polygons(cuts: first.solution) {
      XCTAssertNotNil(
        FoodLayout.labelPosition(
          in: piece, toppings: first.toppings, halfWidth: 20 / 120, halfHeight: 11 / 120))
    }
  }

  func testClippingConservesAreaAcrossObliqueCuts() {
    let cuts = [Cut.line(angle: 0.71, offset: 0.21), Cut.line(angle: -0.49, offset: -0.3)]
    let pieces = Rules.polygons(cuts: cuts)
    XCTAssertEqual(pieces.count, 4)
    XCTAssertEqual(pieces.reduce(0) { $0 + $1.area }, Polygon.pizza.area, accuracy: 0.000001)
    XCTAssertTrue(pieces.allSatisfy { $0.contains($0.center) })
  }

  func testReversedCutHasSameAreas() {
    let cut = Cut.line(angle: 0.31, offset: -0.18)
    let forward = Rules.polygons(cuts: [cut]).map(\.area).sorted()
    let reverse = Rules.polygons(cuts: [Cut(start: cut.end, end: cut.start)]).map(\.area).sorted()
    XCTAssertEqual(forward[0], reverse[0], accuracy: 0.000001)
    XCTAssertEqual(forward[1], reverse[1], accuracy: 0.000001)
  }

  func testTangentDuplicateShortAndTinyCutsRejected() {
    XCTAssertFalse(Rules.valid(.line(angle: 0, offset: 1.1), after: []))
    XCTAssertFalse(Rules.valid(.line(angle: 0, offset: 0.99), after: []))
    XCTAssertFalse(Rules.valid(Cut(start: Point(x: 0, y: 0), end: Point(x: 0.01, y: 0)), after: []))
    XCTAssertFalse(Rules.valid(.line(angle: 0), after: [.line(angle: 0)]))
    XCTAssertTrue(Rules.valid(.line(angle: .pi / 2), after: [.line(angle: 0)]))
  }

  func testBoundaryToppingCountedExactlyOnce() {
    let toppings = [Topping(id: 0, kind: .olive, point: Point(x: 0, y: 0))]
    let pieces = Rules.portions(cuts: [.line(angle: 0), .line(angle: .pi / 2)], toppings: toppings)
    XCTAssertEqual(pieces.flatMap(\.toppings).count, 1)
    XCTAssertEqual(pieces.reduce(0) { $0 + $1.count(.olive) }, 1)
  }

  func testEveryDinnerHasAnAchievableSolutionWithinBudget() {
    XCTAssertEqual(Menu.dinners.count, 12)
    for dinner in Menu.dinners {
      var cuts: [Cut] = []
      for cut in dinner.solution {
        XCTAssertTrue(
          Rules.valid(cut, after: cuts), "Dinner \(dinner.id + 1) has an invalid solution cut")
        cuts.append(cut)
      }
      let portions = Rules.portions(cuts: cuts, toppings: dinner.toppings)
      let verdict = Rules.evaluate(portions, guests: dinner.guests)
      XCTAssertTrue(verdict.success, "Dinner \(dinner.id + 1) is not solvable")
      XCTAssertEqual(portions.count, dinner.guests.count)
      XCTAssertEqual(portions.flatMap(\.toppings).count, dinner.toppings.count)
      XCTAssertEqual(verdict.stars, 3)
    }
  }

  func testAssignmentIsIndependentOfGuestOrder() {
    let dinner = Menu.dinners[6]
    let pieces = Rules.portions(cuts: dinner.solution, toppings: dinner.toppings)
    let verdict = Rules.evaluate(pieces.reversed(), guests: dinner.guests.reversed())
    XCTAssertTrue(verdict.success)
  }

  func testToleranceAndExactToppingCount() {
    let guest = Guest(id: 0, name: "Luca", fraction: 0.5, topping: .olive, count: 1)
    XCTAssertTrue(GuestMatch(guest: guest, portionIndex: 0, fraction: 0.55, count: 1).passed)
    XCTAssertFalse(GuestMatch(guest: guest, portionIndex: 0, fraction: 0.5501, count: 1).passed)
    XCTAssertFalse(GuestMatch(guest: guest, portionIndex: 0, fraction: 0.5, count: 2).passed)
    XCTAssertFalse(GuestMatch(guest: guest, portionIndex: nil, fraction: 0.5, count: 1).passed)
  }

  func testTooFewOrTooManyPortionsCannotWin() {
    let dinner = Menu.dinners[0]
    XCTAssertFalse(
      Rules.evaluate(Rules.portions(cuts: [], toppings: dinner.toppings), guests: dinner.guests)
        .success)
    let extra = Rules.portions(cuts: dinner.solution + [.line(angle: 0)], toppings: dinner.toppings)
    let verdict = Rules.evaluate(extra, guests: dinner.guests)
    XCTAssertFalse(verdict.success)
    XCTAssertEqual(verdict.extraPortions, 2)
  }

  func testDailySeedUsesStableUTCDay() throws {
    let formatter = ISO8601DateFormatter()
    let morning = try XCTUnwrap(formatter.date(from: "2026-09-12T00:00:00Z"))
    let evening = try XCTUnwrap(formatter.date(from: "2026-09-12T23:59:59Z"))
    let next = try XCTUnwrap(formatter.date(from: "2026-09-13T00:00:00Z"))
    XCTAssertEqual(Menu.dailyIndex(date: morning), Menu.dailyIndex(date: evening))
    XCTAssertNotEqual(Menu.dailyIndex(date: morning), Menu.dailyIndex(date: next))
  }

  @MainActor
  func testUndoResetBudgetAndProgressSurviveRelaunch() throws {
    let suite = "last-slice-tests-\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = GameModel(defaults: defaults)
    model.start(index: 0)
    let cut = model.dinner.solution[0]
    model.previewCut(cut)
    model.undo()
    XCTAssertNil(model.preview)
    XCTAssertEqual(model.cuts.count, 0)
    model.previewCut(cut)
    model.commitCut()
    model.previewCut(.line(angle: 0))
    XCTAssertNil(model.preview)
    XCTAssertEqual(model.cuts.count, 1)
    model.serve()
    XCTAssertTrue(try XCTUnwrap(model.result).success)
    XCTAssertEqual(model.best[0], 3)
    model.haptics = false
    let restored = GameModel(defaults: defaults)
    XCTAssertEqual(restored.best[0], 3)
    XCTAssertEqual(restored.unlocked, 1)
    XCTAssertFalse(restored.haptics)
    model.reset()
    XCTAssertTrue(model.cuts.isEmpty)
    XCTAssertNil(model.result)
    XCTAssertEqual(model.best[0], 3)
  }
}
