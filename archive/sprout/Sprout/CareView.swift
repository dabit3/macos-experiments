import SwiftUI

struct CareView: View {
  @EnvironmentObject private var store: PlantStore
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Eyebrow(text: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        Text("A moment\nof care.").font(.system(size: 44, design: .serif))
        Text("Feel the soil. Take your time.\nA little attention goes a long way.")
          .font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(4)
        if store.due.isEmpty {
          VStack(spacing: 10) {
            Botanical(kind: .fern).frame(width: 170, height: 185)
            Text("All caught up.").font(.system(.title2, design: .serif))
            Text("Enjoy the growing. Your next soil checks are below.").font(.subheadline)
              .multilineTextAlignment(.center).foregroundStyle(Palette.muted)
          }.frame(maxWidth: .infinity).padding(.vertical, 12)
        } else {
          Eyebrow(text: "Ready for a soil check · \(store.due.count)")
          ForEach(store.due) { careRow($0) }
        }
        if !store.upcoming.isEmpty {
          Eyebrow(text: "On the horizon").padding(.top, 10)
          ForEach(store.upcoming) { careRow($0) }
        }
        if store.plants.isEmpty {
          Text("Add a plant from My shelf to begin your care rhythm.").font(.body).foregroundStyle(
            Palette.muted)
        }
        Text(
          "A date is a reminder to check, not a reason to water. Cool rooms and winter light often mean less water."
        )
        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4).padding(.top, 8)
      }.padding(24)
    }
    .clipped()
    .background(Palette.cream).foregroundStyle(Palette.forest)
    .toolbar(.hidden, for: .navigationBar)
  }

  private func careRow(_ plant: Plant) -> some View {
    NavigationLink {
      PlantDetailView(plantID: plant.id)
    } label: {
      HStack(spacing: 14) {
        PlantPortrait(plant: plant).frame(width: 75, height: 90).clipped()
        VStack(alignment: .leading, spacing: 7) {
          Text(plant.name).font(.system(.title3, design: .serif))
          Text(plant.room).font(.caption).foregroundStyle(Palette.muted)
          Text(plant.status()).font(.caption.weight(.medium))
            .foregroundStyle(plant.daysUntilDue() < 0 ? Palette.terracotta : Palette.muted)
        }
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right").font(.subheadline)
      }.padding(.bottom, 10).contentShape(Rectangle()).overlay(alignment: .bottom) {
        Rectangle().fill(Palette.line).frame(height: 1)
      }
    }.buttonStyle(.plain)
  }
}

struct GuideView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Eyebrow(text: "The slow-growing library")
        Text("Good things\ntake tending.").font(.system(size: 42, design: .serif))
        Text("A small, offline guide to feeling at home with your plants.").font(.subheadline)
          .foregroundStyle(Palette.muted).lineSpacing(4)
        ForEach(Array(PlantKind.allCases.enumerated()), id: \.element) { index, kind in
          NavigationLink {
            GuideDetail(kind: kind)
          } label: {
            HStack(spacing: 16) {
              Botanical(kind: kind).frame(width: 90, height: 120)
              VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Field note 0\(index + 1)")
                Text(kind.rawValue).font(.system(.title2, design: .serif))
                Text(kind.light).font(.caption).foregroundStyle(Palette.muted)
              }
              Spacer(minLength: 0)
              Image(systemName: "arrow.right").font(.subheadline)
            }.padding(.vertical, 5).contentShape(Rectangle())
              .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
          }.buttonStyle(.plain)
        }
        Text(
          "General guidance, not a diagnosis. Check your plant’s exact species and local growing conditions."
        ).font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
      }.padding(24)
    }
    .clipped()
    .background(Palette.cream).foregroundStyle(Palette.forest)
    .toolbar(.hidden, for: .navigationBar)
  }
}

struct GuideDetail: View {
  var kind: PlantKind
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Botanical(kind: kind).frame(height: 280).frame(maxWidth: .infinity)
          .background(Palette.sage.opacity(0.5), in: RoundedRectangle(cornerRadius: 100))
        Eyebrow(text: kind.scientific)
        Text(kind.rawValue).font(.system(.largeTitle, design: .serif))
        section(
          "01 / Find its light",
          text: kind.light
            + ". Move gradually when changing the light it receives; sudden direct sun can scorch leaves."
        )
        section("02 / Water with intention", text: kind.water)
        section("03 / The little things", text: kind.note)
        Text(
          "These are starting points. Soil, drainage, season and your home’s light matter more than a fixed interval."
        )
        .font(.caption).foregroundStyle(Palette.muted).lineSpacing(4)
      }.padding(26)
    }.background(Palette.cream).foregroundStyle(Palette.forest)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .principal) { Eyebrow(text: "Field guide") } }
  }
  private func section(_ title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).font(.system(.title3, design: .serif))
      Text(text).font(.body).foregroundStyle(Palette.muted).lineSpacing(5)
    }
  }
}
