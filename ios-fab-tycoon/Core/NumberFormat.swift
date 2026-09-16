import Foundation

public enum NumberFormat {
  public static func format(_ value: Double) -> String {
    guard value.isFinite, value >= 0 else { return "0" }
    if value < 1_000 { return String(format: "%.0f", value) }
    let suffixes = ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
    let exponent = Int(floor(log10(value) / 3))
    guard exponent > 0 else { return String(format: "%.0f", value) }
    guard exponent <= suffixes.count else {
      return String(format: "%.1e", value)
    }
    let scaled = value / pow(1000, Double(exponent))
    let format = scaled < 10 ? "%.2f" : scaled < 100 ? "%.1f" : "%.0f"
    return String(format: "\(format)\(suffixes[exponent - 1])", scaled)
  }

  public static func formatCash(_ value: Double) -> String { "$" + format(value) }
  public static func formatRate(_ value: Double) -> String { format(value) + "/s" }
}
