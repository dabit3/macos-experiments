import CourtCore
import SwiftUI

struct PieceGlyph: View {
    let piece: Piece
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 100, y: size.height / 100)
            let white = piece.side == .white
            let fill = white ? Color(hex: 0xFFF9E6) : Color(hex: 0x233B70)
            let ink = white ? Color(hex: 0x485984) : Color(hex: 0x091737)
            let detail = white ? ink : Color(hex: 0xFFF9E6).opacity(0.55)
            let path = Self.bodies[piece.kind] ?? Path()
            context.drawLayer { shadow in
                shadow.addFilter(.blur(radius: 1.6)); shadow.translateBy(x: 0, y: 1.5)
                shadow.fill(path, with: .color(Arcade.midnight.opacity(0.28)))
            }
            context.fill(path, with: .linearGradient(
                Gradient(colors: [white ? .white : Color(hex: 0x657594), fill, white ? Color(hex: 0xD7D6D0) : Color(hex: 0x172B57)]),
                startPoint: CGPoint(x: 20, y: 10), endPoint: CGPoint(x: 85, y: 95)
            ))
            context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))
            func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, width: CGFloat = 2) {
                var p = Path(); p.move(to: CGPoint(x: x1, y: y1)); p.addLine(to: CGPoint(x: x2, y: y2))
                context.stroke(p, with: .color(detail), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            switch piece.kind {
            case .pawn: line(32, 76, 68, 76)
            case .rook: line(30, 43, 70, 43); line(34, 76, 66, 76); line(38, 50, 62, 50, width: 1.4)
            case .knight:
                context.fill(Path(ellipseIn: CGRect(x: 34.4, y: 29.4, width: 5.2, height: 5.2)), with: .color(ink))
                context.fill(Path(ellipseIn: CGRect(x: 21.4, y: 47.4, width: 3.2, height: 3.2)), with: .color(ink))
                line(46, 30, 64, 46, width: 1.8); line(30, 76, 70, 76)
            case .bishop: line(53, 28, 61, 44, width: 3); line(36, 68, 64, 68); line(30, 76, 70, 76)
            case .queen: line(36, 59, 64, 59); line(30, 76, 70, 76)
            case .king: line(36, 59, 64, 59); line(30, 76, 70, 76); line(50, 36, 50, 52, width: 1.8)
            }
        }
        .accessibilityLabel("\(piece.side.label) \(piece.kind.label)")
    }

    private static let bodies: [PieceKind: Path] = Dictionary(uniqueKeysWithValues: PieceKind.allCases.map { ($0, bodyPath($0)) })
    private static func bodyPath(_ kind: PieceKind) -> Path {
        var result = Path()
        func add(_ path: Path) {
            result = result.union(path)
        }
        func rectangle(_ left: CGFloat, _ top: CGFloat, _ right: CGFloat, _ bottom: CGFloat, _ radius: CGFloat = 0) {
            add(Path(roundedRect: CGRect(x: left, y: top, width: right - left, height: bottom - top),
                     cornerRadius: radius))
        }
        func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) {
            add(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)))
        }
        func polygon(_ points: [(CGFloat, CGFloat)]) {
            var path = Path(); path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) }); path.closeSubpath(); add(path)
        }
        switch kind {
        case .pawn:
            circle(50, 29, 11.5); rectangle(36, 41, 64, 48, 3)
            var p = Path(); p.move(to: CGPoint(x: 41.5, y: 47))
            p.addCurve(to: CGPoint(x: 30, y: 77), control1: CGPoint(x: 41, y: 58), control2: CGPoint(x: 36, y: 66))
            p.addLine(to: CGPoint(x: 70, y: 77))
            p.addCurve(to: CGPoint(x: 58.5, y: 47), control1: CGPoint(x: 64, y: 66), control2: CGPoint(x: 59, y: 58))
            p.closeSubpath(); add(p); rectangle(25, 76, 75, 88, 4)
        case .rook:
            rectangle(22, 77, 78, 88, 4); polygon([(31, 42), (69, 42), (66, 77), (34, 77)])
            rectangle(27, 33, 73, 43, 2); rectangle(27, 18, 38, 34)
            rectangle(44.5, 18, 55.5, 34); rectangle(62, 18, 73, 34)
        case .knight:
            var p = Path(); p.move(to: CGPoint(x: 27, y: 77)); p.addLine(to: CGPoint(x: 73, y: 77)); p.addLine(to: CGPoint(x: 72, y: 62))
            p.addCurve(to: CGPoint(x: 58, y: 22), control1: CGPoint(x: 74, y: 46), control2: CGPoint(x: 70, y: 30))
            for point in [(56.0, 10.0), (49, 19), (43, 9), (40, 20)] {
                p.addLine(to: CGPoint(x: point.0, y: point.1))
            }
            p.addCurve(to: CGPoint(x: 19, y: 46), control1: CGPoint(x: 30, y: 24), control2: CGPoint(x: 22, y: 34))
            p.addLine(to: CGPoint(x: 16, y: 52))
            p.addCurve(to: CGPoint(x: 25, y: 57), control1: CGPoint(x: 16, y: 56), control2: CGPoint(x: 20, y: 58))
            p.addLine(to: CGPoint(x: 31, y: 54))
            p.addCurve(to: CGPoint(x: 40, y: 70), control1: CGPoint(x: 37, y: 58), control2: CGPoint(x: 42, y: 64))
            p.addCurve(to: CGPoint(x: 27, y: 77), control1: CGPoint(x: 38, y: 74), control2: CGPoint(x: 32, y: 76))
            p.closeSubpath(); add(p); rectangle(22, 77, 78, 88, 4)
        case .bishop:
            circle(50, 14, 5.5)
            var p = Path(); p.move(to: CGPoint(x: 50, y: 19))
            p.addCurve(to: CGPoint(x: 50, y: 63), control1: CGPoint(x: 73, y: 33), control2: CGPoint(x: 73, y: 56))
            p.addCurve(to: CGPoint(x: 50, y: 19), control1: CGPoint(x: 27, y: 56), control2: CGPoint(x: 27, y: 33))
            p.closeSubpath(); add(p); rectangle(35, 61, 65, 69, 3)
            polygon([(40, 69), (60, 69), (66, 77), (34, 77)]); rectangle(24, 77, 76, 88, 4)
        case .queen, .king:
            rectangle(22, 77, 78, 88, 4); polygon([(32, 77), (68, 77), (64, 57), (36, 57)])
            rectangle(33, 53, 67, 60, 3)
            if kind == .queen {
                polygon([(35, 55), (23, 28), (33.5, 43), (37, 17), (44.5, 40), (50, 13), (55.5, 40), (63, 17), (66.5, 43), (77, 28), (65, 55)])
                for (x, y): (CGFloat, CGFloat) in [(23, 26), (37, 15), (50, 11), (63, 15), (77, 26)] {
                    circle(x, y, 3.6)
                }
            } else {
                var p = Path(); p.move(to: CGPoint(x: 36, y: 55))
                p.addCurve(to: CGPoint(x: 42, y: 30), control1: CGPoint(x: 24, y: 44), control2: CGPoint(x: 28, y: 28))
                p.addLine(to: CGPoint(x: 58, y: 30))
                p.addCurve(to: CGPoint(x: 64, y: 55), control1: CGPoint(x: 72, y: 28), control2: CGPoint(x: 76, y: 44))
                p.closeSubpath(); add(p); rectangle(47, 8, 53, 31, 1.5); rectangle(41, 14, 59, 20, 1.5)
            }
        }
        return result
    }
}
