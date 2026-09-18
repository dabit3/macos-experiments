import Foundation

struct Place: Codable, Equatable, Identifiable {
  var name: String
  var latitude: Double
  var longitude: Double
  var zoneID: String
  var id: String { "\(name)|\(latitude)|\(longitude)|\(zoneID)" }
  var zone: TimeZone { TimeZone(identifier: zoneID) ?? .gmt }
  var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    return calendar
  }
  var coordinates: String {
    String(
      format: "%.2f° %@  ·  %.2f° %@",
      abs(latitude), latitude < 0 ? "S" : "N",
      abs(longitude), longitude < 0 ? "W" : "E")
  }
  static func valid(latitude: Double, longitude: Double) -> Bool {
    latitude.isFinite && longitude.isFinite
      && (-90...90).contains(latitude) && (-180...180).contains(longitude)
  }
  static let presets = [
    Place(
      name: "San Francisco", latitude: 37.7749, longitude: -122.4194, zoneID: "America/Los_Angeles"),
    Place(name: "New York", latitude: 40.7128, longitude: -74.0060, zoneID: "America/New_York"),
    Place(name: "Lisbon", latitude: 38.7223, longitude: -9.1393, zoneID: "Europe/Lisbon"),
    Place(name: "London", latitude: 51.5074, longitude: -0.1278, zoneID: "Europe/London"),
    Place(name: "Tokyo", latitude: 35.6762, longitude: 139.6503, zoneID: "Asia/Tokyo"),
    Place(name: "Sydney", latitude: -33.8688, longitude: 151.2093, zoneID: "Australia/Sydney"),
    Place(name: "Reykjavík", latitude: 64.1466, longitude: -21.9426, zoneID: "Atlantic/Reykjavik"),
    Place(name: "Tromsø", latitude: 69.6492, longitude: 18.9553, zoneID: "Europe/Oslo"),
    Place(
      name: "Longyearbyen", latitude: 78.2232, longitude: 15.6469, zoneID: "Arctic/Longyearbyen"),
  ]
}

struct SunPosition {
  let altitude: Double
  let azimuth: Double
  var phase: String {
    switch altitude {
    case 6...: "Daylight"
    case -4..<6: "Golden light"
    case -6 ..< -4: "Blue hour"
    case -18 ..< -6: "Twilight"
    default: "Night"
    }
  }
}

struct LightWindow: Identifiable {
  let start: Date
  let end: Date
  var id: Date { start }
  var minutes: Int { Int(end.timeIntervalSince(start) / 60) }
}

struct SunSample {
  let date: Date
  let position: SunPosition
}

struct SunDay {
  let start: Date
  let end: Date
  let samples: [SunSample]
  let sunrise: Date?
  let sunset: Date?
  let golden: [LightWindow]
  let condition: String?
  var duration: TimeInterval { end.timeIntervalSince(start) }
  func date(at fraction: Double) -> Date {
    start.addingTimeInterval(min(max(fraction, 0), 0.999_99) * duration)
  }
  func fraction(at date: Date) -> Double {
    min(max(date.timeIntervalSince(start) / duration, 0), 1)
  }
}

enum Solar {
  private static let radians = Double.pi / 180
  private static func normalized(_ degrees: Double) -> Double {
    let value = degrees.truncatingRemainder(dividingBy: 360)
    return value < 0 ? value + 360 : value
  }

  // NOAA solar equations; geometric center altitude, true-north clockwise azimuth.
  static func position(at date: Date, place: Place) -> SunPosition {
    let jd = date.timeIntervalSince1970 / 86400 + 2440587.5
    let t = (jd - 2_451_545) / 36525
    let longitude = normalized(280.46646 + t * (36000.76983 + t * 0.0003032))
    let anomaly = (357.52911 + t * (35999.05029 - 0.0001537 * t)) * radians
    let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
    let center =
      sin(anomaly) * (1.914602 - t * (0.004817 + 0.000014 * t))
      + sin(2 * anomaly) * (0.019993 - 0.000101 * t) + sin(3 * anomaly) * 0.000289
    let omega = (125.04 - 1934.136 * t) * radians
    let apparent = (longitude + center - 0.00569 - 0.00478 * sin(omega)) * radians
    let obliquity =
      (23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        + 0.00256 * cos(omega)) * radians
    let declination = asin(sin(obliquity) * sin(apparent))
    let y = pow(tan(obliquity / 2), 2)
    let l = longitude * radians
    let equation =
      4 / radians
      * (y * sin(2 * l) - 2 * eccentricity * sin(anomaly)
        + 4 * eccentricity * y * sin(anomaly) * cos(2 * l)
        - 0.5 * y * y * sin(4 * l)
        - 1.25 * eccentricity * eccentricity * sin(2 * anomaly))
    let utcMinutes = (jd + 0.5 - floor(jd + 0.5)) * 1440
    let solarMinutes = normalized((utcMinutes + equation + 4 * place.longitude) / 4) * 4
    let hour = (solarMinutes / 4 - 180) * radians
    let latitude = place.latitude * radians
    let sineAltitude =
      sin(latitude) * sin(declination)
      + cos(latitude) * cos(declination) * cos(hour)
    let altitude = asin(min(1, max(-1, sineAltitude))) / radians
    let azimuth = normalized(
      atan2(sin(hour), cos(hour) * sin(latitude) - tan(declination) * cos(latitude))
        / radians + 180)
    return SunPosition(altitude: altitude, azimuth: azimuth)
  }

  static func day(on date: Date, place: Place) -> SunDay {
    let start = place.calendar.startOfDay(for: date)
    let end = place.calendar.date(byAdding: .day, value: 1, to: start)!
    let count = Int(end.timeIntervalSince(start) / 300)
    let samples = (0...count).map { index in
      let instant = start.addingTimeInterval(Double(index) * 300)
      return SunSample(date: instant, position: position(at: instant, place: place))
    }
    func crossings(_ threshold: Double) -> [(date: Date, rising: Bool)] {
      var events: [(Date, Bool)] = []
      for index in 1..<samples.count {
        let a = samples[index - 1]
        let b = samples[index]
        let rising = a.position.altitude < threshold && b.position.altitude >= threshold
        let falling = a.position.altitude >= threshold && b.position.altitude < threshold
        if rising || falling {
          var low = a.date
          var high = b.date
          for _ in 0..<16 {
            let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if (position(at: mid, place: place).altitude >= threshold) == rising {
              high = mid
            } else {
              low = mid
            }
          }
          events.append((high, rising))
        }
      }
      return events
    }
    let events = crossings(-0.833)
    let boundaries = ([start, end] + crossings(-4).map(\.date) + crossings(6).map(\.date)).sorted()
    var golden: [LightWindow] = []
    for index in 1..<boundaries.count {
      let a = boundaries[index - 1]
      let b = boundaries[index]
      let altitude = position(at: a.addingTimeInterval(b.timeIntervalSince(a) / 2), place: place)
        .altitude
      if (-4...6).contains(altitude) {
        golden.append(LightWindow(start: a, end: b))
      }
    }
    let allAbove = samples.allSatisfy { $0.position.altitude >= -0.833 }
    let allBelow = samples.allSatisfy { $0.position.altitude < -0.833 }
    return SunDay(
      start: start, end: end, samples: samples,
      sunrise: events.first(where: \.rising)?.date,
      sunset: events.first(where: { !$0.rising })?.date,
      golden: golden,
      condition: allAbove ? "Midnight sun" : allBelow ? "Polar night" : nil)
  }

  static func time(_ date: Date?, in place: Place) -> String {
    guard let date else { return "—" }
    let formatter = DateFormatter()
    formatter.timeZone = place.zone
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
  }

  static func dateLabel(_ date: Date, in place: Place) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = place.zone
    formatter.dateFormat = "EEE, d MMM yyyy"
    return formatter.string(from: date)
  }
}
