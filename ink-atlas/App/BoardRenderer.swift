import UIKit

extension UIColor {
  convenience init(hex: String) {
    let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
    self.init(
      red: CGFloat((value >> 16) & 255) / 255,
      green: CGFloat((value >> 8) & 255) / 255,
      blue: CGFloat(value & 255) / 255, alpha: 1)
  }
}

enum BoardRenderer {
  static let paper = UIColor(hex: "#F8F5ED")
  static let ink = UIColor(hex: "#244858")

  static func draw(_ board: Board, in context: CGContext) {
    for connection in board.connections {
      guard let (start, end) = board.endpoints(for: connection) else { continue }
      line(from: start, to: end, color: UIColor(hex: connection.tone.line), in: context)
    }
    for element in board.elements { draw(element, in: context) }
  }

  static func line(from start: CGPoint, to end: CGPoint, color: UIColor, in context: CGContext) {
    context.saveGState()
    context.setStrokeColor(color.withAlphaComponent(0.62).cgColor)
    context.setLineWidth(1.8)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: start)
    context.addLine(to: end)
    let angle = atan2(end.y - start.y, end.x - start.x)
    context.move(to: CGPoint(x: end.x - cos(angle - 0.45) * 11, y: end.y - sin(angle - 0.45) * 11))
    context.addLine(to: end)
    context.addLine(
      to: CGPoint(x: end.x - cos(angle + 0.45) * 11, y: end.y - sin(angle + 0.45) * 11))
    context.strokePath()
    context.restoreGState()
  }

  static func draw(_ element: BoardElement, in context: CGContext) {
    context.saveGState()
    let r = element.frame
    if element.kind == .stroke {
      context.setStrokeColor(UIColor(hex: element.tone.line).cgColor)
      context.setLineWidth(element.lineWidth)
      context.setLineCap(.round)
      context.setLineJoin(.round)
      for (index, point) in element.points.enumerated() {
        let p = CGPoint(x: r.minX + point.x * r.width, y: r.minY + point.y * r.height)
        if index == 0 { context.move(to: p) } else { context.addLine(to: p) }
      }
      context.strokePath()
      if element.points.count == 1, let point = element.points.first {
        context.setFillColor(UIColor(hex: element.tone.line).cgColor)
        context.fillEllipse(
          in: CGRect(
            x: r.minX + point.x * r.width - element.lineWidth / 2,
            y: r.minY + point.y * r.height - element.lineWidth / 2,
            width: element.lineWidth, height: element.lineWidth))
      }
      context.restoreGState()
      return
    }
    let isText = element.kind == .text
    if !isText {
      let path =
        element.kind == .ellipse
        ? UIBezierPath(ovalIn: r)
        : UIBezierPath(roundedRect: r, cornerRadius: 13)
      context.saveGState()
      context.setShadow(
        offset: CGSize(width: 0, height: 5), blur: 12, color: ink.withAlphaComponent(0.075).cgColor)
      UIColor(hex: element.tone.fill).setFill()
      path.fill()
      context.restoreGState()
      UIColor(hex: element.tone.line).withAlphaComponent(0.15).setStroke()
      path.lineWidth = 1
      path.stroke()
      if element.kind == .card {
        let dot = CGRect(x: r.minX + 21, y: r.minY + 18, width: 5, height: 5)
        context.setFillColor(
          UIColor(hex: element.tone.line).withAlphaComponent(element.tone == .ink ? 0.0 : 0.35)
            .cgColor)
        context.fillEllipse(in: dot)
      }
    }
    context.clip(to: r)
    let color =
      element.tone == .ink && !isText ? UIColor(hex: "#FFFEF9") : UIColor(hex: element.tone.line)
    let fontSize: CGFloat = isText ? (r.width > 400 ? 44 : 22) : 22
    let font =
      isText
      ? UIFont(name: "Georgia", size: fontSize) ?? .systemFont(ofSize: fontSize)
      : UIFont.systemFont(ofSize: fontSize, weight: .semibold)
    let centered = element.kind == .ellipse
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = centered ? .center : .left
    paragraph.lineSpacing = 3
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
      .kern: isText ? -0.9 : -0.4,
    ]
    let inset: CGFloat = isText ? 0 : 22
    let width = r.width - inset * 2
    let textHeight = (element.text as NSString).boundingRect(
      with: CGSize(width: width, height: 1000),
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: attributes, context: nil
    ).height
    let y = centered ? r.midY - textHeight / 2 : r.minY + (isText ? 0 : 33)
    (element.text as NSString).draw(
      with: CGRect(x: r.minX + inset, y: y, width: width, height: min(textHeight + 3, r.height)),
      options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    if !element.detail.isEmpty {
      let style = NSMutableParagraphStyle()
      style.lineSpacing = isText ? 3 : 6
      let detailAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: isText ? 11 : 15, weight: isText ? .medium : .regular),
        .foregroundColor: color.withAlphaComponent(0.76),
        .paragraphStyle: style, .kern: isText ? 1.5 : 0,
      ]
      let detailY = y + textHeight + (isText ? 12 : 10)
      (element.detail as NSString).draw(
        with: CGRect(
          x: r.minX + inset, y: detailY, width: width, height: max(0, r.maxY - detailY - 12)),
        options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: detailAttributes,
        context: nil)
    }
    context.restoreGState()
  }

  static func pdf(_ board: Board) -> Data {
    let content =
      board.elements.isEmpty
      ? CGRect(x: 0, y: 0, width: 1000, height: 750)
      : board.contentBounds.insetBy(dx: -55, dy: -55)
    let format = UIGraphicsPDFRendererFormat()
    format.documentInfo = [
      kCGPDFContextTitle as String: board.title, kCGPDFContextCreator as String: "Ink Atlas",
    ]
    let renderer = UIGraphicsPDFRenderer(
      bounds: CGRect(origin: .zero, size: content.size), format: format)
    return renderer.pdfData { rendererContext in
      rendererContext.beginPage()
      let context = rendererContext.cgContext
      context.setFillColor(paper.cgColor)
      context.fill(CGRect(origin: .zero, size: content.size))
      context.translateBy(x: -content.minX, y: -content.minY)
      draw(board, in: context)
    }
  }

  static func thumbnail(_ board: Board) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 360))
    return renderer.image { rendererContext in
      let context = rendererContext.cgContext
      paper.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 500, height: 360))
      let bounds =
        board.elements.isEmpty
        ? CGRect(x: 0, y: 0, width: 1000, height: 750)
        : board.contentBounds.insetBy(dx: -50, dy: -50)
      let scale = min(500 / bounds.width, 360 / bounds.height)
      context.translateBy(x: (500 - bounds.width * scale) / 2, y: (360 - bounds.height * scale) / 2)
      context.scaleBy(x: scale, y: scale)
      context.translateBy(x: -bounds.minX, y: -bounds.minY)
      draw(board, in: context)
    }
  }
}
