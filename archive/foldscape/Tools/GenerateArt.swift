import AppKit
import CoreGraphics
import Foundation

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
  CGColor(
    red: CGFloat((hex >> 16) & 255) / 255,
    green: CGFloat((hex >> 8) & 255) / 255,
    blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

struct Grain {
  var state: UInt64 = 7831
  mutating func next() -> CGFloat {
    state = state &* 6_364_136_223_846_793_005 &+ 1
    return CGFloat(state >> 33) / CGFloat(UInt32.max >> 1)
  }
}

final class PaperPainter {
  let context: CGContext

  init(size: Int) {
    context = CGContext(
      data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: CGFloat(size) / 1000, y: -CGFloat(size) / 1000)
  }

  func cut(_ path: CGPath, _ fill: UInt32, shadow: CGFloat = 10) {
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 4, height: -6), blur: shadow * 0.65,
      color: color(0x17242A, alpha: 0.20))
    context.addPath(path)
    context.setFillColor(color(fill))
    context.fillPath(using: .evenOdd)
    context.restoreGState()
    context.addPath(path)
    context.setStrokeColor(color(0xFFFFFF, alpha: 0.15))
    context.setLineWidth(1.8)
    context.strokePath()
  }

  func polygon(_ points: [(CGFloat, CGFloat)], _ fill: UInt32, shadow: CGFloat = 10) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: points[0].0, y: points[0].1))
    for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
    path.closeSubpath()
    cut(path, fill, shadow: shadow)
  }

  func ellipse(
    _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: UInt32, shadow: CGFloat = 8
  ) {
    cut(
      CGPath(ellipseIn: CGRect(x: x, y: y, width: w, height: h), transform: nil), fill,
      shadow: shadow)
  }

  func hill(_ y: CGFloat, _ bend: CGFloat, _ fill: UInt32) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: -80, y: y))
    path.addCurve(
      to: CGPoint(x: 1100, y: y + bend / 3),
      control1: CGPoint(x: 220, y: y - bend),
      control2: CGPoint(x: 530, y: y + bend))
    path.addLine(to: CGPoint(x: 1100, y: 1100))
    path.addLine(to: CGPoint(x: -80, y: 1100))
    path.closeSubpath()
    cut(path, fill)
  }

  func cloud(_ x: CGFloat, _ y: CGFloat, _ scale: CGFloat, _ fill: UInt32 = 0xF7F1DD) {
    context.saveGState()
    context.translateBy(x: x, y: y)
    context.scaleBy(x: scale, y: scale)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: 42))
    path.addCurve(
      to: CGPoint(x: 52, y: 18), control1: CGPoint(x: 10, y: 16), control2: CGPoint(x: 27, y: 7))
    path.addCurve(
      to: CGPoint(x: 123, y: 14), control1: CGPoint(x: 63, y: -20), control2: CGPoint(x: 115, y: -9)
    )
    path.addCurve(
      to: CGPoint(x: 178, y: 43), control1: CGPoint(x: 154, y: 5), control2: CGPoint(x: 169, y: 22))
    path.closeSubpath()
    cut(path, fill, shadow: 5)
    context.restoreGState()
  }

  func pine(_ x: CGFloat, _ y: CGFloat, _ height: CGFloat, _ fill: UInt32) {
    polygon(
      [(x - 5, y), (x + 6, y), (x + 3, y - height * 0.65), (x - 2, y - height * 0.65)],
      0x485446, shadow: 3)
    let width = height * (0.25 + abs(sin(x)) * 0.05)
    let top = y - height
    let lean = sin(x * 0.12) * height * 0.035
    let outline: [(CGFloat, CGFloat)] = [
      (x + lean, top),
      (x + width * 0.48, top + height * 0.28),
      (x + width * 0.22, top + height * 0.25),
      (x + width * 0.71, top + height * 0.46),
      (x + width * 0.38, top + height * 0.42),
      (x + width * 0.88, top + height * 0.63),
      (x + width * 0.52, top + height * 0.59),
      (x + width, top + height * 0.83),
      (x - width * 0.95, top + height * 0.84),
      (x - width * 0.46, top + height * 0.60),
      (x - width * 0.85, top + height * 0.65),
      (x - width * 0.32, top + height * 0.44),
      (x - width * 0.68, top + height * 0.49),
      (x - width * 0.15, top + height * 0.27),
      (x - width * 0.46, top + height * 0.30),
    ]
    polygon(outline, fill, shadow: 7)
    context.saveGState()
    let fold = CGMutablePath()
    fold.move(to: CGPoint(x: x + lean, y: top))
    for point in outline[1...7] {
      fold.addLine(to: CGPoint(x: point.0, y: point.1))
    }
    fold.addLine(to: CGPoint(x: x + 1, y: top + height * 0.837))
    fold.closeSubpath()
    context.addPath(fold)
    context.setFillColor(color(0x112D28, alpha: 0.13))
    context.fillPath()
    context.move(to: CGPoint(x: x + lean, y: top + 3))
    context.addLine(to: CGPoint(x: x, y: top + height * 0.83))
    context.setLineWidth(1.2)
    context.setStrokeColor(color(0xF7ECCE, alpha: 0.25))
    context.strokePath()
    context.restoreGState()
  }

  func grasses(_ x: CGFloat, _ y: CGFloat, _ fill: UInt32) {
    for i in -2...2 {
      let offset = CGFloat(i) * 9
      polygon([(x - 2, y), (x + offset, y - 45 + abs(offset)), (x + 3, y)], fill, shadow: 2)
    }
  }

  func draw(_ id: String) {
    switch id {
    case "mosslight":
      polygon([(0, 0), (1000, 0), (1000, 1000), (0, 1000)], 0xDDE6D4, shadow: 0)
      ellipse(633, 120, 185, 185, 0xF4DDA0)
      cloud(114, 167, 1.0)
      cloud(432, 268, 0.65)
      hill(480, 230, 0xABC3AA)
      hill(550, -290, 0x7F9E88)
      for i in 0..<12 {
        pine(CGFloat(i) * 94, 646 + CGFloat(i % 3) * 12, 160 + CGFloat(i % 4) * 23, 0x527D68)
      }
      hill(730, 240, 0x3F705E)
      let river = CGMutablePath()
      river.move(to: CGPoint(x: 623, y: 543))
      river.addCurve(
        to: CGPoint(x: 645, y: 695), control1: CGPoint(x: 519, y: 652),
        control2: CGPoint(x: 763, y: 641))
      river.addCurve(
        to: CGPoint(x: 578, y: 853), control1: CGPoint(x: 390, y: 780),
        control2: CGPoint(x: 494, y: 794))
      river.addCurve(
        to: CGPoint(x: 386, y: 1030), control1: CGPoint(x: 759, y: 944),
        control2: CGPoint(x: 457, y: 969))
      river.addLine(to: CGPoint(x: 73, y: 1030))
      river.addCurve(
        to: CGPoint(x: 428, y: 851), control1: CGPoint(x: 247, y: 934),
        control2: CGPoint(x: 566, y: 905))
      river.addCurve(
        to: CGPoint(x: 577, y: 685), control1: CGPoint(x: 233, y: 777),
        control2: CGPoint(x: 558, y: 730))
      river.addCurve(
        to: CGPoint(x: 604, y: 543), control1: CGPoint(x: 684, y: 645),
        control2: CGPoint(x: 474, y: 654))
      river.closeSubpath()
      cut(river, 0xBCD6C3, shadow: 7)
      hill(910, -170, 0x285744)
      pine(125, 1030, 514, 0x234B3C)
      pine(882, 941, 329, 0x315944)
      pine(958, 1000, 423, 0x254B3C)
      grasses(750, 974, 0x89A583)
    case "coral-summit":
      polygon([(0, 0), (1000, 0), (1000, 1000), (0, 1000)], 0xF1DCC8, shadow: 0)
      ellipse(674, 104, 180, 180, 0xDB8B64)
      cloud(90, 200, 1.05, 0xFFF1D9)
      polygon(
        [
          (0, 650), (110, 389), (236, 531), (497, 168), (741, 491), (876, 330),
          (1100, 612), (1100, 1100), (0, 1100),
        ], 0xCF9C8B)
      polygon([(174, 641), (496, 167), (460, 474), (605, 772)], 0xB97C70)
      polygon([(390, 323), (497, 168), (612, 321), (537, 296), (501, 329), (465, 289)], 0xF9EAD5)
      polygon(
        [(-30, 860), (277, 454), (586, 819), (756, 465), (1070, 898), (1070, 1100), (-30, 1100)],
        0xBD6A5B)
      polygon([(279, 454), (324, 773), (586, 819)], 0x9C534E)
      polygon([(756, 465), (813, 840), (1070, 898)], 0xA3534C)
      polygon(
        [
          (665, 732), (620, 812), (467, 854), (568, 912), (456, 1000), (633, 1000),
          (698, 926), (611, 865), (711, 830),
        ], 0xEBC5AF)
      hill(989, 120, 0x814842)
      grasses(160, 952, 0xD9AE8A)
      cloud(680, 365, 0.7, 0xF4E3CE)
    case "indigo-tide":
      polygon([(0, 0), (1000, 0), (1000, 1000), (0, 1000)], 0xADB9CC, shadow: 0)
      ellipse(696, 121, 152, 152, 0xF0DDAF)
      cloud(365, 172, 0.9, 0xDCE0DC)
      cloud(128, 304, 0.6, 0xDCE0DC)
      hill(540, 115, 0x7B91AA)
      hill(617, -125, 0x566C94)
      hill(717, 170, 0x40577E)
      hill(820, -135, 0x30476A)
      hill(943, 110, 0x233A59)
      polygon(
        [
          (-50, 515), (233, 507), (344, 657), (329, 774), (455, 885), (423, 1000),
          (-50, 1000),
        ], 0x697B69)
      polygon(
        [
          (233, 507), (344, 657), (329, 774), (455, 885), (423, 1000), (206, 1000),
          (226, 740), (134, 652),
        ], 0x414F55)
      polygon([(109, 521), (128, 283), (214, 283), (234, 521)], 0xEDE6D2)
      polygon([(182, 284), (214, 283), (234, 521), (180, 521)], 0xC9C8BB)
      polygon([(110, 284), (235, 284), (210, 251), (136, 251)], 0x334F62)
      polygon([(128, 251), (214, 251), (214, 209), (128, 209)], 0xE6D2A0)
      polygon([(110, 208), (233, 208), (173, 165)], 0x334F62)
      polygon([(152, 521), (152, 475), (182, 475), (182, 521)], 0x344F61)
      for point in [(CGFloat(600), CGFloat(699)), (737, 875), (471, 561)] {
        ellipse(point.0, point.1, 128, 5, 0xA6B9C8, shadow: 1)
      }
      grasses(61, 618, 0xCBD0AC)
    case "amber-dunes":
      polygon([(0, 0), (1000, 0), (1000, 1000), (0, 1000)], 0xF1DFB9, shadow: 0)
      ellipse(526, 130, 262, 262, 0xDC9A52)
      hill(537, 230, 0xDBB479)
      hill(617, -410, 0xCA985D)
      hill(759, 365, 0xB87944)
      hill(831, -365, 0x975D38)
      let path = CGMutablePath()
      path.move(to: CGPoint(x: 0, y: 878))
      path.addCurve(
        to: CGPoint(x: 1020, y: 793), control1: CGPoint(x: 250, y: 605),
        control2: CGPoint(x: 670, y: 1090))
      path.addLine(to: CGPoint(x: 1020, y: 1100))
      path.addLine(to: CGPoint(x: 0, y: 1100))
      path.closeSubpath()
      cut(path, 0xD7A262)
      grasses(125, 922, 0x6F6845)
      grasses(170, 950, 0x6F6845)
      grasses(859, 824, 0x7F744C)
      cloud(140, 236, 0.9, 0xF8EACD)
      polygon([(430, 708), (425, 671), (434, 655), (443, 673), (440, 706)], 0x6E623E)
      polygon([(417, 684), (406, 675), (405, 657), (411, 655), (414, 672), (431, 677)], 0x6E623E)
    case "lilac-hour":
      polygon([(0, 0), (1000, 0), (1000, 1000), (0, 1000)], 0xB1ABC4, shadow: 0)
      ellipse(594, 127, 165, 165, 0xF0E3C9)
      for i in 0..<21 {
        let x = CGFloat((i * 137 + 43) % 960)
        let y = CGFloat((i * 79 + 30) % 430)
        ellipse(x, y, i % 3 == 0 ? 5 : 3, i % 3 == 0 ? 5 : 3, 0xF0E3D3, shadow: 0)
      }
      polygon(
        [
          (-20, 635), (187, 357), (342, 537), (510, 312), (755, 582),
          (920, 398), (1050, 557), (1050, 1100), (-20, 1100),
        ], 0x8C85A6)
      polygon([(510, 312), (594, 602), (755, 582)], 0x79718F)
      hill(626, -140, 0x716B90)
      hill(742, 140, 0x5A6289)
      polygon(
        [
          (537, 605), (664, 606), (604, 675), (718, 746), (678, 812),
          (940, 1000), (59, 1000), (441, 802), (425, 733), (584, 672),
        ], 0xA4A4BC)
      ellipse(572, 680, 100, 6, 0xDBD3CC, shadow: 1)
      ellipse(508, 727, 150, 6, 0xDBD3CC, shadow: 1)
      ellipse(519, 777, 208, 7, 0xC7C3CB, shadow: 1)
      hill(990, -170, 0x424F6D)
      pine(114, 949, 324, 0x414963)
      pine(33, 1000, 390, 0x39445B)
      pine(887, 1050, 418, 0x38465F)
      cloud(90, 249, 0.85, 0xC8BFD0)
    default:
      polygon([(0, 0), (1000, 0), (1000, 1000), (0, 1000)], 0xEDDAB7, shadow: 0)
      ellipse(628, 174, 197, 197, 0xE7B065)
      hill(556, 170, 0xC99C76)
      polygon(
        [
          (0, 647), (114, 634), (160, 424), (283, 424), (325, 620), (466, 663),
          (553, 526), (695, 526), (743, 647), (1000, 681), (1000, 1000), (0, 1000),
        ], 0xB7815E)
      hill(768, -260, 0xA86C4E)
      let arch = CGMutablePath()
      arch.move(to: CGPoint(x: 74, y: 960))
      arch.addLine(to: CGPoint(x: 140, y: 466))
      arch.addCurve(
        to: CGPoint(x: 741, y: 454), control1: CGPoint(x: 210, y: 92),
        control2: CGPoint(x: 660, y: 144))
      arch.addLine(to: CGPoint(x: 916, y: 980))
      arch.closeSubpath()
      arch.move(to: CGPoint(x: 277, y: 997))
      arch.addLine(to: CGPoint(x: 296, y: 507))
      arch.addCurve(
        to: CGPoint(x: 597, y: 501), control1: CGPoint(x: 334, y: 312),
        control2: CGPoint(x: 535, y: 305))
      arch.addLine(to: CGPoint(x: 710, y: 997))
      arch.closeSubpath()
      cut(arch, 0xB56746, shadow: 20)
      polygon([(74, 960), (140, 466), (211, 361), (172, 806), (220, 965)], 0xC27A50)
      polygon([(741, 454), (916, 980), (797, 988), (665, 455), (652, 333)], 0x8D4E3A)
      hill(1017, 145, 0xD0A273)
      pine(925, 982, 147, 0x566F53)
      grasses(91, 1000, 0x5F7150)
      cloud(742, 104, 0.82, 0xF4E8CB)
    }
    var grain = Grain()
    for _ in 0..<58_000 {
      let x = grain.next() * 1000
      let y = grain.next() * 1000
      let shade: UInt32 = grain.next() > 0.48 ? 0xFFF8E7 : 0x222B29
      context.setFillColor(color(shade, alpha: grain.next() * (y > 550 ? 0.10 : 0.065)))
      context.fill(CGRect(x: x, y: y, width: grain.next() * 3.2 + 0.5, height: 0.8))
    }
  }

  func image() -> CGImage { context.makeImage()! }
}

let root = URL(
  fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "Foldscape/Assets.xcassets")
let names = ["mosslight", "coral-summit", "indigo-tide", "amber-dunes", "lilac-hour", "terra-arch"]
let fileManager = FileManager.default
try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
try Data("{\"info\":{\"author\":\"xcode\",\"version\":1}}".utf8).write(
  to: root.appendingPathComponent("Contents.json"))

for name in names {
  let painter = PaperPainter(size: 1200)
  painter.draw(name)
  let folder = root.appendingPathComponent("\(name).imageset")
  try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
  let data = NSBitmapImageRep(cgImage: painter.image()).representation(
    using: .png, properties: [:])!
  try data.write(to: folder.appendingPathComponent("\(name).png"))
  let contents = """
    {"images":[{"filename":"\(name).png","idiom":"universal"}],"info":{"author":"xcode","version":1}}
    """
  try Data(contents.utf8).write(to: folder.appendingPathComponent("Contents.json"))
}

let icon = PaperPainter(size: 1024)
icon.draw("mosslight")
icon.context.setStrokeColor(color(0xF5F0E5))
icon.context.setLineWidth(15)
for position in [CGFloat(333), 666] {
  icon.context.move(to: CGPoint(x: position, y: 0))
  icon.context.addLine(to: CGPoint(x: position, y: 1000))
  icon.context.move(to: CGPoint(x: 0, y: position))
  icon.context.addLine(to: CGPoint(x: 1000, y: position))
}
icon.context.strokePath()
icon.polygon([(674, 674), (1000, 674), (1000, 1000), (674, 1000)], 0xF5F0E5, shadow: 0)
icon.polygon([(695, 695), (965, 709), (951, 967), (679, 953)], 0x315944, shadow: 15)
let iconFolder = root.appendingPathComponent("AppIcon.appiconset")
try fileManager.createDirectory(at: iconFolder, withIntermediateDirectories: true)
try NSBitmapImageRep(cgImage: icon.image()).representation(using: .png, properties: [:])!
  .write(to: iconFolder.appendingPathComponent("AppIcon.png"))
try Data(
  """
  {"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
  """.utf8
).write(to: iconFolder.appendingPathComponent("Contents.json"))
print("Generated six original paper landscapes and the Foldscape icon.")
