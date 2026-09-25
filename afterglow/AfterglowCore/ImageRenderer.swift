import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum RenderError: LocalizedError {
  case missingImage, failedRender, failedExport
  public var errorDescription: String? {
    switch self {
    case .missingImage: "The original image could not be opened."
    case .failedRender: "This image could not be developed. Try resetting the edit."
    case .failedExport: "The image could not be saved. Please try again."
    }
  }
}

public enum PhotoRenderer {
  private static let context = CIContext(options: [.cacheIntermediates: false])

  public static func cropRect(size: CGSize, edit: Edit) -> CGRect {
    let edit = edit.sanitized()
    let aspect = edit.crop.ratio ?? Double(size.width / size.height)
    var width = Double(size.width)
    var height = width / aspect
    if height > Double(size.height) {
      height = Double(size.height)
      width = height * aspect
    }
    width = max(1, floor(width / edit.zoom))
    height = max(1, floor(height / edit.zoom))
    let x = floor((Double(size.width) - width) * (edit.panX + 1) / 2)
    let y = floor((Double(size.height) - height) * (edit.panY + 1) / 2)
    return CGRect(x: x, y: y, width: width, height: height)
  }

  public static func render(url: URL, edit: Edit, maxDimension: CGFloat? = nil) throws
    -> CGImage
  {
    guard var image = CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
    else { throw RenderError.missingImage }
    let edit = edit.sanitized()
    for _ in 0..<edit.rotation {
      image = image.oriented(.right)
    }
    image = image.transformed(
      by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
    let crop = cropRect(size: image.extent.size, edit: edit)
    image = image.cropped(to: crop).transformed(
      by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))

    if let maxDimension, max(image.extent.width, image.extent.height) > maxDimension {
      let scale = maxDimension / max(image.extent.width, image.extent.height)
      image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    var exposure = edit.exposure
    var contrast = edit.contrast
    var saturation = edit.saturation
    var warmth = edit.warmth
    switch edit.look {
    case .original: break
    case .ember:
      exposure += 0.12
      contrast *= 1.08
      saturation *= 0.88
      warmth += 0.38
    case .coast:
      contrast *= 0.94
      saturation *= 0.78
      warmth -= 0.3
    case .silver:
      saturation = 0
      contrast *= 1.16
    case .dusk:
      exposure -= 0.25
      saturation *= 0.66
      contrast *= 1.12
      warmth -= 0.14
    }
    let exposureFilter = CIFilter.exposureAdjust()
    exposureFilter.inputImage = image
    exposureFilter.ev = Float(exposure)
    image = exposureFilter.outputImage ?? image
    if warmth != 0 {
      let temperature = CIFilter.temperatureAndTint()
      temperature.inputImage = image
      temperature.neutral = CIVector(x: 6500, y: 0)
      temperature.targetNeutral = CIVector(x: 6500 - warmth * 2200, y: 0)
      image = temperature.outputImage ?? image
    }
    let color = CIFilter.colorControls()
    color.inputImage = image
    color.contrast = Float(contrast)
    color.saturation = Float(saturation)
    image = color.outputImage ?? image
    guard
      let result = context.createCGImage(
        image, from: image.extent, format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    else { throw RenderError.failedRender }
    return result
  }

  public static func exportJPEG(image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw RenderError.failedExport }
    CGImageDestinationAddImage(
      destination, image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw RenderError.failedExport }
  }
}
