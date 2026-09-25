import SwiftUI
import UniformTypeIdentifiers

struct WorkbenchView: View {
  @EnvironmentObject private var store: GardenStore
  @State private var showProjects = false
  @State private var showGuide = false
  @State private var showSave = false
  @State private var showReset = false
  @State private var showImport = false
  @State private var showExport = false
  @State private var name = ""
  @State private var exports: [URL] = []

  var body: some View {
    VStack(spacing: 18) {
      header
      HStack(alignment: .top, spacing: 18) {
        partsTray.frame(width: 84)
        BoardView()
        ScrollView {
          VStack(spacing: 16) {
            instrument
            inspector
          }
        }
        .scrollIndicators(.hidden)
        .frame(width: 254)
      }
      footer
    }
    .padding(.horizontal, 24)
    .padding(.top, 16)
    .padding(.bottom, 12)
    .background(Color(red: 0.985, green: 0.979, blue: 0.952).ignoresSafeArea())
    .foregroundStyle(GardenStyle.ink)
    .sheet(isPresented: $showProjects) { projectsSheet }
    .sheet(isPresented: $showGuide) { guideSheet }
    .sheet(isPresented: $showSave) { saveSheet }
    .sheet(isPresented: $showExport) { exportSheet }
    .confirmationDialog("Clear this workbench?", isPresented: $showReset, titleVisibility: .visible)
    {
      Button("Clear board", role: .destructive) {
        store.load(Circuit())
        store.notice = "Fresh paper. Place a battery, switch, resistor and lamp."
      }
    } message: {
      Text("Saved projects stay in your library. You can Undo this action.")
    }
    .alert(
      "Something needs attention",
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
    .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
      do {
        let url = try result.get()
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let circuit = try Circuit.decode(Data(contentsOf: url))
        store.load(circuit)
      } catch {
        store.error = error.localizedDescription
      }
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 15).fill(GardenStyle.green)
        Image(systemName: "point.3.connected.trianglepath.dotted")
          .font(.system(size: 28, weight: .light))
          .foregroundStyle(GardenStyle.paper)
      }
      .frame(width: 54, height: 54)
      VStack(alignment: .leading, spacing: 3) {
        Text("Circuit Garden")
          .font(.system(size: 30, weight: .regular, design: .serif))
        Text("SMALL EXPERIMENTS. BRIGHT IDEAS.")
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .tracking(1.4)
          .foregroundStyle(GardenStyle.muted)
      }
      Spacer(minLength: 8)
      toolbarButton("Projects", symbol: "square.stack") { showProjects = true }
      toolbarButton("Undo", symbol: "arrow.uturn.backward") { store.undo() }
        .disabled(!store.canUndo)
        .keyboardShortcut("z", modifiers: .command)
      toolbarButton("Export", symbol: "square.and.arrow.up") {
        exports = store.export()
        showExport = !exports.isEmpty
      }
      Button {
        name = store.circuit.title
        showSave = true
      } label: {
        Label("Save", systemImage: "bookmark")
          .font(.system(size: 13, weight: .semibold))
          .padding(.horizontal, 19)
          .frame(height: 44)
          .background(GardenStyle.green, in: Capsule())
          .foregroundStyle(.white)
      }
      .buttonStyle(.plain)
      .keyboardShortcut("s", modifiers: .command)
      .accessibilityIdentifier("project.save")
    }
    .padding(.bottom, 4)
  }

  private var partsTray: some View {
    VStack(spacing: 12) {
      sectionLabel("PARTS")
        .padding(.top, 7)
      ForEach(ComponentKind.allCases, id: \.self) { kind in
        Button {
          store.add(kind)
        } label: {
          VStack(spacing: 9) {
            Image(systemName: kind.symbol).font(.system(size: 24, weight: .light))
            Text(kind.title).font(.system(size: 11, weight: .medium))
          }
          .frame(width: 82, height: 82)
          .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 17))
          .overlay(RoundedRectangle(cornerRadius: 17).stroke(GardenStyle.brass.opacity(0.20)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(kind.title)")
        .accessibilityIdentifier("add.\(kind.rawValue)")
      }
      Text("TAP TO PLACE\nDRAG TO MOVE")
        .font(.system(size: 8, weight: .medium, design: .monospaced))
        .multilineTextAlignment(.center)
        .lineSpacing(4)
        .foregroundStyle(GardenStyle.muted)
        .padding(.top, 4)
      Spacer(minLength: 10)
      Button {
        showReset = true
      } label: {
        Label("Clear", systemImage: "arrow.counterclockwise")
          .font(.system(size: 12, weight: .medium))
          .frame(height: 44)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("board.clear")
    }
  }

  private var instrument: some View {
    let reading = store.reading
    return VStack(alignment: .leading, spacing: 15) {
      HStack {
        Text("LIVE MEASUREMENT")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .tracking(1.1)
        Spacer()
        Circle().fill(
          reading.current > 0 ? Color(red: 0.80, green: 0.91, blue: 0.51) : Color.white.opacity(0.3)
        )
        .frame(width: 6, height: 6)
      }
      HStack(alignment: .firstTextBaseline, spacing: 5) {
        Text(reading.milliamps)
          .font(.system(size: 48, weight: .light, design: .monospaced))
          .contentTransition(.numericText())
          .minimumScaleFactor(0.6)
        Text("mA").font(.system(size: 15, weight: .light, design: .monospaced))
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("reading.current")
      Divider().overlay(.white.opacity(0.2))
      HStack {
        miniReading("SOURCE", value: "\(Int(reading.voltage))", unit: "V")
        Spacer()
        miniReading("TOTAL R", value: "\(Int(reading.resistance))", unit: "Ω")
      }
      HStack {
        Text("LAMP OUTPUT").font(.system(size: 9, weight: .medium, design: .monospaced))
        Spacer()
        Text("\(Int(reading.brightness * 100))%").font(
          .system(size: 11, weight: .medium, design: .monospaced))
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(.white.opacity(0.12))
          Capsule().fill(Color(red: 0.92, green: 0.81, blue: 0.46))
            .frame(width: geo.size.width * reading.brightness)
        }
      }
      .frame(height: 5)
      HStack(spacing: 7) {
        Image(systemName: reading.current > 0 ? "checkmark.circle.fill" : "circle.dotted")
        Text(reading.status.rawValue).font(.system(size: 12, weight: .semibold))
      }
      .foregroundStyle(Color(red: 0.92, green: 0.88, blue: 0.68))
      Text(reading.detail)
        .font(.system(size: 11))
        .lineSpacing(3)
        .foregroundStyle(.white.opacity(0.78))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
    .background(GardenStyle.ink, in: RoundedRectangle(cornerRadius: 22))
    .foregroundStyle(GardenStyle.paper)
    .animation(.easeInOut(duration: 0.2), value: reading.current)
  }

  private var inspector: some View {
    VStack(alignment: .leading, spacing: 15) {
      sectionLabel(store.selectedWireID != nil ? "CONNECTION" : "FIELD NOTES")
      if store.selectedWireID != nil {
        Text("A small break,\na big difference.")
          .font(.system(size: 22, design: .serif))
        Text("Disconnect this wire to open the circuit. The current will fall to zero.")
          .font(.system(size: 12)).lineSpacing(3)
        Button("Disconnect wire") { store.disconnect() }
          .buttonStyle(GardenButtonStyle(destructive: true))
          .accessibilityIdentifier("wire.disconnect")
      } else if let part = store.selected {
        componentInspector(part)
      } else {
        Text(store.circuit.title)
          .font(.system(size: 24, weight: .regular, design: .serif))
        Text("Electricity needs a way home.")
          .font(.system(size: 13, weight: .medium))
        Text(
          "Tap two brass terminals to connect them. Select a connected terminal to remove its wire."
        )
        .font(.system(size: 12)).lineSpacing(4)
        .foregroundStyle(GardenStyle.muted)
        Divider()
        HStack(alignment: .top, spacing: 9) {
          Text("I = V / R")
            .font(.system(size: 14, weight: .medium, design: .serif))
          Spacer()
          Text("ONE LOOP.\nONE CURRENT.")
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .lineSpacing(3)
        }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(red: 0.95, green: 0.94, blue: 0.88), in: RoundedRectangle(cornerRadius: 22))
  }

  @ViewBuilder
  private func componentInspector(_ part: Component) -> some View {
    Text(part.kind.title).font(.system(size: 24, design: .serif))
    switch part.kind {
    case .battery, .resistor:
      let values: [Double] = part.kind == .battery ? [3, 6, 9, 12] : [100, 220, 470, 1000]
      let unit = part.kind == .battery ? "V" : "Ω"
      Text("\(Int(part.value)) \(unit)")
        .font(.system(size: 29, weight: .light, design: .monospaced))
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
        ForEach(values, id: \.self) { value in
          Button {
            store.setValue(value, id: part.id)
          } label: {
            Text("\(Int(value)) \(unit)")
              .font(.system(size: 12, weight: .semibold, design: .monospaced))
              .frame(maxWidth: .infinity).frame(height: 40)
              .background(
                part.value == value ? GardenStyle.green : Color.white.opacity(0.65),
                in: RoundedRectangle(cornerRadius: 10)
              )
              .foregroundStyle(part.value == value ? .white : GardenStyle.ink)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("value.\(Int(value))")
        }
      }
      Stepper(
        "Fine tune",
        value: Binding(get: { part.value }, set: { store.setValue($0, id: part.id) }),
        in: part.kind == .battery ? 1...24 : 10...2000,
        step: part.kind == .battery ? 1 : 10
      )
      .font(.system(size: 12))
      .accessibilityLabel(part.kind == .battery ? "Voltage" : "Resistance")
      Text(
        part.kind == .battery
          ? "An ideal DC source, adjustable from 1–24 volts."
          : "Higher resistance means less current, and a softer glow."
      )
      .font(.system(size: 11)).lineSpacing(3).foregroundStyle(GardenStyle.muted)
    case .toggle:
      Text("An open switch breaks the loop. A closed switch has zero resistance.")
        .font(.system(size: 12)).lineSpacing(4)
      Button(part.closed ? "Open switch" : "Close switch") { store.toggle(part.id) }
        .buttonStyle(GardenButtonStyle())
    case .lamp:
      Text("\(Int(store.reading.brightness * 100))% brightness")
        .font(.system(size: 20, weight: .light, design: .monospaced))
      Text(
        "A 100 Ω model lamp. Its glow follows electrical power, I²R, reaching full brightness at 0.12 W."
      )
      .font(.system(size: 12)).lineSpacing(4)
      Text(String(format: "%.3f W", store.reading.lampPower))
        .font(.system(size: 18, weight: .medium, design: .monospaced))
    }
    Button {
      store.removeSelected()
    } label: {
      Label("Remove part", systemImage: "trash")
        .font(.system(size: 11))
        .foregroundStyle(GardenStyle.coral)
        .frame(minHeight: 36)
    }
    .buttonStyle(.plain)
  }

  private var footer: some View {
    HStack(spacing: 10) {
      Image(
        systemName: store.pendingTerminal != nil
          ? "point.topleft.down.to.point.bottomright.curvepath" : "info.circle"
      )
      .foregroundStyle(GardenStyle.brass)
      Text(store.notice)
        .font(.system(size: 11))
        .lineLimit(2)
      Spacer(minLength: 10)
      Text("AUTO-SAVED")
        .font(.system(size: 8, weight: .medium, design: .monospaced))
        .foregroundStyle(GardenStyle.muted)
      Button {
        showGuide = true
      } label: {
        Label("Field guide", systemImage: "book.closed")
          .font(.system(size: 11, weight: .medium))
          .frame(height: 32)
      }
      .buttonStyle(.plain)
    }
    .frame(minHeight: 30)
  }

  private var projectsSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("A collection of bright ideas.")
            .font(.system(size: 30, design: .serif))
          sectionLabel("START SOMETHING")
          projectRow(
            "Blank workbench", detail: "Place your own parts and wire your first loop.",
            symbol: "plus"
          ) {
            store.load(Circuit())
            showProjects = false
          }
          projectRow("First light", detail: "9 V · 220 Ω resistor · 28.1 mA", symbol: "lightbulb") {
            store.load(.example())
            showProjects = false
          }
          projectRow("A softer glow", detail: "9 V · 470 Ω resistor · 15.8 mA", symbol: "sun.min") {
            store.load(.example(dimmed: true))
            showProjects = false
          }
          sectionLabel("YOUR SAVED PROJECTS")
          if store.projects.isEmpty {
            Text("Your next bright idea belongs here. Use Save to keep a named snapshot.")
              .font(.system(size: 14)).foregroundStyle(GardenStyle.muted)
          }
          ForEach(store.projects) { project in
            projectRow(
              project.circuit.title,
              detail: project.savedAt.formatted(date: .abbreviated, time: .shortened),
              symbol: "bookmark"
            ) {
              store.load(project.circuit)
              showProjects = false
            }
          }
          Button("Import project JSON") {
            showProjects = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showImport = true }
          }
          .buttonStyle(GardenButtonStyle())
        }
        .padding(28)
      }
      .background(GardenStyle.paper)
      .navigationTitle("Projects")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { showProjects = false } }
      }
    }
    .tint(GardenStyle.green)
  }

  private var saveSheet: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 20) {
        Text("Keep this little discovery.")
          .font(.system(size: 28, design: .serif))
        TextField("Project name", text: $name)
          .textFieldStyle(.roundedBorder)
          .accessibilityIdentifier("project.name")
        Text(
          "Saving an existing name updates its snapshot. Your current workbench also saves automatically after every change."
        )
        .font(.system(size: 13)).foregroundStyle(GardenStyle.muted)
        Button("Save project") {
          store.saveProject(name: name)
          if store.error == nil { showSave = false }
        }
        .buttonStyle(GardenButtonStyle())
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Spacer()
      }
      .padding(28)
      .background(GardenStyle.paper)
      .navigationTitle("Save to Projects")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showSave = false } }
      }
    }
    .presentationDetents([.medium])
    .tint(GardenStyle.green)
  }

  private var guideSheet: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Text("Follow the current.")
            .font(.system(size: 34, design: .serif))
          guideStep(
            "01", title: "Place your parts",
            text:
              "Start a blank project. Add a battery, switch, resistor and lamp using the tray. Drag the body of any part to arrange it."
          )
          guideStep(
            "02", title: "Give electricity a way home",
            text:
              "Tap the battery’s right terminal, then the switch’s left. Join switch right to resistor right, resistor left to lamp right, and lamp left to battery left."
          )
          guideStep(
            "03", title: "Close the loop",
            text:
              "Tap the switch blade. A 9 V battery with a 220 Ω resistor and 100 Ω lamp gives 28.1 mA. Try 470 Ω: current drops to 15.8 mA."
          )
          guideStep(
            "04", title: "Make a break. Make a repair.",
            text:
              "Tap any connected terminal, then Disconnect wire. Current becomes zero. Rejoin the free terminals or use Undo. Save a named project, then reopen it from Projects."
          )
          Divider()
          Text("A deliberately small model").font(.system(size: 23, design: .serif))
          Text(
            "One ideal DC battery. One connected, unbranched series loop. Ideal wires and switches. Resistors from 10–2,000 Ω. Lamps are fixed 100 Ω loads, with an illustrative glow of min(I² × 100 / 0.12, 1). All placed components must belong to the loop. Floating parts, branches and multiple sources are reported rather than simulated."
          )
          Text(
            "This is not a nonlinear LED or incandescent thermal model. There are no transients, capacitors, inductors, parallel circuits or hardware connections. Animated wire dashes indicate activity, not electron speed or direction. Lamp power is displayed per lamp."
          )
          Text(
            "Exports contain editable JSON and a plain-text reading report. They are saved in the app’s Documents/CircuitGarden/Exports folder and can be shared to Files. Import JSON from Projects."
          )
        }
        .font(.system(size: 14))
        .lineSpacing(4)
        .padding(30)
      }
      .background(GardenStyle.paper)
      .navigationTitle("Field guide")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { showGuide = false } }
      }
    }
    .tint(GardenStyle.green)
  }

  private var exportSheet: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 24) {
        Image(systemName: "doc.badge.arrow.up")
          .font(.system(size: 42, weight: .ultraLight))
        Text("Your experiment, on paper.")
          .font(.system(size: 30, design: .serif))
        Text(
          "Two real files have been saved in the app’s Documents folder. Share them to Files or another app."
        )
        .font(.system(size: 14)).foregroundStyle(GardenStyle.muted)
        ForEach(exports, id: \.self) { url in
          ShareLink(item: url) {
            Label(
              url.pathExtension == "json"
                ? "Share editable project (.json)" : "Share measurement report (.txt)",
              systemImage: "square.and.arrow.up")
          }
          .buttonStyle(GardenButtonStyle())
        }
        Spacer()
      }
      .padding(30)
      .background(GardenStyle.paper)
      .navigationTitle("Export complete")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { showExport = false } }
      }
    }
    .tint(GardenStyle.green)
  }

  private func toolbarButton(_ title: String, symbol: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Label(title, systemImage: symbol)
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 13)
        .frame(height: 44)
        .background(.white.opacity(0.7), in: Capsule())
        .overlay(Capsule().stroke(GardenStyle.brass.opacity(0.15)))
    }
    .buttonStyle(.plain)
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text).font(.system(size: 9, weight: .bold, design: .monospaced))
      .tracking(1.4).foregroundStyle(GardenStyle.muted)
  }

  private func miniReading(_ title: String, value: String, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.system(size: 8, weight: .medium, design: .monospaced)).opacity(0.65)
      Text("\(value) \(unit)").font(.system(size: 18, weight: .light, design: .monospaced))
    }
  }

  private func projectRow(
    _ title: String, detail: String, symbol: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 16) {
        Image(systemName: symbol).font(.system(size: 24, weight: .light)).frame(width: 40)
        VStack(alignment: .leading, spacing: 5) {
          Text(title).font(.system(size: 18, weight: .medium, design: .serif))
          Text(detail).font(.system(size: 12)).foregroundStyle(GardenStyle.muted)
        }
        Spacer()
        Image(systemName: "arrow.up.right").font(.system(size: 14))
      }
      .padding(20).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 17))
    }
    .buttonStyle(.plain)
  }

  private func guideStep(_ number: String, title: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 18) {
      Text(number).font(.system(size: 24, weight: .light, design: .monospaced)).foregroundStyle(
        GardenStyle.brass)
      VStack(alignment: .leading, spacing: 7) {
        Text(title).font(.system(size: 20, design: .serif))
        Text(text).font(.system(size: 14))
      }
    }
  }
}

struct GardenButtonStyle: ButtonStyle {
  var destructive = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .semibold))
      .frame(maxWidth: .infinity)
      .frame(minHeight: 44)
      .background(
        (destructive ? GardenStyle.coral : GardenStyle.green).opacity(
          configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 12)
      )
      .foregroundStyle(.white)
  }
}
