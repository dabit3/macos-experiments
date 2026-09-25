import KeystoneCore
import SwiftUI

struct ContentView: View {
  @EnvironmentObject var studio: Studio
  var body: some View {
    VStack(spacing: 0) {
      header.fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 0) {
        library.frame(width: 194)
        Rectangle().fill(Ink.line).frame(width: 1)
        VStack(spacing: 0) {
          tools
          ZStack(alignment: .topLeading) {
            DraftingCanvas()
            VStack(alignment: .leading, spacing: 7) {
              Text("STRUCTURAL STUDY / 01").font(
                .system(size: 10, weight: .semibold, design: .monospaced)
              ).tracking(2)
              Text(studio.design.name.components(separatedBy: " / ").last ?? studio.design.name)
                .font(.system(size: 29, weight: .regular, design: .serif))
              Text(
                "\(studio.design.nodes.count) NODES  /  \(studio.design.members.count) MEMBERS  /  METERS"
              )
              .font(.system(size: 10, design: .monospaced)).foregroundStyle(Ink.muted)
            }
            .padding(26).allowsHitTesting(false)
            VStack {
              Spacer()
              if let error = studio.analysisError {
                HStack(spacing: 12) {
                  Image(systemName: "exclamationmark.triangle").font(.title2)
                  VStack(alignment: .leading, spacing: 3) {
                    Text("UNSTABLE STRUCTURE").font(.system(size: 11, weight: .bold)).tracking(1)
                    Text(error).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                  }
                  Spacer()
                  Button("Undo", action: studio.undo).disabled(!studio.canUndo)
                }
                .foregroundStyle(Ink.copper).padding(16).background(Ink.paper)
                .overlay(Rectangle().stroke(Ink.copper.opacity(0.4)))
                .padding(.horizontal, 24).padding(.bottom, 8)
              }
              canvasLegend
            }.frame(maxWidth: .infinity).padding(.bottom, 18)
          }
          metrics
        }
        Rectangle().fill(Ink.line).frame(width: 1)
        inspector.frame(width: 250)
      }.frame(maxHeight: .infinity).clipped()
      footer.fixedSize(horizontal: false, vertical: true)
    }
    .background(Ink.paper).foregroundStyle(Ink.navy)
    .buttonStyle(.plain)
    .alert(
      "Keystone",
      isPresented: Binding(
        get: { studio.errorMessage != nil }, set: { if !$0 { studio.errorMessage = nil } })
    ) {
      Button("OK") { studio.errorMessage = nil }
    } message: {
      Text(studio.errorMessage ?? "")
    }
  }

  private var header: some View {
    HStack(spacing: 16) {
      Image(systemName: "point.3.connected.trianglepath.dotted").font(
        .system(size: 29, weight: .light))
      VStack(alignment: .leading, spacing: 2) {
        Text("KEYSTONE").font(.system(size: 21, weight: .medium, design: .serif)).tracking(4)
        Text("THE STRUCTURAL PLAYGROUND").font(.system(size: 8, weight: .medium)).tracking(2)
          .foregroundStyle(.white.opacity(0.6))
      }
      Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 28).padding(.horizontal, 10)
      Text("Build beautifully.\nUnderstand the forces.").font(.system(size: 11)).lineSpacing(3)
        .foregroundStyle(.white.opacity(0.72))
      Spacer()
      headerButton("Open", icon: "folder", action: studio.open)
      headerButton("Save", icon: "square.and.arrow.down", action: studio.save)
      Menu {
        Button("Engineering report · HTML") { studio.export(report: true) }
        Button("Vector drawing · SVG") { studio.export(report: false) }
      } label: {
        Label("Export", systemImage: "square.and.arrow.up").font(.system(size: 12, weight: .medium))
          .foregroundColor(.white)
          .padding(.horizontal, 14).padding(.vertical, 10)
          .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
      }.menuStyle(.borderlessButton).tint(.white).fixedSize()
    }
    .foregroundStyle(.white).padding(.leading, 28).padding(.trailing, 22).padding(.top, 26).padding(
      .bottom, 19
    )
    .background(Ink.navy)
  }

  private func headerButton(_ title: String, icon: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Label(title, systemImage: icon).font(.system(size: 12)).padding(9)
    }.accessibilityLabel(title)
  }

  private var library: some View {
    GeometryReader { geometry in
      ScrollView {
        libraryContent
          .padding(20)
          .frame(minHeight: geometry.size.height, alignment: .topLeading)
      }
    }.background(Color.white.opacity(0.32))
  }

  private var libraryContent: some View {
    VStack(alignment: .leading, spacing: 20) {
      eyebrow("DESIGN LIBRARY")
      VStack(spacing: 10) {
        exampleCard("01", title: "Warren", detail: "Balanced / 3.0 m rise", height: 3)
        exampleCard("02", title: "Highline", detail: "Deeper / 4.5 m rise", height: 4.5)
        exampleCard("03", title: "Low profile", detail: "Slender / 1.5 m rise", height: 1.5)
      }
      Divider().overlay(Ink.line)
      VStack(alignment: .leading, spacing: 12) {
        eyebrow("THE EXPERIMENT")
        instruction("1", "Shape the span", detail: "Move a joint or connect a member.")
        instruction("2", "Follow the forces", detail: "Apply load. Inspect the colored members.")
        instruction(
          "3", "Find a better balance", detail: "Reduce deflection. Watch the material cost.")
      }
      Spacer(minLength: 4)
      VStack(alignment: .leading, spacing: 9) {
        Image(systemName: "triangle.lefthalf.filled").font(.system(size: 23)).foregroundStyle(
          Ink.copper)
        Text("Strength comes\nfrom geometry.").font(.system(size: 18, design: .serif)).lineSpacing(
          3)
        Text("A local, offline engineering desk.\nNo two spans need be the same.")
          .font(.system(size: 10)).foregroundStyle(Ink.muted).lineSpacing(4)
      }
    }.fixedSize(horizontal: false, vertical: true)
  }

  private func exampleCard(_ number: String, title: String, detail: String, height: Double)
    -> some View
  {
    Button {
      studio.example(height, name: "\(title) / River crossing")
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(number).font(.system(size: 9, design: .monospaced)).foregroundStyle(Ink.muted)
          Spacer()
          Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(Ink.copper)
        }
        MiniTruss(rise: height).frame(height: 32)
        Text(title).font(.system(size: 13, weight: .semibold))
        Text(detail).font(.system(size: 9)).foregroundStyle(Ink.muted)
      }.padding(12).background(Ink.paper)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Ink.line))
    }.accessibilityLabel("Load \(title) example")
  }

  private func instruction(_ number: String, _ title: String, detail: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Text(number).font(.system(size: 10, design: .monospaced)).foregroundStyle(Ink.copper)
        .frame(width: 17, height: 17).overlay(Circle().stroke(Ink.line))
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.system(size: 11, weight: .medium))
        Text(detail).font(.system(size: 10)).foregroundStyle(Ink.muted).lineSpacing(3)
      }
    }
  }

  private var tools: some View {
    HStack(spacing: 4) {
      ForEach(EditorTool.allCases, id: \.self) { tool in
        Button {
          studio.tool = tool
          studio.startNode = nil
        } label: {
          Label(tool.rawValue, systemImage: tool.icon).font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 10).padding(.vertical, 9)
            .background(
              studio.tool == tool ? Ink.navy : Color.clear, in: RoundedRectangle(cornerRadius: 4)
            )
            .foregroundStyle(studio.tool == tool ? Ink.paper : Ink.navy)
        }.help(tool.hint).accessibilityLabel("\(tool.rawValue) tool")
      }
      Spacer(minLength: 8)
      Button(action: studio.undo) {
        Image(systemName: "arrow.uturn.backward").frame(width: 25, height: 30)
      }
      .disabled(!studio.canUndo).opacity(studio.canUndo ? 1 : 0.3).help("Undo · ⌘Z")
      .accessibilityLabel("Undo")
      Button(action: studio.redo) {
        Image(systemName: "arrow.uturn.forward").frame(width: 25, height: 30)
      }
      .disabled(!studio.canRedo).opacity(studio.canRedo ? 1 : 0.3).help("Redo · ⇧⌘Z")
      .accessibilityLabel("Redo")
    }.padding(.horizontal, 18).padding(.vertical, 10).background(Color.white.opacity(0.4))
      .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
  }

  private var canvasLegend: some View {
    VStack(spacing: 15) {
      if studio.mode != .geometry, studio.result != nil {
        HStack(spacing: 18) {
          legendItem("COMPRESSION", color: Ink.blue)
          legendItem("TENSION", color: Ink.copper)
          legendItem("NEAR ZERO", color: Ink.muted.opacity(0.5))
        }.font(.system(size: 9, weight: .medium, design: .monospaced))
        if studio.mode == .deflection {
          Text("DEFORMATION ×100 · ORIGINAL GEOMETRY DASHED")
            .font(.system(size: 9, design: .monospaced)).foregroundStyle(Ink.muted)
        }
      }
      HStack(spacing: 6) {
        Image(systemName: studio.tool.icon)
        Text(studio.tool.hint)
      }.font(.system(size: 10)).foregroundStyle(Ink.muted)
    }.allowsHitTesting(false)
  }

  private func legendItem(_ text: String, color: Color) -> some View {
    HStack(spacing: 5) {
      Capsule().fill(color).frame(width: 18, height: 3)
      Text(text)
    }
  }

  private var metrics: some View {
    HStack(spacing: 0) {
      metric(
        "MAX DISPLACEMENT",
        value: studio.result.map { String(format: "%.2f", $0.maxDisplacementMM) } ?? "—", unit: "mm"
      )
      Rectangle().fill(Ink.line).frame(width: 1, height: 42)
      metric(
        "AXIAL YIELD USE",
        value: studio.result.map { String(format: "%.1f", $0.maxUtilization * 100) } ?? "—",
        unit: "%")
      Rectangle().fill(Ink.line).frame(width: 1, height: 42)
      metric("MATERIAL ESTIMATE", value: String(format: "%.0f", studio.design.cost), unit: "$")
    }.padding(.vertical, 20).background(Color.white.opacity(0.5))
      .overlay(alignment: .top) { Rectangle().fill(Ink.line).frame(height: 1) }
  }

  private func metric(_ title: String, value: String, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title).font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(Ink.muted)
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(value).font(.system(size: 27, weight: .light, design: .rounded)).monospacedDigit()
        Text(unit).font(.system(size: 12)).foregroundStyle(Ink.muted)
      }
    }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 22)
  }

  private var inspector: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          eyebrow("ANALYSIS DESK")
          Spacer()
          Circle().fill(
            studio.analysisError != nil
              ? Ink.copper : (studio.result == nil ? Ink.muted : Ink.green)
          ).frame(width: 6, height: 6)
        }
        Button(action: studio.applyLoad) {
          HStack {
            Image(systemName: "arrow.down").font(.system(size: 13))
            Text("Apply load").font(.system(size: 13, weight: .semibold))
            Spacer()
            Image(systemName: "play.fill").font(.system(size: 9))
          }.padding(14).foregroundStyle(.white).background(
            Ink.copper, in: RoundedRectangle(cornerRadius: 5))
        }.accessibilityIdentifier("applyLoad")
        VStack(alignment: .leading, spacing: 10) {
          eyebrow("VIEW")
          HStack(spacing: 0) {
            ForEach(DisplayMode.allCases, id: \.self) { mode in
              Button {
                studio.mode = mode
                if mode != .geometry, !studio.analyzed {
                  studio.analyzed = true
                  studio.solve()
                }
              } label: {
                Text(mode.rawValue).font(.system(size: 10, weight: .medium)).frame(
                  maxWidth: .infinity
                )
                .padding(.vertical, 9).background(studio.mode == mode ? Ink.navy : .clear)
                .foregroundStyle(studio.mode == mode ? .white : Ink.muted)
              }.accessibilityLabel("\(mode.rawValue) view")
            }
          }.background(Ink.line.opacity(0.35)).clipShape(RoundedRectangle(cornerRadius: 4))
          HStack {
            Toggle("Grid", isOn: $studio.showGrid)
            Spacer()
            Toggle("Labels", isOn: $studio.showLabels)
          }.toggleStyle(.checkbox).font(.system(size: 11))
        }
        Divider()
        selectionPanel
        Divider()
        materialPanel
        if let baseline = studio.baselineMM, let result = studio.result, baseline > 1e-8 {
          let improvement = (1 - result.maxDisplacementMM / baseline) * 100
          VStack(alignment: .leading, spacing: 7) {
            eyebrow("AGAINST FIRST LOAD")
            Text(String(format: "%+.1f%%", improvement)).font(
              .system(size: 24, weight: .light, design: .rounded)
            )
            .foregroundStyle(improvement >= 0 ? Ink.green : Ink.copper)
            Text("deflection improvement").font(.system(size: 10)).foregroundStyle(Ink.muted)
            Button("Set current as reference") { studio.baselineMM = result.maxDisplacementMM }
              .font(.system(size: 10)).foregroundStyle(Ink.copper)
          }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(
            Ink.line.opacity(0.24))
        }
        Text(
          "LINEAR 2D TRUSS\nAxial elasticity only. No buckling,\nbending, self-weight or code checks."
        )
        .font(.system(size: 9)).foregroundStyle(Ink.muted).lineSpacing(4)
      }.padding(20)
    }.background(Color.white.opacity(0.32))
  }

  @ViewBuilder
  private var selectionPanel: some View {
    if let member = studio.selectedMember {
      VStack(alignment: .leading, spacing: 13) {
        eyebrow("MEMBER INSPECTOR")
        HStack(alignment: .firstTextBaseline) {
          Text("M\(member.id + 1)").font(.system(size: 27, design: .serif))
          Spacer()
          Text("N\(member.a + 1) → N\(member.b + 1)").font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Ink.muted)
        }
        infoRow("Length", String(format: "%.2f m", studio.design.length(member)))
        stepRow(
          "Area", value: String(format: "%.0f cm²", member.areaCM2),
          minus: {
            studio.setArea(member.id, area: member.areaCM2 - 5)
          }, plus: { studio.setArea(member.id, area: member.areaCM2 + 5) })
        if let r = studio.result?.members[member.id] {
          infoRow("Axial force", String(format: "%+.2f kN", r.forceKN))
          infoRow("Stress", String(format: "%+.2f MPa", r.stressMPa))
          Text(
            abs(r.forceKN) < 0.001
              ? "NEAR ZERO FORCE" : (r.forceKN < 0 ? "IN COMPRESSION" : "IN TENSION")
          )
          .font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(
            r.forceKN < 0 ? Ink.blue : Ink.copper)
        }
        removeButton("Remove member")
      }
    } else if let node = studio.selectedNode {
      VStack(alignment: .leading, spacing: 13) {
        eyebrow("NODE INSPECTOR")
        Text("N\(node.id + 1)").font(.system(size: 27, design: .serif))
        infoRow("Position", String(format: "%.1f, %.1f m", node.x, node.y))
        Picker(
          "Support",
          selection: Binding(
            get: { node.support },
            set: { support in studio.setNode(node.id) { $0.support = support } })
        ) {
          ForEach(Support.allCases, id: \.self) { support in Text(support.rawValue).tag(support) }
        }.font(.system(size: 11))
        stepRow(
          "Load ↓", value: String(format: "%.0f kN", node.loadKN),
          minus: {
            studio.setNode(node.id) { $0.loadKN = max(0, $0.loadKN - 25) }
          }, plus: { studio.setNode(node.id) { $0.loadKN = min(1000, $0.loadKN + 25) } })
        if let d = studio.result?.displacement[node.id] {
          infoRow("Vertical Δ", String(format: "%+.3f mm", d.y * 1000))
        }
        if node.loadKN != 0 {
          Button("Clear load") { studio.setNode(node.id) { $0.loadKN = 0 } }
            .font(.system(size: 11)).foregroundStyle(Ink.copper)
        }
        removeButton("Remove node")
      }
    } else {
      VStack(alignment: .leading, spacing: 12) {
        eyebrow("DESIGN INSPECTOR")
        Text("Every member\nhas a story.").font(.system(size: 22, design: .serif)).lineSpacing(2)
        Text(
          "Select a beam to see its force,\nor a joint to change its load\nand support conditions."
        )
        .font(.system(size: 11)).foregroundStyle(Ink.muted).lineSpacing(4)
        infoRow(
          "Span",
          String(
            format: "%.1f m",
            (studio.design.nodes.map(\.x).max() ?? 0) - (studio.design.nodes.map(\.x).min() ?? 0)))
        infoRow(
          "Applied load",
          String(format: "%.0f kN", studio.design.nodes.reduce(0) { $0 + $1.loadKN }))
      }
    }
  }

  private var materialPanel: some View {
    VStack(alignment: .leading, spacing: 12) {
      eyebrow("MATERIAL & BUDGET")
      Picker(
        "Material",
        selection: Binding(
          get: { studio.design.material.name },
          set: { name in
            studio.change { $0.material = name == Material.steel.name ? .steel : .aluminum }
          })
      ) {
        Text("Steel · 200 GPa").tag(Material.steel.name)
        Text("Aluminum · 69 GPa").tag(Material.aluminum.name)
      }.labelsHidden().font(.system(size: 11))
      infoRow("Total mass", String(format: "%.0f kg", studio.design.massKg))
      stepRow(
        "Budget", value: String(format: "$%.0f", studio.design.budget),
        minus: {
          studio.change { $0.budget = max(500, $0.budget - 500) }
        }, plus: { studio.change { $0.budget = min(20000, $0.budget + 500) } })
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(Ink.line)
          Capsule().fill(studio.design.cost > studio.design.budget ? Ink.copper : Ink.green)
            .frame(width: geometry.size.width * min(1, studio.design.cost / studio.design.budget))
        }
      }.frame(height: 4)
      Text(
        studio.design.cost > studio.design.budget
          ? "OVER BUDGET · raw material only" : "WITHIN BUDGET · raw material only"
      )
      .font(.system(size: 8, weight: .medium)).foregroundStyle(Ink.muted)
      Button {
        studio.change { design in
          for i in design.members.indices {
            design.members[i].areaCM2 = min(100, design.members[i].areaCM2 + 5)
          }
        }
      } label: {
        Label("Thicken all +5 cm²", systemImage: "plus").font(.system(size: 11, weight: .medium))
          .frame(maxWidth: .infinity).padding(.vertical, 10)
          .overlay(RoundedRectangle(cornerRadius: 4).stroke(Ink.line))
      }
    }
  }

  private func removeButton(_ title: String) -> some View {
    Button(action: studio.deleteSelection) {
      Label(title, systemImage: "trash").font(.system(size: 11)).foregroundStyle(Ink.copper)
        .padding(.vertical, 6)
    }
  }

  private func stepRow(
    _ title: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 7) {
      Text(title).font(.system(size: 11)).foregroundStyle(Ink.muted)
      Spacer()
      Button(action: minus) {
        Image(systemName: "minus").frame(width: 25, height: 25).background(
          Ink.line.opacity(0.4), in: RoundedRectangle(cornerRadius: 3))
      }
      .accessibilityLabel("Decrease \(title)")
      Text(value).font(.system(size: 11, weight: .medium, design: .monospaced)).monospacedDigit()
        .frame(minWidth: 53)
      Button(action: plus) {
        Image(systemName: "plus").frame(width: 25, height: 25).background(
          Ink.line.opacity(0.4), in: RoundedRectangle(cornerRadius: 3))
      }
      .accessibilityLabel("Increase \(title)")
    }
  }

  private func infoRow(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label).font(.system(size: 11)).foregroundStyle(Ink.muted)
      Spacer()
      Text(value).font(.system(size: 11, weight: .medium, design: .monospaced)).monospacedDigit()
    }
  }
  private func eyebrow(_ title: String) -> some View {
    Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(Ink.muted)
  }
  private var footer: some View {
    HStack {
      Circle().fill(Ink.green).frame(width: 5, height: 5)
      Text(studio.notice).lineLimit(1)
      Spacer()
      Text("PIN + ROLLER").tracking(1)
      Text("·").padding(.horizontal, 6)
      Text("SI UNITS").tracking(1)
      Text("·").padding(.horizontal, 6)
      Text("KEYSTONE 1.0").tracking(1)
    }.font(.system(size: 9)).foregroundStyle(Ink.muted)
      .padding(.horizontal, 22).padding(.vertical, 10)
      .overlay(alignment: .top) { Rectangle().fill(Ink.line).frame(height: 1) }
  }
}

struct MiniTruss: View {
  var rise: Double
  var body: some View {
    Canvas { context, size in
      let y = size.height - 4
      let top = y - rise * 5
      var path = Path()
      path.move(to: CGPoint(x: 0, y: y))
      path.addLine(to: CGPoint(x: size.width, y: y))
      for i in 0..<4 {
        let x = size.width * Double(i) / 4
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + size.width / 8, y: top))
        path.addLine(to: CGPoint(x: x + size.width / 4, y: y))
      }
      path.move(to: CGPoint(x: size.width / 8, y: top))
      path.addLine(to: CGPoint(x: size.width * 7 / 8, y: top))
      context.stroke(path, with: .color(Ink.navy), lineWidth: 1.2)
    }
  }
}
