import AudioToolbox
import SwiftUI
import UIKit

@MainActor @Observable
final class LunchStore {
  private let defaults: UserDefaults
  var best: [String: Int]
  var activeGames: [String: PackingGame]
  var sound: Bool { didSet { defaults.set(sound, forKey: "sound") } }
  var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
  var learned: Bool { didSet { defaults.set(learned, forKey: "learned") } }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    best = defaults.dictionary(forKey: "best") as? [String: Int] ?? [:]
    if let data = defaults.data(forKey: "activeGames"),
      let decoded = try? JSONDecoder().decode([String: PackingGame].self, from: data)
    {
      activeGames = decoded
    } else {
      activeGames = [:]
    }
    sound = defaults.bool(forKey: "sound")
    haptics = defaults.object(forKey: "haptics") as? Bool ?? true
    learned = defaults.bool(forKey: "learned")
  }

  var nextIndex: Int {
    LunchBook.all.firstIndex { best[$0.id] == nil } ?? 11
  }
  var stars: Int { LunchBook.all.reduce(0) { $0 + (best[$1.id] ?? 0) } }

  func game(for lunch: Lunch) -> PackingGame {
    if let game = activeGames[lunch.id], game.isValid(for: lunch), !game.isComplete(lunch) {
      return game
    }
    return PackingGame(lunch: lunch)
  }

  func save(_ game: PackingGame) {
    activeGames[game.lunchID] = game
    let dailyKey = LunchBook.daily().id
    activeGames = activeGames.filter { !$0.key.hasPrefix("daily-") || $0.key == dailyKey }
    if let data = try? JSONEncoder().encode(activeGames) {
      defaults.set(data, forKey: "activeGames")
    }
  }

  func finish(_ game: PackingGame, lunch: Lunch) {
    best[lunch.id] = max(best[lunch.id] ?? 0, game.stars(lunch))
    defaults.set(best, forKey: "best")
    save(game)
  }

  func feedback(success: Bool = true) {
    if haptics {
      if success {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      } else {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
      }
    }
    if sound { AudioServicesPlaySystemSound(success ? 1104 : 1053) }
  }
}

@main
struct BentoCircuitApp: App {
  @State private var store = LunchStore()
  var body: some Scene {
    WindowGroup {
      RootView(store: store)
        .preferredColorScheme(.light)
        .tint(Palette.orange)
    }
  }
}

struct RootView: View {
  @Bindable var store: LunchStore
  @State private var selectedLunch: Lunch?
  @State private var showSettings = false

  var body: some View {
    ZStack {
      PaperBackground()
      if let lunch = selectedLunch {
        GameView(lunch: lunch, store: store) {
          selectedLunch = nil
        } next: {
          if lunch.isDaily || lunch.number == 12 {
            selectedLunch = nil
          } else {
            selectedLunch = LunchBook.all[lunch.number]
          }
        }
        .id(lunch.id)
      } else {
        home
      }
    }
    .overlay(alignment: .top) {
      GeometryReader { proxy in
        Palette.paper.frame(height: proxy.safeAreaInsets.top)
          .ignoresSafeArea(edges: .top)
      }
      .allowsHitTesting(false)
    }
    .sheet(isPresented: $showSettings) { SettingsView(store: store) }
  }

  private var home: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          HStack(spacing: 10) {
            CircuitMark()
            MicroLabel(text: "THE LUNCHBOX PUZZLE")
            Spacer()
            IconButton(symbol: "slider.horizontal.3", label: "Settings") { showSettings = true }
          }
          VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 7) {
              Text("Bento").font(
                .system(size: geometry.size.width < 390 ? 68 : 78, weight: .regular, design: .serif)
              )
              .tracking(-4)
              Text("Circuit").font(
                .system(size: geometry.size.width < 390 ? 35 : 41, weight: .regular, design: .serif)
              )
              .italic().tracking(-1.8)
            }
            Text("The art of a perfectly packed lunch.")
              .font(.system(size: 15, design: .serif)).foregroundStyle(Palette.muted)
          }
          homeHero(width: geometry.size.width - 52)
          HStack {
            MicroLabel(text: "A SMALL DAILY RITUAL")
            Spacer()
            MicroLabel(text: "VOL. 01 / 12 LUNCHES", color: Palette.orange)
          }
          VStack(spacing: 17) {
            Button {
              selectedLunch = LunchBook.all[store.nextIndex]
            } label: {
              HStack {
                Text(store.stars == 0 ? "Let’s make lunch" : "Continue the journey")
                Spacer()
                Text(String(format: "%02d", store.nextIndex + 1))
                  .font(.system(size: 13, weight: .medium, design: .monospaced))
                  .opacity(0.65)
                Image(systemName: "arrow.right")
              }.padding(.horizontal, 20)
            }
            .buttonStyle(PrimaryButton())
            .accessibilityIdentifier("Start lunch")
            Button {
              selectedLunch = LunchBook.daily()
            } label: {
              HStack(spacing: 16) {
                VStack(spacing: 5) {
                  Image(systemName: "sun.max").font(.system(size: 23, weight: .light))
                  MicroLabel(text: "DAILY", color: Palette.orange)
                }.frame(width: 46).foregroundStyle(Palette.orange)
                Rectangle().fill(Palette.line).frame(width: 1, height: 43)
                VStack(alignment: .leading, spacing: 5) {
                  Text("The daily parcel").font(.system(size: 23, design: .serif))
                  MicroLabel(
                    text: store.best[LunchBook.daily().id] != nil
                      ? "PACKED WITH CARE" : "A FRESH LITTLE CHALLENGE")
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 15))
              }.padding(.vertical, 17)
                .overlay(alignment: .top) { Perforation() }
                .overlay(alignment: .bottom) { Perforation() }
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
              .accessibilityIdentifier("Daily challenge")
          }
          VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .lastTextBaseline) {
              Text("The local line").font(.system(size: 26, design: .serif)).tracking(-0.7)
              Spacer()
              MicroLabel(text: "\(store.stars) / 36 STARS", color: Palette.orange)
            }
            LazyVGrid(
              columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4), spacing: 18
            ) {
              ForEach(LunchBook.all) { lunch in
                let unlocked = lunch.number <= store.nextIndex + 1
                let current = lunch.number == store.nextIndex + 1
                Button {
                  selectedLunch = lunch
                } label: {
                  VStack(spacing: 7) {
                    ZStack {
                      Rectangle().fill(Palette.line).frame(height: 1)
                      Circle().fill(current ? Palette.orange : Palette.paper).frame(
                        width: 48, height: 48)
                      Circle().stroke(current ? Palette.orange : Palette.line, lineWidth: 1).frame(
                        width: 54, height: 54)
                      Text(String(format: "%02d", lunch.number))
                        .font(.system(size: 23, weight: .regular, design: .serif))
                        .foregroundStyle(
                          current
                            ? Palette.cream : (unlocked ? Palette.ink : Palette.muted.opacity(0.55))
                        )
                    }
                    HStack(spacing: 3) {
                      ForEach(0..<3) { star in
                        Image(
                          systemName: star < (store.best[lunch.id] ?? 0) ? "star.fill" : "circle"
                        )
                        .font(.system(size: 6))
                      }
                    }.foregroundStyle(Palette.orange.opacity(unlocked ? 1 : 0.25))
                  }.frame(maxWidth: .infinity).frame(height: 72)
                }
                .buttonStyle(.plain).disabled(!unlocked)
                .accessibilityLabel(
                  "Lunch \(lunch.number), \(lunch.title), \(unlocked ? "\(store.best[lunch.id] ?? 0) stars" : "locked")"
                )
                .accessibilityIdentifier("Lunch \(lunch.number)")
              }
            }
          }
          HStack {
            Rectangle().fill(Palette.line).frame(height: 1)
            CircuitMark().scaleEffect(0.65).frame(width: 33)
            Rectangle().fill(Palette.line).frame(height: 1)
          }.padding(.vertical, 8)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 26).padding(.top, 14)
      }
    }
  }

  private func homeHero(width: CGFloat) -> some View {
    ZStack {
      FuroshikiCloth()
        .frame(width: width * 0.88, height: width * 0.62)
        .rotationEffect(.degrees(12)).offset(x: -6, y: 12)
      LunchIllustration().frame(width: width * 0.85)
        .rotationEffect(.degrees(-9)).offset(x: -7, y: -6)
      HStack(spacing: 5) {
        ForEach(0..<2) { _ in
          Capsule().fill(
            LinearGradient(
              colors: [Palette.wood, Palette.gold, Palette.wood],
              startPoint: .leading, endPoint: .trailing)
          ).frame(width: 4, height: width * 0.63)
        }
      }.rotationEffect(.degrees(26)).offset(x: width * 0.43, y: 12)
      PackingSeal().rotationEffect(.degrees(13)).offset(x: width * 0.30, y: width * 0.29)
    }.frame(maxWidth: .infinity).frame(height: width * 0.83).padding(.vertical, 7)
      .accessibilityHidden(true)
  }
}

struct SettingsView: View {
  @Bindable var store: LunchStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      Form {
        Section("A little atmosphere") {
          Toggle("Packing sounds", isOn: $store.sound).accessibilityIdentifier("Packing sounds")
          Toggle("Gentle haptics", isOn: $store.haptics).accessibilityIdentifier("Gentle haptics")
        }
        Section {
          Text(
            "Your lunches and best ratings stay on this iPhone. Daily parcels change at midnight UTC."
          )
          Text(
            "A perfect lunch uses one placement per piece, without a guide. Undo is always free.")
        } header: {
          Text("Packed with care")
        }
        Section {
          Text("Bento Circuit · Volume 01").font(.system(.body, design: .serif))
          Text("No clocks to race. Your move budget is the train ticket.")
        }
      }
      .navigationTitle("Make yourself at home")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    .presentationDetents([.medium, .large])
  }
}
