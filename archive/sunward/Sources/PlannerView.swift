import SwiftUI

enum PlannerSheet: String, Identifiable {
  case location, date, save, shoots, guide
  var id: String { rawValue }
}

struct PlannerView: View {
  @Bindable var planner: Planner
  @State private var sheet: PlannerSheet?
  @State private var saved = false
  @State private var isScrubbing = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ScaledMetric(relativeTo: .largeTitle) private var locationSize = 32

  private var sun: SunPosition { Solar.position(at: planner.date, place: planner.place) }
  private var skyColor: Color {
    sun.altitude < -6
      ? Color(red: 0.12, green: 0.17, blue: 0.29)
      : Color(red: 0.29, green: 0.21, blue: 0.25)
  }

  var body: some View {
    ZStack {
      Palette.ink.ignoresSafeArea()
      LinearGradient(
        colors: [skyColor, Palette.ink, Palette.ink],
        startPoint: .topLeading, endPoint: .bottomTrailing
      ).ignoresSafeArea()
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 16) {
            header
            location
            dateBar
            VStack(spacing: 0) {
              Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                  proxy.scrollTo("windows", anchor: .top)
                }
              } label: {
                windowSummary.frame(minHeight: 44).contentShape(Rectangle())
              }.accessibilityHint("Show all golden windows and sunrise and sunset")
              SunDial(
                day: planner.day, place: planner.place, date: planner.date,
                onScrub: { planner.scrub($0) }, isScrubbing: $isScrubbing
              )
              .frame(height: 250)
              Text(isScrubbing ? "SCRUBBING · RELEASE TO FINISH" : "HOLD THE PATH TO SCRUB")
                .technical(10).foregroundStyle(Palette.muted).padding(.bottom, 8)
              HStack(alignment: .firstTextBaseline) {
                Text(Solar.time(planner.date, in: planner.place))
                  .font(.system(size: 42, weight: .light, design: .rounded)).monospacedDigit()
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                  Text(sun.phase).font(.system(.headline, design: .serif)).foregroundStyle(
                    Palette.copper)
                  Text(planner.place.zone.abbreviation(for: planner.date) ?? planner.place.zoneID)
                    .technical()
                }
              }
              Slider(
                value: Binding(
                  get: { planner.day.fraction(at: planner.date) }, set: { planner.scrub($0) }),
                in: 0...0.999_99
              )
              .accessibilityLabel("Time of day")
              .accessibilityValue(Solar.time(planner.date, in: planner.place))
              HStack {
                Text("00")
                Spacer()
                Text(timelineLabel(0.25))
                Spacer()
                Text(timelineLabel(0.5))
                Spacer()
                Text(timelineLabel(0.75))
                Spacer()
                Text("24")
              }.technical(10).foregroundStyle(Palette.muted)
              HStack(spacing: 0) {
                metric("ALTITUDE", value: String(format: "%+.1f°", sun.altitude))
                Spacer()
                Rectangle().fill(Palette.line).frame(width: 1, height: 30)
                Spacer()
                metric("AZIMUTH", value: String(format: "%.1f°", sun.azimuth))
              }.padding(.top, 14)
            }
            lightWindows.id("windows")
            HStack {
              event("Sunrise", icon: "sunrise", date: planner.day.sunrise)
              Spacer()
              event("Sunset", icon: "sunset", date: planner.day.sunset)
            }
            .padding(.vertical, 18)
            .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
            Text("LOCAL TIME · TRUE NORTH · MADE FOR THE LIGHT")
              .technical(9).foregroundStyle(Palette.muted).padding(.bottom, 12)
          }
          .padding(.horizontal, 24)
          .padding(.top, 4)
        }.clipped()
      }
    }
    .foregroundStyle(Palette.cream)
    .safeAreaInset(edge: .bottom) {
      Button {
        sheet = .save
      } label: {
        HStack {
          Image(systemName: saved ? "checkmark" : "bookmark")
          Text(saved ? "Shoot saved" : "Save this shoot").fontWeight(.semibold)
          Spacer()
          Image(systemName: "arrow.up.right")
        }.padding(14).background(Palette.copper, in: RoundedRectangle(cornerRadius: 16))
          .foregroundStyle(Palette.ink)
      }
      .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 8)
      .background(Palette.ink.ignoresSafeArea(edges: .bottom))
    }
    .sheet(item: $sheet) { item in
      Group {
        switch item {
        case .location: LocationSheet(planner: planner)
        case .date: DateSheet(planner: planner)
        case .save:
          SaveShootSheet(planner: planner) {
            saved = true
          }
        case .shoots: ShootsSheet(planner: planner)
        case .guide: GuideSheet()
        }
      }
      .preferredColorScheme(.dark)
      .presentationDragIndicator(.visible)
      .presentationCornerRadius(28)
    }
    .onChange(of: planner.date) { saved = false }
    .sensoryFeedback(.success, trigger: saved)
  }

  private var header: some View {
    HStack {
      HStack(spacing: 8) {
        Circle().stroke(Palette.copper, lineWidth: 1).frame(width: 14, height: 14)
          .overlay { Circle().fill(Palette.copper).frame(width: 4, height: 4) }
        Text("SUNWARD").technical(14)
      }
      Spacer()
      Button {
        sheet = .guide
      } label: {
        Image(systemName: "info.circle").frame(width: 44, height: 44)
      }.accessibilityLabel("About the sun dial")
      Button {
        sheet = .shoots
      } label: {
        Image(systemName: "bookmark").frame(width: 44, height: 44)
      }.accessibilityLabel("Saved shoots")
    }
  }

  private var location: some View {
    Button {
      sheet = .location
    } label: {
      VStack(alignment: .leading, spacing: 9) {
        Text("CHASE A DIFFERENT LIGHT").technical(10).foregroundStyle(Palette.copper)
        HStack(alignment: .firstTextBaseline) {
          Text(planner.place.name).font(
            .system(size: locationSize, weight: .regular, design: .serif)
          )
          .multilineTextAlignment(.leading)
          Spacer(minLength: 8)
          Image(systemName: "chevron.down").font(.system(size: 13))
        }
        Text(planner.place.coordinates).technical(10).foregroundStyle(Palette.muted)
      }.frame(maxWidth: .infinity, alignment: .leading)
    }.accessibilityLabel("Location: \(planner.place.name). Change location")
  }

  private var dateBar: some View {
    HStack {
      Button {
        planner.shiftDay(-1)
      } label: {
        Image(systemName: "chevron.left").frame(width: 44, height: 44)
      }.accessibilityLabel("Previous day")
      Spacer(minLength: 0)
      Button {
        sheet = .date
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "calendar")
          Text(Solar.dateLabel(planner.date, in: planner.place)).font(
            .system(.subheadline, design: .monospaced))
        }.frame(minHeight: 44)
      }.accessibilityLabel("Choose date, \(Solar.dateLabel(planner.date, in: planner.place))")
      Spacer(minLength: 0)
      Button {
        planner.shiftDay(1)
      } label: {
        Image(systemName: "chevron.right").frame(width: 44, height: 44)
      }.accessibilityLabel("Next day")
    }.background(Color.white.opacity(0.04), in: Capsule())
  }

  private func metric(_ title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).technical(9).foregroundStyle(Palette.muted)
      Text(value).font(.system(.title3, design: .monospaced)).monospacedDigit()
    }
  }

  private var lightWindows: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("The golden windows").font(.system(.title2, design: .serif))
        Spacer()
        Text("−4° → +6°").technical(10).foregroundStyle(Palette.copper)
      }
      if let condition = planner.day.condition {
        HStack(alignment: .top, spacing: 12) {
          Image(systemName: condition == "Polar night" ? "moon.stars" : "sun.max")
            .foregroundStyle(Palette.copper)
          VStack(alignment: .leading, spacing: 6) {
            Text(condition).font(.headline)
            Text(
              condition == "Polar night"
                ? "The sun stays below the horizon today. Twilight can still bring beautiful light."
                : "The sun stays above the horizon today. Watch the low arc for softer light."
            )
            .font(.subheadline).foregroundStyle(Palette.muted)
          }
        }.padding(16).background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
      }
      if planner.day.golden.isEmpty {
        Text("No golden window on this date. Try another day or latitude.")
          .font(.subheadline).foregroundStyle(Palette.muted).padding(.vertical, 12)
      } else {
        ForEach(Array(planner.day.golden.enumerated()), id: \.element.id) { index, window in
          Button {
            planner.scrub(
              planner.day.fraction(
                at: window.start.addingTimeInterval(window.end.timeIntervalSince(window.start) / 2))
            )
          } label: {
            HStack(spacing: 14) {
              Text(String(format: "%02d", index + 1)).technical(12).foregroundStyle(Palette.copper)
              VStack(alignment: .leading, spacing: 6) {
                Text(
                  "\(Solar.time(window.start, in: planner.place)) – \(windowEnd(window))"
                )
                .font(.system(.title3, design: .monospaced))
                Text("\(window.minutes) MIN OF GOLDEN LIGHT").technical(9).foregroundStyle(
                  Palette.muted)
              }
              Spacer()
              Image(systemName: "arrow.up.right").foregroundStyle(Palette.copper)
            }.padding(.vertical, 14)
              .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
          }.accessibilityLabel(
            "Golden window \(index + 1), \(Solar.time(window.start, in: planner.place)) to \(windowEnd(window)). Jump to midpoint"
          )
        }
      }
    }
  }

  private func event(_ title: String, icon: String, date: Date?) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon).foregroundStyle(Palette.copper)
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.caption).foregroundStyle(Palette.muted)
        Text(Solar.time(date, in: planner.place)).font(.system(.headline, design: .monospaced))
      }
    }
  }

  private func timelineLabel(_ fraction: Double) -> String {
    Solar.time(planner.day.date(at: fraction), in: planner.place)
  }

  private func windowEnd(_ window: LightWindow) -> String {
    window.end == planner.day.end ? "24:00" : Solar.time(window.end, in: planner.place)
  }

  private var windowSummary: some View {
    HStack(spacing: 8) {
      Circle().fill(Palette.copper).frame(width: 5, height: 5)
      if let condition = planner.day.condition {
        Text(condition.uppercased()).technical(11)
      } else if let window = planner.day.golden.first(where: { $0.end > planner.date })
        ?? planner.day.golden.last
      {
        Text("GOLDEN \(Solar.time(window.start, in: planner.place))–\(windowEnd(window))")
          .technical(11)
      } else {
        Text("NO GOLDEN WINDOW TODAY").technical(10)
      }
      Spacer()
      Image(systemName: "chevron.down").font(.caption).foregroundStyle(Palette.muted)
    }.foregroundStyle(Palette.copper)
  }
}
