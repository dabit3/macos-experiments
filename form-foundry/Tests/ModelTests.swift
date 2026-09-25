import Foundation

@main
struct ModelTests {
  static func main() throws {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ description: String) {
      precondition(condition(), description)
      checks += 1
      print("PASS: \(description)")
    }
    let box = Solid(name: "Box", width: 20, depth: 30, height: 40)
    let boxMesh = Mesh.make(for: box)
    check(boxMesh.vertices.count == 8 && boxMesh.triangles.count == 12, "Box topology")
    check(box.volume == 24000, "Box volume in cubic millimeters")
    let ellipse = Solid(name: "Ellipse", profile: .circle, width: 20, depth: 30, height: 40)
    let ellipseMesh = Mesh.make(for: ellipse)
    check(
      ellipseMesh.vertices.count == 128 && ellipseMesh.triangles.count == 252,
      "64-segment ellipse topology")
    check(abs(ellipse.volume - 6000 * .pi) < 0.00001, "Elliptical extrusion analytic volume")

    for (name, mesh) in [("box", boxMesh), ("ellipse", ellipseMesh)] {
      var edges: [String: Int] = [:]
      var signedVolume = 0.0
      for face in mesh.triangles {
        check(face.allSatisfy { mesh.vertices.indices.contains($0) }, "\(name) valid face indices")
        for i in 0..<3 {
          let a = face[i]
          let b = face[(i + 1) % 3]
          edges["\(min(a, b)):\(max(a, b))", default: 0] += 1
        }
        let a = mesh.vertices[face[0]]
        let b = mesh.vertices[face[1]]
        let c = mesh.vertices[face[2]]
        signedVolume +=
          (a.x * (b.y * c.z - b.z * c.y)
            + a.y * (b.z * c.x - b.x * c.z)
            + a.z * (b.x * c.y - b.y * c.x)) / 6
      }
      check(
        edges.values.allSatisfy { $0 == 2 },
        "\(name) watertight: every edge shared by two triangles")
      check(signedVolume > 0, "\(name) outward face winding")
      let analytic = name == "box" ? box.volume : ellipse.volume
      check(
        abs(signedVolume / analytic - 1) < 0.002, "\(name) mesh volume agrees with analytic volume")
    }
    var moved = box
    moved.rotation = 90
    moved.x = 12
    moved.y = 5
    moved.z = -4
    let transformed = moved.world(Vertex(x: 10, y: 40, z: 15))
    check(
      abs(transformed.x - 27) < 0.0001 && abs(transformed.z + 14) < 0.0001 && transformed.y == 45,
      "Rotation around Y plus translation")
    var resized = box
    resized.width = 40
    check(Mesh.make(for: resized).vertices.map(\.x).max() == 20, "Dimension edit updates geometry")
    check(Project.sample.isValid, "Bundled sample validates")
    let encoded = try JSONEncoder().encode(Project.sample)
    let decoded = try ProjectIO.decode(encoded)
    let encodedAgain = try JSONEncoder().encode(decoded)
    let roundTrip = try JSONDecoder().decode(Project.self, from: encodedAgain)
    check(
      roundTrip == decoded,
      "Project JSON round trip")
    var invalid = decoded
    invalid.solids[0].width = -1
    check(!invalid.isValid, "Invalid dimension rejected")
    invalid = decoded
    invalid.solids.append(invalid.solids[0])
    check(!invalid.isValid, "Duplicate object IDs rejected")
    invalid = decoded
    invalid.solids[0].rotation = .infinity
    check(!invalid.isValid, "Non-finite transform rejected")

    var history = History()
    let empty = Project(title: "Empty", solids: [])
    history.record(decoded)
    check(history.undo(empty) == decoded, "Undo restores full assembly")
    check(history.redo(decoded) == empty, "Redo restores full assembly")
    _ = history.undo(empty)
    history.record(decoded)
    check(history.future.isEmpty, "Editing after undo clears redo")
    let obj = Mesh.obj(project: Project(title: "Export", solids: [box, moved, ellipse]))
    let lines = obj.split(separator: "\n")
    check(lines.filter { $0.hasPrefix("v ") }.count == 144, "OBJ vertex count")
    check(lines.filter { $0.hasPrefix("f ") }.count == 276, "OBJ triangle count")
    check(lines.filter { $0.hasPrefix("o ") }.count == 3, "OBJ separate objects")
    let faceIndices = lines.filter { $0.hasPrefix("f ") }.flatMap {
      $0.split(separator: " ").dropFirst().compactMap { Int($0) }
    }
    check(
      faceIndices.allSatisfy { (1...144).contains($0) } && faceIndices.max() == 144,
      "OBJ one-based global indices")
    print("\(checks) checks passed")
  }
}
