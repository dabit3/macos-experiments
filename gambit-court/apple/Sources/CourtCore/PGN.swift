import Foundation

public struct PGN: Sendable {
    public var tags: [String: String]
    public var start: Position
    public var moves: [PlayedMove]
    public var warning: String?
    public init(start: Position, moves: [PlayedMove], tags: [String: String]) {
        self.start = start; self.moves = moves; self.tags = tags
    }

    public init(text: String) throws {
        guard text.utf8.count <= 1_000_000 else { throw ChessError.invalidPGN("PGN must be smaller than 1 MB.") }
        let pattern = #"\[\s*(\w+)\s+"((?:[^"\\]|\\.)*)"\s*\]"#
        let regex = try NSRegularExpression(pattern: pattern)
        tags = [:]
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let key = Range(match.range(at: 1), in: text), let value = Range(match.range(at: 2), in: text) {
                tags[String(text[key])] = String(text[value]).replacingOccurrences(of: #"\""#, with: "\"")
                    .replacingOccurrences(of: #"\\"#, with: "\\")
            }
        }
        start = try Position(fen: tags["FEN"] ?? Position.startFen)
        moves = []
        let withoutTags = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        var rest = "", braces = 0, variations = 0, semicolon = false
        for char in withoutTags {
            if semicolon {
                if char == "\n" {
                    semicolon = false; rest += " "
                }; continue
            }
            if char == "{" {
                braces += 1; continue
            }
            if char == "}" {
                braces = max(0, braces - 1); rest += " "; continue
            }
            if braces > 0 {
                continue
            }
            if char == ";" {
                semicolon = true; continue
            }
            if char == "(" {
                variations += 1; continue
            }
            if char == ")" {
                variations = max(0, variations - 1); rest += " "; continue
            }
            if variations == 0 {
                rest.append(char)
            }
        }
        rest = rest.replacingOccurrences(of: #"\$\d+"#, with: " ", options: .regularExpression)
        var position = start
        for raw in rest.split(whereSeparator: \.isWhitespace) {
            let token = String(raw).replacingOccurrences(of: #"^\d+\.+"#, with: "", options: .regularExpression)
            if ["1-0", "0-1", "1/2-1/2", "½-½", "*"].contains(token) {
                tags["Result"] = token.replacingOccurrences(of: "½", with: "1/2"); break
            }
            if token.isEmpty || token.allSatisfy({ $0 == "." }) || token == "e.p." {
                continue
            }
            guard moves.count < 10000 else { warning = "Stopped after 10,000 plies."; break }
            guard let move = position.parseSAN(token) else {
                warning = "Illegal or unreadable move “\(token)” at ply \(moves.count + 1)."; break
            }
            let san = position.san(move)
            position = position.applying(move)
            moves.append(PlayedMove(uci: move.uci, san: san, fen: position.fen))
        }
        guard !moves.isEmpty || !tags.isEmpty else { throw ChessError.invalidPGN(warning ?? "No PGN game found.") }
    }

    public var text: String {
        var roster = ["Event": "Gambit Court game", "Site": "Gambit Court", "Date": "????.??.??",
                      "Round": "-", "White": "White", "Black": "Black", "Result": "*"]
        roster.merge(tags) { _, value in value }
        if start.fen != Position.startFen {
            roster["SetUp"] = "1"; roster["FEN"] = start.fen
        }
        var output = roster.keys.sorted().map { key in
            let value = (roster[key] ?? "").replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            return "[\(key) \"\(value)\"]"
        }.joined(separator: "\n") + "\n\n"
        var number = start.fullmove, side = start.turn, tokens: [String] = []
        for (index, move) in moves.enumerated() {
            if side == .white {
                tokens.append("\(number).")
            } else if index == 0 {
                tokens.append("\(number)...")
            }
            tokens.append(move.san)
            if side == .black {
                number += 1
            }
            side = side.opposite
        }
        tokens.append(roster["Result"] ?? "*")
        var length = 0
        for token in tokens {
            if length + token.count > 78 {
                output += "\n"; length = 0
            }
            output += token + " "; length += token.count + 1
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
}
