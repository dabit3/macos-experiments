import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import UniformTypeIdentifiers

public final class Renderer {
  private let context = CIContext(options: [.cacheIntermediates: true])

  public init() {}

  public func evaluate(_ project: Project, load: (String) -> CIImage?) throws -> CIImage {
    _ = try project.validated()
    guard let output = project.nodes.first(where: { $0.kind == .output }) else {
      throw GraphError.invalidProject
    }
    var memo: [UUID: CIImage] = [:]
    func visit(_ node: GraphNode) throws -> CIImage {
      if let cached = memo[node.id] { return cached }
      func input(_ slot: Int) throws -> CIImage {
        guard let edge = project.incoming(node.id, input: slot),
          let parent = project.nodes.first(where: { $0.id == edge.source })
        else { throw GraphError.missingInput(node.kind.title, slot) }
        return try visit(parent)
      }
      let image: CIImage
      switch node.kind {
      case .image:
        guard let source = load(node.asset) else { throw GraphError.missingAsset }
        image = source
      case .exposure:
        image = try input(0).applyingFilter("CIExposureAdjust", parameters: ["inputEV": node.value])
      case .saturation:
        image = try input(0).applyingFilter(
          "CIColorControls", parameters: ["inputSaturation": node.value])
      case .blur:
        let source = try input(0)
        image = source.clampedToExtent().applyingFilter(
          "CIGaussianBlur", parameters: ["inputRadius": node.value]
        ).cropped(to: source.extent)
      case .blend:
        let a = try input(0)
        let b = try input(1)
        image = a.applyingFilter(
          "CIDissolveTransition",
          parameters: ["inputTargetImage": b, "inputTime": node.value]
        ).cropped(to: a.extent)
      case .output:
        image = try input(0)
      }
      memo[node.id] = image
      return image
    }
    return try visit(output)
  }

  public func cgImage(_ image: CIImage) throws -> CGImage {
    guard let result = context.createCGImage(image, from: image.extent) else {
      throw GraphError.missingAsset
    }
    return result
  }

  public func exportPNG(_ image: CIImage, to url: URL) throws {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    try context.writePNGRepresentation(
      of: image, to: url, format: .RGBA8, colorSpace: colorSpace)
  }
}
