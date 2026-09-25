import SwiftUI
import UIKit

enum Screen: Equatable {
  case home
  case location(String)
  case shop
  case missions
  case profile
  case fishing
  case daySummary
}

struct Toast: Identifiable, Equatable {
  enum Kind { case info, success, warning }
  let id = UUID()
  let text: String
  let kind: Kind
}

/// Owns the persisted profile, the active fishing session and screen routing.
@MainActor
final class GameStore: ObservableObject {
  @Published var profile: PlayerProfile
  @Published var screen: Screen = .home
  @Published var session: FishingSession?
  @Published var toasts: [Toast] = []
  @Published var shopCategory: TackleCategory = .lures
  @Published var pendingCatch: CatchRecord?
  @Published var dayCatchIDs: [UUID] = []
  @Published var dayEarnings = 0
  @Published var levelUpTo: Int?
  @Published var splash: SplashEffect?
  @Published var showTutorial = false

  private var ticker: Timer?
  private var lastTick: Date?
  private let storageURL: URL
  private var saveWork: DispatchWorkItem?
  private let haptic = UIImpactFeedbackGenerator(style: .medium)
  private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)

  struct SplashEffect: Equatable {
    let id = UUID()
    let started = Date()
    let strength: Double
  }

  /// Launch arguments used by UI tests and demos:
  /// `--reset-profile` starts a fresh angler, `--skip-tutorial` hides the intro,
  /// `--fast-fish` makes bites near-instant, `--rich` grants credits for shop tests.
  static let launchArgs = Set(ProcessInfo.processInfo.arguments)

  init(storageURL: URL? = nil) {
    let url =
      storageURL
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("ReelHorizon", isDirectory: true)
      .appendingPathComponent("profile.json")
    self.storageURL = url
    if !Self.launchArgs.contains("--reset-profile"),
      let data = try? Data(contentsOf: url),
      let saved = try? JSONDecoder().decode(PlayerProfile.self, from: data)
    {
      profile = saved
    } else {
      profile = PlayerProfile.newAngler()
      showTutorial = true
    }
    if Self.launchArgs.contains("--skip-tutorial") {
      showTutorial = false
      profile.tutorialSeen = true
    }
    if Self.launchArgs.contains("--rich") {
      profile.credits += 100_000
    }
  }

  // MARK: Persistence

  func save() {
    saveWork?.cancel()
    let profile = self.profile
    let url = storageURL
    let work = DispatchWorkItem {
      do {
        try FileManager.default.createDirectory(
          at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(profile)
        try data.write(to: url, options: .atomic)
      } catch {
        print("save failed: \(error)")
      }
    }
    saveWork = work
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.25, execute: work)
  }

  func resetProgress() {
    profile = PlayerProfile.newAngler()
    session = nil
    screen = .home
    save()
  }

  // MARK: Navigation

  func go(_ next: Screen) {
    withAnimation(.easeInOut(duration: 0.22)) { screen = next }
  }

  func toast(_ text: String, _ kind: Toast.Kind = .info) {
    let toast = Toast(text: text, kind: kind)
    toasts.append(toast)
    Task { [weak self] in
      try? await Task.sleep(for: .seconds(2.6))
      self?.toasts.removeAll { $0.id == toast.id }
    }
  }

  private func tap(_ heavy: Bool = false) {
    guard profile.hapticsEnabled else { return }
    if heavy { heavyHaptic.impactOccurred() } else { haptic.impactOccurred() }
  }

  // MARK: Shop

  func buy(_ item: TackleItem) {
    switch profile.buy(item) {
    case .success:
      tap()
      toast("Purchased \(item.name)", .success)
      if profile.rig.lure.category == item.category && item.category == .baits
        && !profile.owns(profile.rig.lureID)
      {
        _ = profile.equip(item)
      }
      save()
    case .failure(.insufficientCredits): toast("Not enough credits", .warning)
    case .failure(.levelTooLow): toast("Requires level \(item.requiredLevel)", .warning)
    case .failure(.alreadyOwned): toast("Already in your inventory", .warning)
    }
  }

  func equip(_ item: TackleItem) {
    switch profile.equip(item) {
    case .success:
      tap()
      toast("Equipped \(item.name)", .success)
      save()
    case .failure(.notOwned): toast("Buy it first", .warning)
    case .failure(.wrongSlot): toast("Terminal tackle is fitted automatically", .info)
    }
  }

  func repair() {
    let cost = profile.repairAll()
    if cost > 0 {
      toast("Tackle repaired for \(cost) credits", .success)
      save()
    } else if cost < 0 {
      toast("Not enough credits to repair", .warning)
    } else {
      toast("Nothing to repair", .info)
    }
  }

  // MARK: Travel

  func buyLicense(_ option: LicenseOption, for waterway: Waterway) {
    if profile.buyLicense(option, for: waterway) {
      tap()
      toast("\(option.durationLabel) \(option.advanced ? "advanced" : "basic") license for \(waterway.name)", .success)
      save()
    } else {
      toast("Not enough credits", .warning)
    }
  }

  func travelAndFish(_ waterway: Waterway) {
    switch profile.travel(to: waterway) {
    case .success:
      startSession()
    case .failure(.levelTooLow): toast("Unlocks at level \(waterway.requiredLevel)", .warning)
    case .failure(.noLicense): toast("You need a fishing license here", .warning)
    case .failure(.insufficientCredits): toast("Not enough credits for the trip", .warning)
    }
  }

  private func startSession() {
    let seed = UInt64(Date().timeIntervalSince1970 * 1000) ^ UInt64(profile.stats.casts)
    var session = FishingSession(
      rig: profile.rig, waterway: profile.currentWaterway, seed: seed,
      rodDurability: profile.rodDurability, reelDurability: profile.reelDurability,
      lineDurability: profile.lineDurability)
    session.minutesPerSecond = 1.0
    if Self.launchArgs.contains("--fast-fish") {
      session.biteBoost = 40
    }
    self.session = session
    dayCatchIDs = []
    dayEarnings = 0
    profile.stats.daysFished += 1
    go(.fishing)
    startTicking()
    save()
  }

  private func startTicking() {
    lastTick = nil
    ticker?.invalidate()
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tick(Date()) }
    }
    RunLoop.main.add(timer, forMode: .common)
    ticker = timer
  }

  private func stopTicking() {
    ticker?.invalidate()
    ticker = nil
  }

  private func tick(_ now: Date) {
    guard var session else { return }
    let dt = lastTick.map { now.timeIntervalSince($0) } ?? (1.0 / 60.0)
    lastTick = now
    session.update(dt: dt)
    let events = session.drainEvents()
    self.session = session
    for event in events { handle(event) }
  }

  private func handle(_ event: FishingEvent) {
    switch event {
    case .cast(let distance):
      profile.stats.casts += 1
      splash = SplashEffect(strength: min(1, distance / 150))
    case .bite:
      tap(true)
    case .hooked:
      tap(true)
      toast("Fish on!", .success)
    case .strikeMissed:
      toast("Missed the strike", .warning)
    case .baitStolen:
      profile.useBaitIfNeeded()
      if var session, session.rig != profile.rig {
        session.rig = profile.rig
        self.session = session
      }
      toast("Bait stolen", .warning)
    case .surge:
      tap()
    case .landed(_, let weight, _):
      tap(true)
      splash = SplashEffect(strength: min(1, 0.4 + weight / 20))
      pendingCatch = session?.landedCatch
    case .lineSnapped:
      tap(true)
      profile.stats.lineBreaks += 1
      profile.useBaitIfNeeded()
      toast("Line snapped!", .warning)
    case .fishEscaped:
      profile.stats.fishLost += 1
      toast("The fish got away", .warning)
    case .retrieved:
      break
    case .dayOver:
      toast("The day is over", .info)
    }
  }

  // MARK: Fishing controls

  func beginCast() {
    session?.beginCast()
  }

  func releaseCast() {
    session?.releaseCast()
    tap()
  }

  func strike() {
    session?.strike()
    tap()
  }

  func setReeling(_ on: Bool) {
    session?.setReeling(on)
  }

  func setRodRaised(_ raised: Bool) {
    session?.setRodRaised(raised)
  }

  func changeReelSpeed(_ delta: Int) {
    session?.changeReelSpeed(delta)
    tap()
  }

  func skipHour() {
    session?.skipHour()
  }

  func decide(keep: Bool) {
    guard var record = pendingCatch, var session else { return }
    let species = record.species
    let canKeep = keep && !profile.mustRelease(species) && profile.keepnetHasRoom
    if keep && !canKeep {
      toast(
        profile.mustRelease(species) ? "Basic license: \(species.name) must be released"
          : "Keepnet is full", .warning)
    }
    record.kept = canKeep
    let levelBefore = profile.level
    profile.record(record)
    dayCatchIDs.append(record.id)
    profile.useBaitIfNeeded()
    if session.rig != profile.rig { session.rig = profile.rig }
    session.acknowledgeOutcome()
    self.session = session
    pendingCatch = nil
    if profile.level > levelBefore { levelUpTo = profile.level }
    save()
  }

  func acknowledgeOutcome() {
    session?.acknowledgeOutcome()
  }

  func endDay() {
    guard let session else { return }
    profile.rodDurability = session.rodDurability
    profile.reelDurability = session.reelDurability
    profile.lineDurability = session.lineDurability
    stopTicking()
    go(.daySummary)
    save()
  }

  func sellKeepnet() {
    let earned = profile.sellKeepnet()
    dayEarnings += earned
    if earned > 0 {
      tap()
      toast("Sold catch for \(earned) credits", .success)
    }
    save()
  }

  func finishDay() {
    profile.endDay()
    session = nil
    go(.home)
    save()
  }

  func claim(_ mission: Mission) {
    let levelBefore = profile.level
    if profile.claimMission(mission) {
      tap()
      toast("+\(mission.rewardCredits) credits, +\(mission.rewardXP) XP", .success)
      if profile.level > levelBefore { levelUpTo = profile.level }
      save()
    }
  }

  var currentWaterway: Waterway { profile.currentWaterway }
  var todaysCatches: [CatchRecord] { profile.catchLog.filter { dayCatchIDs.contains($0.id) } }
}
