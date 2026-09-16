import Foundation

public enum FlavorText {
  private static let heatWaveLines = [
    "Thermal throttle! The vapor chamber gave up.",
    "Junction temp: critical. Fans at 100%.",
    "You hit a heat wave at full boost clock.",
    "Shipped to fab — returned as slag.",
    "Thermal paste? Never heard of her.",
  ]

  private static let capacitorBarLines = [
    "Out of VRAM — swap thrashing detected.",
    "Clipped the power stage. VRMs everywhere.",
    "That capacitor bar was rated for 105°C. You were not.",
    "PCIe link down. Reseat the card and try again.",
    "Straight into the MLCC array. Crackling ensues.",
  ]

  public static func crashLine(for kind: ObstacleKind, rng: inout SeededRandom) -> String {
    let lines = kind == .heatWave ? heatWaveLines : capacitorBarLines
    return lines[rng.nextInt(lines.count)]
  }

  public static func milestoneLine(_ meters: Int) -> String {
    switch meters {
    case 500: return "Tensor cores warming up…"
    case 1000: return "Boost clock holding steady."
    case 1500: return "1.5 km of trace, zero bottlenecks."
    case 2000: return "CUDA cores fully lit."
    case 2500: return "Binning: legendary."
    case 3000: return "Ray tracing your way to glory."
    default: return "\(meters) m of silicon behind you."
    }
  }
}
