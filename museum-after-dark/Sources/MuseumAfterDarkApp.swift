import SwiftUI
import UIKit

@main
struct MuseumAfterDarkApp: App {
  @StateObject private var store = HeistStore()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      MuseumRoot()
        .environmentObject(store)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
          if phase == .background {
            store.persist()
            if store.screen == .play && store.state.outcome == .playing { store.showPause = true }
          }
        }
    }
  }
}

struct MuseumRoot: View {
  @EnvironmentObject private var store: HeistStore
  var body: some View {
    ZStack {
      MuseumAtmosphere()
      switch store.screen {
      case .home: HomeView()
      case .rooms: RoomsView()
      case .play:
        if store.state.outcome == .escaped { ResultView() } else { PlayView() }
      }
    }
    .foregroundStyle(Palette.paper)
    .tint(Palette.gold)
    .sheet(isPresented: $store.showSettings, onDismiss: store.persist) { SettingsView() }
    .sheet(isPresented: $store.showPause) { PauseView() }
  }
}

struct Eyebrow: View {
  let text: String
  var color = Palette.gold
  var body: some View {
    Text(text).font(.system(size: 10, weight: .semibold, design: .monospaced))
      .tracking(2.3).foregroundStyle(color)
  }
}

struct GoldButton: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .semibold))
      .tracking(1.5)
      .foregroundStyle(Palette.ink)
      .frame(maxWidth: .infinity)
      .frame(height: 58)
      .background(
        LinearGradient(
          colors: [Palette.paper, Palette.gold.opacity(0.95)],
          startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 2)
      )
      .overlay {
        Rectangle().stroke(Palette.ink.opacity(0.2), lineWidth: 0.7).padding(4)
          .allowsHitTesting(false)
      }
      .shadow(color: Palette.gold.opacity(0.12), radius: 16, y: 5)
      .brightness(configuration.isPressed ? -0.08 : 0)
      .scaleEffect(configuration.isPressed ? 0.985 : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
  }
}

struct IconButton: View {
  let symbol: String
  let label: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 17, weight: .light))
        .frame(width: 44, height: 44)
        .background(Palette.ink.opacity(0.55), in: Circle())
        .overlay(Circle().stroke(Palette.gold.opacity(0.35), lineWidth: 0.7))
    }
    .accessibilityLabel(label)
    .accessibilityIdentifier(label)
  }
}

struct HomeView: View {
  @EnvironmentObject private var store: HeistStore
  var body: some View {
    GeometryReader { geo in
      ScrollView {
        VStack(spacing: 0) {
          ZStack {
            MuseumHero()
            VStack(spacing: 0) {
              HStack {
                MuseumEmblem()
                Spacer()
                Eyebrow(text: "THE NIGHT COLLECTION")
                Spacer()
                IconButton(symbol: "slider.horizontal.3", label: "Settings") {
                  store.showSettings = true
                }
              }
              .padding(.horizontal, 24)
              .padding(.top, 10)
              VStack(spacing: -4) {
                Text("MUSEUM").font(MuseumType.display(48)).tracking(6)
                Text("After Dark").font(MuseumType.italic(53)).foregroundStyle(Palette.paper)
              }
              .shadow(color: .black.opacity(0.8), radius: 15)
              .padding(.top, 18)
              HStack(spacing: 9) {
                Rectangle().fill(Palette.gold.opacity(0.6)).frame(width: 19, height: 0.5)
                Eyebrow(text: "TEN GALLERIES. ONE PERFECT CRIME.")
                Rectangle().fill(Palette.gold.opacity(0.6)).frame(width: 19, height: 0.5)
              }
              .padding(.top, 13)
              Spacer()
              HStack(spacing: 7) {
                Circle().fill(Palette.ruby).frame(width: 4, height: 4)
                  .shadow(color: Palette.ruby, radius: 4)
                Text("AFTER HOURS ACCESS")
                  .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2)
              }
              .foregroundStyle(Palette.paper.opacity(0.75))
              .padding(.bottom, 12)
            }
          }
          .frame(height: max(440, geo.size.height - 222))
          VStack(spacing: 13) {
            Text("An exquisite art. A quiet crime.")
              .font(MuseumType.italic(23))
            Text("Outwit the light. Acquire the extraordinary.")
              .font(.system(size: 12)).foregroundStyle(Palette.muted)
            Button {
              store.begin(store.saved.roomIndex, fresh: store.state.outcome != .playing)
            } label: {
              HStack {
                Image(systemName: "key.horizontal").font(.system(size: 18, weight: .light))
                Spacer()
                Text(
                  store.saved.state.turn > 0 && store.state.outcome == .playing
                    ? "CONTINUE THE HEIST" : "ENTER THE MUSEUM")
                Spacer()
                Image(systemName: "arrow.right")
              }.padding(.horizontal, 20)
            }
            .buttonStyle(GoldButton())
            .accessibilityIdentifier("start-heist")
            Button {
              store.screen = .rooms
            } label: {
              HStack {
                Text("THE COLLECTION")
                Spacer()
                Text("\(store.saved.best.count) / 10 ACQUIRED")
                Image(systemName: "arrow.up.right")
              }
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .tracking(1.2)
              .frame(height: 44)
              .foregroundStyle(Palette.gold)
            }
            .accessibilityIdentifier("collection")
          }
          .padding(.horizontal, 26)
          .padding(.top, 2)
          .padding(.bottom, 12)
        }
        .frame(minHeight: geo.size.height)
      }
      .background(Palette.ink)
      .scrollIndicators(.hidden)
      .clipped()
    }
  }
}

struct RoomsView: View {
  @EnvironmentObject private var store: HeistStore
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        IconButton(symbol: "arrow.left", label: "Back to museum") { store.screen = .home }
        Spacer()
        Eyebrow(text: "\(store.medals) PERFECT HEISTS")
      }
      Text("The collection").font(MuseumType.display(39))
      Text("Each acquisition opens another gallery.").font(.system(size: 13)).foregroundStyle(
        Palette.muted)
      ScrollView {
        VStack(spacing: 0) {
          ForEach(Array(Rooms.all.enumerated()), id: \.element.id) { index, room in
            Button {
              store.begin(index)
            } label: {
              HStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                  Jewel(size: 58, artifactID: room.id)
                    .frame(width: 74, height: 80)
                    .background(Palette.stone.opacity(0.35))
                    .overlay(EngravedFrame().stroke(Palette.gold.opacity(0.3), lineWidth: 0.5))
                  Text(String(format: "%02d", room.id))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Palette.gold)
                    .padding(6)
                }
                VStack(alignment: .leading, spacing: 6) {
                  Eyebrow(text: room.collection, color: Palette.muted)
                  Text(room.title).font(MuseumType.display(21)).foregroundStyle(
                    Palette.paper)
                  if let best = store.saved.best[room.id] {
                    Text("\(best) MOVES · \(best <= room.par ? "PERFECT" : "ACQUIRED")").font(
                      .system(size: 9, design: .monospaced)
                    ).foregroundStyle(Palette.gold)
                  }
                }
                Spacer(minLength: 0)
                Image(systemName: index >= store.unlocked ? "lock" : "arrow.up.right").font(
                  .system(size: 14))
              }
              .padding(.vertical, 15)
              .opacity(index >= store.unlocked ? 0.4 : 1)
              .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.gold.opacity(0.2)).frame(height: 1)
              }
            }
            .disabled(index >= store.unlocked)
            .accessibilityLabel(
              "Gallery \(room.id), \(room.title), \(index >= store.unlocked ? "locked" : "available")"
            )
          }
        }
      }
      .scrollIndicators(.hidden)
      .clipped()
    }
    .padding(.horizontal, 24)
    .padding(.top, 10)
  }
}

struct PlayView: View {
  @EnvironmentObject private var store: HeistStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    GeometryReader { geo in
      VStack(spacing: 10) {
        HStack {
          IconButton(symbol: "pause", label: "Pause heist") { store.showPause = true }
          Spacer()
          VStack(spacing: 5) {
            Eyebrow(text: "THE NIGHT COLLECTION", color: Palette.muted)
            HStack(spacing: 6) {
              ForEach(1...10, id: \.self) { number in
                Diamond().fill(number == store.room.id ? Palette.gold : Palette.gold.opacity(0.18))
                  .frame(width: number == store.room.id ? 5 : 3, height: 5)
              }
            }.accessibilityLabel("Gallery \(store.room.id) of 10")
          }
          Spacer()
          VStack(spacing: 0) {
            Text(String(format: "%02d", store.state.turn)).font(MuseumType.display(29))
              .contentTransition(.numericText())
            Text("MOVES").font(.system(size: 7, weight: .medium, design: .monospaced)).tracking(1.5)
              .foregroundStyle(Palette.muted)
          }
          .frame(width: 44, height: 44)
          .accessibilityLabel("\(store.state.turn) moves")
        }
        DecoRule().padding(.top, 1)
        VStack(alignment: .leading, spacing: 5) {
          HStack {
            Eyebrow(text: String(format: "%02d  /  ", store.room.id) + store.room.collection)
            Spacer()
            Text("PAR \(store.room.par)").font(.system(size: 10, design: .monospaced))
              .foregroundStyle(Palette.muted)
          }
          HStack(alignment: .firstTextBaseline) {
            Text(store.room.title).font(MuseumType.display(31)).minimumScaleFactor(0.75)
              .lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        HStack(spacing: 8) {
          Image(systemName: store.state.hasArtifact ? "checkmark.diamond.fill" : "diamond")
          Text(
            store.state.hasArtifact
              ? "ARTIFACT SECURED" : "ACQUIRE THE ARTIFACT"
          )
          .fixedSize(horizontal: true, vertical: false)
          Rectangle().fill(Palette.gold.opacity(0.3)).frame(height: 0.5)
          Image(systemName: "arrow.down.left")
          Text("EXIT").fixedSize(horizontal: true, vertical: false)
          Spacer(minLength: 0)
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .tracking(0.7)
        .foregroundStyle(store.state.hasArtifact ? Palette.mint : Palette.gold)
        .frame(height: 22)
        ZStack {
          MuseumBoard(room: store.room, state: store.state, tap: store.tap)
            .frame(maxWidth: min(geo.size.width - 20, max(238, (geo.size.height - 315) * 7 / 8)))
          if store.state.outcome == .caught {
            caughtOverlay
          }
          if store.revealArtifact && store.state.outcome == .playing {
            artifactReveal
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, -10)
        HStack(spacing: 12) {
          HStack(spacing: 4) {
            ThiefFigure().frame(width: 18, height: 20)
            Text("YOU").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.paper)
          }.accessibilityHidden(true)
          legend("xmark", text: "DANGER NOW", color: Palette.ruby)
          if !store.room.sentries.isEmpty {
            legend("square.dashed", text: "NEXT SWEEP", color: Palette.amber)
          }
          Spacer(minLength: 0)
        }
        VStack(alignment: .leading, spacing: 5) {
          HStack(spacing: 8) {
            Image(systemName: "ear").font(.system(size: 10))
            Eyebrow(text: instructionTitle)
          }
          Text(instruction)
            .font(.system(size: 12)).lineSpacing(3).foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("context-instruction")
        }
        .frame(minHeight: 48, alignment: .topLeading)
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(Palette.stone.opacity(0.3))
        .overlay(alignment: .leading) {
          Rectangle().fill(Palette.gold.opacity(0.7)).frame(width: 1)
        }
        HStack(spacing: 0) {
          control("arrow.uturn.backward", text: "Undo", disabled: store.saved.history.isEmpty) {
            store.undo()
          }
          Rectangle().fill(Palette.gold.opacity(0.25)).frame(width: 0.5, height: 20)
          control("clock.arrow.circlepath", text: "Wait") { store.act(.wait) }
          Rectangle().fill(Palette.gold.opacity(0.25)).frame(width: 0.5, height: 20)
          control("arrow.counterclockwise", text: "Restart") { store.restart() }
        }
        .background(
          LinearGradient(
            colors: [Palette.stone.opacity(0.6), Palette.ink],
            startPoint: .top, endPoint: .bottom)
        )
        .overlay(EngravedFrame().stroke(Palette.gold.opacity(0.4), lineWidth: 0.5))
        .padding(.bottom, 8)
      }
      .padding(.horizontal, 22)
      .padding(.top, 6)
      .allowsHitTesting(!store.revealArtifact || store.state.outcome != .playing)
      .overlay {
        if store.revealArtifact && store.state.outcome == .playing {
          Color.clear.contentShape(Rectangle()).onTapGesture { store.revealArtifact = false }
            .accessibilityLabel("Continue with artifact").accessibilityAddTraits(.isButton)
        }
      }
      .task(id: store.revealArtifact) {
        if store.revealArtifact {
          try? await Task.sleep(for: .seconds(reduceMotion ? 1.0 : 1.8))
          withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
            store.revealArtifact = false
          }
        }
      }
    }
  }

  private var instructionTitle: String {
    if !store.message.isEmpty { return "A QUIET REMINDER" }
    if store.state.hasArtifact { return "MAKE YOUR EXIT" }
    if store.state.turn == 0 { return "THE PLAN" }
    if (store.room.nodes + store.room.mirrors).contains(where: {
      store.state.player.distance(to: $0) == 1
    }) {
      return "WITHIN REACH"
    }
    return "ONE MOVE AHEAD"
  }
  private var instruction: String {
    if !store.message.isEmpty { return store.message }
    if store.state.hasArtifact {
      return "The piece is yours. Retrace a safe route to the green EXIT."
    }
    if store.state.turn == 0 { return store.room.briefing }
    if let node = store.room.nodes.first(where: { store.state.player.distance(to: $0) == 1 }) {
      return "Tap brass node \(store.room.circuit(at: node) + 1) to toggle its laser circuit."
    }
    if store.room.mirrors.contains(where: { store.state.player.distance(to: $0) == 1 }) {
      return "Tap the round mirror to rotate it. Check where the beam will go."
    }
    return store.room.sentries.isEmpty
      ? "Tap a mint-outlined neighbor to step. Never enter an active ruby beam."
      : "Tap a neighbor to step. Avoid solid light now and dotted amber on the next turn."
  }

  private func legend(_ symbol: String, text: String, color: Color) -> some View {
    HStack(spacing: 5) {
      Image(systemName: symbol).font(.system(size: 8))
      Text(text).font(.system(size: 10, design: .monospaced)).tracking(0.5)
    }.foregroundStyle(color.opacity(0.8))
  }

  private func control(
    _ symbol: String, text: String, disabled: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 7) {
        Image(systemName: symbol)
        Text(text)
      }
      .font(.system(size: 12))
      .frame(maxWidth: .infinity)
      .frame(height: 46)
      .opacity(disabled ? 0.3 : 1)
    }
    .disabled(disabled || store.state.outcome != .playing)
    .accessibilityIdentifier(text.lowercased())
  }

  private var caughtOverlay: some View {
    VStack(spacing: 13) {
      Eyebrow(text: "SECURITY ALERT", color: Palette.ruby)
      Text("Spotted.").font(MuseumType.display(46))
      Text("A beam found you.\nUndo your move, or try a fresh approach.")
        .font(.system(size: 13)).lineSpacing(4).multilineTextAlignment(.center).foregroundStyle(
          Palette.muted)
      Button("UNDO LAST MOVE") { store.undo() }.buttonStyle(GoldButton()).accessibilityIdentifier(
        "undo-caught")
      Button("Restart gallery") { store.restart() }.font(.system(size: 13)).frame(height: 44)
        .accessibilityIdentifier("restart-caught")
    }
    .padding(24)
    .background(Palette.ink.opacity(0.97))
    .overlay(EngravedFrame().stroke(Palette.ruby.opacity(0.5), lineWidth: 0.7))
    .padding(.horizontal, 12)
  }

  private var artifactReveal: some View {
    VStack(spacing: 9) {
      ArtifactMount(artifactID: store.room.id, size: 110).overlay(AcquisitionParticles())
      Eyebrow(text: "ACQUIRED")
      Text(store.room.artifactName).font(MuseumType.display(32))
      Text("Now, disappear.").font(MuseumType.italic(20)).foregroundStyle(Palette.muted)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      RadialGradient(
        colors: [Palette.ink.opacity(0.98), Palette.ink.opacity(0.75), .clear], center: .center,
        startRadius: 50, endRadius: 230)
    )
    .transition(.opacity)
  }
}

struct PauseView: View {
  @EnvironmentObject private var store: HeistStore
  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      Eyebrow(text: "THE MUSEUM CAN WAIT")
      Text("Hold your breath.").font(MuseumType.display(38))
      Text("Your heist is saved after every move.").font(.system(size: 14)).foregroundStyle(
        Palette.muted)
      Button("RESUME HEIST") { store.showPause = false }.buttonStyle(GoldButton())
      Button("Restart this gallery") { store.restart() }.frame(height: 44)
      Button("Return to the museum") {
        store.showPause = false
        store.screen = .home
      }.frame(height: 44)
    }
    .padding(30)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(.top, 24)
    .presentationDetents([.medium])
    .presentationDragIndicator(.visible)
    .presentationBackground(Palette.ink)
    .foregroundStyle(Palette.paper)
    .tint(Palette.gold)
  }
}

struct SettingsView: View {
  @EnvironmentObject private var store: HeistStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      Form {
        Section("Atmosphere") {
          Toggle("Sound effects", isOn: $store.saved.sound).accessibilityIdentifier("sound-toggle")
          Toggle("Haptic feedback", isOn: $store.saved.haptics).accessibilityIdentifier(
            "haptics-toggle")
        }
        Section("The rules") {
          Text(
            "Tap an adjacent floor tile to move. Tap adjacent brass nodes or round mirrors to interact. Wait advances the watch without moving."
          )
          Text(
            "Ruby beams and amber searchlights catch you. Searchlights rotate clockwise after every action; dotted amber tiles preview their next position."
          )
          Text(
            "Take the artifact back to EXIT. Undo is unlimited. Match the par move count for a perfect-heist medal."
          )
        }
        Section("On your device") {
          Text(
            "Ten authored galleries. Progress stays on this device. Reduced Motion follows your iPhone's accessibility setting."
          )
        }
      }
      .font(.system(size: 14))
      .scrollContentBackground(.hidden)
      .background(Palette.ink)
      .navigationTitle("After hours")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    .tint(Palette.gold)
  }
}

struct DossierView: View {
  let room: Room
  let moves: Int
  var compact = false
  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: compact ? 10 : 18) {
        HStack {
          Eyebrow(text: "M / AD")
          Spacer()
          Eyebrow(text: String(format: "DOSSIER %03d", room.id), color: Palette.muted)
        }
        ArtifactMount(artifactID: room.id, size: compact ? 103 : 173)
        Text(room.artifactName).font(MuseumType.display(compact ? 31 : 46))
        Eyebrow(text: room.collection, color: Palette.muted)
      }
      .padding(compact ? 22 : 38)
      .frame(maxWidth: .infinity)
      .background {
        LinearGradient(
          colors: [Palette.stone, Palette.ink], startPoint: .topLeading, endPoint: .bottomTrailing)
      }
      VStack(spacing: compact ? 13 : 22) {
        HStack(alignment: .center) {
          VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text(String(format: "%02d", moves)).font(MuseumType.display(compact ? 47 : 66))
              Text("MOVES").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(
                1.5)
            }
            Text("WITHOUT A TRACE").font(.system(size: 8, design: .monospaced)).tracking(1.5)
          }
          Spacer()
          VStack(spacing: 5) {
            ZStack {
              Circle().stroke(Palette.velvet.opacity(0.65), lineWidth: 0.8).frame(
                width: 40, height: 40)
              Circle().stroke(Palette.velvet.opacity(0.4), lineWidth: 0.5).frame(
                width: 34, height: 34)
              Image(systemName: moves <= room.par ? "star.fill" : "checkmark")
                .font(.system(size: 16, weight: .light))
            }
            Text(moves <= room.par ? "PERFECT HEIST" : "CLEAN ESCAPE")
              .font(.system(size: 8, weight: .semibold, design: .monospaced)).tracking(1)
          }.foregroundStyle(Palette.velvet)
        }
        DecoRule(color: Palette.ink)
        HStack {
          Text("MUSEUM AFTER DARK")
            .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.5)
          Spacer()
          Text(String(format: "MAD—%02d—%03d", room.id, moves))
            .font(.system(size: 8, design: .monospaced))
        }
      }
      .foregroundStyle(Palette.ink)
      .padding(compact ? 22 : 38)
      .background {
        LinearGradient(
          colors: [Palette.paper, Color(red: 0.81, green: 0.75, blue: 0.62)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      }
    }
    .foregroundStyle(Palette.paper)
    .overlay(EngravedFrame().stroke(Palette.gold.opacity(0.6), lineWidth: 0.7))
    .padding(2)
    .background(Palette.ink)
  }
}

struct SharedDossier: Identifiable {
  let id = UUID()
  let image: UIImage
  let text: String
}

struct ResultView: View {
  @EnvironmentObject private var store: HeistStore
  @State private var dossier: SharedDossier?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Eyebrow(
            text: store.saved.best.count == 10
              ? "THE COLLECTION IS COMPLETE" : "ACQUISITION CONFIRMED")
          Spacer()
          IconButton(symbol: "xmark", label: "Close dossier") { store.screen = .rooms }
        }
        VStack(alignment: .leading, spacing: 2) {
          Text("Gone by midnight.").font(MuseumType.display(38)).minimumScaleFactor(0.8)
            .lineLimit(1)
          Text("The museum will never be the same.").font(MuseumType.italic(18))
            .foregroundStyle(Palette.muted)
        }
        DossierView(room: store.room, moves: store.state.turn, compact: true)
          .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
        HStack(spacing: 8) {
          Image(systemName: "lock.open").font(.system(size: 12))
          Text(
            store.room.id < 10
              ? "Gallery \(store.room.id + 1) is now open."
              : "All ten galleries are yours. Replay for every medal."
          )
          .font(.system(size: 12))
        }.foregroundStyle(Palette.muted)
        Button(store.room.id < 10 ? "ENTER THE NEXT GALLERY  →" : "VIEW THE COLLECTION  →") {
          if store.room.id < 10 {
            store.begin(store.saved.roomIndex + 1)
          } else {
            store.screen = .rooms
          }
        }.buttonStyle(GoldButton()).accessibilityIdentifier("next-gallery")
        HStack(spacing: 12) {
          Button {
            let renderer = ImageRenderer(
              content: DossierView(room: store.room, moves: store.state.turn).frame(width: 600)
                .padding(30).background(Palette.ink))
            renderer.scale = 2
            if let image = renderer.uiImage {
              dossier = SharedDossier(
                image: image,
                text:
                  "I acquired \(store.room.artifactName) in \(store.state.turn) moves. Museum After Dark — gallery \(store.room.id) of 10."
              )
            }
          } label: {
            Label("Share dossier", systemImage: "square.and.arrow.up").frame(
              maxWidth: .infinity, minHeight: 44)
          }.accessibilityIdentifier("share-dossier")
          Button {
            store.restart()
          } label: {
            Label("Replay", systemImage: "arrow.counterclockwise").frame(
              maxWidth: .infinity, minHeight: 44)
          }.accessibilityIdentifier("replay-gallery")
        }
        .font(.system(size: 12))
      }
      .padding(24)
    }
    .scrollIndicators(.hidden)
    .clipped()
    .sheet(item: $dossier) { item in
      ShareSheet(image: item.image, text: item.text)
    }
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let image: UIImage
  let text: String
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [image, text], applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
