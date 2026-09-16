import Foundation

/// Forty levels: the first eight are hand-drawn ASCII boards, the rest are generated
/// from fixed seeds so every player sees the same campaign.
public enum LevelCatalog {
  public static let count = 40

  public static let all: [Level] = (1...count).map { level($0) }

  public static func level(_ id: Int) -> Level {
    if let handmade = handmade[id] { return handmade.build(id: id) }
    return LevelGenerator.generate(spec(id))
  }

  public static func spec(_ id: Int) -> LevelSpec {
    let title = names[(id - 1) % names.count]
    let stage = id - 1
    let width = min(7, 4 + stage / 6)
    let height = min(8, 4 + stage / 5)
    let nets = id >= 14 && id % 3 != 1 ? 2 : 1
    let hot: Int = id < 10 ? 0 : id < 18 ? 1 : id < 28 ? 2 : id < 36 ? 3 : 4
    let cells = Double(width * height)
    let time = (14 + cells * 0.75 + Double(nets) * 8 + Double(hot) * 3).rounded()
    return LevelSpec(
      id: id, name: title.0, subtitle: title.1, width: width, height: height, nets: nets,
      hotTiles: hot, timeLimit: time, seed: 0xC0DE_0000 &+ UInt64(id) &* 7919)
  }

  static let names: [(String, String)] = [
    ("First Boot", "Plug it in. Any port in a storm."),
    ("Hello, CUDA", "One lane. One kernel. Launch."),
    ("Warp Speed", "Thirty-two threads walk in lockstep."),
    ("Tensor Twist", "Bend the lane. Multiply the math."),
    ("Founders Edition", "Reference design, reference route."),
    ("Wafer Thin", "Every die on the wafer wants power."),
    ("Fab 12", "Yield is everything."),
    ("Ray Traced", "Follow the bounce to the light."),
    ("DLSS Detour", "Upscale a tiny route into a big one."),
    ("Hot Spot", "Something on this board runs warm."),
    ("Thermal Throttle", "Cables near heat glow, then go."),
    ("Boost Clock", "Faster than spec, if you dare."),
    ("Frame Pacing", "Steady taps, steady frames."),
    ("Dual Lane", "Power and data both want in."),
    ("SLI Bridge", "Two cards, two cables, zero regrets."),
    ("Memory Bus", "Wide, fast and easy to trip on."),
    ("Shader Cache", "You have seen this pattern before."),
    ("Junction Temp", "The hot spot has friends now."),
    ("Undervolt", "Less is more. Route lean."),
    ("Ampere Alley", "Every tile hums at full tilt."),
    ("Ada Approach", "Newer architecture, older problem."),
    ("Blackwell Bend", "The lanes curve around the furnace."),
    ("NVLink", "Fast interconnect, slow hands."),
    ("Volta Vault", "The vault is warm. The keys are cables."),
    ("Turing Test", "Can you tell the decoy from the route?"),
    ("Pascal Pass", "A narrow pass between two heaters."),
    ("Maxwell Maze", "Corners upon corners."),
    ("Kepler Kink", "Three hot tiles. No mercy."),
    ("Fermi Furnace", "This one runs famously hot."),
    ("Tesla Coil", "Coiled lanes, crackling air."),
    ("Hopper Hop", "Skip the heat, hop the lane."),
    ("Grace Gauntlet", "Two nets. Three fires. Ninety seconds."),
    ("Omniverse", "Everything, everywhere, all plugged in."),
    ("Ray Reconstruction", "Rebuild the path from noisy tiles."),
    ("Frame Generation", "Make up the frames you don't have."),
    ("Reflex Mode", "Four heaters. Low latency required."),
    ("Wafer Scale", "The largest board yet."),
    ("Foundry Floor", "Molten. Careful."),
    ("Keynote Demo", "Do not crash on stage."),
    ("The More You Route", "The more you save. Final boot."),
  ]

  /// ASCII legend: `.` empty, `-` `|` straight, `L` corner, `T` tee, `+` cross,
  /// `P` 12VHPWR source, `G` power GPU connector, `S` PCIe source, `H` PCIe GPU connector,
  /// `#` hot tile. Cables are scrambled deterministically by `seed`.
  struct Handmade {
    var name: String
    var subtitle: String
    var timeLimit: Double
    var rows: [String]
    var seed: UInt64

    func build(id: Int) -> Level {
      let height = rows.count
      let width = rows[0].count
      var tiles: [Tile] = []
      for row in rows {
        precondition(row.count == width, "Ragged level \(id)")
        for ch in row {
          let kind: TileKind
          var rotation = 0
          switch ch {
          case ".": kind = .empty
          case "|": kind = .straight
          case "-":
            kind = .straight
            rotation = 1
          case "L": kind = .corner
          case "T": kind = .tee
          case "+": kind = .cross
          case "P": kind = .source(.power)
          case "G": kind = .sink(.power)
          case "S": kind = .source(.pcie)
          case "H": kind = .sink(.pcie)
          case "#": kind = .hot
          default: preconditionFailure("Unknown glyph \(ch) in level \(id)")
          }
          tiles.append(Tile(kind, rotation: rotation))
        }
      }
      var level = Level(
        id: id, name: name, subtitle: subtitle, width: width, height: height, tiles: tiles,
        timeLimit: timeLimit, par: 0, seed: seed)
      var board = Board(level: level)
      // Point sources at a cable neighbour, then aim each sink so a route exists.
      let sources = board.points.filter {
        if case .source = board[$0].kind { return true }
        return false
      }
      let sinks = board.points.filter {
        if case .sink = board[$0].kind { return true }
        return false
      }
      for p in sources {
        let preferred: [Direction] = [.right, .down, .up, .left]
        if let dir = preferred.first(where: {
          board.contains(p.moved($0)) && board[p.moved($0)].kind.isCable
        }) {
          board[p].rotation = board[p].turnsToMatch([dir]) ?? 0
        }
      }
      for p in sinks {
        guard case .sink(let net) = board[p].kind else { continue }
        for dir in [Direction.left, .up, .down, .right] {
          guard board.contains(p.moved(dir)), board[p.moved(dir)].kind.isCable else { continue }
          board[p].rotation += board[p].turnsToMatch([dir]) ?? 0
          if Solver.route(board, net: net, avoidHeat: true) != nil { break }
        }
      }
      var rng = SeededRNG(seed: seed)
      for p in board.points where board[p].isRotatable && board[p].kind.symmetry > 1 {
        board[p].rotation += rng.int(1..<board[p].kind.symmetry)
      }
      if board.flow().isComplete, let p = board.points.first(where: { board[$0].isRotatable }) {
        board[p].rotation += 1
      }
      level.tiles = board.tiles
      board = Board(level: level)
      level.par = Solver.par(board) ?? 0
      precondition(
        level.par > 0 && Solver.isSolvable(board, avoidHeat: true), "Level \(id) unsolvable")
      return level
    }
  }

  static let handmade: [Int: Handmade] = [
    1: Handmade(
      name: "First Boot", subtitle: "Plug it in. Rotate the cable to reach the GPU.", timeLimit: 40,
      rows: [
        "....",
        "P--G",
        "....",
        "....",
      ], seed: 11),
    2: Handmade(
      name: "Hello, CUDA", subtitle: "Corners turn the lane. Tap to rotate.", timeLimit: 45,
      rows: [
        "P-L.",
        "..L-G",
        ".....",
        ".....",
      ].map { $0.padding(toLength: 5, withPad: ".", startingAt: 0) }, seed: 23),
    3: Handmade(
      name: "Warp Speed", subtitle: "Decoy cables carry nothing. Ignore them.", timeLimit: 45,
      rows: [
        ".L-L..",
        "PL.|..",
        ".L-|..",
        "...L-G",
      ].map { $0.padding(toLength: 6, withPad: ".", startingAt: 0) }, seed: 37),
    4: Handmade(
      name: "Tensor Twist", subtitle: "Tees have three openings. Only two matter.", timeLimit: 50,
      rows: [
        ".....",
        "PT-T.",
        ".L.LG",
        ".L-L.",
        ".....",
      ], seed: 41),
    5: Handmade(
      name: "Founders Edition", subtitle: "A long snake of a lane.", timeLimit: 55,
      rows: [
        "PL.L-L",
        ".L-L.|",
        ".L-L.|",
        ".L-L.|",
        ".....G",
      ].map { $0.padding(toLength: 6, withPad: ".", startingAt: 0) }, seed: 53),
    6: Handmade(
      name: "Wafer Thin", subtitle: "A cross carries the lane straight through.", timeLimit: 55,
      rows: [
        "..L-L.",
        "P-+-+G",
        "..L-L.",
        "......",
        "......",
      ], seed: 59),
    7: Handmade(
      name: "Fab 12", subtitle: "Yield depends on every corner.", timeLimit: 60,
      rows: [
        "PL.L-L.",
        ".L-L.|.",
        "..L-.|.",
        ".L-L.LL",
        "..L-L.|",
        "....L-G",
      ].map { $0.padding(toLength: 7, withPad: ".", startingAt: 0) }, seed: 67),
    8: Handmade(
      name: "Ray Traced", subtitle: "Follow the bounce all the way to the light.", timeLimit: 60,
      rows: [
        ".L-L..",
        "PL.L-L",
        "..L-L|",
        ".L-L.|",
        ".L-L.|",
        ".....G",
      ].map { $0.padding(toLength: 6, withPad: ".", startingAt: 0) }, seed: 71),
  ]
}
