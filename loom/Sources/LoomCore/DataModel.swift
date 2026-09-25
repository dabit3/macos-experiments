import Foundation

public enum LoomError: LocalizedError, Equatable {
  case invalid(String)

  public var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    }
  }
}

public struct Dataset: Codable, Equatable, Sendable {
  public var name: String
  public var columns: [String]
  public var rows: [[String]]

  public init(name: String, columns: [String], rows: [[String]]) {
    self.name = name
    self.columns = columns
    self.rows = rows
  }

  public var numericColumns: [Int] {
    columns.indices.filter { index in
      !rows.isEmpty && rows.allSatisfy { Self.number($0[index]) != nil }
    }
  }

  public static func number(_ value: String) -> Double? {
    guard let value = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)),
      value.isFinite
    else { return nil }
    return value
  }
}

public enum CSV {
  public static func parse(_ text: String, name: String) throws -> Dataset {
    guard text.utf8.count <= 5_000_000 else {
      throw LoomError.invalid("CSV files must be smaller than 5 MB.")
    }
    var source = text
    if source.first == "\u{FEFF}" { source.removeFirst() }
    source = source.replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    let characters = Array(source)
    var records: [[String]] = []
    var row: [String] = []
    var field = ""
    var quoted = false
    var closedQuote = false
    var index = 0
    while index < characters.count {
      let character = characters[index]
      if quoted {
        if character == "\"" {
          if index + 1 < characters.count && characters[index + 1] == "\"" {
            field.append("\"")
            index += 1
          } else {
            quoted = false
            closedQuote = true
          }
        } else {
          field.append(character)
        }
      } else if character == "," || character == "\n" {
        row.append(field)
        field = ""
        closedQuote = false
        if character == "\n" {
          if row != [""] { records.append(row) }
          row = []
        }
      } else if character == "\"" && field.isEmpty && !closedQuote {
        quoted = true
      } else if closedQuote || character == "\"" {
        throw LoomError.invalid(
          "Unexpected character near row \(records.count + 1). Check CSV quotation marks.")
      } else {
        field.append(character)
      }
      index += 1
    }
    guard !quoted else { throw LoomError.invalid("Unclosed quoted field at the end of the CSV.") }
    if !field.isEmpty || !row.isEmpty || closedQuote {
      row.append(field)
      records.append(row)
    }
    guard let header = records.first, header.count >= 2 else {
      throw LoomError.invalid("Include a header and at least two comma-separated columns.")
    }
    let columns = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard columns.allSatisfy({ !$0.isEmpty }), Set(columns).count == columns.count else {
      throw LoomError.invalid("Column headers must be unique and nonempty.")
    }
    let rows = Array(records.dropFirst())
    guard !rows.isEmpty else { throw LoomError.invalid("The CSV has headers but no data rows.") }
    guard rows.count <= 10_000, columns.count <= 50 else {
      throw LoomError.invalid("Loom supports up to 10,000 rows and 50 columns.")
    }
    for (offset, row) in rows.enumerated() where row.count != columns.count {
      throw LoomError.invalid(
        "Row \(offset + 2) has \(row.count) fields; expected \(columns.count).")
    }
    return Dataset(name: name, columns: columns, rows: rows)
  }
}

public enum ChartKind: String, Codable, CaseIterable, Sendable {
  case bar = "Bar"
  case line = "Line"
  case scatter = "Scatter"
}

public enum Aggregation: String, Codable, CaseIterable, Sendable {
  case sum = "Sum"
  case average = "Average"
  case count = "Count"
}

public enum SortOrder: String, Codable, CaseIterable, Sendable {
  case source = "Source order"
  case ascending = "Value: low to high"
  case descending = "Value: high to low"
  case label = "Label: A to Z"
}

public enum FilterOperation: String, Codable, CaseIterable, Sendable {
  case contains = "contains"
  case equals = "equals"
  case atLeast = "≥"
  case atMost = "≤"
}

public enum Theme: String, Codable, CaseIterable, Sendable {
  case coral = "Vermilion"
  case blue = "Cobalt"
  case green = "Botanical"
}

public struct Project: Codable, Equatable, Sendable {
  public var version = 1
  public var dataset: Dataset
  public var title = "The cities choosing\ntwo wheels."
  public var subtitle = "A portrait of everyday cycling across eight European cities."
  public var source = "ILLUSTRATIVE DATA  /  DAILY RIDES, THOUSANDS"
  public var kind: ChartKind = .bar
  public var category: Int = 0
  public var measure: Int = 2
  public var scatterX: Int = 3
  public var aggregation: Aggregation = .sum
  public var sort: SortOrder = .descending
  public var filterColumn: Int = 1
  public var filterOperation: FilterOperation = .equals
  public var filterValue = "2025"
  public var theme: Theme = .coral
  public var showValues = true

  public init(dataset: Dataset) {
    self.dataset = dataset
    let numeric = dataset.numericColumns
    measure = numeric.first ?? 0
    scatterX = numeric.dropFirst().first ?? measure
    filterColumn = 0
    filterValue = ""
  }

  public func validate() throws {
    guard version == 1 else { throw LoomError.invalid("This project version is not supported.") }
    let data = dataset
    guard data.columns.count >= 2, data.columns.count <= 50,
      !data.rows.isEmpty, data.rows.count <= 10_000,
      Set(data.columns).count == data.columns.count,
      data.columns.allSatisfy({ !$0.isEmpty }),
      data.rows.allSatisfy({ $0.count == data.columns.count })
    else { throw LoomError.invalid("The project contains an invalid data table.") }
    guard [category, measure, scatterX, filterColumn].allSatisfy(data.columns.indices.contains)
    else {
      throw LoomError.invalid("The project references a missing column.")
    }
  }

  public static func decode(_ data: Data) throws -> Project {
    guard data.count <= 10_000_000 else { throw LoomError.invalid("Project is larger than 10 MB.") }
    let project = try JSONDecoder().decode(Project.self, from: data)
    try project.validate()
    return project
  }
}

public struct Datum: Identifiable, Equatable, Sendable {
  public var id: Int
  public var label: String
  public var value: Double
  public var x: Double
  public var rowCount: Int
}

public struct ChartResult: Sendable {
  public var points: [Datum]
  public var matchedRows: [[String]]
  public var total: Double
  public var excludedRows: Int
  public var message: String?
}

public enum DataEngine {
  public static func compute(_ project: Project) -> ChartResult {
    let dataset = project.dataset
    let empty = ChartResult(points: [], matchedRows: [], total: 0, excludedRows: 0, message: nil)
    guard (try? project.validate()) != nil else { return empty }
    let needle = project.filterValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if !needle.isEmpty,
      project.filterOperation == .atLeast || project.filterOperation == .atMost,
      Dataset.number(needle) == nil
    {
      var invalid = empty
      invalid.message = "Enter a number for this filter."
      return invalid
    }
    let rows = dataset.rows.filter { row in
      guard !needle.isEmpty else { return true }
      let cell = row[project.filterColumn]
      switch project.filterOperation {
      case .contains: return cell.localizedCaseInsensitiveContains(needle)
      case .equals: return cell.caseInsensitiveCompare(needle) == .orderedSame
      case .atLeast:
        guard let a = Dataset.number(cell), let b = Dataset.number(needle) else { return false }
        return a >= b
      case .atMost:
        guard let a = Dataset.number(cell), let b = Dataset.number(needle) else { return false }
        return a <= b
      }
    }
    var points: [Datum] = []
    var excluded = 0
    for (offset, row) in rows.enumerated() {
      let number =
        project.aggregation == .count && project.kind != .scatter
        ? 1 : Dataset.number(row[project.measure])
      guard let value = number else {
        excluded += 1
        continue
      }
      if project.kind == .scatter {
        guard let x = Dataset.number(row[project.scatterX]) else {
          excluded += 1
          continue
        }
        points.append(
          Datum(id: offset, label: row[project.category], value: value, x: x, rowCount: 1))
      } else if let index = points.firstIndex(where: { $0.label == row[project.category] }) {
        points[index].value += value
        points[index].rowCount += 1
      } else {
        points.append(
          Datum(id: offset, label: row[project.category], value: value, x: 0, rowCount: 1))
      }
    }
    if project.aggregation == .average && project.kind != .scatter {
      for index in points.indices { points[index].value /= Double(points[index].rowCount) }
    }
    switch project.sort {
    case .source: break
    case .ascending: points.sort { $0.value == $1.value ? $0.id < $1.id : $0.value < $1.value }
    case .descending: points.sort { $0.value == $1.value ? $0.id < $1.id : $0.value > $1.value }
    case .label: points.sort { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }
    let total = points.reduce(0) { $0 + $1.value }
    guard total.isFinite, points.allSatisfy({ $0.value.isFinite && $0.x.isFinite }) else {
      var invalid = empty
      invalid.message = "Values are too large to chart. Use smaller numeric units."
      return invalid
    }
    let message =
      points.isEmpty ? "No data matches this view. Adjust your filter or numeric mapping." : nil
    return ChartResult(
      points: points, matchedRows: rows, total: total, excludedRows: excluded, message: message)
  }
}
