import SwiftUI

@main
struct CadenceApp: App {
  @StateObject private var store = CoachStore()
  @Environment(\.scenePhase) private var scenePhase
  var body: some Scene {
    WindowGroup {
      HomeView().environmentObject(store)
        .tint(Palette.ink)
        .onChange(of: scenePhase) { _, phase in
          if phase == .active { store.tick() }
          store.save()
        }
    }
  }
}

struct HomeView: View {
  @EnvironmentObject private var store: CoachStore
  @State private var selectedRoutine: Routine?
  @State private var editingRoutine: Routine?
  @State private var showHistory = false
  @State private var showSettings = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          HStack {
            HStack(spacing: 10) {
              CadenceMark(color: Palette.ink).scaleEffect(0.7).frame(width: 28)
              Text("CADENCE").font(.system(size: 17, weight: .semibold)).tracking(3)
                .fixedSize()
            }
            Spacer()
            Button {
              showSettings = true
            } label: {
              Image(systemName: "slider.horizontal.3").font(.system(size: 20))
                .frame(width: 44, height: 44)
            }.accessibilityLabel("Settings")
          }
          VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: "Make time for you").foregroundStyle(Palette.muted)
            Text("Find your\nnext gear.").instrumentDisplay(54).lineSpacing(-3)
          }
          if let first = store.routines.last(where: { !$0.isExample }) ?? store.routines.first {
            Button {
              selectedRoutine = first
            } label: {
              VStack(alignment: .leading, spacing: 14) {
                HStack {
                  Eyebrow(text: first.isExample ? "Featured routine" : "Your routine")
                  Spacer()
                  Image(systemName: "arrow.up.right")
                }.foregroundStyle(Palette.cream.opacity(0.8))
                IntervalSculpture().frame(height: 108).padding(.vertical, 4)
                Text(first.name).instrumentDisplay(32).foregroundStyle(Palette.cream)
                HStack {
                  Text("\(durationLabel(first.totalSeconds))  /  \(first.rounds) rounds")
                    .font(.subheadline).foregroundStyle(Palette.cream.opacity(0.7))
                  Spacer()
                  Image(systemName: "play.fill").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 42, height: 42).background(Palette.lime).clipShape(Circle())
                }
              }.padding(24).background(Palette.ink).clipShape(RoundedRectangle(cornerRadius: 26))
            }.buttonStyle(.plain).accessibilityLabel(
              "Open \(first.name), \(durationLabel(first.totalSeconds)), \(first.rounds) rounds")
          }
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Eyebrow(text: "Your routines")
              Spacer()
              Button {
                editingRoutine = .blank
              } label: {
                Label("New", systemImage: "plus").font(.subheadline.weight(.bold)).frame(
                  minHeight: 44)
              }.accessibilityLabel("New routine")
            }
            if store.routines.isEmpty {
              Text("A fresh start.\nBuild a rhythm that feels like you.")
                .font(.title3).padding(.vertical, 20)
            }
            ForEach(store.routines) { routine in
              Button {
                selectedRoutine = routine
              } label: {
                HStack(spacing: 16) {
                  Text(
                    String(
                      format: "%02d",
                      (store.routines.firstIndex(where: { $0.id == routine.id }) ?? 0) + 1)
                  )
                  .font(.system(.caption, design: .monospaced)).foregroundStyle(Palette.muted)
                  VStack(alignment: .leading, spacing: 5) {
                    Text(routine.name).font(.headline)
                    Text(
                      "\(routine.isExample ? "EXAMPLE · " : "")\(durationLabel(routine.totalSeconds)) · \(routine.rounds) rounds"
                    )
                    .font(.caption).foregroundStyle(Palette.muted)
                  }
                  Spacer()
                  Image(systemName: "arrow.up.right").font(.subheadline)
                }.padding(.vertical, 18).contentShape(Rectangle())
              }.buttonStyle(.plain)
              Rectangle().fill(Palette.ink.opacity(0.12)).frame(height: 1)
            }
          }
          Button {
            showHistory = true
          } label: {
            HStack {
              Image(systemName: "clock.arrow.circlepath").font(.title2)
              VStack(alignment: .leading, spacing: 4) {
                Text("Your training log").font(.headline)
                Text(
                  store.history.isEmpty
                    ? "Every effort starts somewhere." : "\(store.history.count) saved sessions"
                )
                .font(.caption).foregroundStyle(Palette.muted)
              }
              Spacer()
              Image(systemName: "arrow.right")
            }.padding(.vertical, 8)
          }.buttonStyle(.plain)
          Text("SHOW UP. FIND YOUR RHYTHM.").font(.system(size: 10, weight: .semibold)).tracking(2)
            .foregroundStyle(Palette.muted).frame(maxWidth: .infinity).padding(.bottom, 18)
        }.padding(.horizontal, 24).padding(.top, 10)
      }
      .background(Palette.cream).foregroundStyle(Palette.ink)
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(item: $selectedRoutine) { routine in
        RoutineDetail(routineID: routine.id)
      }
      .navigationDestination(isPresented: $showHistory) { HistoryView() }
      .sheet(item: $editingRoutine) { routine in RoutineEditor(routine: routine) }
      .sheet(isPresented: $showSettings) { SettingsView() }
      .fullScreenCover(isPresented: Binding(get: { store.session != nil }, set: { _ in })) {
        SessionView()
      }
      .alert(
        "Storage",
        isPresented: Binding(get: { store.saveError != nil }, set: { _ in store.saveError = nil })
      ) {
        Button("OK") { store.saveError = nil }
      } message: {
        Text(store.saveError ?? "")
      }
    }
  }
}

extension Routine: Hashable {
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct RoutineDetail: View {
  @EnvironmentObject private var store: CoachStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  let routineID: UUID
  @State private var editing: Routine?
  @State private var confirmDelete = false
  private var routine: Routine? { store.routines.first { $0.id == routineID } }
  var body: some View {
    Group {
      if let routine {
        ScrollView {
          VStack(alignment: .leading, spacing: 30) {
            Eyebrow(text: routine.isExample ? "Example routine / Make it yours" : "Your routine")
              .foregroundStyle(Palette.muted)
            Text(routine.name).instrumentDisplay(48)
            Text(routine.subtitle).font(.title3).foregroundStyle(Palette.muted)
            AdaptiveRow {
              Metric(value: clock(routine.totalSeconds), label: "TOTAL TIME")
              if !typeSize.isAccessibilitySize {
                Rectangle().fill(Palette.ink.opacity(0.15)).frame(width: 1, height: 42)
              }
              Metric(value: "\(routine.rounds)", label: "ROUNDS")
              if !typeSize.isAccessibilitySize {
                Rectangle().fill(Palette.ink.opacity(0.15)).frame(width: 1, height: 42)
              }
              Metric(value: "\(routine.intervals.count)", label: "INTERVALS")
            }.padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 18) {
              AdaptiveRow {
                Eyebrow(text: "The sequence")
                Spacer()
                Text("REPEAT ×\(routine.rounds)").font(.caption.weight(.bold)).foregroundStyle(
                  Palette.muted)
              }
              ForEach(Array(routine.intervals.enumerated()), id: \.element.id) { index, interval in
                AdaptiveRow(spacing: 16) {
                  RoundedRectangle(cornerRadius: 4).fill(
                    interval.kind == .work ? Palette.ink : Palette.rest
                  )
                  .frame(width: 6, height: 48)
                  VStack(alignment: .leading, spacing: 5) {
                    Text(interval.kind.title.uppercased()).font(.caption2.weight(.bold)).tracking(1)
                      .foregroundStyle(Palette.muted)
                    Text(interval.name).font(.headline)
                  }
                  Spacer()
                  Text(clock(interval.seconds)).instrumentDisplay(28)
                }
                .accessibilityElement(children: .combine)
              }
            }
            Text("Move in a way that works for you. Pause or end whenever you need.")
              .font(.footnote).foregroundStyle(Palette.muted)
            ActionButton(title: "Start session", symbol: "play.fill") { store.start(routine) }
          }.padding(24)
        }
      }
    }
    .background(Palette.cream).foregroundStyle(Palette.ink)
    .navigationTitle("Routine").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Edit routine", systemImage: "pencil") { editing = routine }
          Button("Delete routine", systemImage: "trash", role: .destructive) {
            confirmDelete = true
          }
        } label: {
          Image(systemName: "ellipsis").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Routine options")
      }
    }
    .sheet(item: $editing) { RoutineEditor(routine: $0) }
    .confirmationDialog(
      "Delete this routine?", isPresented: $confirmDelete, titleVisibility: .visible
    ) {
      Button("Delete routine", role: .destructive) {
        if let routine { store.delete(routine) }
        dismiss()
      }
    } message: {
      Text("Your training history will stay saved.")
    }
  }
}
