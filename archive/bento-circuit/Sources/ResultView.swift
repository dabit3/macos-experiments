import LinkPresentation
import SwiftUI
import UIKit

struct ShareParcel: Identifiable {
  let id = UUID()
  let image: UIImage
  let text: String
}

struct NativeShareSheet: UIViewControllerRepresentable {
  let parcel: ShareParcel
  func makeUIViewController(context: Context) -> UIActivityViewController {
    let configuration = UIActivityItemsConfiguration(objects: [
      parcel.image, parcel.text as NSString,
    ])
    configuration.perItemMetadataProvider = { index, key in
      guard index == 0 else { return nil }
      if key == .linkPresentationMetadata {
        let metadata = LPLinkMetadata()
        metadata.title = "Bento Circuit · Packed with care"
        metadata.imageProvider = NSItemProvider(object: parcel.image)
        metadata.iconProvider = NSItemProvider(object: parcel.image)
        return metadata
      }
      if key == .title { return "Bento Circuit postcard" }
      return nil
    }
    return UIActivityViewController(activityItemsConfiguration: configuration)
  }
  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct LunchPostcard: View {
  let lunch: Lunch
  let game: PackingGame
  var width: CGFloat = 340

  var body: some View {
    VStack(spacing: 20) {
      HStack(alignment: .center, spacing: 9) {
        CircuitMark()
        VStack(alignment: .leading, spacing: 5) {
          Text("Bento Circuit").font(.system(size: 21, weight: .regular, design: .serif))
            .tracking(-0.7)
          Text(
            lunch.isDaily
              ? "THE DAILY PARCEL" : "THE LOCAL LINE / VOL. 01"
          )
          .font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1)
          .foregroundStyle(Palette.muted)
        }
        Spacer()
        PackingSeal(title: "STOP", subtitle: String(format: "%02d", lunch.number))
          .scaleEffect(0.82).frame(width: 51, height: 51).rotationEffect(.degrees(9))
      }
      Perforation()
      BoardView(
        lunch: lunch, game: game, cellSize: (width - 76) / CGFloat(lunch.width), showLetters: false
      )
      .rotationEffect(.degrees(-4))
      .padding(.vertical, 20)
      .accessibilityHidden(true)
      VStack(spacing: 8) {
        HStack(spacing: 10) {
          ForEach(0..<3) { index in
            Image(systemName: index < game.stars(lunch) ? "star.fill" : "star")
          }
        }.font(.system(size: 18)).foregroundStyle(Palette.orange).padding(.bottom, 5)
        Text(game.stars(lunch) == 3 ? "Lunch, perfected." : "Packed with care.")
          .font(.system(size: 32, design: .serif)).tracking(-1.1)
          .minimumScaleFactor(0.7).lineLimit(1)
        Text(lunch.title.uppercased())
          .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.3)
          .foregroundStyle(Palette.muted)
      }
      Perforation()
      HStack {
        Text("\(game.moves) MOVES  ·  \(game.stars(lunch)) / 3 STARS")
        Spacer()
        Text(game.usedGuide ? "GUIDED LUNCH" : "MADE TO FIT")
      }
      .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(0.7)
      .foregroundStyle(Palette.muted)
    }
    .padding(24).frame(width: width)
    .background(Palette.cream)
    .foregroundStyle(Palette.ink)
    .overlay(Rectangle().stroke(Palette.gold.opacity(0.45), lineWidth: 0.7).padding(7))
    .overlay(alignment: .top) { Rectangle().fill(Palette.orange).frame(height: 4) }
  }
}

struct CelebrationPetals: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var scattered = false
  var body: some View {
    GeometryReader { proxy in
      ZStack {
        ForEach(0..<24) { index in
          Capsule().fill(index.isMultiple(of: 2) ? Palette.orange.opacity(0.65) : Palette.sage)
            .frame(width: 3, height: CGFloat(5 + index % 5))
            .rotationEffect(.degrees(Double(index * 41) + (scattered ? 180 : 0)))
            .position(
              x: scattered
                ? CGFloat((index * 47 + 19) % 100) / 100 * proxy.size.width : proxy.size.width / 2,
              y: scattered ? CGFloat((index * 71 + 11) % 100) / 100 * proxy.size.height : 80
            )
            .opacity(scattered ? 0 : 0.9)
        }
      }
      .onAppear {
        withAnimation(.easeOut(duration: reduceMotion ? 0 : 2.4)) { scattered = true }
      }
    }
    .allowsHitTesting(false).accessibilityHidden(true)
  }
}

struct ResultView: View {
  let lunch: Lunch
  let game: PackingGame
  let best: Int
  let replay: () -> Void
  let next: () -> Void
  let home: () -> Void
  @State private var parcel: ShareParcel?
  @State private var shareError = false

  var body: some View {
    GeometryReader { proxy in
      ScrollView {
        VStack(spacing: 20) {
          HStack(spacing: 12) {
            Rectangle().fill(Palette.gold.opacity(0.5)).frame(height: 1)
            MicroLabel(text: "YOUR LUNCH IS SERVED", color: Palette.cream)
            Rectangle().fill(Palette.gold.opacity(0.5)).frame(height: 1)
          }.padding(.top, 28)
          LunchPostcard(lunch: lunch, game: game, width: min(proxy.size.width - 40, 370))
            .compositingGroup()
            .shadow(color: Palette.ink.opacity(0.15), radius: 16, x: 0, y: 10)
          Text(
            game.stars(lunch) == 3
              ? "A perfect lunch. Every piece, one move."
              : (game.usedGuide
                ? "A guided lunch. Try without a guide for three stars."
                : "A lovely fit. Try one move per piece for three stars.")
          )
          .font(.system(size: 13, design: .serif)).italic()
          .foregroundStyle(Palette.cream.opacity(0.8)).multilineTextAlignment(.center)
          HStack(spacing: 12) {
            Button {
              share()
            } label: {
              Label("Share postcard", systemImage: "square.and.arrow.up")
            }.buttonStyle(PrimaryButton(light: true)).accessibilityIdentifier("Share postcard")
          }
          Button(
            lunch.isDaily || lunch.number == 12 ? "Back to the journey" : "Next lunch  →",
            action: next
          )
          .buttonStyle(PrimaryButton()).accessibilityIdentifier("Next lunch")
          HStack {
            Button("Pack again", action: replay).accessibilityIdentifier("Replay")
            Spacer()
            Text("BEST  \(best) / 3").font(.system(size: 9, weight: .bold, design: .monospaced))
            Spacer()
            Button("Journey", action: home).accessibilityIdentifier("Journey")
          }
          .font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.cream.opacity(0.85))
        }
        .padding(.horizontal, 22).padding(.bottom, 28)
      }
      .overlay(CelebrationPetals())
    }
    .background(Palette.ink)
    .sheet(item: $parcel) { NativeShareSheet(parcel: $0) }
    .alert("The postcard couldn’t be prepared.", isPresented: $shareError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Please try sharing again.")
    }
  }

  @MainActor private func share() {
    let renderer = ImageRenderer(content: LunchPostcard(lunch: lunch, game: game, width: 380))
    renderer.scale = 3
    guard let image = renderer.uiImage else {
      shareError = true
      return
    }
    parcel = ShareParcel(
      image: image,
      text:
        "Bento Circuit — \(lunch.title). \(game.stars(lunch))/3 stars in \(game.moves) moves. A little lunch, beautifully arranged."
    )
  }
}
