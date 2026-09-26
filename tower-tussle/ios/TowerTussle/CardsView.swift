import SwiftUI

struct CardsView: View {
    @EnvironmentObject var profile: PlayerProfile
    let onBack: () -> Void
    let onBattle: () -> Void

    enum EditMode: Equatable {
        case browse
        case replacing(deckCard: String)
        case adding(collectionCard: String)
    }

    @State private var mode: EditMode = .browse
    @State private var detailCard: CardDef? = nil
    @State private var showResetConfirm = false
    @State private var toast: String? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ZStack {
            SceneryBackdrop(dim: 0.45)
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        deckSection
                        collectionSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 30)
                }
                footer
            }
        }
        .sheet(item: $detailCard) { card in
            let inDeck = profile.deck.contains(card.id)
            CardDetailSheet(card: card, inDeck: inDeck) {
                detailCard = nil
                withAnimation(.spring(duration: 0.3)) {
                    mode = inDeck ? .replacing(deckCard: card.id) : .adding(collectionCard: card.id)
                }
            }
            .presentationDetents([.fraction(0.7), .large])
        }
        .confirmationDialog("Reset to the starter deck?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset deck", role: .destructive) {
                withAnimation(.spring(duration: 0.3)) {
                    profile.resetDeck()
                    mode = .browse
                }
                showToast("Starter deck restored")
            }
            Button("Keep my deck", role: .cancel) {}
        } message: {
            Text("Your current eight cards will be replaced with the starter deck.")
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Button(action: { ArcadeAudio.play(.tap); onBack() }) {
                Label("Home", systemImage: "chevron.left")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
            }
            .buttonStyle(ChunkyButtonStyle(style: .slate))
            .accessibilityIdentifier("backButton")
            Spacer()
            DisplayText(text: "DECK", size: 30, fill: .goldText)
            Spacer()
            Button { ArcadeAudio.play(.tap); showResetConfirm = true } label: {
                Text("Reset")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
            }
            .buttonStyle(ChunkyButtonStyle(style: .slate))
            .opacity(profile.deck == Cards.defaultDeck ? 0.55 : 1)
            .accessibilityIdentifier("resetDeckButton")
            .accessibilityHint("Restore the starter deck")
        }
        .foregroundStyle(.white)
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var deckSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BATTLE DECK")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .shadow(color: .black.opacity(0.8), radius: 0, x: 1, y: 1)
                    Text("\(profile.troopCount) troops · \(profile.spellCount) spells")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                HStack(spacing: 4) {
                    IconView(kind: .elixir, size: 16)
                    Text(String(format: "%.1f", profile.averageElixir))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Text("AVG")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .panel(cornerRadius: 14)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("avgElixir")
                .accessibilityLabel(String(format: "Average elixir %.1f", profile.averageElixir))
            }
            .foregroundStyle(.white)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(profile.deck, id: \.self) { id in
                    let card = Cards.byId(id)
                    CardTile(card: card, selected: isHighlighted(deck: id), dimmed: isDimmed(deck: id))
                        .onTapGesture { tapDeck(id) }
                        .accessibilityIdentifier("deck-\(id)")
                        .accessibilityLabel("\(card.name), \(card.cost) elixir, in deck")
                        .accessibilityHint(deckHint(id))
                }
            }

            banner
        }
    }

    private var collectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("COLLECTION")
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.8), radius: 0, x: 1, y: 1)
                Text("\(profile.collection.count) cards on the bench")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 6)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(profile.collection, id: \.self) { id in
                    let card = Cards.byId(id)
                    CardTile(card: card, selected: isHighlighted(collection: id), dimmed: isDimmed(collection: id))
                        .onTapGesture { tapCollection(id) }
                        .accessibilityIdentifier("collection-\(id)")
                        .accessibilityLabel("\(card.name), \(card.cost) elixir, in collection")
                        .accessibilityHint(collectionHint(id))
                }
            }
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let toast {
            HintBanner(step: nil, text: toast, tone: .active)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            switch mode {
            case .browse:
                HintBanner(step: "i", text: "Tap any card for stats and to swap it in or out of your deck.")
            case .replacing(let deckCard):
                HintBanner(step: "2", text: "Pick a collection card to replace \(Cards.byId(deckCard).name).", tone: .active) {
                    withAnimation(.spring(duration: 0.3)) { mode = .browse }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            case .adding(let collectionCard):
                HintBanner(step: "2", text: "Pick a deck card to swap out for \(Cards.byId(collectionCard).name).", tone: .active) {
                    withAnimation(.spring(duration: 0.3)) { mode = .browse }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var footer: some View {
        ChunkyButton(title: "BATTLE WITH THIS DECK", icon: .swords, style: .gold, height: 54, fontSize: 19, action: onBattle)
            .accessibilityIdentifier("deckBattleButton")
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(
                LinearGradient(colors: [Theme.background.opacity(0), Theme.background.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
    }

    // MARK: Interaction

    private func tapDeck(_ id: String) {
        ArcadeAudio.play(.tap)
        switch mode {
        case .browse:
            detailCard = Cards.byId(id)
        case .replacing(let current):
            if current == id {
                detailCard = Cards.byId(id)
            } else {
                withAnimation(.spring(duration: 0.25)) { mode = .replacing(deckCard: id) }
            }
        case .adding(let incoming):
            performSwap(deckCard: id, collectionCard: incoming)
        }
    }

    private func tapCollection(_ id: String) {
        ArcadeAudio.play(.tap)
        switch mode {
        case .browse:
            detailCard = Cards.byId(id)
        case .adding(let current):
            if current == id {
                detailCard = Cards.byId(id)
            } else {
                withAnimation(.spring(duration: 0.25)) { mode = .adding(collectionCard: id) }
            }
        case .replacing(let outgoing):
            performSwap(deckCard: outgoing, collectionCard: id)
        }
    }

    private func performSwap(deckCard: String, collectionCard: String) {
        withAnimation(.spring(duration: 0.35)) {
            profile.swap(deckCard: deckCard, with: collectionCard)
            mode = .browse
        }
        ArcadeAudio.play(.deploy)
        showToast("\(Cards.byId(collectionCard).name) is in, \(Cards.byId(deckCard).name) is out.")
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(duration: 0.3)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toast == text { withAnimation(.easeOut(duration: 0.3)) { toast = nil } }
        }
    }

    private func isHighlighted(deck id: String) -> Bool {
        if case .replacing(let d) = mode { return d == id }
        return false
    }

    private func isHighlighted(collection id: String) -> Bool {
        if case .adding(let c) = mode { return c == id }
        return false
    }

    private func isDimmed(deck id: String) -> Bool {
        if case .replacing(let d) = mode { return d != id }
        return false
    }

    private func isDimmed(collection id: String) -> Bool {
        if case .adding(let c) = mode { return c != id }
        return false
    }

    private func deckHint(_ id: String) -> String {
        switch mode {
        case .browse: return "Shows stats and lets you swap it out"
        case .replacing(let d): return d == id ? "Selected to be replaced" : "Select this card to replace instead"
        case .adding(let c): return "Replace with \(Cards.byId(c).name)"
        }
    }

    private func collectionHint(_ id: String) -> String {
        switch mode {
        case .browse: return "Shows stats and lets you add it to your deck"
        case .adding(let c): return c == id ? "Selected to add" : "Select this card to add instead"
        case .replacing(let d): return "Swap in for \(Cards.byId(d).name)"
        }
    }
}

struct CardTile: View {
    let card: CardDef
    let selected: Bool
    let dimmed: Bool

    var body: some View {
        CardFrame(card: card, selected: selected)
            .padding(.top, 6)
            .padding(.leading, 6)
            .opacity(dimmed ? 0.45 : 1)
            .scaleEffect(selected ? 1.06 : 1)
            .overlay(alignment: .bottomTrailing) {
                if selected {
                    IconView(kind: .swap, size: 22)
                        .padding(4)
                        .background(Circle().fill(Theme.accent))
                        .overlay(Circle().stroke(Art.outline, lineWidth: 2))
                        .offset(x: 6, y: 6)
                        .transition(.scale)
                }
            }
            .animation(.spring(duration: 0.2), value: selected)
            .animation(.easeOut(duration: 0.2), value: dimmed)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(card.name), \(card.cost) elixir")
            .accessibilityAddTraits(.isButton)
    }
}

struct CardDetailSheet: View {
    let card: CardDef
    let inDeck: Bool
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                CardFrame(card: card, showName: false)
                    .frame(width: 84)
                    .padding(.leading, 8)
                VStack(alignment: .leading, spacing: 4) {
                    DisplayText(text: card.name, size: 26, fill: .goldText)
                    Text(card.kind == .spell ? "Spell" : (card.flying ? "Flying troop" : "Ground troop"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(inDeck ? "IN YOUR DECK" : "ON THE BENCH")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(inDeck ? Art.outline : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(inDeck ? Theme.accent : .white.opacity(0.18)))
                }
                Spacer()
                ElixirBadge(cost: card.cost, size: 40)
            }
            Text(card.description)
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(.white.opacity(0.2))
            if card.kind == .troop {
                statRow("Hitpoints", "\(Int(card.hp))" + (card.count > 1 ? " ×\(card.count)" : ""))
                statRow("Damage", "\(Int(card.damage))")
                statRow("Hit speed", String(format: "%.1fs", card.hitSpeed))
                statRow("Range", card.range <= 1.2 ? "Melee" : String(format: "%.1f", card.range))
                statRow("Speed", card.speed >= 3.4 ? "Very fast" : card.speed >= 2.8 ? "Fast" : card.speed >= 1.8 ? "Medium" : "Slow")
                if card.buildingsOnly { statRow("Targets", "Buildings only") }
                statRow("Deploy", "Your half of the arena")
            } else {
                statRow("Damage", "\(Int(card.damage))")
                statRow("Tower damage", "\(Int(card.damage * Arena.towerSpellFactor))")
                statRow("Radius", String(format: "%.1f", card.radius))
                statRow("Deploy", "Anywhere in the arena")
            }
            Spacer(minLength: 8)
            ChunkyButton(title: inDeck ? "SWAP OUT" : "ADD TO DECK", icon: .swap, style: inDeck ? .slate : .gold, height: 54, fontSize: 20, action: onAction)
                .accessibilityIdentifier("cardActionButton")
            Text(inDeck ? "Next, pick the collection card that takes its place." : "Next, pick which deck card it replaces.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LinearGradient(colors: [Theme.panel, Theme.background], startPoint: .top, endPoint: .bottom))
        .accessibilityIdentifier("cardDetail")
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value).font(.body.weight(.bold)).monospacedDigit()
        }
        .font(.subheadline)
    }
}
