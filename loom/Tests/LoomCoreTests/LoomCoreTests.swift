import Foundation
import XCTest

@testable import LoomCore

final class LoomCoreTests: XCTestCase {
  func testQuotedFieldsEscapesNewlinesAndBOM() throws {
    let data = try CSV.parse(
      "\u{FEFF}City,Label,Value\r\n\"Paris, France\",\"The \"\"blue\"\" room\",12\r\nBerlin,\"two\nlines\",9",
      name: "quoted.csv")
    XCTAssertEqual(data.columns, ["City", "Label", "Value"])
    XCTAssertEqual(data.rows[0], ["Paris, France", "The \"blue\" room", "12"])
    XCTAssertEqual(data.rows[1][1], "two\nlines")
    XCTAssertEqual(data.numericColumns, [2])
  }

  func testTrailingEmptyFieldsAndBlankLines() throws {
    let data = try CSV.parse("A,B,C\nx,2,\n\nz,3,\"\"\n", name: "empty.csv")
    XCTAssertEqual(data.rows, [["x", "2", ""], ["z", "3", ""]])
  }

  func testMalformedCSVRejected() {
    let malformed = [
      "a,b\nx", "a,a\n1,2", "a,\n1,2", "a,b\n\"unfinished,2",
      "a,b\n\"done\"oops,2", "a,b\nab\"c,2", "a,b", "a\n1",
    ]
    for text in malformed {
      XCTAssertThrowsError(try CSV.parse(text, name: "invalid.csv"), text)
    }
  }

  func project() throws -> Project {
    let data = try CSV.parse(
      "City,Year,Rides,Area\nA,2020,10,3\nB,2025,30,4\nA,2025,20,5\nC,2025,40,6", name: "test")
    var project = Project(dataset: data)
    project.measure = 2
    project.scatterX = 3
    project.sort = .source
    return project
  }

  func testSumGroupsAndPreservesSourceOrder() throws {
    let result = DataEngine.compute(try project())
    XCTAssertEqual(result.points.map(\.label), ["A", "B", "C"])
    XCTAssertEqual(result.points.map(\.value), [30, 30, 40])
    XCTAssertEqual(result.points.map(\.rowCount), [2, 1, 1])
    XCTAssertEqual(result.total, 100)
  }

  func testFilterBeforeAverage() throws {
    var project = try project()
    project.aggregation = .average
    XCTAssertEqual(DataEngine.compute(project).points.map(\.value), [15, 30, 40])
    project.filterColumn = 1
    project.filterValue = "2025"
    project.filterOperation = .equals
    let result = DataEngine.compute(project)
    XCTAssertEqual(result.matchedRows.count, 3)
    XCTAssertEqual(result.points.map(\.value), [30, 20, 40])
    XCTAssertEqual(result.total, 90)
  }

  func testCountCanUseNonNumericMeasure() throws {
    var project = try project()
    project.aggregation = .count
    project.measure = 0
    XCTAssertEqual(DataEngine.compute(project).points.map(\.value), [2, 1, 1])
  }

  func testNumericFilterAndInvalidInput() throws {
    var project = try project()
    project.filterColumn = 2
    project.filterOperation = .atLeast
    project.filterValue = "30"
    XCTAssertEqual(DataEngine.compute(project).total, 70)
    project.filterOperation = .atMost
    XCTAssertEqual(DataEngine.compute(project).total, 60)
    project.filterValue = "not a number"
    XCTAssertEqual(DataEngine.compute(project).message, "Enter a number for this filter.")
    XCTAssertTrue(DataEngine.compute(project).points.isEmpty)
  }

  func testContainsAndNoMatches() throws {
    var project = try project()
    project.filterColumn = 0
    project.filterOperation = .contains
    project.filterValue = "a"
    XCTAssertEqual(DataEngine.compute(project).total, 30)
    project.filterValue = "missing"
    XCTAssertNotNil(DataEngine.compute(project).message)
  }

  func testSortingAndStableTies() throws {
    var project = try project()
    project.sort = .descending
    XCTAssertEqual(DataEngine.compute(project).points.map(\.label), ["C", "A", "B"])
    project.sort = .ascending
    XCTAssertEqual(DataEngine.compute(project).points.map(\.label), ["A", "B", "C"])
  }

  func testScatterUsesActualXValuesWithoutAggregation() throws {
    var project = try project()
    project.kind = .scatter
    project.aggregation = .count
    let result = DataEngine.compute(project)
    XCTAssertEqual(result.points.map(\.x), [3, 4, 5, 6])
    XCTAssertEqual(result.points.map(\.value), [10, 30, 20, 40])
    XCTAssertEqual(result.points.count, 4)
  }

  func testInvalidAndInfiniteNumbersExcluded() throws {
    let data = try CSV.parse("A,B\none,NaN\ntwo,inf\nthree,-2\nfour,12x", name: "bad-numbers")
    var project = Project(dataset: data)
    project.measure = 1
    let result = DataEngine.compute(project)
    XCTAssertEqual(result.total, -2)
    XCTAssertEqual(result.excludedRows, 3)
    XCTAssertEqual(Dataset.number(" 2.5 "), 2.5)
  }

  func testOverflowProducesUsefulError() throws {
    var project = Project(dataset: try CSV.parse("A,B\none,1e308\none,1e308", name: "overflow"))
    project.measure = 1
    XCTAssertNotNil(DataEngine.compute(project).message)
    XCTAssertTrue(DataEngine.compute(project).points.isEmpty)
  }

  func testProjectRoundTrip() throws {
    var original = try project()
    original.title = "A story\nin two lines"
    original.theme = .blue
    original.kind = .scatter
    original.filterOperation = .atMost
    let decoded = try Project.decode(JSONEncoder().encode(original))
    XCTAssertEqual(decoded, original)
    XCTAssertEqual(DataEngine.compute(decoded).points, DataEngine.compute(original).points)
  }

  func testInvalidProjectMappingRejected() throws {
    var project = try project()
    project.category = 99
    XCTAssertThrowsError(try Project.decode(JSONEncoder().encode(project)))
    XCTAssertTrue(DataEngine.compute(project).points.isEmpty)
  }

  func testInvalidProjectRowsAndVersionRejected() throws {
    var project = try project()
    project.dataset.rows[0].removeLast()
    XCTAssertThrowsError(try project.validate())
    project = try self.project()
    project.version = 2
    XCTAssertThrowsError(try project.validate())
  }

  func testBundledCyclingFixtureComputedValues() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let url = root.appendingPathComponent("Sources/Loom/Resources/cycling.csv")
    var project = Project(
      dataset: try CSV.parse(String(contentsOf: url, encoding: .utf8), name: "cycling.csv"))
    project.measure = 2
    project.filterColumn = 1
    project.filterOperation = .equals
    project.filterValue = "2025"
    let result = DataEngine.compute(project)
    XCTAssertEqual(result.matchedRows.count, 8)
    XCTAssertEqual(result.total, 422)
    XCTAssertEqual(result.points.first?.label, "Amsterdam")
    XCTAssertEqual(result.points.first?.value, 86)
    project.filterValue = ""
    XCTAssertEqual(DataEngine.compute(project).total, 692)
  }
}
