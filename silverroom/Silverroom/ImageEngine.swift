import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UIKit

enum DarkroomError: LocalizedError {
  case unreadable, renderFailed, exportFailed

  var errorDescription: String? {
    switch self {
    case .unreadable: "This photograph couldn’t be opened. Try a JPEG, HEIC, or PNG image."
    case .renderFailed: "We couldn’t develop this image. Your original is safe; try another photo."
    case .exportFailed: "The export couldn’t be saved. Please free some storage and try again."
    }
  }
}

final class ImageEngine {
  private let context = CIContext(options: [.cacheIntermediates: false])

  func source(_ data: Data, maxPixel: CGFloat? = nil) throws -> CIImage {
    if let maxPixel {
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let image = CGImageSourceCreateThumbnailAtIndex(
          source, 0,
          [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
          ] as CFDictionary)
      else { throw DarkroomError.unreadable }
      return CIImage(cgImage: image)
    }
    guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]),
      !image.extent.isEmpty, !image.extent.isInfinite
    else { throw DarkroomError.unreadable }
    return image
  }

  func filtered(_ source: CIImage, settings raw: EditSettings) -> CIImage {
    let settings = raw.normalized
    var image = source
    if settings.exposure != 0 {
      image = image.applyingFilter(
        "CIExposureAdjust", parameters: [kCIInputEVKey: settings.exposure])
    }
    let filmWarmth: Double = settings.film == .dune ? 0.26 : settings.film == .faded ? 0.08 : 0
    let warmth = settings.warmth + filmWarmth
    if warmth != 0 {
      image = image.applyingFilter(
        "CITemperatureAndTint",
        parameters: [
          "inputNeutral": CIVector(x: 6500 + warmth * 1800, y: 0),
          "inputTargetNeutral": CIVector(x: 6500, y: 0),
        ])
    }
    let saturation: Double =
      switch settings.film {
      case .silver, .noir: 0
      case .dune: 0.82
      case .faded: 0.65
      case .original: 1
      }
    let filmContrast: Double =
      switch settings.film {
      case .silver: 1.04
      case .noir: 1.23
      case .dune: 1.04
      case .faded: 0.89
      case .original: 1
      }
    image = image.applyingFilter(
      "CIColorControls",
      parameters: [
        kCIInputSaturationKey: saturation,
        kCIInputContrastKey: 1,
      ])
    let contrast = (settings.contrast * filmContrast - 1) * 0.55
    if contrast != 0 {
      image = image.applyingFilter(
        "CIToneCurve",
        parameters: [
          "inputPoint0": CIVector(x: 0, y: 0),
          "inputPoint1": CIVector(x: 0.25, y: 0.25 - contrast / 2),
          "inputPoint2": CIVector(x: 0.5, y: 0.5),
          "inputPoint3": CIVector(x: 0.75, y: 0.75 + contrast / 2),
          "inputPoint4": CIVector(x: 1, y: 1),
        ])
    }
    if settings.film == .silver || settings.film == .faded {
      let lift = settings.film == .silver ? 0.025 : 0.065
      image = image.applyingFilter(
        "CIToneCurve",
        parameters: [
          "inputPoint0": CIVector(x: 0, y: lift),
          "inputPoint1": CIVector(x: 0.25, y: 0.24 + lift),
          "inputPoint2": CIVector(x: 0.5, y: 0.52),
          "inputPoint3": CIVector(x: 0.75, y: 0.78),
          "inputPoint4": CIVector(x: 1, y: 0.98),
        ])
    }
    for _ in 0..<settings.quarterTurns {
      image = image.oriented(.right)
    }
    let extent = image.extent
    image = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
    if settings.squareCrop {
      let side = floor(min(image.extent.width, image.extent.height))
      let crop = CGRect(
        x: floor((image.extent.width - side) / 2),
        y: floor((image.extent.height - side) / 2), width: side, height: side)
      image = image.cropped(to: crop).transformed(
        by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
    }
    return image
  }

  func render(_ data: Data, settings: EditSettings, maxPixel: CGFloat? = nil) throws -> UIImage {
    let image = filtered(try source(data, maxPixel: maxPixel), settings: settings)
    guard
      let cgImage = context.createCGImage(
        image, from: image.extent, format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    else { throw DarkroomError.renderFailed }
    return UIImage(cgImage: cgImage)
  }

  func export(_ data: Data, settings: EditSettings) throws -> Data {
    guard let jpeg = try render(data, settings: settings).jpegData(compressionQuality: 0.96) else {
      throw DarkroomError.exportFailed
    }
    return jpeg
  }

  func dimensions(_ data: Data, settings: EditSettings) throws -> CGSize {
    let image = try source(data)
    let width =
      settings.normalized.quarterTurns.isMultiple(of: 2) ? image.extent.width : image.extent.height
    let height =
      settings.normalized.quarterTurns.isMultiple(of: 2) ? image.extent.height : image.extent.width
    return settings.squareCrop
      ? CGSize(width: min(width, height), height: min(width, height))
      : CGSize(width: width, height: height)
  }
}
