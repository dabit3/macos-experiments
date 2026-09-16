import Foundation

public enum StreakTracker {
  public struct Record: Codable, Equatable {
    public var bestScore: Int
    public var bestDistance: Double
    public var totalRuns: Int
    public var streakDays: Int
    public var lastPlayedDay: String?
    public init(
      bestScore: Int = 0, bestDistance: Double = 0, totalRuns: Int = 0, streakDays: Int = 0,
      lastPlayedDay: String? = nil
    ) {
      self.bestScore = bestScore
      self.bestDistance = bestDistance
      self.totalRuns = totalRuns
      self.streakDays = streakDays
      self.lastPlayedDay = lastPlayedDay
    }
  }

  public static func recordRun(
    _ record: Record, score: Int, distance: Double, on date: Date,
    calendar: Calendar = .current
  ) -> Record {
    var out = record
    out.bestScore = max(out.bestScore, score)
    out.bestDistance = max(out.bestDistance, distance)
    out.totalRuns += 1
    let today = dayString(for: date, calendar: calendar)
    if record.lastPlayedDay == today {
      out.streakDays = max(1, out.streakDays)
    } else if isYesterday(record.lastPlayedDay, relativeTo: date, calendar: calendar) {
      out.streakDays = max(1, out.streakDays + 1)
    } else {
      out.streakDays = 1
    }
    out.lastPlayedDay = today
    return out
  }

  public static func isStreakAlive(
    _ record: Record, on date: Date, calendar: Calendar = .current
  ) -> Bool {
    guard let last = record.lastPlayedDay else { return false }
    return last == dayString(for: date, calendar: calendar)
      || isYesterday(last, relativeTo: date, calendar: calendar)
  }

  private static func isYesterday(
    _ day: String?, relativeTo date: Date, calendar: Calendar
  ) -> Bool {
    guard let day, let lastDate = parse(day, calendar: calendar) else { return false }
    let lastStart = calendar.startOfDay(for: lastDate)
    let todayStart = calendar.startOfDay(for: date)
    return calendar.dateComponents([.day], from: lastStart, to: todayStart).day == 1
  }

  private static func dayString(for date: Date, calendar: Calendar) -> String {
    let formatter = formatter(calendar: calendar)
    return formatter.string(from: date)
  }

  private static func parse(_ string: String, calendar: Calendar) -> Date? {
    formatter(calendar: calendar).date(from: string)
  }

  private static func formatter(calendar: Calendar) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }
}
