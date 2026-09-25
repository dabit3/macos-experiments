import CoreGraphics
import Foundation

enum SVGExporter {
  static func number(_ value: CGFloat) -> String {
    String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(value))
  }

  static func escape(_ value: String) -> String {
    value.replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&apos;")
  }

  static func wrappedLines(_ text: String, width: CGFloat, fontSize: CGFloat) -> [String] {
    let limit = max(4, Int(width / (fontSize * 0.54)))
    return text.components(separatedBy: "\n").flatMap { paragraph -> [String] in
      var result: [String] = []
      var line = ""
      for word in paragraph.components(separatedBy: " ") {
        if line.count + word.count + 1 > limit && !line.isEmpty {
          result.append(line)
          line = ""
        }
        line += (line.isEmpty ? "" : " ") + word
      }
      result.append(line)
      return result
    }
  }

  static func export(_ board: Board) -> String {
    let bounds =
      board.elements.isEmpty
      ? CGRect(x: 0, y: 0, width: 1000, height: 750)
      : board.contentBounds.insetBy(dx: -55, dy: -55)
    var svg = """
      <?xml version="1.0" encoding="UTF-8"?>
      <svg xmlns="http://www.w3.org/2000/svg" width="\(number(bounds.width))" height="\(number(bounds.height))" viewBox="\(number(bounds.minX)) \(number(bounds.minY)) \(number(bounds.width)) \(number(bounds.height))">
      <title>\(escape(board.title))</title>
      <desc>Created with Ink Atlas. Editable vector board.</desc>
      <rect x="\(number(bounds.minX))" y="\(number(bounds.minY))" width="\(number(bounds.width))" height="\(number(bounds.height))" fill="#F8F5ED"/>
      """
    for connection in board.connections {
      guard let (start, end) = board.endpoints(for: connection) else { continue }
      let angle = atan2(end.y - start.y, end.x - start.x)
      let a = CGPoint(x: end.x - cos(angle - 0.45) * 12, y: end.y - sin(angle - 0.45) * 12)
      let b = CGPoint(x: end.x - cos(angle + 0.45) * 12, y: end.y - sin(angle + 0.45) * 12)
      svg += """
        <g fill="none" stroke="\(connection.tone.line)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M\(number(start.x)),\(number(start.y)) L\(number(end.x)),\(number(end.y))"/>
        <path d="M\(number(a.x)),\(number(a.y)) L\(number(end.x)),\(number(end.y)) L\(number(b.x)),\(number(b.y))"/>
        </g>
        """
    }
    for item in board.elements {
      let r = item.frame
      if item.kind == .stroke {
        let points = item.points.map {
          "\(number(r.minX + $0.x * r.width)),\(number(r.minY + $0.y * r.height))"
        }.joined(separator: " ")
        svg += """
          <polyline points="\(points)" fill="none" stroke="\(item.tone.line)" stroke-width="\(number(item.lineWidth))" stroke-linecap="round" stroke-linejoin="round"/>
          """
        if item.points.count == 1, let point = item.points.first {
          svg += """
            <circle cx="\(number(r.minX + point.x * r.width))" cy="\(number(r.minY + point.y * r.height))" r="\(number(item.lineWidth / 2))" fill="\(item.tone.line)"/>
            """
        }
        continue
      }
      if item.kind == .ellipse {
        svg += """
          <ellipse cx="\(number(r.midX))" cy="\(number(r.midY))" rx="\(number(r.width / 2))" ry="\(number(r.height / 2))" fill="\(item.tone.fill)" stroke="\(item.tone.line)" stroke-opacity="0.18"/>
          """
      } else if item.kind == .card {
        svg += """
          <rect x="\(number(r.minX))" y="\(number(r.minY))" width="\(number(r.width))" height="\(number(r.height))" rx="12" fill="\(item.tone.fill)" stroke="\(item.tone.line)" stroke-opacity="0.18"/>
          """
      }
      let isText = item.kind == .text
      let fontSize: CGFloat = isText ? (r.width > 400 ? 44 : 22) : 22
      let color = item.tone == .ink && !isText ? "#FFFEF9" : item.tone.line
      let inset: CGFloat = isText ? 0 : 22
      let centered = item.kind == .ellipse
      let lines = wrappedLines(item.text, width: r.width - inset * 2, fontSize: fontSize)
      var y =
        centered
        ? r.midY - CGFloat(lines.count) * fontSize * 0.62 + fontSize : r.minY + inset + fontSize
      let x = centered ? r.midX : r.minX + inset
      svg += """
        <clipPath id="clip-\(item.id.uuidString)"><rect x="\(number(r.minX))" y="\(number(r.minY))" width="\(number(r.width))" height="\(number(r.height))"/></clipPath>
        <g clip-path="url(#clip-\(item.id.uuidString))" fill="\(color)" font-family="\(isText ? "Georgia, serif" : "-apple-system, Helvetica, sans-serif")">
        """
      for line in lines {
        svg += """
          <text x="\(number(x))" y="\(number(y))" font-size="\(number(fontSize))" font-weight="\(isText ? "400" : "600")" text-anchor="\(centered ? "middle" : "start")">\(escape(line))</text>
          """
        y += fontSize * 1.24
      }
      if !item.detail.isEmpty {
        y += isText ? 3 : 9
        for line in wrappedLines(
          item.detail, width: r.width - inset * 2, fontSize: isText ? 12 : 15)
        {
          svg += """
            <text x="\(number(x))" y="\(number(y))" font-family="-apple-system, Helvetica, sans-serif" font-size="\(isText ? "12" : "15")" opacity="0.78">\(escape(line))</text>
            """
          y += isText ? 17 : 23
        }
      }
      svg += "</g>"
    }
    return svg + "</svg>"
  }
}
