import Foundation

struct SynthControl {
  var patch: Patch
  var hold = false
  var trigger: UInt64 = 0
}

struct SynthKernel {
  let sampleRate: Double
  private var phase = 0.0
  private var low1 = 0.0
  private var low2 = 0.0
  private var gate = 0.0
  private var noteTime = 100.0
  private var previousTrigger: UInt64 = 0
  private var smoothedFrequency = 220.0
  private var smoothedCutoff = 1600.0
  private var smoothedVolume = 0.0

  init(sampleRate: Double) { self.sampleRate = sampleRate }

  mutating func render(
    control: SynthControl, frames: Int, write: (Int, Float) -> Void
  ) {
    let path = control.patch.signalPath
    let hasFilter = path.contains(.filter)
    let hasEnvelope = path.contains(.envelope)
    if control.trigger != previousTrigger {
      noteTime = 0
      previousTrigger = control.trigger
    }
    let dt = 1 / sampleRate
    let smoothing = 1 - exp(-1 / (0.008 * sampleRate))
    for index in 0..<frames {
      smoothedFrequency += (control.patch.frequency - smoothedFrequency) * smoothing
      smoothedCutoff += (control.patch.cutoff - smoothedCutoff) * smoothing
      smoothedVolume += (control.patch.volume - smoothedVolume) * smoothing
      let step = min(smoothedFrequency / sampleRate, 0.45)
      var value: Double
      switch control.patch.shape {
      case .sine: value = sin(phase * 2 * .pi)
      case .triangle: value = 1 - 4 * abs(phase - 0.5)
      case .saw: value = 2 * phase - 1 - polyBLEP(phase, step)
      }
      phase += step
      if phase >= 1 { phase -= 1 }
      for module in path {
        if module == .filter {
          let alpha = 1 - exp(-2 * .pi * min(smoothedCutoff, sampleRate * 0.4) / sampleRate)
          low1 += alpha * (value - low1)
          low2 += alpha * (low1 - low2)
          value = low2
        }
        if module == .envelope && !control.hold {
          value *= exp(-noteTime / control.patch.decay)
        }
      }
      if !hasFilter {
        low1 = value
        low2 = value
      }
      let active = control.hold || noteTime < (hasEnvelope ? control.patch.decay * 5 : 0.75)
      gate += ((active ? 1 : 0) - gate) * smoothing
      noteTime += dt
      let sample = path.isEmpty ? 0 : value * gate * smoothedVolume
      write(index, Float(max(-1, min(1, sample))))
    }
  }

  private func polyBLEP(_ t: Double, _ dt: Double) -> Double {
    if t < dt {
      let x = t / dt
      return x + x - x * x - 1
    }
    if t > 1 - dt {
      let x = (t - 1) / dt
      return x * x + x + x + 1
    }
    return 0
  }
}
