import LinkPresentation
import UIKit

final class ShareCardItem: NSObject, UIActivityItemSource {
  private let image: UIImage
  private let playerName: String

  init(image: UIImage, playerName: String) {
    self.image = image
    self.playerName = playerName
  }

  func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController)
    -> Any
  {
    image
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    image
  }

  func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController)
    -> LPLinkMetadata?
  {
    let metadata = LPLinkMetadata()
    metadata.imageProvider = NSItemProvider(object: image)
    metadata.title = "GTC Keynote Bingo — \(playerName)"
    return metadata
  }
}
