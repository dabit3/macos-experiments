// Prints the CGWindowID of the frontmost on-screen window owned by the named
// application, so `screencapture -l <id>` can capture that window alone even
// when notification banners or other windows overlap it.
//
//   swift window_id.swift <owner name>
import CoreGraphics
import Foundation

let owner = CommandLine.arguments.dropFirst().first ?? "Lastfort"
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
  exit(1)
}
for info in list {
  guard let name = info[kCGWindowOwnerName as String] as? String, name == owner,
    let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
    let id = info[kCGWindowNumber as String] as? Int
  else { continue }
  print(id)
  exit(0)
}
exit(1)
