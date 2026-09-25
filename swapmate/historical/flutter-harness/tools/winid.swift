// Prints the CGWindowID of the frontmost on-screen window owned by the named app.
// Usage: winid <ownerName> [ownerPid]
import CoreGraphics
import Foundation

let name = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Swapmate"
let pid = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2]) : nil
let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { exit(2) }
for w in list {
  let owner = w[kCGWindowOwnerName as String] as? String ?? ""
  let ownerPid = w[kCGWindowOwnerPID as String] as? Int ?? -1
  let layer = w[kCGWindowLayer as String] as? Int ?? 0
  let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
  let h = bounds["Height"] as? Double ?? 0
  if owner == name && layer == 0 && h > 100 && (pid == nil || pid == ownerPid),
    let id = w[kCGWindowNumber as String] as? Int {
    print(id)
    exit(0)
  }
}
exit(1)
