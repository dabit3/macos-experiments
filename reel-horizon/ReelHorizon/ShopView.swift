import SwiftUI

/// Tackle shop with the category tab bar on the left, item grid in the middle and the
/// current rig on the right. Doubles as the inventory: owned items show an EQUIP button.
struct ShopView: View {
  @EnvironmentObject var store: GameStore
  @State private var showOwnedOnly = false

  var body: some View {
    ZStack {
      LinearGradient(colors: [Color(red: 0.05, green: 0.12, blue: 0.20), Theme.night], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
      VStack(spacing: 10) {
        HeaderBar(title: showOwnedOnly ? "Inventory" : "Shop")
        HStack(spacing: 10) {
          VStack(spacing: 4) {
            ForEach(TackleCategory.allCases, id: \.self) { category in
              categoryTab(category)
            }
            Spacer()
            Toggle(isOn: $showOwnedOnly) {
              Text("Owned").font(Theme.display(12)).foregroundStyle(Theme.ink)
            }
            .toggleStyle(.switch).tint(Theme.cyanDeep)
            .accessibilityIdentifier("shop.ownedToggle")
          }
          .frame(width: 150)
          .panel(padding: 8, radius: 10)

          ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], spacing: 8) {
              ForEach(items) { item in
                ShopItemCard(item: item)
              }
            }
            .padding(2)
          }
          .accessibilityIdentifier("shop.grid")

          RigPanel()
            .frame(width: 250)
        }
      }
      .padding(14)
    }
  }

  private var items: [TackleItem] {
    let all = TackleCatalog.items(in: store.shopCategory)
    return showOwnedOnly ? all.filter { store.profile.owns($0.id) } : all
  }

  private func categoryTab(_ category: TackleCategory) -> some View {
    let active = store.shopCategory == category
    return Button {
      store.shopCategory = category
    } label: {
      HStack {
        Image(systemName: icon(for: category)).font(.system(size: 13, weight: .bold)).frame(width: 18)
        Text(category.label).font(Theme.display(12)).kerning(0.5)
        Spacer()
      }
      .foregroundStyle(active ? .black : Theme.ink)
      .padding(.horizontal, 10).padding(.vertical, 9)
      .background(RoundedRectangle(cornerRadius: 6).fill(active ? Theme.cyan : Color.white.opacity(0.05)))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("shop.tab.\(category.rawValue)")
  }

  static func iconName(_ category: TackleCategory) -> String {
    switch category {
    case .rods: return "line.diagonal"
    case .reels: return "circle.circle"
    case .lines: return "scribble.variable"
    case .terminalTackle: return "paperclip"
    case .lures: return "sparkle"
    case .baits: return "leaf.fill"
    }
  }

  private func icon(for category: TackleCategory) -> String { Self.iconName(category) }
}

struct ShopItemCard: View {
  @EnvironmentObject var store: GameStore
  let item: TackleItem

  var body: some View {
    let owned = store.profile.quantity(of: item.id)
    let equipped = isEquipped
    let locked = store.profile.level < item.requiredLevel
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .top) {
        TackleIcon(item: item).frame(width: 54, height: 54)
        VStack(alignment: .leading, spacing: 2) {
          Text(item.brand.uppercased()).font(Theme.mono(9)).foregroundStyle(Theme.cyan)
          Text(item.name).font(Theme.body(13, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(2)
          Text(item.specLine).font(Theme.body(10)).foregroundStyle(Theme.inkDim).lineLimit(2)
        }
        Spacer(minLength: 0)
      }
      HStack {
        if locked {
          HStack(spacing: 3) { Image(systemName: "lock.fill"); Text("LVL \(item.requiredLevel)") }.font(Theme.mono(11)).foregroundStyle(Theme.gold)
        } else if owned > 0 && item.isConsumable {
          Text("×\(owned)").font(Theme.mono(12)).foregroundStyle(Theme.green)
        } else if owned > 0 {
          Text(equipped ? "EQUIPPED" : "OWNED").font(Theme.mono(11)).foregroundStyle(equipped ? Theme.gold : Theme.green)
        }
        Spacer()
        if item.price == 0 { Text("FREE").font(Theme.mono(12)).foregroundStyle(Theme.green) } else { CurrencyChip(kind: .credits, amount: item.price, size: 12) }
      }
      HStack(spacing: 6) {
        if owned > 0 && item.category != .terminalTackle && !equipped {
          ChromeButton(title: "Equip", tone: .cyan, size: 11, minWidth: 0) { store.equip(item) }
            .accessibilityIdentifier("shop.equip.\(item.id)")
        }
        if owned == 0 || item.isConsumable {
          ChromeButton(title: item.isConsumable ? "Buy pack" : "Buy", tone: .gold, size: 11, minWidth: 0, disabled: locked || store.profile.credits < item.price) {
            store.buy(item)
          }
          .accessibilityIdentifier("shop.buy.\(item.id)")
        }
        Spacer()
      }
    }
    .panel(padding: 10, radius: 10, light: equipped)
    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(equipped ? Theme.gold.opacity(0.7) : .clear, lineWidth: 1.5))
  }

  private var isEquipped: Bool {
    let rig = store.profile.rig
    return [rig.rodID, rig.reelID, rig.lineID, rig.lureID].contains(item.id)
  }
}

/// Vector icons for each tackle category so the shop grid has artwork without bitmaps.
struct TackleIcon: View {
  let item: TackleItem

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [Color(red: 0.14, green: 0.22, blue: 0.30), Color(red: 0.06, green: 0.10, blue: 0.16)], startPoint: .top, endPoint: .bottom))
      Canvas { ctx, size in
        let w = size.width
        let h = size.height
        switch item.category {
        case .rods:
          var rod = Path()
          rod.move(to: CGPoint(x: w * 0.15, y: h * 0.85))
          rod.addQuadCurve(to: CGPoint(x: w * 0.85, y: h * 0.15), control: CGPoint(x: w * 0.6, y: h * 0.6))
          ctx.stroke(rod, with: .color(Color(red: 0.85, green: 0.85, blue: 0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
          ctx.fill(Path(roundedRect: CGRect(x: w * 0.12, y: h * 0.72, width: w * 0.18, height: h * 0.16), cornerRadius: 3), with: .color(Color(red: 0.35, green: 0.22, blue: 0.12)))
        case .reels:
          ctx.fill(Path(ellipseIn: CGRect(x: w * 0.2, y: h * 0.2, width: w * 0.6, height: h * 0.6)), with: .color(Color(red: 0.55, green: 0.58, blue: 0.64)))
          ctx.fill(Path(ellipseIn: CGRect(x: w * 0.32, y: h * 0.32, width: w * 0.36, height: h * 0.36)), with: .color(Color(red: 0.2, green: 0.22, blue: 0.26)))
          var handle = Path()
          handle.move(to: CGPoint(x: w * 0.5, y: h * 0.5))
          handle.addLine(to: CGPoint(x: w * 0.85, y: h * 0.8))
          ctx.stroke(handle, with: .color(.white.opacity(0.8)), lineWidth: 2.5)
        case .lines:
          var spool = Path()
          for i in 0..<5 {
            spool.addEllipse(in: CGRect(x: w * 0.2, y: h * (0.22 + Double(i) * 0.1), width: w * 0.6, height: h * 0.22))
          }
          ctx.stroke(spool, with: .color(Theme.cyan.opacity(0.8)), lineWidth: 1.5)
        case .terminalTackle:
          var hook = Path()
          hook.move(to: CGPoint(x: w * 0.55, y: h * 0.15))
          hook.addLine(to: CGPoint(x: w * 0.55, y: h * 0.55))
          hook.addArc(center: CGPoint(x: w * 0.42, y: h * 0.55), radius: w * 0.13, startAngle: .degrees(0), endAngle: .degrees(160), clockwise: false)
          ctx.stroke(hook, with: .color(Color(red: 0.8, green: 0.8, blue: 0.85)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        case .lures:
          var body = Path()
          body.addEllipse(in: CGRect(x: w * 0.18, y: h * 0.38, width: w * 0.5, height: h * 0.24))
          ctx.fill(body, with: .linearGradient(Gradient(colors: [Theme.gold, Theme.orange]), startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
          ctx.fill(Path(ellipseIn: CGRect(x: w * 0.24, y: h * 0.42, width: 5, height: 5)), with: .color(.black))
          var hook = Path()
          hook.move(to: CGPoint(x: w * 0.68, y: h * 0.5))
          hook.addLine(to: CGPoint(x: w * 0.8, y: h * 0.7))
          ctx.stroke(hook, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
        case .baits:
          var worm = Path()
          worm.move(to: CGPoint(x: w * 0.15, y: h * 0.6))
          worm.addCurve(to: CGPoint(x: w * 0.85, y: h * 0.45), control1: CGPoint(x: w * 0.35, y: h * 0.15), control2: CGPoint(x: w * 0.6, y: h * 0.9))
          ctx.stroke(worm, with: .color(Color(red: 0.85, green: 0.40, blue: 0.35)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
      }
      .padding(4)
    }
  }
}

/// Current rod/reel/line/lure with durability meters and cast range summary.
struct RigPanel: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    let p = store.profile
    VStack(alignment: .leading, spacing: 8) {
      Text("Your rig").capsLabel(13, color: Theme.cyan)
      slot("Rod", p.rig.rod, durability: p.rodDurability)
      slot("Reel", p.rig.reel, durability: p.reelDurability)
      slot("Line", p.rig.line, durability: p.lineDurability)
      slot(p.rig.lure.isConsumable ? "Bait ×\(p.quantity(of: p.rig.lureID))" : "Lure", p.rig.lure, durability: nil)
      Divider().overlay(Theme.panelStroke)
      HStack {
        Text("Max cast").capsLabel(11)
        Spacer()
        Text("\(Int(p.rig.maxCastFt)) ft").font(Theme.mono(12)).foregroundStyle(Theme.ink)
      }
      HStack {
        Text("Line test").capsLabel(11)
        Spacer()
        Text(String(format: "%.1f lb", p.rig.breakingStrainLb)).font(Theme.mono(12)).foregroundStyle(Theme.ink)
      }
      HStack {
        Text("Drag").capsLabel(11)
        Spacer()
        Text(String(format: "%.1f lb", p.rig.reel.maxDragLb)).font(Theme.mono(12)).foregroundStyle(Theme.ink)
      }
      Spacer()
      ChromeButton(title: "Repair all", icon: "wrench.and.screwdriver.fill", tone: .slate, size: 12, minWidth: 0) { store.repair() }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("shop.repair")
    }
    .panel(padding: 10, radius: 10)
  }

  private func slot(_ label: String, _ item: TackleItem, durability: Double?) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack {
        Text(label).capsLabel(10)
        Spacer()
        Text(item.name).font(Theme.body(11, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
      }
      if let durability {
        MeterBar(value: durability, colors: durability > 0.5 ? [Theme.green, Theme.greenDeep] : [Theme.orange, Theme.red], height: 4)
      }
    }
  }
}

// MARK: - Missions

struct MissionsView: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    ZStack {
      LinearGradient(colors: [Color(red: 0.05, green: 0.12, blue: 0.20), Theme.night], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
      VStack(spacing: 10) {
        HeaderBar(title: "Missions")
        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
            ForEach(MissionCatalog.all) { mission in
              MissionCard(mission: mission)
            }
          }
        }
      }
      .padding(14)
    }
  }
}

struct MissionCard: View {
  @EnvironmentObject var store: GameStore
  let mission: Mission

  var body: some View {
    let state = store.profile.missionState(mission.id)
    let progress = min(state?.progress ?? 0, mission.target)
    let complete = store.profile.isMissionComplete(mission)
    let claimed = state?.claimed ?? false
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: claimed ? "checkmark.seal.fill" : "flag.fill").foregroundStyle(claimed ? Theme.green : Theme.gold)
        Text(mission.title).font(Theme.display(17)).textCase(.uppercase).foregroundStyle(Theme.ink)
        Spacer()
        Text("\(progress)/\(mission.target)").font(Theme.mono(12)).foregroundStyle(Theme.inkDim)
      }
      Text(mission.detail).font(Theme.body(12)).foregroundStyle(Theme.inkDim)
      MeterBar(value: Double(progress) / Double(max(1, mission.target)), colors: claimed ? [Theme.green, Theme.greenDeep] : [Theme.gold, Theme.goldDeep], height: 6)
      HStack(spacing: 12) {
        CurrencyChip(kind: .credits, amount: mission.rewardCredits, size: 12)
        CurrencyChip(kind: .xp, amount: mission.rewardXP, size: 12)
        if mission.rewardBaitcoins > 0 { CurrencyChip(kind: .baitcoins, amount: mission.rewardBaitcoins, size: 12) }
        Spacer()
        if claimed {
          Text("CLAIMED").font(Theme.mono(11)).foregroundStyle(Theme.green)
        } else {
          ChromeButton(title: "Claim", tone: .green, size: 11, minWidth: 70, disabled: !complete) { store.claim(mission) }
            .accessibilityIdentifier("mission.claim.\(mission.id)")
        }
      }
    }
    .panel(padding: 12, radius: 10, light: complete && !claimed)
  }
}

// MARK: - Angler profile

struct ProfileView: View {
  @EnvironmentObject var store: GameStore
  @State private var confirmReset = false

  var body: some View {
    let p = store.profile
    ZStack {
      LinearGradient(colors: [Color(red: 0.05, green: 0.12, blue: 0.20), Theme.night], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
      VStack(spacing: 10) {
        HeaderBar(title: "Angler")
        HStack(alignment: .top, spacing: 10) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Statistics").capsLabel(13, color: Theme.cyan)
            ScrollView {
              VStack(alignment: .leading, spacing: 6) {
                statRow("Level", "\(p.level)  ·  \(p.xp) XP")
                statRow("Fish caught", "\(p.stats.totalCatches)")
                statRow("Released", "\(p.stats.totalReleased)")
                statRow("Species", "\(p.stats.speciesCaught.count) / \(SpeciesCatalog.all.count)")
                statRow("Heaviest", p.stats.heaviestLb > 0 ? "\(p.stats.heaviestLb.lbOz) \(SpeciesCatalog.find(p.stats.heaviestSpeciesID ?? "bluegill").name)" : "—")
                statRow("Casts", "\(p.stats.casts)")
                statRow("Line breaks", "\(p.stats.lineBreaks)")
                statRow("Lost fish", "\(p.stats.fishLost)")
                statRow("Credits earned", "\(p.stats.creditsEarned)")
                statRow("Days fished", "\(p.stats.daysFished)")
              }
            }
            Divider().overlay(Theme.panelStroke)
            Toggle(isOn: Binding(get: { store.profile.hapticsEnabled }, set: { store.profile.hapticsEnabled = $0; store.save() })) {
              Text("Haptics").font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.ink)
            }.tint(Theme.cyanDeep)
            ChromeButton(title: confirmReset ? "Tap again to reset" : "Reset progress", tone: .red, size: 11, minWidth: 0) {
              if confirmReset { store.resetProgress() } else { confirmReset = true }
            }
            .accessibilityIdentifier("profile.reset")
          }
          .frame(width: 250)
          .panel(padding: 12, radius: 10)

          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Keepnet").capsLabel(13, color: Theme.cyan)
              Spacer()
              Text("\(p.keepnet.count)/\(PlayerProfile.keepnetMaxCount) · \(p.keepnetWeightLb.lbOz)").font(Theme.mono(11)).foregroundStyle(Theme.inkDim)
            }
            MeterBar(value: p.keepnetWeightLb / PlayerProfile.keepnetMaxWeightLb, colors: [Theme.cyan, Theme.cyanDeep], height: 6)
            if p.keepnet.isEmpty {
              Text("Nothing in the keepnet. Fish you keep are sold when you end the day.").font(Theme.body(12)).foregroundStyle(Theme.inkDim)
            }
            ScrollView {
              VStack(spacing: 4) {
                ForEach(p.keepnet) { record in CatchRow(record: record) }
              }
            }
            HStack {
              Text("Value").capsLabel(11)
              Spacer()
              CurrencyChip(kind: .credits, amount: p.keepnetValue)
              ChromeButton(title: "Sell all", tone: .gold, size: 11, minWidth: 0, disabled: p.keepnet.isEmpty) { store.sellKeepnet() }
                .accessibilityIdentifier("profile.sell")
            }
          }
          .frame(maxWidth: .infinity)
          .panel(padding: 12, radius: 10)

          VStack(alignment: .leading, spacing: 8) {
            Text("Catch log").capsLabel(13, color: Theme.cyan)
            if p.catchLog.isEmpty {
              Text("Your catches will be listed here.").font(Theme.body(12)).foregroundStyle(Theme.inkDim)
            }
            ScrollView {
              VStack(spacing: 4) {
                ForEach(p.catchLog.prefix(40)) { record in CatchRow(record: record) }
              }
            }
          }
          .frame(maxWidth: .infinity)
          .panel(padding: 12, radius: 10)
        }
      }
      .padding(14)
    }
  }

  private func statRow(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label).capsLabel(11)
      Spacer()
      Text(value).font(Theme.mono(11)).foregroundStyle(Theme.ink).lineLimit(1)
    }
  }
}

struct CatchRow: View {
  let record: CatchRecord

  var body: some View {
    HStack(spacing: 8) {
      FishIllustration(coloring: record.species.coloring).frame(width: 40, height: 22)
      VStack(alignment: .leading, spacing: 0) {
        Text(record.species.name).font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.ink)
        Text("\(record.weightLb.lbOz) · \(record.lengthIn.inchLabel)").font(Theme.mono(9)).foregroundStyle(Theme.inkDim)
      }
      Spacer()
      GradeTag(grade: record.grade)
      if record.kept { CurrencyChip(kind: .credits, amount: record.sellPrice, size: 11) } else { Text("RELEASED").font(Theme.mono(9)).foregroundStyle(Theme.inkDim) }
    }
    .padding(6)
    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
  }
}

struct GradeTag: View {
  let grade: CatchGrade

  var body: some View {
    Text(grade.label).font(Theme.display(10)).kerning(0.5)
      .foregroundStyle(grade == .young ? Theme.inkDim : .black)
      .padding(.horizontal, 6).padding(.vertical, 2)
      .background(Capsule().fill(color))
  }

  private var color: Color {
    switch grade {
    case .young: return Color.white.opacity(0.12)
    case .common: return Theme.cyan
    case .trophy: return Theme.gold
    case .unique: return Color(red: 0.85, green: 0.45, blue: 0.95)
    }
  }
}
