import SwiftUI

struct JourneyView: View {
  @EnvironmentObject private var journal: Journal
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicType
  @State private var mode = 0
  @State private var editing = false
  @State private var addingStop = false
  @State private var reordering = false
  @State private var deleting = false
  let journeyID: UUID

  var body: some View {
    Group {
      if let trip = journal.journey(journeyID) {
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            Landscape(style: trip.style).frame(height: dynamicType.isAccessibilitySize ? 110 : 175)
              .overlay(alignment: .bottomTrailing) {
                Eyebrow(text: "Original illustration", color: Ink.navy)
                  .padding(8).background(Ink.paper.opacity(0.9)).padding(12)
              }
            VStack(alignment: .leading, spacing: 20) {
              Eyebrow(text: trip.region.isEmpty ? "A personal journey" : trip.region)
              Text(trip.title).font(.system(.largeTitle, design: .serif)).foregroundStyle(Ink.navy)
                .accessibilityAddTraits(.isHeader)
              HStack {
                Text(trip.dateLabel).font(.subheadline).foregroundStyle(Ink.muted)
                Spacer()
                if trip.isSample { Eyebrow(text: "Sample", color: Ink.blue) }
              }
              if !trip.stops.isEmpty {
                Picker("Journal view", selection: $mode) {
                  Text("Journal").tag(0)
                  Text("Route").tag(1)
                }
                .pickerStyle(.segmented)
              }
              if trip.stops.isEmpty {
                EmptyJournal(
                  title: "Every journey starts somewhere.",
                  detail: "Add a place, a date and a little detail you don't want to forget.")
              } else if mode == 0 {
                ForEach(Array(trip.stops.enumerated()), id: \.element.id) { index, stop in
                  NavigationLink {
                    MemoryView(journeyID: journeyID, memoryID: stop.id)
                  } label: {
                    JournalRow(memory: stop, index: index, style: trip.style)
                  }
                  .buttonStyle(.plain)
                }
              } else {
                RouteView(journey: trip)
              }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
          }
        }
        .background(Ink.paper)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          ActionShelf {
            Button {
              addingStop = true
            } label: {
              Label("Add a stop", systemImage: "plus")
            }
          }
        }
        .sheet(isPresented: $editing) { JourneyEditor(existing: trip) }
        .sheet(isPresented: $addingStop) { MemoryEditor(journeyID: journeyID) }
        .sheet(isPresented: $reordering) { ReorderView(journeyID: journeyID) }
      } else {
        EmptyJournal(
          title: "This chapter has closed.", detail: "Return to your journeys to begin another.")
      }
    }
    .navigationTitle("The journal").navigationBarTitleDisplayMode(.inline)
    .journalNavigation()
    .toolbar(.hidden, for: .tabBar)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Edit journey", systemImage: "pencil") { editing = true }
          Button("Reorder stops", systemImage: "arrow.up.arrow.down") { reordering = true }
          Button("Delete journey", systemImage: "trash", role: .destructive) { deleting = true }
        } label: {
          Image(systemName: "ellipsis").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Journey options")
      }
    }
    .confirmationDialog("Delete this journey?", isPresented: $deleting, titleVisibility: .visible) {
      Button("Delete journey", role: .destructive) {
        if journal.deleteJourney(journeyID) { dismiss() }
      }
    } message: {
      Text("Its stops, notes and photos will be removed from this device.")
    }
  }
}

struct JournalRow: View {
  let memory: Memory
  let index: Int
  let style: JourneyStyle
  var body: some View {
    HStack(alignment: .top, spacing: 15) {
      VStack(spacing: 8) {
        Text(String(format: "%02d", index + 1))
          .font(.system(.caption, design: .monospaced)).foregroundStyle(Ink.red)
        Rectangle().fill(Ink.red.opacity(0.28)).frame(width: 1)
      }
      .frame(width: 26)
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Eyebrow(
            text: memory.date.formatted(.dateTime.month(.abbreviated).day()), color: Ink.muted)
          Spacer()
          if memory.isFavorite {
            Image(systemName: "heart.fill").font(.caption).foregroundStyle(Ink.red)
          }
        }
        HStack {
          Text(memory.place).font(.system(.title2, design: .serif)).foregroundStyle(Ink.navy)
          Spacer(minLength: 8)
          Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Ink.blue)
        }
        if !memory.note.isEmpty {
          Text(memory.note).font(.subheadline).lineSpacing(4)
            .foregroundStyle(Ink.muted).lineLimit(3)
        }
        if memory.photo != nil {
          MemoryArt(photo: memory.photo, style: style).frame(height: 140)
            .padding(7).background(.white)
        }
        Divider().padding(.top, 8)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityElement(children: .combine)
  }
}

struct RouteView: View {
  var journey: Journey
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 14) {
        Eyebrow(text: "The way we wandered", color: Ink.blue)
        ZStack {
          RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0xDFE5D6))
          Canvas { context, size in
            for i in 0..<12 {
              var path = Path()
              let y = CGFloat(i) * size.height / 10
              path.move(to: CGPoint(x: -10, y: y))
              path.addCurve(
                to: CGPoint(x: size.width + 10, y: y + 35),
                control1: CGPoint(x: size.width * 0.3, y: y - 30),
                control2: CGPoint(x: size.width * 0.7, y: y + 90))
              context.stroke(path, with: .color(Ink.navy.opacity(0.07)), lineWidth: 1)
            }
            if journey.stops.count > 1 {
              var route = Path()
              route.addLines((0...60).map { RouteGeometry.point(at: CGFloat($0) / 60, size: size) })
              context.stroke(
                route, with: .color(Ink.blue), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
          }
          ForEach(0..<min(journey.stops.count, 5), id: \.self) { index in
            GeometryReader { geo in
              Text("\(index + 1)").font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white).frame(width: 28, height: 28)
                .background(Ink.blue, in: Circle())
                .overlay(Circle().stroke(Ink.paper, lineWidth: 3))
                .position(
                  RouteGeometry.point(
                    at: CGFloat(index) / CGFloat(max(1, min(journey.stops.count, 5) - 1)),
                    size: geo.size))
            }
          }
          VStack {
            HStack {
              Eyebrow(text: "A trail of memories", color: Ink.blue)
              Spacer()
            }
            Spacer()
            HStack {
              Spacer()
              Eyebrow(text: "\(journey.stopCountLabel) · one story", color: Ink.blue)
            }
          }.padding(18)
        }
        .frame(height: 230).accessibilityHidden(true)
        Text(
          "Illustrated route · not a geographic map\(journey.stops.count > 5 ? " · first 5 stops shown" : "")"
        )
        .font(.caption).foregroundStyle(Ink.muted)
      }
      ForEach(Array(journey.stops.enumerated()), id: \.element.id) { index, stop in
        NavigationLink {
          MemoryView(journeyID: journey.id, memoryID: stop.id)
        } label: {
          HStack(spacing: 15) {
            Text(String(format: "%02d", index + 1))
              .font(.system(.subheadline, design: .monospaced)).foregroundStyle(Ink.red)
            VStack(alignment: .leading, spacing: 4) {
              Text(stop.place).font(.system(.title3, design: .serif)).foregroundStyle(Ink.navy)
              Text(stop.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption).foregroundStyle(Ink.muted)
            }
            Spacer()
            Image(systemName: "arrow.up.right").foregroundStyle(Ink.blue)
          }
          .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

enum RouteGeometry {
  static func point(at t: CGFloat, size: CGSize) -> CGPoint {
    let u = 1 - t
    let x = u * u * u * 0.16 + 3 * u * u * t * 0.90 + 3 * u * t * t * 0.10 + t * t * t * 0.84
    let y = u * u * u * 0.74 + 3 * u * u * t * 0.88 + 3 * u * t * t * 0.08 + t * t * t * 0.26
    return CGPoint(x: x * size.width, y: y * size.height)
  }
}

struct ReorderView: View {
  @EnvironmentObject private var journal: Journal
  @Environment(\.dismiss) private var dismiss
  let journeyID: UUID
  var body: some View {
    NavigationStack {
      List {
        Section {
          if let trip = journal.journey(journeyID) {
            ForEach(Array(trip.stops.enumerated()), id: \.element.id) { index, stop in
              HStack {
                Text("\(index + 1)").foregroundStyle(Ink.red).font(
                  .system(.caption, design: .monospaced))
                Text(stop.place).font(.system(.body, design: .serif))
                Spacer()
                Button {
                  journal.moveMemory(stop.id, in: journeyID, by: -1)
                } label: {
                  Image(systemName: "arrow.up").frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless).disabled(index == 0)
                .accessibilityLabel("Move \(stop.place) earlier")
                Button {
                  journal.moveMemory(stop.id, in: journeyID, by: 1)
                } label: {
                  Image(systemName: "arrow.down").frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless).disabled(index == trip.stops.count - 1)
                .accessibilityLabel("Move \(stop.place) later")
              }
            }
          }
        } footer: {
          Text("Tell the story your way. Order changes save immediately; dates stay the same.")
        }
      }
      .scrollContentBackground(.hidden).background(Ink.paper)
      .navigationTitle("Order of adventures").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
}
