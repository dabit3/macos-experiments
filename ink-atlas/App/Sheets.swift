import SwiftUI

struct ElementEditor: View {
  @ObservedObject var store: BoardStore
  let element: BoardElement
  @State private var title: String
  @State private var detail: String
  @Environment(\.dismiss) private var dismiss
  @FocusState private var titleFocused: Bool

  init(store: BoardStore, element: BoardElement) {
    self.store = store
    self.element = element
    _title = State(initialValue: element.text)
    _detail = State(initialValue: element.detail)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack {
        VStack(alignment: .leading, spacing: 7) {
          Text("PUT IT INTO WORDS").font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(2)
          Text("A thought worth keeping.").font(.system(size: 30, weight: .regular, design: .serif))
        }
        Spacer()
        Button("Cancel") { dismiss() }.buttonStyle(SoftButtonStyle())
      }
      VStack(alignment: .leading, spacing: 9) {
        Text("THE IDEA").font(.system(size: 10, weight: .semibold)).tracking(1)
        TextField("Give this thought a name", text: $title, axis: .vertical)
          .font(.system(size: 23, weight: .medium)).lineLimit(1...3)
          .padding(17).background(.white, in: RoundedRectangle(cornerRadius: 12))
          .focused($titleFocused).accessibilityIdentifier("idea-title")
          .onChange(of: title) { _, value in
            if value.count > 160 { title = String(value.prefix(160)) }
          }
      }
      VStack(alignment: .leading, spacing: 9) {
        Text("A LITTLE MORE CONTEXT").font(.system(size: 10, weight: .semibold)).tracking(1)
        TextEditor(text: $detail)
          .font(.system(size: 17)).scrollContentBackground(.hidden)
          .padding(12).frame(height: 130).background(.white, in: RoundedRectangle(cornerRadius: 12))
          .accessibilityIdentifier("idea-detail")
          .onChange(of: detail) { _, value in
            if value.count > 500 { detail = String(value.prefix(500)) }
          }
      }
      HStack {
        Text("Make room for more words by resizing the object.")
          .font(.system(size: 11)).foregroundStyle(AtlasStyle.muted)
        Spacer()
        Button {
          store.apply { board in
            if let index = board.elements.firstIndex(where: { $0.id == element.id }) {
              board.elements[index].text = title.trimmingCharacters(in: .whitespacesAndNewlines)
              board.elements[index].detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            }
          }
          dismiss()
        } label: {
          Label("Keep thought", systemImage: "checkmark")
            .font(.system(size: 14, weight: .semibold)).padding(.horizontal, 20).padding(
              .vertical, 15
            )
            .background(AtlasStyle.ink, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(
              .white)
        }
        .buttonStyle(.plain).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        .accessibilityIdentifier("keep-thought")
      }
    }
    .padding(32).background(AtlasStyle.paper).foregroundStyle(AtlasStyle.ink)
    .presentationSizing(.fitted)
    .frame(idealWidth: 700)
  }
}

struct LibraryView: View {
  @ObservedObject var store: BoardStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 9) {
              Text("YOUR COLLECTION").font(
                .system(size: 10, weight: .semibold, design: .monospaced)
              ).tracking(2)
              Text("Places for your ideas.").font(
                .system(size: 35, weight: .regular, design: .serif))
              Text("Every board is saved privately on this iPad.")
                .font(.system(size: 13)).foregroundStyle(AtlasStyle.muted)
            }
            Spacer()
            Button {
              store.createBoard()
            } label: {
              Label("New board", systemImage: "plus").font(.system(size: 14, weight: .semibold))
                .padding(16).background(AtlasStyle.ink, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain).accessibilityIdentifier("new-board")
          }
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 20)], spacing: 25) {
            ForEach(store.boards) { board in
              Button {
                store.switchBoard(board)
              } label: {
                VStack(alignment: .leading, spacing: 0) {
                  Image(uiImage: BoardRenderer.thumbnail(board))
                    .resizable().aspectRatio(1.4, contentMode: .fit)
                    .overlay(alignment: .topTrailing) {
                      if board.id == store.board.id {
                        Text("OPEN").font(.system(size: 9, weight: .semibold, design: .monospaced))
                          .padding(9).background(AtlasStyle.ink, in: Capsule()).foregroundStyle(
                            .white
                          ).padding(13)
                      }
                    }
                  VStack(alignment: .leading, spacing: 7) {
                    Text(board.title).font(.system(size: 22, weight: .regular, design: .serif))
                      .lineLimit(1)
                    HStack {
                      Text("\(board.elements.count) objects")
                      Spacer()
                      Text(board.updated, style: .date)
                    }
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(AtlasStyle.muted)
                  }
                  .padding(20).frame(maxWidth: .infinity, alignment: .leading).background(
                    AtlasStyle.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AtlasStyle.border, lineWidth: 1))
              }
              .buttonStyle(.plain).accessibilityLabel("Open \(board.title)")
            }
          }
        }
        .padding(30)
      }
      .background(AtlasStyle.paper).foregroundStyle(AtlasStyle.ink)
      .navigationTitle("Your boards")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
      }
    }
    .presentationSizing(.page)
  }
}

struct ExportView: View {
  @ObservedObject var store: BoardStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 25) {
      HStack {
        VStack(alignment: .leading, spacing: 8) {
          Text("OUT INTO THE WORLD").font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(2)
          Text("Good ideas travel.").font(.system(size: 34, design: .serif))
        }
        Spacer()
        Button("Done") { dismiss() }.buttonStyle(SoftButtonStyle())
      }
      Image(uiImage: BoardRenderer.thumbnail(store.board))
        .resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 235)
        .background(AtlasStyle.paper).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AtlasStyle.border))
      HStack(spacing: 16) {
        exportButton(
          title: "Create PDF", subtitle: "A crisp, printable page", symbol: "doc.richtext",
          pdf: true)
        exportButton(
          title: "Create SVG", subtitle: "Editable vector artwork",
          symbol: "point.topleft.down.to.point.bottomright.curvepath", pdf: false)
      }
      if let url = store.latestExport {
        HStack(spacing: 12) {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: "#527565"))
          VStack(alignment: .leading, spacing: 5) {
            Text("Export saved").font(.system(size: 14, weight: .semibold))
            Text(url.lastPathComponent).font(.system(size: 10, design: .monospaced)).lineLimit(2)
              .foregroundStyle(AtlasStyle.muted)
          }
          Spacer()
          ShareLink(item: url) {
            Label("Share / save to Files", systemImage: "square.and.arrow.up")
          }
          .buttonStyle(SoftButtonStyle())
        }
        .padding(17).background(.white, in: RoundedRectangle(cornerRadius: 12))
      } else {
        Text(
          "Your full board, without the tools or selection handles.\nExports are saved in Ink Atlas → Exports and can be shared to Files."
        )
        .font(.system(size: 12)).lineSpacing(5).foregroundStyle(AtlasStyle.muted)
      }
    }
    .padding(30).frame(idealWidth: 700).background(AtlasStyle.paper).foregroundStyle(AtlasStyle.ink)
    .presentationSizing(.fitted)
  }

  private func exportButton(title: String, subtitle: String, symbol: String, pdf: Bool) -> some View
  {
    Button {
      store.export(pdf: pdf)
    } label: {
      HStack(spacing: 14) {
        Image(systemName: symbol).font(.system(size: 25, weight: .light))
        VStack(alignment: .leading, spacing: 7) {
          Text(title).font(.system(size: 16, weight: .semibold))
          Text(subtitle).font(.system(size: 11)).foregroundStyle(AtlasStyle.muted)
        }
        Spacer()
        Image(systemName: "arrow.down").font(.system(size: 15))
      }
      .padding(20).background(AtlasStyle.white, in: RoundedRectangle(cornerRadius: 13))
      .overlay(RoundedRectangle(cornerRadius: 13).stroke(AtlasStyle.border))
    }
    .buttonStyle(.plain)
  }
}

struct HelpView: View {
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    VStack(alignment: .leading, spacing: 23) {
      HStack {
        Text("A field guide to Ink Atlas").font(.system(size: 31, design: .serif))
        Spacer()
        Button("Done") { dismiss() }.buttonStyle(SoftButtonStyle())
      }
      guide(
        "pencil.tip", "Make a mark",
        "Choose Draw and drag with a finger, mouse or Apple Pencil. Three stroke widths, five thoughtful colors."
      )
      guide(
        "rectangle.on.rectangle", "Give an idea a home",
        "Tap Card, Ellipse or Text, then the paper. Drag while placing a shape to set its size. Double-tap an object to edit its words."
      )
      guide(
        "arrow.up.right", "Connect the dots",
        "Choose Connect. Tap a source object, then a destination. Move either one; the arrow stays attached."
      )
      guide(
        "cursorarrow", "Keep things moving",
        "Select an object and drag. Pull the larger lower-right handle to resize. Use the toolbox to change its color, disconnect or delete."
      )
      guide(
        "hand.draw", "See the bigger picture",
        "Hand pans the canvas. Pinch or use − / + to zoom. Fit brings the whole board home. Undo and Redo work across edits."
      )
      guide(
        "square.and.arrow.up", "Take it with you",
        "Boards save automatically on this iPad. Export creates real PDF or SVG files. Use Share to send them to Files or another app."
      )
      Text("Hardware keyboard: ⌘Z Undo · ⇧⌘Z Redo · Delete removes selection")
        .font(.system(size: 11, design: .monospaced)).foregroundStyle(AtlasStyle.muted)
    }
    .padding(32).frame(idealWidth: 750).background(AtlasStyle.paper).foregroundStyle(AtlasStyle.ink)
    .presentationSizing(.fitted)
  }

  private func guide(_ symbol: String, _ title: String, _ detail: String) -> some View {
    HStack(alignment: .top, spacing: 18) {
      Image(systemName: symbol).font(.system(size: 24, weight: .light)).frame(width: 32)
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(.system(size: 16, weight: .semibold))
        Text(detail).font(.system(size: 13)).lineSpacing(3).foregroundStyle(AtlasStyle.muted)
      }
    }
  }
}
