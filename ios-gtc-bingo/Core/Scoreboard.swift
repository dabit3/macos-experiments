import Foundation

public struct Player: Codable, Identifiable, Equatable {
  public var id: UUID
  public var name: String
  public var wins: Int
  public var card: BingoCard

  public init(id: UUID = UUID(), name: String, wins: Int = 0, card: BingoCard) {
    self.id = id
    self.name = name
    self.wins = wins
    self.card = card
  }
}

public struct GameState: Codable, Equatable {
  public var players: [Player]
  public var currentIndex: Int
  public var totalRounds: Int

  public static let maxPlayers = 6

  public init() {
    players = [Player(name: "Player 1", card: BingoCard(seed: 1))]
    currentIndex = 0
    totalRounds = 1
  }

  public var current: Player {
    get {
      players[currentIndex]
    }
    set {
      guard let index = players.firstIndex(where: { $0.id == newValue.id }) else { return }
      players[index] = newValue
    }
  }

  @discardableResult
  public mutating func addPlayer(name: String) -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, players.count < Self.maxPlayers else { return false }
    let seed = UInt64(players.count + 1) ^ UInt64(totalRounds) &* 0x9E37_79B9_7F4A_7C15
    players.append(Player(name: trimmed, card: BingoCard(seed: seed)))
    return true
  }

  public mutating func removePlayer(id: UUID) {
    guard players.count > 1, let index = players.firstIndex(where: { $0.id == id }) else { return }
    players.remove(at: index)
    if currentIndex >= players.count {
      currentIndex = players.count - 1
    } else if index < currentIndex {
      currentIndex -= 1
    }
  }

  public mutating func nextPlayer() {
    guard !players.isEmpty else { return }
    currentIndex = (currentIndex + 1) % players.count
  }

  public mutating func previousPlayer() {
    guard !players.isEmpty else { return }
    currentIndex = (currentIndex - 1 + players.count) % players.count
  }

  public mutating func markBingo(for id: UUID) {
    guard let index = players.firstIndex(where: { $0.id == id }),
      !players[index].card.bingoAwarded
    else { return }
    players[index].wins += 1
    players[index].card.bingoAwarded = true
  }

  public mutating func newCard(for id: UUID, seed: UInt64) {
    guard let index = players.firstIndex(where: { $0.id == id }) else { return }
    players[index].card = BingoCard(seed: seed)
  }

  public mutating func newRound(seed: UInt64) {
    for index in players.indices {
      let derivedSeed = seed ^ (UInt64(index) &* 0x9E37_79B9_7F4A_7C15)
      players[index].card = BingoCard(seed: derivedSeed)
    }
    totalRounds += 1
    currentIndex = 0
  }

  public var leaderboard: [Player] {
    players.sorted {
      if $0.wins != $1.wins { return $0.wins > $1.wins }
      return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }
}
