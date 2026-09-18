import SwiftUI

struct ShelfView: View {
  @EnvironmentObject private var store: PlantStore
  @State private var room: String?
  @State private var adding = false
  @State private var showSettings = false
  @State private var selectingRoom = false
  @Environment(\.dynamicTypeSize) private var typeSize

  private var visible: [Plant] { store.plants.filter { room == nil || $0.room == room } }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Eyebrow(text: typeSize.isAccessibilitySize ? "Sprout" : "A little greener, every day")
          Spacer()
          Button {
            showSettings = true
          } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: 44)
          }.accessibilityLabel("Shelf settings")
        }
        HStack(alignment: .bottom) {
          VStack(alignment: .leading, spacing: 8) {
            Text(typeSize.isAccessibilitySize ? "My shelf" : "Room to grow.")
              .font(.system(.largeTitle, design: .serif))
            if !typeSize.isAccessibilitySize {
              Text("Your own small corner of green.").font(.subheadline).foregroundStyle(
                Palette.muted)
            }
          }
          Spacer(minLength: 0)
          Button {
            adding = true
          } label: {
            Image(systemName: "plus").font(.title3).frame(width: 52, height: 52)
              .background(Palette.forest, in: Circle()).foregroundStyle(Palette.cream)
          }.accessibilityLabel("Add a plant")
        }
        if store.plants.contains(where: \.isSample) {
          HStack(spacing: 9) {
            Image(systemName: "sparkle")
            Text("Includes your starter collection.").font(.caption)
          }.foregroundStyle(Palette.muted)
        }
        Button {
          selectingRoom = true
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease")
            Text(room ?? "All plants").font(.subheadline.weight(.medium))
              .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Image(systemName: "chevron.down").font(.caption.weight(.semibold))
          }
          .padding(.horizontal, 16).padding(.vertical, 13)
          .background(Palette.sage.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityLabel("Filter by room, \(room ?? "All plants")")
        if visible.isEmpty {
          VStack(spacing: 14) {
            Botanical(kind: .monstera).frame(width: 190, height: 210)
            Text("Every shelf starts\nwith one plant.").font(.system(.title, design: .serif))
              .multilineTextAlignment(.center)
            Button("Add your first plant") { adding = true }.buttonStyle(PrimaryButton())
          }.padding(.vertical, 20)
        } else {
          LazyVGrid(
            columns: Array(
              repeating: GridItem(.flexible(), spacing: 20),
              count: typeSize.isAccessibilitySize ? 1 : 2), alignment: .leading, spacing: 22
          ) {
            ForEach(visible) { plant in
              NavigationLink {
                PlantDetailView(plantID: plant.id)
              } label: {
                VStack(alignment: .leading, spacing: 6) {
                  PlantPortrait(plant: plant).frame(
                    height: typeSize.isAccessibilitySize ? 230 : 160
                  )
                  .frame(maxWidth: .infinity).clipped()
                  Rectangle().fill(Palette.line).frame(height: 3)
                    .shadow(color: Palette.forest.opacity(0.12), radius: 4, y: 4)
                  HStack {
                    Text(plant.name).font(.system(.title3, design: .serif).weight(.medium))
                    Spacer(minLength: 0)
                  }
                  Text(plant.kind.rawValue).font(.caption).foregroundStyle(Palette.muted)
                  HStack(spacing: 4) {
                    Image(systemName: plant.daysUntilDue() <= 0 ? "drop.fill" : "drop")
                    Text(plant.status())
                  }
                  .font(.caption.weight(.medium))
                  .foregroundStyle(plant.daysUntilDue() < 0 ? Palette.terracotta : Palette.muted)
                }
                .contentShape(Rectangle())
              }.buttonStyle(.plain)
                .accessibilityLabel("\(plant.name), \(plant.kind.rawValue), \(plant.status())")
            }
          }
        }
        VStack(spacing: 16) {
          Rectangle().fill(Palette.line).frame(height: 1).accessibilityHidden(true)
          Eyebrow(text: "\(visible.count) little \(visible.count == 1 ? "life" : "lives")")
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 12)
      }.padding(.horizontal, 24).padding(.bottom, 20)
    }
    .clipped()
    .background(Palette.cream)
    .foregroundStyle(Palette.forest)
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $adding) { PlantEditor() }
    .sheet(isPresented: $showSettings) { ShelfSettings() }
    .sheet(isPresented: $selectingRoom) {
      NavigationStack {
        ScrollView {
          VStack(spacing: 0) {
            roomChoice(nil)
            ForEach(store.rooms, id: \.self) { roomChoice($0) }
          }.padding(24)
        }
        .background(Palette.cream).foregroundStyle(Palette.forest)
        .navigationTitle("Rooms").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { selectingRoom = false }
          }
        }
      }
    }
    .onChange(of: store.rooms) { _, rooms in
      if let room, !rooms.contains(room) { self.room = nil }
    }
  }

  private func roomChoice(_ value: String?) -> some View {
    Button {
      room = value
      selectingRoom = false
    } label: {
      HStack(spacing: 12) {
        Text(value ?? "All plants").font(.system(.title3, design: .serif))
          .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
        if room == value {
          Image(systemName: "checkmark").accessibilityHidden(true)
        }
      }
      .frame(minHeight: 44).padding(.vertical, 14).contentShape(Rectangle())
      .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
    .buttonStyle(.plain).accessibilityAddTraits(room == value ? .isSelected : [])
  }

}

struct ShelfSettings: View {
  @EnvironmentObject private var store: PlantStore
  @Environment(\.dismiss) private var dismiss
  @State private var confirm = false
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          Text("On this shelf").font(.system(.largeTitle, design: .serif))
          VStack(alignment: .leading, spacing: 12) {
            Label("Your private little garden", systemImage: "lock")
              .font(.system(.title3, design: .serif))
            Text(
              "Plants, notes, photos and watering history stay on this device. No account. No cloud service."
            ).foregroundStyle(Palette.muted)
          }
          Divider()
          VStack(alignment: .leading, spacing: 12) {
            Text("A rhythm, not a rule").font(.system(.title3, design: .serif))
            Text("Watering dates are gentle reminders to check the soil, never a command to water.")
              .foregroundStyle(Palette.muted)
          }
          if store.plants.contains(where: \.isSample) {
            Divider()
            VStack(alignment: .leading, spacing: 12) {
              Text("Starter collection").font(.system(.title3, design: .serif))
              Text(
                "Sunday, Olive, Cleo and Frida are sample plants. Add your own, or clear the samples for an empty shelf."
              ).foregroundStyle(Palette.muted)
              Button("Remove sample plants", role: .destructive) { confirm = true }
                .foregroundStyle(.red).frame(minHeight: 44)
            }
          }
          Divider()
          Eyebrow(text: "Made for slow growth")
        }.padding(26).lineSpacing(4)
      }.clipped().background(Palette.cream).foregroundStyle(Palette.forest)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        .alert("Remove the starter collection?", isPresented: $confirm) {
          Button("Remove sample plants", role: .destructive) { store.removeSamples() }
          Button("Cancel", role: .cancel) {}
        } message: {
          Text("Your own plants will stay. Sample notes and care history will be deleted.")
        }
    }
  }
}
