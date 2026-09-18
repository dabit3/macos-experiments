import SwiftUI

struct HerbariumView: View {
  @EnvironmentObject private var store: GardenStore
  @Environment(\.dynamicTypeSize) private var textSize
  @State private var filter = "All"
  private let filters = ["All", "Focus", "Previews"]
  private var specimens: [Specimen] {
    store.data.specimens.filter {
      filter == "All" || ($0.isPreview ? filter == "Previews" : filter == "Focus")
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HStack {
            Eyebrow(text: "The personal collection")
            Spacer()
            Text(String(format: "%02d", store.data.specimens.count))
              .font(.system(.subheadline, design: .monospaced))
          }
          Text("Your herbarium")
            .modifier(EditorialHeading(size: 38))
          Text("Small moments, made tangible.")
            .font(.subheadline).foregroundStyle(Palette.muted)
          Picker("Sessions", selection: $filter) {
            ForEach(filters, id: \.self) { Text($0) }
          }
          .pickerStyle(.segmented)
          if specimens.isEmpty {
            VStack(spacing: 15) {
              Botanical(growth: 0.35).frame(height: 200)
              Text(
                filter == "All" ? "A garden begins with one moment." : "Nothing planted here yet."
              )
              .font(.system(.title2, design: .serif)).multilineTextAlignment(.center)
              Text(
                "Complete a ritual to press your first specimen.\nPreview plants are always labeled."
              )
              .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
          } else {
            LazyVGrid(
              columns: specimens.count == 1 || textSize >= .xxxLarge
                ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())],
              spacing: 16
            ) {
              ForEach(specimens) { specimen in
                NavigationLink {
                  SpecimenDetail(specimenID: specimen.id)
                } label: {
                  VStack(alignment: .leading, spacing: 10) {
                    HStack {
                      Eyebrow(text: String(format: "No. %03d", number(specimen)))
                      Spacer(minLength: 0)
                      if specimens.count == 1 && !textSize.isAccessibilitySize {
                        Eyebrow(text: "A moment preserved")
                      }
                    }
                    Botanical(species: specimen.species).frame(
                      height: specimens.count == 1 ? 250 : 170)
                    if specimens.count == 1 {
                      Divider()
                      Text(Botany.latin[specimen.species])
                        .font(.system(.caption, design: .serif).italic())
                        .foregroundStyle(Palette.muted)
                    }
                    Text(Botany.names[specimen.species])
                      .font(.system(.title3, design: .serif))
                      .fixedSize(horizontal: false, vertical: true)
                    Text(specimen.intention).font(.caption)
                      .fixedSize(horizontal: false, vertical: true)
                    Text(
                      specimen.isPreview
                        ? "20 SEC · PREVIEW" : "\(Int(specimen.duration / 60)) MIN · FOCUS"
                    )
                    .font(.system(.caption2, design: .monospaced)).tracking(0.5)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(specimen.completedAt, format: .dateTime.month(.abbreviated).day())
                      .font(.caption2).foregroundStyle(Palette.muted)
                  }
                  .padding(15)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(.white.opacity(0.36))
                  .overlay(Rectangle().stroke(Palette.line, lineWidth: 0.75))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                  "\(Botany.names[specimen.species]), \(specimen.intention), \(specimen.isPreview ? "preview" : "focus session")"
                )
              }
            }
          }
        }
        .padding(26)
      }
      .modifier(Paper())
      .toolbar(.hidden, for: .navigationBar)
    }
  }

  private func number(_ specimen: Specimen) -> Int {
    store.data.specimens.count - (store.data.specimens.firstIndex { $0.id == specimen.id } ?? 0)
  }
}

struct SpecimenDetail: View {
  @EnvironmentObject private var store: GardenStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var textSize
  let specimenID: UUID
  @State private var edit = false
  @State private var delete = false
  private var specimen: Specimen? { store.data.specimens.first { $0.id == specimenID } }

  var body: some View {
    ScrollView {
      if let specimen {
        VStack(alignment: .leading, spacing: 20) {
          Eyebrow(text: specimen.isPreview ? "Preview specimen" : "A moment preserved")
          Text(Botany.names[specimen.species]).modifier(EditorialHeading(size: 42))
          Text(Botany.latin[specimen.species]).font(.system(.body, design: .serif).italic())
            .foregroundStyle(Palette.muted)
          Botanical(species: specimen.species).frame(height: 300)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.35))
            .overlay(Rectangle().stroke(Palette.line, lineWidth: 0.75))
          (textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))) {
              Text(specimen.intention).font(.system(.title2, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
              if !textSize.isAccessibilitySize { Spacer() }
              Text(specimen.isPreview ? "20 sec" : "\(Int(specimen.duration / 60)) min")
                .font(.system(.title2, design: .serif)).fixedSize()
            }
          Text(
            specimen.completedAt,
            format: .dateTime.weekday(.wide).month(.wide).day().hour().minute()
          )
          .font(.subheadline).foregroundStyle(Palette.muted)
          if specimen.isPreview {
            Text(
              "A real 20-second preview. This plant is kept in your collection, but doesn’t count toward mindful minutes."
            )
            .font(.footnote).foregroundStyle(Palette.muted)
          }
          Divider()
          Eyebrow(text: "Field notes")
          Text(specimen.note.isEmpty ? "What did this time make room for?" : specimen.note)
            .font(.system(.body, design: .serif))
          PrimaryButton(
            title: specimen.note.isEmpty ? "Add a reflection" : "Edit reflection", icon: "pencil"
          ) {
            edit = true
          }
          Button("Remove specimen", role: .destructive) { delete = true }
            .font(.subheadline).frame(minHeight: 44)
        }
        .padding(26)
      }
    }
    .modifier(Paper())
    .navigationTitle("Field notes")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
    .sheet(isPresented: $edit) {
      if let specimen { EditSpecimen(specimen: specimen) }
    }
    .alert("Remove this specimen?", isPresented: $delete) {
      Button("Remove permanently", role: .destructive) {
        store.delete(specimenID)
        dismiss()
      }
      Button("Keep specimen", role: .cancel) {}
    } message: {
      Text("Its session will also be removed from your daily totals.")
    }
  }
}

struct EditSpecimen: View {
  @EnvironmentObject private var store: GardenStore
  @Environment(\.dismiss) private var dismiss
  let specimen: Specimen
  @State private var intention = ""
  @State private var note = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("Intention") {
          TextField("Intention", text: $intention, axis: .vertical)
            .lineLimit(1...4)
            .onChange(of: intention) { _, value in intention = String(value.prefix(60)) }
        }
        Section("A note to your future self") {
          TextEditor(text: $note).frame(minHeight: 150)
            .accessibilityLabel("Reflection")
            .onChange(of: note) { _, value in note = String(value.prefix(500)) }
          Text("\(note.count) / 500").font(.caption).foregroundStyle(Palette.muted)
        }
      }
      .scrollContentBackground(.hidden)
      .modifier(Paper())
      .navigationTitle("Reflection")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            store.edit(specimen, intention: intention, note: note)
            dismiss()
          }
          .disabled(intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onAppear {
        intention = specimen.intention
        note = specimen.note
      }
    }
  }
}
