import Foundation

public enum DesignExport {
  public static func json(_ design: Design) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(design.validated())
  }

  public static func decode(_ data: Data) throws -> Design {
    guard data.count <= 2_000_000 else {
      throw AnalysisError.invalid("Design files must be under 2 MB.")
    }
    return try JSONDecoder().decode(Design.self, from: data).validated()
  }

  public static func escape(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }

  public static func svg(_ design: Design, analysis: Analysis?) -> String {
    let minX = design.nodes.map(\.x).min() ?? 0
    let maxX = design.nodes.map(\.x).max() ?? 12
    let minY = design.nodes.map(\.y).min() ?? 0
    let maxY = design.nodes.map(\.y).max() ?? 3
    let scale = min(900 / max(maxX - minX, 1), 360 / max(maxY - minY, 1))
    func point(_ node: Node) -> (Double, Double) {
      (90 + (node.x - minX) * scale, 500 - (node.y - minY) * scale)
    }
    var body = """
      <svg xmlns="http://www.w3.org/2000/svg" width="1100" height="680" viewBox="0 0 1100 680">
      <rect width="1100" height="680" fill="#f5f2e9"/>
      <text x="60" y="55" fill="#193448" font-family="Helvetica" font-size="28">KEYSTONE / \(escape(design.name))</text>
      <text x="60" y="85" fill="#6c7679" font-family="Helvetica" font-size="14">\(analysis == nil ? "GEOMETRY · NOT ANALYZED" : "AXIAL STRESS · BLUE COMPRESSION / COPPER TENSION")</text>
      """
    for member in design.members {
      guard let a = design.node(member.a), let b = design.node(member.b) else { continue }
      let pa = point(a)
      let pb = point(b)
      let result = analysis?.members[member.id]
      let color =
        result.map {
          $0.forceKN < -0.001 ? "#31657b" : ($0.forceKN > 0.001 ? "#ba613d" : "#9a9e97")
        } ?? "#193448"
      body += """
        <line x1="\(pa.0)" y1="\(pa.1)" x2="\(pb.0)" y2="\(pb.1)" stroke="\(color)" stroke-width="5" stroke-linecap="round"/>
        <text x="\((pa.0 + pb.0)/2)" y="\((pa.1 + pb.1)/2 - 12)" fill="#193448" font-family="Helvetica" font-size="11">M\(member.id + 1)\(result.map { String(format: " · %.1f MPa", $0.stressMPa) } ?? "")</text>
        """
    }
    for node in design.nodes {
      let p = point(node)
      body +=
        "<circle cx=\"\(p.0)\" cy=\"\(p.1)\" r=\"7\" fill=\"#f5f2e9\" stroke=\"#193448\" stroke-width=\"2\"/>"
      body +=
        "<text x=\"\(p.0 + 10)\" y=\"\(p.1 - 10)\" font-family=\"Helvetica\" font-size=\"12\">N\(node.id + 1)</text>"
      if node.support != .free {
        body += "<path d=\"M \(p.0) \(p.1 + 10) l -12 20 h 24 Z\" fill=\"#193448\"/>"
      }
      if node.loadKN != 0 {
        let end = p.1 - 16
        body +=
          "<path d=\"M \(p.0) \(end - 65) V \(end) m -5 -8 l 5 8 l 5 -8\" fill=\"none\" stroke=\"#ba613d\" stroke-width=\"2\"/>"
        body +=
          "<text x=\"\(p.0 + 12)\" y=\"\(end - 50)\" font-family=\"Helvetica\" fill=\"#ba613d\" font-size=\"13\">\(node.loadKN) kN ↓</text>"
      }
    }
    body +=
      "<text x=\"60\" y=\"620\" font-family=\"Helvetica\" font-size=\"14\" fill=\"#193448\">\(analysis.map { String(format: "Max displacement %.3f mm · Axial yield utilization %.1f%%", $0.maxDisplacementMM, $0.maxUtilization * 100) } ?? "Run analysis to compute member forces.")</text>"
    body +=
      "<text x=\"60\" y=\"650\" font-family=\"Helvetica\" font-size=\"11\" fill=\"#6c7679\">Educational linear 2D pin-jointed model. No buckling, self-weight, bending or design-code checks.</text></svg>"
    return body
  }

  public static func report(_ design: Design, analysis: Analysis) -> String {
    let rows = design.members.map { member -> String in
      guard let r = analysis.members[member.id] else { return "" }
      return String(
        format:
          "<tr><td>M%d</td><td>N%d → N%d</td><td>%.3f</td><td>%.1f</td><td>%+.3f</td><td>%+.3f</td><td>%.1f%%</td></tr>",
        member.id + 1, member.a + 1, member.b + 1, design.length(member), member.areaCM2,
        r.forceKN, r.stressMPa, r.utilization * 100)
    }.joined()
    let nodes = design.nodes.map { node -> String in
      let d = analysis.displacement[node.id] ?? .zero
      let r = analysis.reactionsKN[node.id] ?? .zero
      return String(
        format:
          "<tr><td>N%d</td><td>%@</td><td>%.2f</td><td>%+.4f</td><td>%+.4f</td><td>%+.3f</td><td>%+.3f</td></tr>",
        node.id + 1, escape(node.support.rawValue), node.loadKN, d.x * 1000, d.y * 1000, r.x, r.y)
    }.joined()
    return """
      <!doctype html><html><head><meta charset="utf-8"><title>Keystone · \(escape(design.name))</title>
      <style>body{background:#f5f2e9;color:#193448;font:15px Helvetica,sans-serif;max-width:1100px;margin:50px auto;padding:30px}h1{font-size:36px}h2{margin-top:40px}table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}th,td{text-align:left;padding:12px;border-bottom:1px solid #d5d7ce}th{font-size:12px;text-transform:uppercase}svg{width:100%;height:auto}.metrics{font-size:22px;border-block:1px solid #b9c1bd;padding:24px 0}p{line-height:1.6}</style></head><body>
      <p>KEYSTONE / STRUCTURAL STUDY 01</p><h1>\(escape(design.name))</h1>
      <p>\(escape(design.material.name)) · E \(design.material.modulusGPa) GPa · axial yield \(design.material.yieldMPa) MPa</p>
      <div class="metrics">\(String(format: "%.3f mm displacement · %.1f%% yield utilization · %.1f kg · $%.0f estimate", analysis.maxDisplacementMM, analysis.maxUtilization * 100, design.massKg, design.cost))</div>
      \(svg(design, analysis: analysis))
      <h2>Member schedule</h2><p>Positive = tension. Negative = compression. Stress is axial force / area.</p>
      <table><tr><th>Member</th><th>Nodes</th><th>Length m</th><th>Area cm²</th><th>Force kN</th><th>Stress MPa</th><th>Yield use</th></tr>\(rows)</table>
      <h2>Nodal displacements &amp; reactions</h2><table><tr><th>Node</th><th>Support</th><th>Load kN ↓</th><th>Ux mm</th><th>Uy mm</th><th>Rx kN</th><th>Ry kN</th></tr>\(nodes)</table>
      <h2>Method &amp; limits</h2><p>Small-displacement 2D truss direct stiffness method: assemble EA/L · bᵀb, constrain pinned X/Y and roller Y degrees of freedom, then solve with a scaled-pivot Cholesky factorization. Pivots ≤ 10⁻¹⁰ of the largest free diagonal are rejected as unstable or ill-conditioned. Free-DOF residual: \(analysis.residualN) N.</p>
      <p>Ideal frictionless joints, axial-only members, linear elastic material and nodal vertical loads. No self-weight, bending, buckling, joint capacity, dynamics, geometric nonlinearity or code compliance. Yield utilization is not a safety certification. Compression can buckle below yield. Budget includes raw material only. Educational use only.</p></body></html>
      """
  }
}
