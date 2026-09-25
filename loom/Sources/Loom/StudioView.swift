import LoomCore
import SwiftUI

private let shell = Color(red: 0.94, green: 0.945, blue: 0.93)
private let labelInk = Color(red: 0.10, green: 0.12, blue: 0.12)
private let secondaryInk = Color(red: 0.40, green: 0.43, blue: 0.42)
private let ruleColor = Color.black.opacity(0.10)

struct StudioView: View {
  @ObservedObject var studio: Studio
  @State private var showTable = true

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      HStack(spacing: 0) {
        inspector
        Divider()
        workspace
      }
      Divider()
      footer
    }
    .background(shell)
    .foregroundStyle(labelInk)
    .tint(studio.project.theme.color)
    .alert(
      "Let’s fix that",
      isPresented: Binding(get: { studio.error != nil }, set: { if !$0 { studio.error = nil } })
    ) {
      Button("OK") { studio.error = nil }
    } message: {
      Text(studio.error ?? "")
    }
  }

  private var header: some View {
    HStack(spacing: 18) {
      HStack(spacing: 3) {
        ForEach(0..<4) { index in
          RoundedRectangle(cornerRadius: 1)
            .fill(index == 3 ? studio.project.theme.color : labelInk)
            .frame(width: 5, height: CGFloat(26 - index * 3))
        }
      }
      Text("loom").font(.system(size: 30, weight: .bold, design: .rounded)).tracking(-1.5)
      Rectangle().fill(ruleColor).frame(width: 1, height: 25).padding(.horizontal, 4)
      VStack(alignment: .leading, spacing: 3) {
        Text("DATA STORYTELLING STUDIO").font(
          .system(size: 9, weight: .semibold, design: .monospaced)
        ).tracking(1.6)
        Text(studio.fileURL?.lastPathComponent ?? "Untitled story")
          .font(.system(size: 12)).foregroundStyle(secondaryInk).lineLimit(1)
      }
      Spacer(minLength: 12)
      Button(action: studio.undo) {
        Image(systemName: "arrow.uturn.backward").frame(width: 24, height: 24)
      }
      .disabled(studio.history.isEmpty).help("Undo last change").accessibilityLabel("Undo")
      Button(action: studio.openProject) { Label("Open", systemImage: "folder").frame(height: 24) }
      Button(action: { studio.save() }) {
        Label("Save", systemImage: "square.and.arrow.down").frame(height: 24)
      }
      Menu {
        Button("PNG · 2080 × 1480", action: { studio.export("PNG") })
        Button("PDF · vector artwork", action: { studio.export("PDF") })
      } label: {
        Label("Export graphic", systemImage: "arrow.up.right").fontWeight(.semibold)
          .frame(height: 26).padding(.horizontal, 4)
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .padding(.horizontal, 12).padding(.vertical, 4)
      .background(labelInk, in: RoundedRectangle(cornerRadius: 7))
      .foregroundStyle(.white)
      .tint(.white)
      .accentColor(.white)
      .accessibilityIdentifier("exportGraphic")
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 18)
    .background(Color.white.opacity(0.75))
  }

  private var inspector: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 0) {
        tab("01  Data", index: 0)
        tab("02  Design", index: 1)
      }.padding(16)
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if studio.inspector == 0 { dataControls } else { designControls }
        }
        .padding(20)
      }
      Divider()
      VStack(alignment: .leading, spacing: 7) {
        Text("MADE TO TELL A STORY").font(.system(size: 9, weight: .medium, design: .monospaced))
          .tracking(1)
        Text("Start with a question.\nLet the data do the talking.")
          .font(.system(size: 12)).foregroundStyle(secondaryInk).lineSpacing(3)
      }.padding(20)
    }
    .frame(width: 265)
    .background(Color.white.opacity(0.68))
  }

  private func tab(_ label: String, index: Int) -> some View {
    Button {
      studio.inspector = index
    } label: {
      Text(label).font(.system(size: 12, weight: .semibold))
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(
          studio.inspector == index ? labelInk : Color.clear, in: RoundedRectangle(cornerRadius: 5)
        )
        .foregroundStyle(studio.inspector == index ? .white : secondaryInk)
    }.buttonStyle(.plain)
  }

  private func sectionLabel(_ number: String, _ title: String) -> some View {
    HStack {
      Text(number).foregroundStyle(studio.project.theme.color)
      Text(title)
    }.font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(0.8)
  }

  private var dataControls: some View {
    Group {
      VStack(alignment: .leading, spacing: 12) {
        sectionLabel("A", "YOUR DATA")
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "tablecells").font(.system(size: 19)).foregroundStyle(
            studio.project.theme.color)
          VStack(alignment: .leading, spacing: 5) {
            Text(studio.project.dataset.name).font(.system(size: 13, weight: .semibold)).lineLimit(
              1)
            Text(
              "\(studio.project.dataset.rows.count) rows · \(studio.project.dataset.columns.count) columns"
            )
            .font(.system(size: 11)).foregroundStyle(secondaryInk)
          }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
          .background(shell, in: RoundedRectangle(cornerRadius: 6))
        HStack {
          Button("Import CSV…", action: studio.importCSV).controlSize(.large)
          Menu("Samples") {
            Button("Cities in motion") { studio.loadSample("cycling") }
            Button("The energy transition") { studio.loadSample("energy") }
          }.menuStyle(.borderlessButton).fixedSize()
        }.font(.system(size: 12))
      }
      VStack(alignment: .leading, spacing: 12) {
        sectionLabel("B", "CHART TYPE")
        HStack(spacing: 7) {
          ForEach(ChartKind.allCases, id: \.self) { kind in
            Button {
              studio.binding(\.kind).wrappedValue = kind
            } label: {
              VStack(spacing: 8) {
                Image(
                  systemName: kind == .bar
                    ? "chart.bar.xaxis" : kind == .line ? "chart.xyaxis.line" : "chart.dots.scatter"
                )
                .font(.system(size: 20))
                Text(kind.rawValue).font(.system(size: 10, weight: .medium))
              }
              .frame(maxWidth: .infinity).frame(height: 67)
              .background(
                studio.project.kind == kind ? studio.project.theme.color.opacity(0.09) : .white,
                in: RoundedRectangle(cornerRadius: 6)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 6).stroke(
                  studio.project.kind == kind ? studio.project.theme.color : ruleColor, lineWidth: 1
                ))
            }.buttonStyle(.plain).accessibilityLabel("\(kind.rawValue) chart")
          }
        }
      }
      VStack(alignment: .leading, spacing: 13) {
        sectionLabel("C", "FIELD MAPPING")
        columnPicker("Labels", key: \.category)
        if studio.project.kind == .scatter { columnPicker("X axis · numeric", key: \.scatterX) }
        columnPicker(
          studio.project.kind == .scatter ? "Y axis · numeric" : "Measure", key: \.measure)
        if studio.project.kind != .scatter {
          labeled("Aggregate") {
            Picker("Aggregate", selection: studio.binding(\.aggregation)) {
              ForEach(Aggregation.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.labelsHidden()
          }
        } else {
          Text("Each dot is one source row. X and Y use numeric values; rows are not aggregated.")
            .font(.system(size: 11)).foregroundStyle(secondaryInk).lineSpacing(3)
        }
        labeled("Sort") {
          Picker("Sort", selection: studio.binding(\.sort)) {
            ForEach(SortOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }.labelsHidden()
        }
      }
      VStack(alignment: .leading, spacing: 13) {
        HStack {
          sectionLabel("D", "FILTER ROWS")
          Spacer()
          if !studio.project.filterValue.isEmpty {
            Button("Clear") { studio.binding(\.filterValue).wrappedValue = "" }
              .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(
                studio.project.theme.color)
          }
        }
        columnPicker("Column", key: \.filterColumn)
        HStack(spacing: 5) {
          Picker("Filter operation", selection: studio.binding(\.filterOperation)) {
            ForEach(FilterOperation.allCases, id: \.self) { Text($0.rawValue).tag($0) }
          }.labelsHidden().frame(width: 100)
          TextField("Any value", text: studio.binding(\.filterValue)).accessibilityLabel(
            "Filter value")
        }
        Text(studio.result.message ?? "\(studio.result.matchedRows.count) rows match this view")
          .font(.system(size: 11)).foregroundStyle(
            studio.result.message == nil ? secondaryInk : studio.project.theme.color
          )
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .controlSize(.regular)
  }

  private var designControls: some View {
    Group {
      VStack(alignment: .leading, spacing: 13) {
        sectionLabel("A", "THE HEADLINE")
        labeled("Title") {
          TextField("Your story’s title", text: studio.binding(\.title), axis: .vertical)
            .lineLimit(2...3).textFieldStyle(.roundedBorder).accessibilityLabel("Story title")
        }
        labeled("Subtitle") {
          TextField("A little context", text: studio.binding(\.subtitle), axis: .vertical)
            .lineLimit(2...3).textFieldStyle(.roundedBorder).accessibilityLabel("Story subtitle")
        }
        labeled("Source note") {
          TextField("Source", text: studio.binding(\.source), axis: .vertical)
            .lineLimit(2...3).textFieldStyle(.roundedBorder)
        }
        Text("The export mirrors this canvas. Keep your headline to two short lines.")
          .font(.system(size: 11)).foregroundStyle(secondaryInk).lineSpacing(3)
      }
      VStack(alignment: .leading, spacing: 12) {
        sectionLabel("B", "COLOR EDITION")
        ForEach(Theme.allCases, id: \.self) { theme in
          Button {
            studio.binding(\.theme).wrappedValue = theme
          } label: {
            HStack(spacing: 12) {
              Circle().fill(theme.color).frame(width: 21, height: 21)
              Text(theme.rawValue).font(.system(size: 12, weight: .medium))
              Spacer()
              if studio.project.theme == theme {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
              }
            }
            .padding(11).background(.white, in: RoundedRectangle(cornerRadius: 5))
            .overlay(
              RoundedRectangle(cornerRadius: 5).stroke(
                studio.project.theme == theme ? theme.color : ruleColor))
          }.buttonStyle(.plain)
        }
      }
      VStack(alignment: .leading, spacing: 14) {
        sectionLabel("C", "FINISHING TOUCHES")
        Toggle("Show values", isOn: studio.binding(\.showValues)).toggleStyle(.switch).font(
          .system(size: 12))
        Text("Warm paper. Quiet rules.\nA single, confident accent.")
          .font(.system(size: 13, design: .serif)).italic().foregroundStyle(secondaryInk)
          .lineSpacing(4)
          .padding(.vertical, 10)
        Button("Reset to cycling sample") { studio.loadSample("cycling") }.controlSize(.large)
        Text("Reset can be undone.").font(.system(size: 10)).foregroundStyle(secondaryInk)
      }
    }
  }

  private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(secondaryInk)
      content().frame(maxWidth: .infinity)
    }
  }

  private func columnPicker(_ label: String, key: WritableKeyPath<Project, Int>) -> some View {
    labeled(label) {
      Picker(label, selection: studio.binding(key)) {
        ForEach(studio.project.dataset.columns.indices, id: \.self) { index in
          Text(studio.project.dataset.columns[index]).tag(index)
        }
      }.labelsHidden()
    }
  }

  private var workspace: some View {
    VStack(spacing: 0) {
      HStack {
        Text("STORY CANVAS").font(.system(size: 10, weight: .semibold, design: .monospaced))
          .tracking(1.5)
        Spacer()
        Circle().fill(studio.project.theme.color).frame(width: 6, height: 6)
        Text("Live data").font(.system(size: 11)).foregroundStyle(secondaryInk)
        Text(" / ").foregroundStyle(ruleColor)
        Text("1040 × 740").font(.system(size: 10, design: .monospaced)).foregroundStyle(
          secondaryInk)
      }.padding(.horizontal, 30).padding(.top, 22).padding(.bottom, 10)
      GeometryReader { geometry in
        let width = min(geometry.size.width - 56, (geometry.size.height - 28) * 1040 / 740)
        ChartCanvas(project: studio.project) { studio.hovered = $0 }
          .frame(width: max(width, 1), height: max(width, 1) * 740 / 1040)
          .shadow(color: .black.opacity(0.09), radius: 15, x: 0, y: 6)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      HStack(spacing: 8) {
        Image(systemName: studio.hovered == nil ? "cursorarrow" : "scope")
        if let point = studio.hovered {
          Text(
            "\(point.label)  ·  \(Graphic.number(point.value))  ·  \(point.rowCount) source \(point.rowCount == 1 ? "row" : "rows")"
          )
          .fontWeight(.medium)
        } else {
          Text("Hover any mark to inspect its value")
        }
        Spacer()
        Text("\(studio.result.points.count) marks").font(.system(size: 10, design: .monospaced))
      }.font(.system(size: 11)).foregroundStyle(secondaryInk).padding(.horizontal, 30).padding(
        .vertical, 12)
      Divider()
      dataTable
    }
  }

  private var dataTable: some View {
    VStack(spacing: 0) {
      HStack(spacing: 13) {
        Button {
          showTable.toggle()
        } label: {
          HStack(spacing: 7) {
            Image(systemName: showTable ? "chevron.down" : "chevron.right")
            Text("SOURCE DATA")
          }.font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(0.6)
        }.buttonStyle(.plain).accessibilityLabel("Toggle source data")
        Text("\(studio.result.matchedRows.count) / \(studio.project.dataset.rows.count) rows")
          .font(.system(size: 11)).foregroundStyle(secondaryInk)
        Spacer()
        Text("Σ \(Graphic.number(studio.result.total))").font(
          .system(size: 13, weight: .semibold, design: .monospaced))
        Text("plotted values").font(.system(size: 10)).foregroundStyle(secondaryInk)
      }.padding(.horizontal, 24).padding(.vertical, 13)
      if showTable {
        ScrollView([.horizontal, .vertical]) {
          VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
              Text("#").frame(width: 42, alignment: .leading)
              ForEach(studio.project.dataset.columns.indices, id: \.self) { index in
                Text(studio.project.dataset.columns[index]).frame(width: 145, alignment: .leading)
              }
            }.font(.system(size: 10, weight: .semibold, design: .monospaced))
              .foregroundStyle(secondaryInk).padding(.vertical, 9)
            ForEach(Array(studio.result.matchedRows.prefix(100).enumerated()), id: \.offset) {
              offset, row in
              HStack(spacing: 0) {
                Text(String(offset + 1)).foregroundStyle(secondaryInk).frame(
                  width: 42, alignment: .leading)
                ForEach(row.indices, id: \.self) { index in
                  Text(row[index].replacingOccurrences(of: "\n", with: " ")).lineLimit(1)
                    .frame(width: 145, alignment: .leading)
                }
              }.font(.system(size: 11)).padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(offset % 2 == 0 ? shell.opacity(0.65) : .clear)
            }
            if studio.result.matchedRows.count > 100 {
              Text("Preview shows first 100 matching rows. Calculations include all rows.")
                .font(.system(size: 11)).foregroundStyle(secondaryInk).padding(.vertical, 8)
            }
          }.padding(.horizontal, 24)
        }.frame(height: 125)
      }
    }.background(Color.white.opacity(0.65))
  }

  private var footer: some View {
    HStack {
      Circle().fill(studio.error == nil ? Color(red: 0.18, green: 0.48, blue: 0.34) : .red).frame(
        width: 5, height: 5)
      Text(studio.notice).lineLimit(1)
      Spacer()
      Text("LOCAL FIRST").tracking(1)
      Text("·")
      Text("LOOM 1.0")
    }.font(.system(size: 10, design: .monospaced)).foregroundStyle(secondaryInk)
      .padding(.horizontal, 20).frame(height: 30).background(.white.opacity(0.6))
  }
}
