import SwiftUI

extension CosmeticSlot {
  var title: String { self == .pickaxe ? "Tool" : rawValue.capitalized }
}
extension Rarity {
  var title: String { rawValue.capitalized }
  var color: Color { Color(rgb: rgb) }
}

struct LockerView: View {
  @EnvironmentObject private var profile: Profile
  @EnvironmentObject private var session: Session
  @Environment(\.horizontalSizeClass) private var sizeClass
  let catalogue: Catalogue
  @State private var slot: CosmeticSlot = .outfit
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top) {
        SectionTitle("Locker", detail: "Original cosmetics. Unlock more through the pass.")
        Spacer()
        if sizeClass != .compact {
          Segmented(options: CosmeticSlot.allCases, label: \.title, selection: $slot)
            .frame(width: 320)
        }
      }
      if sizeClass == .compact {
        Segmented(options: CosmeticSlot.allCases, label: \.title, selection: $slot)
      }
      if let equipped = catalogue.cosmetic(profile.data.loadout[slot]) {
        HStack(spacing: 20) {
          CosmeticArt(cosmetic: equipped).frame(width: 120, height: 140).padding(10)
            .background(
              equipped.rarity.color.opacity(0.12),
              in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Equipped \(slot.title)")
            Text(equipped.name).font(.lfTitle(26)).tracking(-0.4).foregroundStyle(Color.lfText)
            Pill(text: equipped.rarity.title, color: equipped.rarity.color)
            Text(equipped.description).font(.lfBody(14)).foregroundStyle(Color.lfMuted)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 0)
        }.card(padding: 18)
      }
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 12)], spacing: 12
      ) {
        ForEach(catalogue.cosmetics.filter { $0.slot == slot }) { cosmetic in
          let owned = profile.data.unlocked.contains(cosmetic.id)
          let selected = profile.data.loadout[slot] == cosmetic.id
          let tier = catalogue.tiers.first { $0.rewardId == cosmetic.id }?.tier
          Button {
            profile.data.loadout[slot] = cosmetic.id
            session.updateIdentity()
          } label: {
            VStack(alignment: .leading, spacing: 10) {
              ZStack(alignment: .topTrailing) {
                CosmeticArt(cosmetic: cosmetic).frame(height: 120).frame(maxWidth: .infinity)
                  .padding(8)
                  .background(
                    cosmetic.rarity.color.opacity(owned ? 0.12 : 0.05),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                  )
                  .saturation(owned ? 1 : 0.2)
                if !owned {
                  Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.lfMuted).padding(6)
                    .background(Color.lfPanel, in: Circle()).padding(6)
                }
              }
              VStack(alignment: .leading, spacing: 3) {
                Text(cosmetic.name).font(.lfBody(15, weight: .semibold))
                  .foregroundStyle(Color.lfText).lineLimit(1)
                HStack(spacing: 6) {
                  Circle().fill(cosmetic.rarity.color).frame(width: 7, height: 7)
                  Text(cosmetic.rarity.title)
                  if !owned, let tier {
                    Text("· Tier \(tier)")
                  }
                }.font(.lfLabel(12)).foregroundStyle(Color.lfMuted)
              }
              Text(selected ? "Equipped" : owned ? "Equip" : "Locked")
                .font(.lfBody(13, weight: .semibold))
                .foregroundStyle(selected ? .white : owned ? Color.lfText : Color.lfMuted)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(
                  selected ? Color.lfAccent : Color.lfPanel2,
                  in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(10)
            .background(Color.lfPanel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? Color.lfAccent : Color.lfLine, lineWidth: selected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain).disabled(!owned || selected)
          .accessibilityLabel(
            "\(cosmetic.name), \(cosmetic.rarity.title)"
              + (selected ? ", equipped" : owned ? "" : ", locked"))
        }
      }
    }
  }
}

struct PassView: View {
  @EnvironmentObject private var profile: Profile
  let catalogue: Catalogue
  var body: some View {
    let xp = profile.data.xp
    let tier = min(11, xp / 300)
    let claimable = catalogue.tiers.filter {
      xp >= $0.xpRequired && !profile.data.claimed.contains($0.tier)
    }
    VStack(alignment: .leading, spacing: 20) {
      SectionTitle(
        "Season pass", detail: "Earn XP from placement, eliminations, damage and survival.")
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 2) {
            Eyebrow("Current tier")
            Text("Tier \(tier)").font(.lfDisplay(44)).foregroundStyle(Color.lfText)
              .monospacedDigit()
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            Text("\(xp) XP").font(.lfDigits(22)).foregroundStyle(Color.lfText)
            Text(tier >= 11 ? "Max tier" : "\(300 - xp % 300) XP to tier \(tier + 1)")
              .font(.lfLabel(12)).foregroundStyle(Color.lfMuted).monospacedDigit()
          }
        }
        Meter(value: Double(min(xp, 3300)), total: 3300, height: 8)
        if !claimable.isEmpty {
          Button {
            for item in claimable { profile.data.claim(item) }
          } label: {
            Label(
              "Claim \(claimable.count) reward\(claimable.count == 1 ? "" : "s")",
              systemImage: "gift.fill")
          }.buttonStyle(LFButtonStyle(role: .primary))
        }
      }.card(padding: 20)
      VStack(alignment: .leading, spacing: 12) {
        Eyebrow("Rewards")
        ScrollView(.horizontal) {
          HStack(spacing: 12) {
            ForEach(catalogue.tiers) { item in
              if let reward = catalogue.cosmetic(item.rewardId) {
                TierCard(tier: item, reward: reward)
              }
            }
          }.padding(.vertical, 2)
        }.scrollIndicators(.hidden)
      }
      VStack(alignment: .leading, spacing: 12) {
        Eyebrow("Career")
        let career = profile.data.career
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
          StatCell(label: "Matches", value: "\(career.matches)")
          StatCell(label: "Victories", value: "\(career.wins)", color: .lfGold)
          StatCell(label: "Eliminations", value: "\(career.kills)", color: .lfAccent)
          StatCell(label: "Damage", value: "\(career.damage)")
          StatCell(label: "Harvested", value: "\(career.harvested)")
          StatCell(label: "Built", value: "\(career.built)")
          StatCell(
            label: "Best finish",
            value: career.bestPlacement == 0 ? "—" : career.bestPlacement.ordinal)
        }
      }
    }
  }
}

struct TierCard: View {
  @EnvironmentObject private var profile: Profile
  let tier: PassTier
  let reward: Cosmetic
  var body: some View {
    let claimed = profile.data.claimed.contains(tier.tier)
    let unlocked = profile.data.xp >= tier.xpRequired
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Tier \(tier.tier)").font(.lfLabel(12)).foregroundStyle(Color.lfMuted)
        Spacer()
        Text("\(tier.xpRequired) XP").font(.lfLabel(12)).foregroundStyle(Color.lfMuted)
          .monospacedDigit()
      }
      CosmeticArt(cosmetic: reward).frame(width: 130, height: 120).padding(6)
        .background(
          reward.rarity.color.opacity(unlocked ? 0.12 : 0.05),
          in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .saturation(unlocked ? 1 : 0.25)
      VStack(alignment: .leading, spacing: 3) {
        Text(reward.name).font(.lfBody(15, weight: .semibold)).foregroundStyle(Color.lfText)
          .lineLimit(1)
        Text("\(reward.rarity.title) \(reward.slot.title.lowercased())").font(.lfLabel(12))
          .foregroundStyle(Color.lfMuted)
      }
      Button(claimed ? "Claimed" : unlocked ? "Claim" : "Locked") { profile.data.claim(tier) }
        .buttonStyle(
          LFButtonStyle(
            role: unlocked && !claimed ? .primary : .neutral, size: .compact, expand: true)
        )
        .disabled(!unlocked || claimed)
    }
    .padding(12).frame(width: 170)
    .background(Color.lfPanel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.lfLine))
  }
}

struct SettingsView: View {
  @EnvironmentObject private var profile: Profile
  @EnvironmentObject private var session: Session
  @State private var server = ""
  @State private var name = ""
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SectionTitle("Settings")
      group("Profile") {
        field("Display name") {
          HStack(spacing: 8) {
            TextField("Name", text: $name).textFieldStyle(.plain).font(.lfBody(15))
              .padding(.horizontal, 12).frame(height: 40).inset(radius: 9)
              .onSubmit(saveName)
            Button("Save", action: saveName)
              .buttonStyle(LFButtonStyle(role: .neutral, size: .compact))
              .disabled(
                name.trimmingCharacters(in: .whitespaces).isEmpty
                  || name.trimmingCharacters(in: .whitespaces) == profile.data.name)
          }
        }
      }
      group("Appearance") {
        field("Theme") {
          Segmented(
            options: ["system", "dark", "light"], label: { $0.capitalized },
            selection: $profile.data.theme)
        }
        Toggle("Reduce motion", isOn: $profile.data.reducedMotion)
        Toggle("Sound", isOn: $profile.data.sound)
        Toggle("Haptics", isOn: $profile.data.haptics)
      }
      group("Server") {
        field("WebSocket address") {
          TextField("ws://host:8787/ws", text: $server).textFieldStyle(.plain)
            .font(.system(size: 14, design: .monospaced))
            .padding(.horizontal, 12).frame(height: 40).inset(radius: 9)
            #if os(iOS)
              .textInputAutocapitalization(.never).keyboardType(.URL).autocorrectionDisabled()
            #endif
        }
        Text(
          "Use your Mac’s LAN address for a physical iPhone or iPad, and wss:// for remote servers. Reconnect tokens are kept in the Keychain per server."
        ).font(.lfBody(13)).foregroundStyle(Color.lfMuted)
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 8) {
          Button("Apply and reconnect") {
            profile.data.server = server.trimmingCharacters(in: .whitespaces)
            session.connect()
          }.buttonStyle(LFButtonStyle(role: .primary))
          Button("Reset") { server = "ws://localhost:8787/ws" }.buttonStyle(.lfNeutral)
          Spacer()
          ConnectionBadge()
        }
        if session.room != nil {
          Text(
            "Changing servers leaves the current connection. Your match can be resumed when you reconnect to that server."
          ).font(.lfBody(13)).foregroundStyle(Color.lfAmber)
        }
      }
    }
    .toggleStyle(.switch)
    .font(.lfBody(15))
    .frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
    .onAppear {
      server = profile.data.server
      name = profile.data.name
    }
  }
  private func saveName() {
    let trimmed = String(name.trimmingCharacters(in: .whitespaces).prefix(24))
    guard !trimmed.isEmpty else { return }
    profile.data.name = trimmed
    name = trimmed
    session.updateIdentity()
  }
  private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 14) {
      Eyebrow(title)
      content()
    }.card(padding: 18)
  }
  private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 8) {
      Text(label).font(.lfLabel(13)).foregroundStyle(Color.lfMuted)
      content()
    }
  }
}

extension Int {
  var ordinal: String {
    let suffix: String
    switch (self % 100, self % 10) {
    case (11...13, _): suffix = "th"
    case (_, 1): suffix = "st"
    case (_, 2): suffix = "nd"
    case (_, 3): suffix = "rd"
    default: suffix = "th"
    }
    return "\(self)\(suffix)"
  }
}

struct ResultsView: View {
  @EnvironmentObject private var session: Session
  @EnvironmentObject private var profile: Profile
  @Environment(\.horizontalSizeClass) private var sizeClass
  let summary: MatchSummary
  let playerID: Int
  var body: some View {
    let row = summary.players.first { $0.id == playerID }
    let won = row?.team == summary.winnerTeam
    let standings = summary.players.sorted {
      $0.placement == $1.placement ? $0.id < $1.id : $0.placement < $1.placement
    }
    let winner = standings.first { $0.team == summary.winnerTeam }
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 18) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
              Eyebrow(won ? "Victory" : "Match over", color: won ? .lfGold : .lfMuted)
              Text(won ? "1st" : (row?.placement ?? 0) > 0 ? (row?.placement ?? 0).ordinal : "—")
                .font(.lfDisplay(sizeClass == .compact ? 64 : 84)).tracking(-1)
                .foregroundStyle(won ? Color.lfGold : Color.lfText).monospacedDigit()
              Text(
                won
                  ? "Your fort was the last one standing."
                  : "of \(summary.players.count) · \(winner?.name ?? "Nobody") won the match"
              ).font(.lfBody(15, weight: .medium)).foregroundStyle(Color.lfMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
              Text(summary.mode.rawValue.capitalized).font(.lfBody(14, weight: .semibold))
                .foregroundStyle(Color.lfText)
              Text("Island \(summary.seed)").font(.lfLabel(12)).foregroundStyle(Color.lfMuted)
              Text("Storm phase \(summary.stormPhase)").font(.lfLabel(12))
                .foregroundStyle(Color.lfMuted)
            }.monospacedDigit()
          }
          if let row {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
              StatCell(label: "Eliminations", value: "\(row.kills)", color: .lfAccent)
              StatCell(label: "Damage", value: "\(row.damage)")
              StatCell(label: "Harvested", value: "\(row.harvested)")
              StatCell(label: "Built", value: "\(row.built)")
              StatCell(label: "Chests", value: "\(row.chests)")
              StatCell(
                label: "Survived",
                value: "\(row.survived / 60):\(String(format: "%02d", row.survived % 60))")
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
              Text("+\(row.xp) XP").font(.lfDigits(28)).foregroundStyle(Color.lfHealth)
              Text("Tier \(min(11, profile.data.xp / 300)) · \(profile.data.xp) XP total")
                .font(.lfBody(14)).foregroundStyle(Color.lfMuted).monospacedDigit()
              Spacer()
            }
          }
          HStack(spacing: 10) {
            if session.isHost {
              Button {
                session.returnToLobby()
              } label: {
                Label("Play again", systemImage: "arrow.counterclockwise")
              }.buttonStyle(LFButtonStyle(role: .primary, size: .large))
            } else {
              HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Waiting for the host to return to the lobby").font(.lfBody(14))
                  .foregroundStyle(Color.lfMuted)
              }
            }
            Spacer()
            Button("Leave room") { session.leave() }.buttonStyle(LFButtonStyle(role: .destructive))
          }
        }.card(padding: 22)
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Eyebrow("Standings")
            Spacer()
            Text("\(summary.teams) teams · \(summary.players.count) players").font(.lfLabel(12))
              .foregroundStyle(Color.lfMuted)
          }
          VStack(spacing: 0) {
            HStack(spacing: 12) {
              Text("#").frame(width: 36, alignment: .leading)
              Text("Player").frame(maxWidth: .infinity, alignment: .leading)
              Text("Elims").frame(width: 56, alignment: .trailing)
              Text("Dmg").frame(width: 56, alignment: .trailing)
              Text("XP").frame(width: 56, alignment: .trailing)
            }
            .font(.lfLabel(12)).foregroundStyle(Color.lfMuted)
            .padding(.horizontal, 14).padding(.vertical, 8)
            ForEach(standings) { player in
              let you = player.id == playerID
              HStack(spacing: 12) {
                Text(player.placement > 0 ? "\(player.placement)" : "—")
                  .font(.lfDigits(15, weight: .semibold))
                  .foregroundStyle(
                    player.placement == 1 ? Color.lfGold : you ? Color.lfText : Color.lfMuted
                  )
                  .frame(width: 36, alignment: .leading)
                HStack(spacing: 8) {
                  Text(player.name).font(.lfBody(15, weight: you ? .semibold : .regular))
                    .foregroundStyle(Color.lfText).lineLimit(1)
                  if you { Pill(text: "You", color: .lfAccent) }
                  if player.bot {
                    Text("Bot").font(.lfLabel(11)).foregroundStyle(Color.lfMuted)
                  } else {
                    PlatformIcon(platform: player.platform).foregroundStyle(Color.lfMuted)
                  }
                  if summary.mode != .solo {
                    Text("T\(player.team + 1)").font(.lfLabel(11)).foregroundStyle(Color.lfMuted)
                  }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text("\(player.kills)").frame(width: 56, alignment: .trailing)
                Text("\(player.damage)").frame(width: 56, alignment: .trailing)
                Text("\(player.xp)").frame(width: 56, alignment: .trailing)
              }
              .font(.lfDigits(15, weight: .medium)).foregroundStyle(Color.lfText)
              .padding(.horizontal, 14).padding(.vertical, 10)
              .background(you ? Color.lfAccent.opacity(0.1) : .clear)
              .overlay(alignment: .leading) {
                if you { Color.lfAccent.frame(width: 3) }
              }
              .overlay(alignment: .top) { Color.lfLine.frame(height: 1) }
              .accessibilityElement(children: .combine)
            }
          }
          .background(Color.lfPanel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.lfLine))
        }
      }
      .padding(sizeClass == .compact ? 16 : 24).frame(maxWidth: 960).frame(maxWidth: .infinity)
    }
    .background(Color.lfBackground.ignoresSafeArea())
  }
}
