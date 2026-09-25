import CoreImage
import Foundation
import PrismCore
import XCTest

final class GraphTests: XCTestCase {
  func testCycleRejectedWithoutChangingGraph() throws {
    var project = Project.sample()
    let original = project
    XCTAssertThrowsError(
      try project.connect(
        source: project.nodes[2].id, target: project.nodes[1].id, input: 0)
    ) { XCTAssertEqual($0 as? GraphError, .cycle) }
    XCTAssertEqual(project, original)
  }

  func testReplacingInputAndDeletingRemovesEdges() throws {
    var project = Project.sample()
    try project.connect(source: project.nodes[0].id, target: project.nodes[3].id, input: 0)
    XCTAssertEqual(project.edges.count, 3)
    let removed = project.nodes[1].id
    project.delete(removed)
    XCTAssertFalse(project.edges.contains { $0.source == removed || $0.target == removed })
    let output = project.nodes.last!.id
    project.delete(output)
    XCTAssertTrue(project.nodes.contains { $0.id == output })
  }

  func testRoundTripAndInvalidProjects() throws {
    let project = Project.sample()
    XCTAssertEqual(try Project.decode(project.encoded()), project)
    var duplicate = project
    duplicate.nodes.append(project.nodes[0])
    XCTAssertThrowsError(try duplicate.encoded())
    var invalidValue = project
    invalidValue.nodes[1].value = 400
    XCTAssertThrowsError(try invalidValue.encoded())
    XCTAssertThrowsError(try Project.decode(Data("not json".utf8)))
    var badEdge = project
    badEdge.edges.append(.init(source: UUID(), target: project.nodes.last!.id))
    XCTAssertThrowsError(try badEdge.encoded())
  }

  func testBlendRequiresBothInputsAndRealPixelsChange() throws {
    var project = Project.starter()
    let blend = GraphNode(kind: .blend, x: 300, y: 100, value: 0.5)
    let other = GraphNode(kind: .image, x: 10, y: 250, asset: "Nocturne")
    project.nodes += [blend, other]
    try project.connect(source: project.nodes[0].id, target: blend.id, input: 0)
    try project.connect(source: blend.id, target: project.nodes[1].id, input: 0)
    let renderer = Renderer()
    let load: (String) -> CIImage? = {
      CIImage(color: $0 == "Solstice" ? .red : .blue)
        .cropped(to: CGRect(x: 0, y: 0, width: 16, height: 16))
    }
    XCTAssertThrowsError(try renderer.evaluate(project, load: load))
    try project.connect(source: other.id, target: blend.id, input: 1)
    let image = try renderer.evaluate(project, load: load)
    let context = CIContext()
    var pixel = [UInt8](repeating: 0, count: 4)
    context.render(
      image, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
      format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    XCTAssertGreaterThan(pixel[0], 80)
    XCTAssertGreaterThan(pixel[2], 80)
    XCTAssertLessThan(pixel[1], 5)
    XCTAssertEqual(image.extent, CGRect(x: 0, y: 0, width: 16, height: 16))
  }

  func testExposureSaturationBlurAndPNGExport() throws {
    let renderer = Renderer()
    let source = CIImage(
      color: CIColor(red: 0.2, green: 0.1, blue: 0.05)
    ).cropped(to: CGRect(x: 0, y: 0, width: 32, height: 24))
    var project = Project.sample()
    project.nodes[1].value = 1
    project.nodes[2].value = 0
    let blur = GraphNode(kind: .blur, x: 0, y: 0, value: 20)
    project.nodes.append(blur)
    try project.connect(source: project.nodes[2].id, target: blur.id, input: 0)
    try project.connect(source: blur.id, target: project.nodes[3].id, input: 0)
    let image = try renderer.evaluate(project) { _ in source }
    XCTAssertEqual(image.extent, source.extent)
    var pixel = [Float](repeating: 0, count: 4)
    CIContext().render(
      image, toBitmap: &pixel, rowBytes: 16, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
      format: .RGBAf, colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB))
    XCTAssertEqual(pixel[0], pixel[1], accuracy: 0.001)
    XCTAssertEqual(pixel[1], pixel[2], accuracy: 0.001)
    project.nodes[1].value = 0
    let baseline = try renderer.evaluate(project) { _ in source }
    var baselinePixel = [Float](repeating: 0, count: 4)
    CIContext().render(
      baseline, toBitmap: &baselinePixel, rowBytes: 16,
      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
      format: .RGBAf, colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB))
    XCTAssertEqual(pixel[0], baselinePixel[0] * 2, accuracy: 0.001)
    let folder = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Caches/PrismTests", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("\(UUID()).png")
    defer { try? FileManager.default.removeItem(at: url) }
    try renderer.exportPNG(image, to: url)
    let loaded = CIImage(contentsOf: url)
    XCTAssertEqual(loaded?.extent, source.extent)
    XCTAssertGreaterThan(try Data(contentsOf: url).count, 100)
  }
}
