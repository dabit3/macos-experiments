// Prints the CGWindowID of the first on-screen window owned by the process
// named in argv[1]. Used by the e2e harness to screenshot the macOS client
// with `screencapture -l <id>`.
import CoreGraphics
import Foundation

let owner = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Gambit Court"
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
  exit(2)
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
