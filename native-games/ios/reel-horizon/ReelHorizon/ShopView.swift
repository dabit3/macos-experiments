import SwiftUI

/// Tackle shop with the category tab bar on the left, item grid in the middle and the
/// current rig on the right. Doubles as the inventory: owned items show an EQUIP button.
struct ShopView: View {
  @EnvironmentObject var store: GameStore
  @State private var showOwnedOnly = false

  var body: some View {
    ZStack {
      ScreenBackground(accent: Theme.gold)
      VStack(spacing: 10) {
        HeaderBar(title: showOwnedOnly ? "Inventory" : "Shop", subtitle: "Tackle & bait")
        HStack(spacing: 10) {
          VStack(spacing: 4) {
            ForEach(TackleCategory.allCases, id: \.self) { category in
              categoryTab(category)
            }
            Spacer(minLength: 4)
            Toggle(isOn: $showOwnedOnly.animation(.easeInOut(duration: 0.2))) {
              HStack(spacing: 5) {
                Image(systemName: "archivebox.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.cyan)
                Text("OWNED").font(Theme.display(12)).kerning(0.6).foregroundStyle(Theme.ink)
              }
            }
            .toggleStyle(.switch).tint(Theme.cyanDeep)
            .padding(.horizontal, 4)
            .accessibilityIdentifier("shop.ownedToggle")
          }
          .frame(width: 158)
          .panel(padding: 8, radius: 18)

          VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: store.shopCategory.label, icon: Self.iconName(store.shopCategory), trailing: "\(ownedCount) owned · \(items.count) shown", tint: Theme.gold)
              .padding(.horizontal, 4)
            ScrollView {
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(items) { item in
                  ShopItemCard(item: item)
                }
              }
              .padding(2)
              if items.isEmpty {
                VStack(spacing: 6) {
                  Image(systemName: "shippingbox").font(.system(size: 26)).foregroundStyle(Theme.inkDim)
                  Text("Nothing owned in this category yet").font(Theme.body(12)).foregroundStyle(Theme.inkDim)
                }
                .frame(maxWidth: .infinity).padding(.top, 50)
              }
            }
            .accessibilityIdentifier("shop.grid")
          }

          RigPanel()
            .frame(width: 244)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
    }
  }

  private var items: [TackleItem] {
    let all = TackleCatalog.items(in: store.shopCategory)
    return showOwnedOnly ? all.filter { store.profile.owns($0.id) } : all
  }

  private var ownedCount: Int {
    TackleCatalog.items(in: store.shopCategory).filter { store.profile.owns($0.id) }.count
  }

  private func categoryTab(_ category: TackleCategory) -> some View {
    let active = store.shopCategory == category
    return Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { store.shopCategory = category }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: Self.iconName(category)).font(.system(size: 12, weight: .bold)).frame(width: 18)
        Text(category.label).font(Theme.display(12)).kerning(0.5).lineLimit(1).minimumScaleFactor(0.8)
        Spacer(minLength: 0)
        Text("\(TackleCatalog.items(in: category).count)").font(Theme.mono(9)).opacity(0.7)
      }
      .foregroundStyle(active ? Theme.night : Theme.ink)
      .padding(.horizontal, 10).padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(active ? AnyShapeStyle(LinearGradient(colors: [Theme.cyan, Theme.cyanDeep.opacity(0.9)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.04)))
      )
      .shadow(color: active ? Theme.cyan.opacity(0.35) : .clear, radius: 6, y: 2)
    }
    .buttonStyle(PressStyle())
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
}

struct ShopItemCard: View {
  @EnvironmentObject var store: GameStore
  let item: TackleItem

  var body: some View {
    let owned = store.profile.quantity(of: item.id)
    let equipped = isEquipped
    let locked = store.profile.level < item.requiredLevel
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        TackleIcon(item: item).frame(width: 44, height: 44)
          .saturation(locked ? 0.2 : 1)
        VStack(alignment: .leading, spacing: 2) {
          Text(item.brand.uppercased()).font(Theme.mono(8)).kerning(1).foregroundStyle(Theme.cyan)
          Text(item.name).font(Theme.body(13, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(2).minimumScaleFactor(0.85)
          Text(item.specLine).font(Theme.body(9, weight: .medium)).foregroundStyle(Theme.inkDim).lineLimit(2)
        }
        Spacer(minLength: 0)
      }
      .frame(height: 56, alignment: .top)
      HStack(spacing: 6) {
        status(owned: owned, equipped: equipped, locked: locked)
        Spacer(minLength: 0)
        if item.price == 0 { Text("FREE").font(Theme.mono(12)).foregroundStyle(Theme.green) } else { CurrencyChip(kind: .credits, amount: item.price, size: 12) }
      }
      HStack(spacing: 6) {
        if owned > 0 && item.category != .terminalTackle && !equipped {
          ChromeButton(title: "Equip", icon: "checkmark", tone: .cyan, size: 11, minWidth: 0) { store.equip(item) }
            .accessibilityIdentifier("shop.equip.\(item.id)")
        }
        if owned == 0 || item.isConsumable {
          ChromeButton(title: item.isConsumable ? "Buy pack" : "Buy", icon: locked ? "lock.fill" : "cart.fill", tone: .gold, size: 11, minWidth: 0, disabled: locked || store.profile.credits < item.price) {
            store.buy(item)
          }
          .accessibilityIdentifier("shop.buy.\(item.id)")
        }
        Spacer(minLength: 0)
      }
      .frame(minHeight: 34)
    }
    .panel(padding: 10, radius: 16, light: equipped)
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(equipped ? Theme.gold.opacity(0.8) : .clear, lineWidth: 1.5)
    )
    .shadow(color: equipped ? Theme.gold.opacity(0.25) : .clear, radius: 10)
  }

  @ViewBuilder
  private func status(owned: Int, equipped: Bool, locked: Bool) -> some View {
    if locked {
      tag("LVL \(item.requiredLevel)", icon: "lock.fill", color: Theme.gold)
    } else if owned > 0 && item.isConsumable {
      tag("×\(owned)", icon: "shippingbox.fill", color: Theme.green)
    } else if equipped {
      tag("EQUIPPED", icon: "star.fill", color: Theme.gold)
    } else if owned > 0 {
      tag("OWNED", icon: "checkmark", color: Theme.green)
    }
  }

  private func tag(_ text: String, icon: String, color: Color) -> some View {
    HStack(spacing: 3) {
      Image(systemName: icon).font(.system(size: 8, weight: .black))
      Text(text).font(Theme.mono(9))
    }
    .foregroundStyle(color)
    .padding(.horizontal, 6).padding(.vertical, 3)
    .background(Capsule().fill(color.opacity(0.14)))
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
      RoundedRectangle(cornerRadius: 12, style: .continuous).fill(RadialGradient(colors: [Color(red: 0.18, green: 0.30, blue: 0.40), Color(red: 0.05, green: 0.09, blue: 0.15)], center: .topLeading, startRadius: 2, endRadius: 70))
      RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.10))
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
      SectionHeader(title: "Your rig", icon: "figure.fishing")
      slot(.rods, "Rod", p.rig.rod, durability: p.rodDurability)
      slot(.reels, "Reel", p.rig.reel, durability: p.reelDurability)
      slot(.lines, "Line", p.rig.line, durability: p.lineDurability)
      slot(p.rig.lure.isConsumable ? .baits : .lures, p.rig.lure.isConsumable ? "Bait ×\(p.quantity(of: p.rig.lureID))" : "Lure", p.rig.lure, durability: nil)
      HStack(spacing: 6) {
        metric("Cast", "\(Int(p.rig.maxCastFt)) ft")
        metric("Test", String(format: "%.1f lb", p.rig.breakingStrainLb))
        metric("Drag", String(format: "%.1f lb", p.rig.reel.maxDragLb))
      }
      Spacer(minLength: 0)
      ChromeButton(title: "Repair all", icon: "wrench.and.screwdriver.fill", tone: .slate, size: 12, minWidth: 0) { store.repair() }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("shop.repair")
    }
    .panel(padding: 10, radius: 18)
  }

  private func slot(_ category: TackleCategory, _ label: String, _ item: TackleItem, durability: Double?) -> some View {
    HStack(spacing: 8) {
      Image(systemName: ShopView.iconName(category)).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.cyan)
        .frame(width: 26, height: 26)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.cyan.opacity(0.12)))
      VStack(alignment: .leading, spacing: 3) {
        HStack {
          Text(label).capsLabel(9)
          Spacer(minLength: 2)
          if let durability { Text("\(Int(durability * 100))%").font(Theme.mono(8)).foregroundStyle(durability > 0.5 ? Theme.green : Theme.orange) }
        }
        Text(item.name).font(Theme.body(11, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
        if let durability {
          MeterBar(value: durability, colors: durability > 0.5 ? [Theme.green, Theme.greenDeep] : [Theme.orange, Theme.red], height: 3)
        }
      }
    }
  }

  private func metric(_ label: String, _ value: String) -> some View {
    VStack(spacing: 1) {
      Text(label).capsLabel(8)
      Text(value).font(Theme.mono(10)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 5)
    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.05)))
  }
}

// MARK: - Missions

struct MissionsView: View {
  @EnvironmentObject var store: GameStore

  var body: some View {
    let claimed = MissionCatalog.all.filter { store.profile.missionState($0.id)?.claimed ?? false }.count
    ZStack {
      ScreenBackground(accent: Theme.green)
      VStack(spacing: 10) {
        HeaderBar(title: "Missions", subtitle: "\(claimed) of \(MissionCatalog.all.count) complete")
        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
            ForEach(MissionCatalog.all) { mission in
              MissionCard(mission: mission)
            }
          }
          .padding(.bottom, 8)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
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
    let fraction = Double(progress) / Double(max(1, mission.target))
    let tint = claimed ? Theme.green : (complete ? Theme.gold : Theme.cyan)
    HStack(spacing: 12) {
      ZStack {
        Circle().stroke(Color.white.opacity(0.08), lineWidth: 5)
        Circle().trim(from: 0, to: max(0.001, fraction))
          .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Image(systemName: claimed ? "checkmark" : (complete ? "gift.fill" : "flag.fill"))
          .font(.system(size: 15, weight: .black)).foregroundStyle(tint)
      }
      .frame(width: 50, height: 50)

      VStack(alignment: .leading, spacing: 5) {
        HStack {
          Text(mission.title).font(Theme.display(16)).textCase(.uppercase).foregroundStyle(Theme.ink).lineLimit(1)
          Spacer()
          Text("\(progress)/\(mission.target)").font(Theme.mono(11)).foregroundStyle(tint)
        }
        Text(mission.detail).font(Theme.body(11)).foregroundStyle(Theme.inkDim).lineLimit(1)
        HStack(spacing: 10) {
          CurrencyChip(kind: .credits, amount: mission.rewardCredits, size: 11)
          CurrencyChip(kind: .xp, amount: mission.rewardXP, size: 11)
          if mission.rewardBaitcoins > 0 { CurrencyChip(kind: .baitcoins, amount: mission.rewardBaitcoins, size: 11) }
          Spacer()
          if claimed {
            Label("CLAIMED", systemImage: "checkmark.seal.fill").font(Theme.mono(10)).foregroundStyle(Theme.green)
          } else {
            ChromeButton(title: "Claim", tone: complete ? .gold : .slate, size: 11, minWidth: 70, disabled: !complete) { store.claim(mission) }
              .accessibilityIdentifier("mission.claim.\(mission.id)")
          }
        }
      }
    }
    .panel(padding: 12, radius: 18, light: complete && !claimed)
    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(complete && !claimed ? Theme.gold.opacity(0.6) : .clear, lineWidth: 1.5))
    .opacity(claimed ? 0.75 : 1)
  }
}

// MARK: - Angler profile

struct ProfileView: View {
  @EnvironmentObject var store: GameStore
  @State private var confirmReset = false

  var body: some View {
    let p = store.profile
    ZStack {
      ScreenBackground()
      VStack(spacing: 10) {
        HeaderBar(title: "Angler", subtitle: "Profile & records")
        HStack(alignment: .top, spacing: 10) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
              LevelBadge(level: p.level, size: 44)
              VStack(alignment: .leading, spacing: 3) {
                Text(p.name).font(Theme.display(18)).foregroundStyle(Theme.ink)
                Text("\(p.xp.formatted()) XP").font(Theme.mono(10)).foregroundStyle(Theme.green)
                MeterBar(value: p.levelProgress, height: 5)
              }
            }
            ScrollView {
              LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                StatTile(icon: "fish.fill", label: "Caught", value: "\(p.stats.totalCatches)", tint: Theme.cyan)
                StatTile(icon: "arrow.uturn.backward", label: "Released", value: "\(p.stats.totalReleased)", tint: Theme.green)
                StatTile(icon: "books.vertical.fill", label: "Species", value: "\(p.stats.speciesCaught.count)/\(SpeciesCatalog.all.count)", tint: Theme.gold)
                StatTile(icon: "scalemass.fill", label: "Heaviest", value: p.stats.heaviestLb > 0 ? p.stats.heaviestLb.lbOz : "—", tint: Theme.orange)
                StatTile(icon: "arrow.up.right", label: "Casts", value: "\(p.stats.casts)", tint: Theme.cyan)
                StatTile(icon: "scissors", label: "Snaps", value: "\(p.stats.lineBreaks)", tint: Theme.red)
                StatTile(icon: "fish", label: "Lost", value: "\(p.stats.fishLost)", tint: Theme.inkDim)
                StatTile(icon: "calendar", label: "Days", value: "\(p.stats.daysFished)", tint: Theme.green)
                StatTile(icon: "dollarsign.circle.fill", label: "Earned", value: p.stats.creditsEarned.formatted(), tint: Theme.gold)
              }
            }
            HStack {
              Toggle(isOn: Binding(get: { store.profile.hapticsEnabled }, set: { store.profile.hapticsEnabled = $0; store.save() })) {
                Label("Haptics", systemImage: "iphone.radiowaves.left.and.right").font(Theme.body(11, weight: .bold)).foregroundStyle(Theme.ink)
              }
              .tint(Theme.cyanDeep)
            }
            ChromeButton(title: confirmReset ? "Tap again to reset" : "Reset progress", icon: "arrow.counterclockwise", tone: .red, size: 11, minWidth: 0) {
              if confirmReset { store.resetProgress() } else { withAnimation { confirmReset = true } }
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("profile.reset")
          }
          .frame(width: 270)
          .panel(padding: 12, radius: 18)

          VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Keepnet", icon: "basket.fill", trailing: "\(p.keepnet.count)/\(PlayerProfile.keepnetMaxCount)")
            MeterBar(value: p.keepnetWeightLb / PlayerProfile.keepnetMaxWeightLb, colors: [Theme.cyan, Theme.cyanDeep], height: 6)
            if p.keepnet.isEmpty {
              EmptyState(icon: "basket", text: "Nothing in the keepnet. Fish you keep are sold when you end the day.")
            }
            ScrollView {
              VStack(spacing: 4) {
                ForEach(p.keepnet) { record in CatchRow(record: record) }
              }
            }
            HStack {
              Text("Value").capsLabel(10)
              CurrencyChip(kind: .credits, amount: p.keepnetValue)
              Spacer()
              ChromeButton(title: "Sell all", icon: "dollarsign.circle.fill", tone: .gold, size: 11, minWidth: 0, disabled: p.keepnet.isEmpty) { store.sellKeepnet() }
                .accessibilityIdentifier("profile.sell")
            }
          }
          .frame(maxWidth: .infinity)
          .panel(padding: 12, radius: 18)

          VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Catch log", icon: "list.bullet.rectangle.fill", trailing: p.catchLog.isEmpty ? nil : "\(p.catchLog.count) entries", tint: Theme.gold)
            if p.catchLog.isEmpty {
              EmptyState(icon: "fish", text: "Your catches will be listed here.")
            }
            ScrollView {
              VStack(spacing: 4) {
                ForEach(p.catchLog.prefix(40)) { record in CatchRow(record: record) }
              }
            }
          }
          .frame(maxWidth: .infinity)
          .panel(padding: 12, radius: 18)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
    }
  }
}

struct EmptyState: View {
  let icon: String
  let text: String

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon).font(.system(size: 26, weight: .light)).foregroundStyle(Theme.inkDim.opacity(0.7))
      Text(text).font(Theme.body(11)).foregroundStyle(Theme.inkDim).multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 8)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 22)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
  }
}

struct CatchRow: View {
  let record: CatchRecord

  var body: some View {
    HStack(spacing: 8) {
      FishIllustration(coloring: record.species.coloring).frame(width: 40, height: 22)
      VStack(alignment: .leading, spacing: 0) {
        Text(record.species.name).font(Theme.body(12, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
        Text("\(record.weightLb.lbOz) · \(record.lengthIn.inchLabel)").font(Theme.mono(9, weight: .medium)).foregroundStyle(Theme.inkDim)
      }
      Spacer(minLength: 4)
      GradeTag(grade: record.grade)
      if record.kept { CurrencyChip(kind: .credits, amount: record.sellPrice, size: 11) } else { Text("RELEASED").font(Theme.mono(8)).foregroundStyle(Theme.inkDim) }
    }
    .padding(.horizontal, 8).padding(.vertical, 5)
    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.045)))
  }
}

struct GradeTag: View {
  let grade: CatchGrade

  var body: some View {
    Text(grade.label).font(Theme.display(10)).kerning(0.6)
      .foregroundStyle(grade == .young ? Theme.inkDim : .black)
      .padding(.horizontal, 7).padding(.vertical, 2)
      .background(Capsule().fill(color))
      .shadow(color: grade == .trophy || grade == .unique ? color.opacity(0.6) : .clear, radius: 4)
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
