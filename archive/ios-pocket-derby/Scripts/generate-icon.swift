import AppKit

/// 32x32 pixel-art icon magnified 32x with hard edges. Legend:
/// s sky, S deep sky, c cloud, g turf, G dark turf, w chalk, k ink,
/// b blue car, l blue light, r red car, o red light, y yellow, W white.
let rows = [
    "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS",
    "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS",
    "SSsssssssssssssssssssssssssssSSS",
    "SSssssssssssccsssssssssssssssSSS",
    "SSsssssssscccccsssssssssyyyssSSS",
    "SSssssssssscccsssssssssyyyyyssSS",
    "SSssssssssssssssssssssssyyyssSSS",
    "SSkkkkkkkkkkkkkkkkkkkkkkkkkkkkSS",
    "SkggGGggGGggGGggGGggGGggGGggGGkS",
    "SkggGGggGGggGGggGGggGGggGGggGGkS",
    "SkGGwwwwwwwwwwwwwwwwwwwwwwwwGGkS",
    "SkGGwGGggGGggGGwwGGggGGggGGwggkS",
    "SkggwggGGggGGgwggwgGGggGGggwGGkS",
    "SkggwggGGggGGgwggwgGGggGGggwGGkS",
    "lkGGwGGkkkkGGgGwwGgGGkkkkGGwGGkl",
    "lkGGwGkbbbbkGgGwwGgGkrrrrkGwGGkl",
    "lkGGwkbllbbbkGgwwgGkrrroorkwGGkl",
    "lkGGwkbbbbbbkGkkkkGkrrrrrrkwGGkl",
    "lkGGwGkkkkkkGkWWWWkGkkkkkkGwGGkl",
    "SkGGwggGGggGGkWkWWkggGGggGGwGGkS",
    "SkGGwGGggGGggkWWWWkGGggGGggwGGkS",
    "SkGGwggGGggGGkWWkWkggGGggGGwGGkS",
    "SkGGwGGggGGggGkkkkGGGggGGggwGGkS",
    "SkGGwwwwwwwwwwwwwwwwwwwwwwwwGGkS",
    "SkggGGggGGggGGggGGggGGggGGggGGkS",
    "SSkkkkkkkkkkkkkkkkkkkkkkkkkkkkSS",
    "SSkkkkkkkkkkkkkkkkkkkkkkkkkkkkSS",
    "SSSSSSSSSSyyyySSyyyySSSSSSSSSSSS",
    "SSSSSSSSSSySSSySySSSySSSSSSSSSSS",
    "SSSSSSSSSSyyyySSySSSySSSSSSSSSSS",
    "SSSSSSSSSSySSSSSySSSySSSSSSSSSSS",
    "SSSSSSSSSSySSSSSyyyySSSSSSSSSSSS"
]

let palette: [Character: UInt32] = [
    "s": 0x3CBCFC, "S": 0x0058F8, "c": 0xFCFCFC, "g": 0x3CB43C, "G": 0x2C982C,
    "w": 0xFCFCFC, "k": 0x0C0C1C, "b": 0x0058F8, "l": 0x3CBCFC, "r": 0xF83800,
    "o": 0xF87858, "y": 0xF8D800, "W": 0xFCFCFC
]

func color(_ hex: UInt32) -> NSColor {
    NSColor(
        red: CGFloat((hex >> 16) & 255) / 255,
        green: CGFloat((hex >> 8) & 255) / 255,
        blue: CGFloat(hex & 255) / 255,
        alpha: 1
    )
}

let destination = CommandLine.arguments[1]
let side = 1024
let cell = CGFloat(side) / CGFloat(rows.count)
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()
for (rowIndex, row) in rows.enumerated() {
    for (columnIndex, key) in row.enumerated() {
        color(palette[key] ?? 0x0058F8).setFill()
        let y = CGFloat(rows.count - 1 - rowIndex) * cell
        NSRect(x: CGFloat(columnIndex) * cell, y: y, width: cell, height: cell).fill()
    }
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Could not encode icon")
}

try png.write(to: URL(fileURLWithPath: destination))
