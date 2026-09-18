import SwiftUI

struct LibraryView: View {
  @EnvironmentObject private var journal: Journal
  @Environment(\.dynamicTypeSize) private var dynamicType
  @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 44.0
  @State private var tab = 0
  @State private var addingJourney = false
  @State private var showingPassport = false

  var body: some View {
    TabView(selection: $tab) {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            HStack {
              Eyebrow(text: "ELSEWHERE", color: Ink.blue)
              Spacer()
              Button {
                showingPassport = true
              } label: {
                Image(systemName: "person.crop.square").font(.title3)
                  .frame(width: 44, height: 44)
              }
              .accessibilityLabel("Your passport and settings")
            }
            HStack(alignment: .top) {
              Text("The places\nwe keep.")
                .font(.system(size: titleSize, weight: .regular, design: .serif))
                .tracking(-1.8).foregroundStyle(Ink.navy)
                .accessibilityAddTraits(.isHeader)
              if !dynamicType.isAccessibilitySize {
                Spacer()
                Stamp().padding(.top, 16)
              }
            }
            HStack {
              Eyebrow(
                text:
                  "\(journal.journeys.count) \(journal.journeys.count == 1 ? "journey" : "journeys") · collected with love",
                color: Ink.muted)
              Spacer(minLength: 0)
            }
            Button {
              addingJourney = true
            } label: {
              Label(
                dynamicType.isAccessibilitySize ? "New journey" : "Begin a journey",
                systemImage: "plus")
            }
            .buttonStyle(PaperButton())
            if journal.journeys.isEmpty {
              EmptyJournal(
                title: "Your next chapter starts here.",
                detail: "A weekend away or a journey of a lifetime. Keep the little things.")
            }
            ForEach(Array(journal.journeys.enumerated()), id: \.element.id) { index, trip in
              NavigationLink {
                JourneyView(journeyID: trip.id)
              } label: {
                JourneyCover(journey: trip, number: index + 1)
              }
              .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
              Image(systemName: "lock").font(.caption)
              Text("Your memories stay on this device.").font(.caption)
            }
            .foregroundStyle(Ink.muted).frame(maxWidth: .infinity).padding(.vertical, 12)
          }
          .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 20)
        }
        .background(Ink.paper).toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $addingJourney) { JourneyEditor() }
        .sheet(isPresented: $showingPassport) { PassportView() }
      }
      .tabItem { Label("Journeys", systemImage: "book.closed") }.tag(0)
      NavigationStack {
        SavedView()
      }
      .tabItem { Label("Saved", systemImage: "heart") }.tag(1)
    }
    .tint(Ink.blue)
  }
}

struct JourneyCover: View {
  var journey: Journey
  var number: Int
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .topLeading) {
        Landscape(style: journey.style).frame(height: 205)
        Eyebrow(text: "VOL. \(String(format: "%02d", number))", color: Ink.navy)
          .padding(.horizontal, 12).padding(.vertical, 8)
          .background(Ink.paper)
          .padding(15)
      }
      VStack(alignment: .leading, spacing: 9) {
        Eyebrow(text: journey.region.isEmpty ? "Somewhere worth remembering" : journey.region)
        HStack {
          Text(journey.title).font(.system(.title, design: .serif))
            .foregroundStyle(Ink.navy)
          Spacer()
          Image(systemName: "arrow.up.right").foregroundStyle(Ink.blue)
        }
        HStack {
          Text(journey.dateLabel).font(.caption).foregroundStyle(Ink.muted)
          Spacer()
          Text(journey.stopCountLabel).font(.caption).foregroundStyle(Ink.muted)
        }
        Divider().overlay(Ink.pale)
        Eyebrow(
          text: journey.isSample ? "Sample journey · illustrated" : "Personal journal",
          color: Ink.blue)
      }
      .padding(18).background(Color(hex: 0xFFFBF2))
    }
    .clipShape(RoundedRectangle(cornerRadius: 3))
    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Ink.navy.opacity(0.1)))
    .shadow(color: Ink.navy.opacity(0.08), radius: 8, x: 0, y: 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(journey.title), \(journey.stopCountLabel)\(journey.isSample ? ", sample journey" : "")")
  }
}

struct SavedView: View {
  @EnvironmentObject private var journal: Journal
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Eyebrow(text: "Close to the heart", color: Ink.blue)
        Text("Little treasures.").font(.system(.largeTitle, design: .serif)).foregroundStyle(
          Ink.navy)
        Text("The moments you want to come back to.").foregroundStyle(Ink.muted).font(.subheadline)
        if journal.favorites.isEmpty {
          EmptyJournal(
            title: "Keep a little wonder.", detail: "Tap the heart on any stop to collect it here.")
        }
        ForEach(journal.favorites, id: \.memory.id) { item in
          NavigationLink {
            MemoryView(journeyID: item.journey.id, memoryID: item.memory.id)
          } label: {
            VStack(alignment: .leading, spacing: 12) {
              MemoryArt(photo: item.memory.photo, style: item.journey.style).frame(height: 190)
              HStack {
                VStack(alignment: .leading, spacing: 5) {
                  Text(item.memory.place).font(.system(.title2, design: .serif)).foregroundStyle(
                    Ink.navy)
                  Eyebrow(text: item.journey.title, color: Ink.muted)
                }
                Spacer()
                Image(systemName: "heart.fill").foregroundStyle(Ink.red)
              }
            }
            .padding(12).background(.white).rotationEffect(.degrees(-1))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(24)
    }
    .background(Ink.paper).navigationTitle("Saved").navigationBarTitleDisplayMode(.inline)
    .journalNavigation()
  }
}

struct PassportView: View {
  @EnvironmentObject private var journal: Journal
  @Environment(\.dismiss) private var dismiss
  @State private var restoring = false
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          Stamp(text: "GO SLOW\nLOOK CLOSE")
          Text("A passport to\nyour own life.")
            .font(.system(.largeTitle, design: .serif)).foregroundStyle(Ink.navy)
          Text("Elsewhere is a small home for the places that stay with you.")
            .font(.body).foregroundStyle(Ink.muted)
          Divider()
          Label("Entirely on your device", systemImage: "lock")
            .font(.headline).foregroundStyle(Ink.blue)
          Text(
            "Journeys, notes and imported photos are stored locally. There are no accounts, ads, or network maps. Deleting the app also deletes its journal. Export postcards to keep a shareable copy."
          )
          .font(.subheadline).foregroundStyle(Ink.navy)
          Label("Illustrated, not navigational", systemImage: "map")
            .font(.headline).foregroundStyle(Ink.blue)
          Text(
            "Sample journeys are fictional examples. All cover art is original. Routes show stop order on a decorative diagram, not geographic locations."
          )
          .font(.subheadline).foregroundStyle(Ink.navy)
          Button("Restore sample journeys") { restoring = true }
            .buttonStyle(PaperButton(secondary: true))
          Text("This replaces sample journeys only. Your personal journeys stay safe.")
            .font(.caption).foregroundStyle(Ink.muted)
          Eyebrow(text: "Elsewhere · edition 01", color: Ink.muted)
        }
        .padding(26)
      }
      .background(Ink.paper).navigationTitle("Your passport").navigationBarTitleDisplayMode(.inline)
      .journalNavigation()
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
      .confirmationDialog(
        "Restore the original samples?", isPresented: $restoring, titleVisibility: .visible
      ) {
        Button("Restore samples", role: .destructive) { journal.restoreSamples() }
      } message: {
        Text("Edits to sample journeys will be replaced. Personal journeys are kept.")
      }
    }
  }
}
