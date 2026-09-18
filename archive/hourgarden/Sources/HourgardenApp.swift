import SwiftUI

@main
struct HourgardenApp: App {
  @StateObject private var store = GardenStore()
  var body: some Scene {
    WindowGroup {
      GardenRoot().environmentObject(store)
    }
  }
}

struct GardenRoot: View {
  @EnvironmentObject private var store: GardenStore
  @Environment(\.scenePhase) private var scenePhase
  @State private var tab = 0
  private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

  var body: some View {
    ZStack {
      TabView(selection: $tab) {
        RitualView().tabItem { Label("Ritual", systemImage: "leaf") }.tag(0)
        HerbariumView().tabItem { Label("Herbarium", systemImage: "book.closed") }.tag(1)
        RhythmView().tabItem { Label("Rhythm", systemImage: "sun.max") }.tag(2)
      }
      .tint(Palette.ink)
      if let specimen = store.celebration {
        CompletionView(specimen: specimen) {
          store.dismissCelebration()
          tab = 1
        }
        .transition(.opacity)
        .zIndex(2)
      }
    }
    .modifier(Paper())
    .onReceive(ticker) { date in store.synchronize(at: date) }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { store.synchronize() }
    }
    .onAppear { store.synchronize() }
  }
}

struct RitualView: View {
  @EnvironmentObject private var store: GardenStore
  @State private var configure = false
  @State private var settings = false
  @State private var cancel = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 0) {
          HStack {
            Eyebrow(text: "Hourgarden")
            Spacer()
            Button {
              settings = true
            } label: {
              Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
          }
          .padding(.top, 4)
          if let ritual = store.data.active {
            active(ritual)
          } else {
            resting
          }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
      }
      .modifier(Paper())
      .toolbar(.hidden, for: .navigationBar)
      .sheet(isPresented: $configure) { ConfigureView() }
      .sheet(isPresented: $settings) { SettingsView() }
      .alert("Leave this ritual?", isPresented: $cancel) {
        Button("End without planting", role: .destructive) { store.cancel() }
        Button("Keep growing", role: .cancel) {}
      } message: {
        Text("This session won’t be added to your herbarium.")
      }
    }
  }

  private var resting: some View {
    VStack(spacing: 0) {
      HStack {
        Text("A little time.\nA little growth.")
          .modifier(EditorialHeading(size: 41))
          .tracking(-1.5)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }
      .padding(.top, 13)
      .padding(.bottom, 4)
      HStack {
        Text("Make room for what matters.")
          .font(.subheadline)
          .foregroundStyle(Palette.muted)
        Spacer()
      }
      ZStack {
        Ellipse()
          .fill(Palette.sage.opacity(0.065))
          .frame(width: 260, height: 285)
          .offset(x: 35, y: -10)
        Botanical(species: store.data.specimens.count % 3)
          .frame(height: 300)
      }
      .padding(.top, 16)
      HStack(alignment: .firstTextBaseline) {
        Eyebrow(text: "Next to grow")
        Spacer()
        Text(Botany.names[store.data.specimens.count % 3])
          .font(.system(.title3, design: .serif))
      }
      .padding(.top, 4)
      .padding(.bottom, 20)
      PrimaryButton(title: "Begin a ritual") { configure = true }
      HStack(spacing: 6) {
        let minutes = Int(store.focusedSeconds(on: Date()) / 60)
        Image(systemName: "sun.max").font(.caption)
        Text("\(minutes) mindful \(minutes == 1 ? "minute" : "minutes") today")
          .font(.footnote)
      }
      .foregroundStyle(Palette.muted)
      .padding(.top, 18)
      if let message = store.storageMessage {
        Text(message).font(.footnote).foregroundStyle(.red).padding(.top)
      }
    }
  }

  private func active(_ ritual: Ritual) -> some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { context in
      let remaining = ritual.remaining(at: context.date)
      let progress = 1 - remaining / ritual.duration
      VStack(spacing: 12) {
        Eyebrow(
          text: ritual.isPreview ? "20-second preview · real time" : "Your time, well planted"
        )
        .padding(.top, 16)
        Text(ritual.intention)
          .font(.system(.title, design: .serif))
          .multilineTextAlignment(.center)
        Botanical(species: ritual.species, growth: reduceMotion ? 1 : 0.2 + progress * 0.8)
          .frame(height: 270)
        Text(timeString(remaining))
          .font(.system(size: 65, weight: .light, design: .serif))
          .monospacedDigit()
          .contentTransition(.numericText(countsDown: true))
          .accessibilityLabel("\(Int(ceil(remaining))) seconds remaining")
        Eyebrow(text: ritual.isPaused ? "Paused · take a breath" : "Growing quietly")
        PrimaryButton(
          title: ritual.isPaused ? "Resume ritual" : "Pause ritual",
          icon: ritual.isPaused ? "play" : "pause"
        ) {
          if ritual.isPaused { store.resume() } else { store.pause() }
        }
        .padding(.top, 18)
        Button("End ritual") { cancel = true }
          .font(.subheadline)
          .foregroundStyle(Palette.muted)
          .frame(minHeight: 44)
      }
    }
  }

  private func timeString(_ seconds: TimeInterval) -> String {
    let rounded = Int(ceil(seconds))
    return String(format: "%02d:%02d", rounded / 60, rounded % 60)
  }
}

struct ConfigureView: View {
  @EnvironmentObject private var store: GardenStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var textSize
  @State private var intention = ""
  @State private var minutes = 25
  @State private var preview = false
  @FocusState private var editing: Bool
  private let intentions = ["Make something", "Read & wander", "Find clarity", "A little space"]

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Eyebrow(text: "Plant an intention")
          Text("What needs\nyour attention?")
            .modifier(EditorialHeading(size: 36))
          TextField("Your intention", text: $intention, axis: .vertical)
            .lineLimit(1...4)
            .font(.title3)
            .padding(17)
            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
            .focused($editing)
            .submitLabel(.done)
            .onSubmit { editing = false }
            .onChange(of: intention) { _, value in intention = String(value.prefix(60)) }
            .accessibilityIdentifier("intentionField")
          LazyVGrid(
            columns: textSize.isAccessibilitySize
              ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
          ) {
            ForEach(intentions, id: \.self) { tag in
              Button {
                intention = tag
                editing = false
              } label: {
                Text(tag).font(.subheadline)
                  .fixedSize(horizontal: false, vertical: true)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 10)
                  .frame(maxWidth: .infinity, minHeight: 46)
                  .background(
                    intention == tag ? Palette.sage.opacity(0.18) : .clear,
                    in: RoundedRectangle(cornerRadius: 22)
                  )
                  .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.line, lineWidth: 1))
              }
              .buttonStyle(.plain)
            }
          }
          VStack(alignment: .leading, spacing: 16) {
            (textSize.isAccessibilitySize
              ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
              : AnyLayout(HStackLayout())) {
                Eyebrow(text: "Make a little room")
                if !textSize.isAccessibilitySize { Spacer() }
                Text(preview ? "20 sec" : "\(minutes) min")
                  .font(.system(.title2, design: .serif))
              }
            if !preview {
              LazyVGrid(
                columns: Array(
                  repeating: GridItem(.flexible()), count: textSize.isAccessibilitySize ? 2 : 4),
                spacing: 10
              ) {
                ForEach([15, 25, 45, 60], id: \.self) { duration in
                  Button("\(duration)") { minutes = duration }
                    .frame(maxWidth: .infinity, minHeight: 45)
                    .foregroundStyle(minutes == duration ? Palette.paper : Palette.ink)
                    .background(
                      minutes == duration ? Palette.ink : Palette.sage.opacity(0.08),
                      in: RoundedRectangle(cornerRadius: 12)
                    )
                    .accessibilityLabel("\(duration) minutes")
                }
              }
              Stepper("Custom duration: \(minutes) min", value: $minutes, in: 1...90)
                .font(.subheadline)
            }
            Toggle(isOn: $preview) {
              VStack(alignment: .leading, spacing: 5) {
                Text("Try a 20-second preview").font(.subheadline.weight(.medium))
                Text("Grows a plant. Excluded from focus totals.")
                  .font(.caption).foregroundStyle(Palette.muted)
              }
            }
            .tint(Palette.sage)
          }
          Divider()
          Text("Let one thing be enough.\nYour garden keeps time, even when you leave.")
            .font(.system(.body, design: .serif))
            .foregroundStyle(Palette.muted)
        }
        .padding(26)
      }
      .scrollDismissesKeyboard(.interactively)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if !editing {
          VStack(spacing: 0) {
            Rectangle().fill(Palette.line).frame(height: 0.75)
            PrimaryButton(
              title: preview
                ? "Begin preview · 20 sec"
                : "Plant \(minutes) \(minutes == 1 ? "minute" : "minutes")", icon: "leaf"
            ) {
              if store.start(intention: intention, minutes: minutes, preview: preview) { dismiss() }
            }.padding(.horizontal, 26).padding(.vertical, 12)
          }
          .background(Palette.paper)
        }
      }
      .modifier(Paper())
      .navigationTitle("Your ritual")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { editing = false }
        }
      }
      .onAppear {
        intention = store.data.intention
        minutes = store.data.preferredMinutes
      }
    }
  }
}

struct CompletionView: View {
  @Environment(\.dynamicTypeSize) private var textSize
  let specimen: Specimen
  let done: () -> Void
  var body: some View {
    ScrollView {
      VStack(spacing: 15) {
        Eyebrow(text: specimen.isPreview ? "Preview complete" : "Time beautifully spent")
          .padding(.top, 35)
        Text("You grew\nsomething good.")
          .modifier(EditorialHeading(size: 43))
          .multilineTextAlignment(.center)
        Botanical(species: specimen.species).frame(height: 305)
        Text(Botany.names[specimen.species]).font(.system(.title, design: .serif))
        Text(Botany.meanings[specimen.species])
          .font(.system(.body, design: .serif)).foregroundStyle(Palette.muted)
        (textSize.isAccessibilitySize
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout())) {
            Text(specimen.intention)
            if !textSize.isAccessibilitySize { Spacer() }
            Text(specimen.isPreview ? "20 sec · preview" : "\(Int(specimen.duration / 60)) min")
          }
          .font(.subheadline)
          .padding(.vertical, 20)
          .overlay(alignment: .top) { Rectangle().fill(Palette.ink.opacity(0.15)).frame(height: 1) }
        PrimaryButton(title: "Keep in my herbarium", icon: "book.closed", action: done)
        Text("Saved with care, just for you.").font(.caption).foregroundStyle(Palette.muted)
      }
      .padding(28)
    }
    .foregroundStyle(Palette.ink)
    .background(Palette.apricot.ignoresSafeArea())
    .sensoryFeedback(.success, trigger: specimen.id)
  }
}
