import AudioToolbox
import SwiftUI
import UIKit

@main
struct PaperCurrentApp: App {
  var body: some Scene {
    WindowGroup {
      RootView()
        .preferredColorScheme(.dark)
        .tint(Ink.red)
    }
  }
}

enum Feedback {
  static func tap(success: Bool = false) {
    if UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true {
      if success {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      } else {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      }
    }
    if UserDefaults.standard.bool(forKey: "sound") {
      AudioServicesPlaySystemSound(success ? 1025 : 1104)
    }
  }
}

struct MainButton: View {
  let title: String
  var icon = "arrow.right"
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        Text(title).font(Ink.title(21))
        Spacer()
        Image(systemName: icon).font(.system(size: 16, weight: .medium))
          .foregroundStyle(Ink.cream).frame(width: 38, height: 38)
          .background(Ink.red.gradient, in: Circle())
          .overlay(Circle().strokeBorder(Ink.cream.opacity(0.2), lineWidth: 0.7).padding(3))
      }
      .foregroundStyle(Ink.night)
      .padding(.leading, 22).padding(.trailing, 12)
      .frame(minHeight: 62)
      .background(Ink.cream, in: RoundedRectangle(cornerRadius: 3))
      .overlay(PaperTexture().clipShape(RoundedRectangle(cornerRadius: 3)))
      .overlay(
        RoundedRectangle(cornerRadius: 1).strokeBorder(Ink.blue.opacity(0.13), lineWidth: 0.5)
          .padding(4)
      )
      .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
    }
    .buttonStyle(PaperPressStyle())
  }
}

struct PaperPressStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
      .opacity(configuration.isPressed ? 0.82 : 1)
      .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
  }
}

struct IconButton: View {
  let icon: String
  let label: String
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: icon).font(.system(size: 19, weight: .light))
        .foregroundStyle(Ink.paper)
        .frame(width: 46, height: 46).contentShape(Rectangle())
    }
    .buttonStyle(PaperPressStyle())
    .accessibilityLabel(label)
    .accessibilityIdentifier(label)
  }
}

struct Eyebrow: View {
  let text: String
  var color = Ink.muted
  var body: some View {
    Text(text).font(.system(size: 9, weight: .medium))
      .tracking(2).foregroundStyle(color)
  }
}

struct RootView: View {
  @State private var selected: Int?
  @State private var showSettings = false
  @State private var showChapters = false
  @State private var refresh = UUID()
  private let store = ProgressStore()

  var body: some View {
    ZStack {
      NightPaper()
      if let selected {
        GameView(
          level: Level.all[selected],
          home: {
            self.selected = nil
            refresh = UUID()
          },
          next: {
            self.selected = min(selected + 1, Level.all.count - 1)
          }
        ).id(selected).modifier(BookArrival())
      } else {
        home.id(refresh)
      }
    }
    .sheet(isPresented: $showSettings) { SettingsView().preferredColorScheme(.light) }
    .sheet(isPresented: $showChapters) {
      ChapterView(store: store) {
        selected = $0
        showChapters = false
      }.preferredColorScheme(.light)
    }
  }

  private var home: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 0) {
          HStack {
            PaperBoat().frame(width: 25, height: 20)
            Eyebrow(text: "THE RAINWATER POST")
            Spacer()
            IconButton(icon: "slider.horizontal.3", label: "Settings") { showSettings = true }
          }
          VStack(spacing: -8) {
            Text("Paper").font(Ink.title(geometry.size.height < 720 ? 48 : 58)).tracking(-1.5)
            Text("Current").font(Ink.italic(geometry.size.height < 720 ? 58 : 69)).tracking(-2)
          }
          .foregroundStyle(Ink.cream).accessibilityElement(children: .combine).padding(.top, 3)
          HarborIllustration()
            .frame(height: max(245, geometry.size.height - 363))
            .padding(.horizontal, -22).padding(.top, -4)
          VStack(spacing: 15) {
            Text("Some things are worth sending slowly.")
              .font(Ink.italic(18)).foregroundStyle(Ink.paper).multilineTextAlignment(.center)
            MainButton(
              title: store.completed.isEmpty ? "Begin the journey" : "Continue the journey"
            ) {
              Feedback.tap()
              selected = store.unlocked
            }.accessibilityIdentifier("beginJourney")
            Button {
              showChapters = true
            } label: {
              HStack {
                Text("The letter collection").font(.system(size: 12))
                Spacer()
                Text(String(format: "%02d", store.completed.count))
                  .font(Ink.italic(20)).foregroundStyle(Ink.cream)
                Text("/ 10").font(.system(size: 10)).padding(.trailing, 8)
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .light))
              }
              .foregroundStyle(Ink.muted).frame(minHeight: 44)
              .contentShape(Rectangle())
              .overlay(alignment: .bottom) {
                Rectangle().fill(Ink.paper.opacity(0.12)).frame(height: 0.5)
              }
            }.buttonStyle(PaperPressStyle()).accessibilityIdentifier("chapters")
          }.padding(.top, 5).padding(.bottom, 14)
        }
        .padding(.horizontal, 28)
        .frame(minHeight: geometry.size.height, alignment: .top)
        .modifier(BookArrival())
      }.scrollIndicators(.hidden).clipped()
    }
  }
}

struct PaperSheet<Content: View>: View {
  let title: String
  let subtitle: String
  let closeLabel: String
  var closeIdentifier: String?
  let close: () -> Void
  @ViewBuilder let content: Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 25) {
        HStack {
          Eyebrow(text: "THE RAINWATER POST", color: Ink.blue)
          Spacer()
          Button(action: close) {
            Image(systemName: "xmark").font(.system(size: 17, weight: .light))
              .foregroundStyle(Ink.blue).frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }.accessibilityLabel(closeLabel).accessibilityIdentifier(closeIdentifier ?? closeLabel)
        }
        VStack(alignment: .leading, spacing: 8) {
          Text(title).font(Ink.title(36)).tracking(-0.8).foregroundStyle(Ink.night)
          Text(subtitle).font(Ink.italic(18)).foregroundStyle(Ink.blue)
        }
        PostalRule(color: Ink.blue)
        content
      }.padding(.horizontal, 26).padding(.bottom, 36).padding(.top, 14)
    }
    .scrollIndicators(.hidden)
    .background { Ink.cream.overlay(PaperTexture()).ignoresSafeArea() }
    .presentationDragIndicator(.visible)
  }
}

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @AppStorage("sound") private var sound = false
  @AppStorage("haptics") private var haptics = true
  var body: some View {
    PaperSheet(
      title: "Quiet details", subtitle: "Settle into your own rhythm.",
      closeLabel: "Close settings", closeIdentifier: "closeSettings"
    ) {
      dismiss()
    } content: {
      VStack(spacing: 20) {
        Toggle("Sound effects", isOn: $sound).accessibilityIdentifier("soundToggle")
        Divider().overlay(Ink.blue.opacity(0.1))
        Toggle("Gentle haptics", isOn: $haptics).accessibilityIdentifier("hapticsToggle")
      }
      .font(Ink.title(21)).foregroundStyle(Ink.night).tint(Ink.blue)
      VStack(alignment: .leading, spacing: 14) {
        Eyebrow(text: "A SLOWER KIND OF GAME", color: Ink.red)
        Text(
          "Plan as long as you like. The tide rises only while your boat sails. Leave the app and the town waits for you."
        )
        Text(
          "Motion follows your iPhone’s accessibility setting. Your delivered letters stay saved on this device."
        )
      }.font(.system(size: 14)).foregroundStyle(Ink.blue).lineSpacing(5)
      HStack(spacing: 18) {
        PostalSeal(color: Ink.red)
        Text("No accounts. No adverts.\nJust one small boat.")
          .font(Ink.italic(19)).foregroundStyle(Ink.night)
      }.padding(.top, 4)
    }.presentationDetents([.large])
  }
}

struct ChapterView: View {
  let store: ProgressStore
  let select: (Int) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    PaperSheet(
      title: "Letters from the rain",
      subtitle: "\(store.completed.count) of ten little journeys, delivered.",
      closeLabel: "Close collection"
    ) {
      dismiss()
    } content: {
      VStack(spacing: 4) {
        ForEach(Level.all) { level in
          Button {
            select(level.id)
          } label: {
            HStack(spacing: 16) {
              ZStack {
                StampShape().fill(level.id <= store.unlocked ? Ink.blue : Ink.blue.opacity(0.08))
                Text(String(format: "%02d", level.id + 1))
                  .font(Ink.italic(27)).foregroundStyle(
                    level.id <= store.unlocked ? Ink.cream : Ink.blue)
              }.frame(width: 50, height: 61)
              VStack(alignment: .leading, spacing: 5) {
                Text(level.district.uppercased()).font(.system(size: 8, weight: .medium)).tracking(
                  1.5
                )
                .foregroundStyle(Ink.blue)
                Text(level.title).font(Ink.title(22)).foregroundStyle(Ink.night)
                Text(
                  store.completed[String(level.id)].map { "Delivered · best \($0) moves" }
                    ?? (level.id <= store.unlocked
                      ? "Ready to sail" : "Deliver the previous letter")
                )
                .font(.system(size: 11)).foregroundStyle(Ink.blue)
              }
              Spacer()
              Image(
                systemName: level.id > store.unlocked
                  ? "lock" : store.completed[String(level.id)] != nil ? "checkmark" : "arrow.right"
              )
              .font(.system(size: 13, weight: .light)).foregroundStyle(Ink.red)
            }.padding(.vertical, 16).contentShape(Rectangle())
          }
          .buttonStyle(PaperPressStyle())
          .disabled(level.id > store.unlocked)
          .opacity(level.id > store.unlocked ? 0.6 : 1)
          .accessibilityIdentifier("chapter\(level.id + 1)")
          Divider().overlay(Ink.blue.opacity(0.1))
        }
      }
    }
  }
}
