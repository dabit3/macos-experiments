import CoreGraphics
import Foundation
let name = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Voxelhearth"
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
for w in list {
  if (w[kCGWindowOwnerName as String] as? String) == name, (w[kCGWindowLayer as String] as? Int) == 0 {
    print(w[kCGWindowNumber as String] as! Int)
    break
  }
}
