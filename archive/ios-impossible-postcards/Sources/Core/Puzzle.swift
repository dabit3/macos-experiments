import Foundation

struct WorldPoint: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double = 1
}

enum TileKind: Equatable, Sendable {
    case floor, start, destination, switchTile(Int), pivot(Int)
}

struct Tile: Identifiable, Sendable {
    let id: Int
    let name: String
    let point: WorldPoint
    let kind: TileKind
}

struct Walkway: Sendable {
    let from: Int
    let to: Int
    var requiredSwitches: Int = 0
}

struct Mechanism: Sendable {
    let name: String
    let center: Int
    let docks: [Int]
    var elbow = false
    var requiredSwitches = 0

    func connectedDocks(orientation: Int) -> [Int] {
        [docks[orientation % 4], docks[(orientation + (elbow ? 1 : 2)) % 4]]
    }
}

struct PuzzleState: Codable, Hashable, Sendable {
    var tile: Int
    var orientations: [Int]
    var switches: Int = 0
    var moves: Int = 0

    var searchKey: SearchKey {
        SearchKey(tile: tile, orientations: orientations, switches: switches)
    }
}

struct SearchKey: Hashable {
    let tile: Int
    let orientations: [Int]
    let switches: Int
}

enum PuzzleAction: Equatable {
    case walk(Int)
    case rotate(Int)
}

struct Chapter: Identifiable, Sendable {
    let id: Int
    let title: String
    let subtitle: String
    let letter: String
    let hint: String
    let tiles: [Tile]
    let walkways: [Walkway]
    let mechanisms: [Mechanism]
    let start: Int
    let destination: Int
    let requiredSwitches: Int
    let initialOrientations: [Int]

    var initialState: PuzzleState {
        PuzzleState(tile: start, orientations: initialOrientations)
    }

    func hasArrived(_ state: PuzzleState) -> Bool {
        state.tile == destination && state.switches & requiredSwitches == requiredSwitches
    }

    func canRotate(_ index: Int, state: PuzzleState) -> Bool {
        mechanisms.indices.contains(index)
            && state.switches & mechanisms[index].requiredSwitches == mechanisms[index].requiredSwitches
            && !hasArrived(state)
    }

    func connections(_ state: PuzzleState) -> [Walkway] {
        var result = walkways.filter { state.switches & $0.requiredSwitches == $0.requiredSwitches }
        for (index, mechanism) in mechanisms.enumerated() {
            for dock in mechanism.connectedDocks(orientation: state.orientations[index]) {
                result.append(Walkway(from: mechanism.center, to: dock))
            }
        }
        if state.switches & requiredSwitches != requiredSwitches {
            result.removeAll { $0.from == destination || $0.to == destination }
        }
        return result
    }

    func neighbors(of tile: Int, state: PuzzleState) -> [Int] {
        connections(state).compactMap {
            if $0.from == tile {
                return $0.to
            }
            if $0.to == tile {
                return $0.from
            }
            return nil
        }.sorted()
    }

    func applying(_ action: PuzzleAction, to state: PuzzleState) -> PuzzleState? {
        guard !hasArrived(state) else { return nil }
        var next = state
        switch action {
        case let .walk(tile):
            guard neighbors(of: state.tile, state: state).contains(tile) else { return nil }
            next.tile = tile
            if case let .switchTile(bit) = tiles[tile].kind {
                next.switches |= 1 << bit
            }
        case let .rotate(index):
            guard canRotate(index, state: state) else { return nil }
            next.orientations[index] = (next.orientations[index] + 1) % 4
        }
        next.moves += 1
        return next
    }

    func path(to target: Int, state: PuzzleState) -> [Int]? {
        guard tiles.indices.contains(target), !hasArrived(state) else { return nil }
        if target == state.tile {
            return []
        }
        var queue: [(Int, [Int])] = [(state.tile, [])]
        var visited: Set<Int> = [state.tile]
        var cursor = 0
        while cursor < queue.count {
            let (tile, path) = queue[cursor]
            cursor += 1
            for neighbor in neighbors(of: tile, state: state) where !visited.contains(neighbor) {
                let nextPath = path + [neighbor]
                if neighbor == target {
                    return nextPath
                }
                visited.insert(neighbor)
                queue.append((neighbor, nextPath))
            }
        }
        return nil
    }

    func shortestSolution(from initial: PuzzleState? = nil) -> [PuzzleAction]? {
        let startState = initial ?? initialState
        var queue: [(PuzzleState, [PuzzleAction])] = [(startState, [])]
        var visited: Set<SearchKey> = [startState.searchKey]
        var cursor = 0
        while cursor < queue.count {
            let (state, actions) = queue[cursor]
            cursor += 1
            if hasArrived(state) {
                return actions
            }
            let options = neighbors(of: state.tile, state: state).map(PuzzleAction.walk)
                + mechanisms.indices.map(PuzzleAction.rotate)
            for action in options {
                guard let next = applying(action, to: state),
                      visited.insert(next.searchKey).inserted else { continue }
                queue.append((next, actions + [action]))
            }
        }
        return nil
    }

    func isValid(_ state: PuzzleState) -> Bool {
        tiles.indices.contains(state.tile)
            && state.orientations.count == mechanisms.count
            && state.orientations.allSatisfy { (0 ... 3).contains($0) }
            && state.switches >= 0 && state.switches & ~requiredSwitches == 0
            && state.moves >= 0
    }
}

enum Chapters {
    static let all: [Chapter] = [
        Chapter(
            id: 0, title: "The Quiet Crossing", subtitle: "A small change in perspective.",
            letter: "I found a bridge that remembered\nanother way to be.",
            hint: "Walk onto the round bridge. Turn to reach the sun seal. Return to the round bridge, then turn again to reach the arch.",
            tiles: [
                Tile(id: 0, name: "Arrival steps", point: WorldPoint(x: -3.5, y: 0, z: 0.4), kind: .start),
                Tile(id: 1, name: "West landing", point: WorldPoint(x: -2, y: 0), kind: .floor),
                Tile(id: 2, name: "Turning bridge", point: WorldPoint(x: 0, y: 0), kind: .pivot(0)),
                Tile(id: 3, name: "Sun terrace", point: WorldPoint(x: 0, y: -2), kind: .switchTile(0)),
                Tile(id: 4, name: "East landing", point: WorldPoint(x: 2, y: 0), kind: .floor),
                Tile(id: 5, name: "Quiet balcony", point: WorldPoint(x: 0, y: 2), kind: .floor),
                Tile(id: 6, name: "The ivory arch", point: WorldPoint(x: 3.5, y: 0, z: 1.8), kind: .destination),
            ],
            walkways: [Walkway(from: 0, to: 1), Walkway(from: 4, to: 6)],
            mechanisms: [Mechanism(name: "The crossing", center: 2, docks: [3, 4, 5, 1])],
            start: 0, destination: 6, requiredSwitches: 1, initialOrientations: [1]
        ),
        Chapter(
            id: 1, title: "Garden of Angles", subtitle: "Every corner holds a possibility.",
            letter: "The garden did not move.\nOnly the way I saw it.",
            hint: "The coral bridge turns a corner. Visit both sun seals before climbing to the garden gate.",
            tiles: [
                Tile(id: 0, name: "Garden steps", point: WorldPoint(x: -3.5, y: 0, z: 0.4), kind: .start),
                Tile(id: 1, name: "West landing", point: WorldPoint(x: -2, y: 0), kind: .floor),
                Tile(id: 2, name: "Corner bridge", point: WorldPoint(x: 0, y: 0), kind: .pivot(0)),
                Tile(id: 3, name: "First sun terrace", point: WorldPoint(x: 0, y: -2), kind: .switchTile(0)),
                Tile(id: 4, name: "East landing", point: WorldPoint(x: 2, y: 0), kind: .floor),
                Tile(id: 5, name: "Second sun terrace", point: WorldPoint(x: 0, y: 2), kind: .switchTile(1)),
                Tile(id: 6, name: "Garden gate", point: WorldPoint(x: 3.5, y: 0, z: 2), kind: .destination),
            ],
            walkways: [Walkway(from: 0, to: 1), Walkway(from: 4, to: 6)],
            mechanisms: [Mechanism(name: "The corner", center: 2, docks: [3, 4, 5, 1], elbow: true)],
            start: 0, destination: 6, requiredSwitches: 3, initialOrientations: [2]
        ),
        Chapter(
            id: 2, title: "Two Skies", subtitle: "One world opens another.",
            letter: "Between two skies,\nI learned to take the long way home.",
            hint: "The first sun seal releases the upper bridge. Cross the middle stair, then find the second seal.",
            tiles: [
                Tile(id: 0, name: "Low steps", point: WorldPoint(x: -5.5, y: 0, z: 0.4), kind: .start),
                Tile(id: 1, name: "Lower west landing", point: WorldPoint(x: -4, y: 0), kind: .floor),
                Tile(id: 2, name: "Lower bridge", point: WorldPoint(x: -2, y: 0), kind: .pivot(0)),
                Tile(id: 3, name: "Lower sun terrace", point: WorldPoint(x: -2, y: -2), kind: .switchTile(0)),
                Tile(id: 4, name: "Middle stair", point: WorldPoint(x: 0, y: 0, z: 1.5), kind: .floor),
                Tile(id: 5, name: "Lower balcony", point: WorldPoint(x: -2, y: 2), kind: .floor),
                Tile(id: 6, name: "Upper bridge", point: WorldPoint(x: 2, y: 0, z: 2), kind: .pivot(1)),
                Tile(id: 7, name: "Upper sun terrace", point: WorldPoint(x: 2, y: -2, z: 2), kind: .switchTile(1)),
                Tile(id: 8, name: "Upper east landing", point: WorldPoint(x: 4, y: 0, z: 2), kind: .floor),
                Tile(id: 9, name: "Upper balcony", point: WorldPoint(x: 2, y: 2, z: 2), kind: .floor),
                Tile(id: 10, name: "Sky gate", point: WorldPoint(x: 5.5, y: 0, z: 2.7), kind: .destination),
            ],
            walkways: [Walkway(from: 0, to: 1), Walkway(from: 8, to: 10)],
            mechanisms: [
                Mechanism(name: "Lower sky", center: 2, docks: [3, 4, 5, 1], elbow: true),
                Mechanism(name: "Upper sky", center: 6, docks: [7, 8, 9, 4], requiredSwitches: 1),
            ],
            start: 0, destination: 10, requiredSwitches: 3, initialOrientations: [3, 0]
        ),
        Chapter(
            id: 3, title: "The Last Light", subtitle: "Carry a little wonder home.",
            letter: "At the edge of the evening,\nevery impossible road led home.",
            hint: "Three seals light the final arch. The lower seal wakes the far bridge; its two terraces hold the rest.",
            tiles: [
                Tile(id: 0, name: "Evening steps", point: WorldPoint(x: -5.5, y: 0, z: 0.4), kind: .start),
                Tile(id: 1, name: "West landing", point: WorldPoint(x: -4, y: 0), kind: .floor),
                Tile(id: 2, name: "Evening bridge", point: WorldPoint(x: -2, y: 0), kind: .pivot(0)),
                Tile(id: 3, name: "Quiet overlook", point: WorldPoint(x: -2, y: -2), kind: .floor),
                Tile(id: 4, name: "Moon stair", point: WorldPoint(x: 0, y: 0, z: 1.6), kind: .floor),
                Tile(id: 5, name: "First light", point: WorldPoint(x: -2, y: 2), kind: .switchTile(0)),
                Tile(id: 6, name: "Moon bridge", point: WorldPoint(x: 2, y: 0, z: 2.2), kind: .pivot(1)),
                Tile(id: 7, name: "Second light", point: WorldPoint(x: 2, y: -2, z: 2.2), kind: .switchTile(1)),
                Tile(id: 8, name: "Last landing", point: WorldPoint(x: 4, y: 0, z: 2.2), kind: .floor),
                Tile(id: 9, name: "Third light", point: WorldPoint(x: 2, y: 2, z: 2.2), kind: .switchTile(2)),
                Tile(id: 10, name: "Home", point: WorldPoint(x: 5.5, y: 0, z: 3), kind: .destination),
            ],
            walkways: [Walkway(from: 0, to: 1), Walkway(from: 8, to: 10)],
            mechanisms: [
                Mechanism(name: "Evening", center: 2, docks: [3, 4, 5, 1]),
                Mechanism(name: "Moonlight", center: 6, docks: [7, 8, 9, 4], elbow: true, requiredSwitches: 1),
            ],
            start: 0, destination: 10, requiredSwitches: 7, initialOrientations: [0, 1]
        ),
    ]
}
