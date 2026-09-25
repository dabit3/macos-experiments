import SwiftUI
import UIKit

enum MuseumStyle {
  static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
  static let ink = Color(red: 0.19, green: 0.16, blue: 0.13)
  static let muted = Color(red: 0.45, green: 0.42, blue: 0.37)
  static let cobalt = Color(red: 0.12, green: 0.24, blue: 0.89)
  static let stone = Color(red: 0.91, green: 0.89, blue: 0.85)

  static func serif(_ size: CGFloat) -> Font {
    .system(size: size, weight: .regular, design: .serif)
  }
}

struct BrandMark: View {
  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<3) { index in
        RoundedRectangle(cornerRadius: 1)
          .fill(MuseumStyle.cobalt)
          .frame(width: 5, height: CGFloat(18 + index * 5))
      }
    }
    .accessibilityHidden(true)
  }
}

struct ExhibitArtwork: View {
  var artifact: Artifact
  var photo: Data? = nil

  var body: some View {
    GeometryReader { proxy in
      if let photo, let image = UIImage(data: photo) {
        Image(uiImage: image).resizable().scaledToFit()
          .frame(width: proxy.size.width, height: proxy.size.height)
      } else {
        let size = min(proxy.size.width / 300, proxy.size.height / 280)
        ZStack {
          Ellipse().fill(.black.opacity(0.09))
            .frame(width: 185, height: 16).blur(radius: 9).offset(y: 100)
          Group {
            switch artifact {
            case .camera: CameraArt()
            case .vase: VaseArt()
            case .record: RecordArt()
            case .chair: ChairArt()
            case .bottle: BottleArt()
            case .book: BookArt()
            case .unpictured: EmptyPlinth()
            }
          }
          .shadow(color: .black.opacity(0.12), radius: 9, x: 3, y: 9)
        }
        .frame(width: 300, height: 280)
        .scaleEffect(size)
        .frame(width: proxy.size.width, height: proxy.size.height)
      }
    }
    .accessibilityHidden(true)
  }
}

private struct EmptyPlinth: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 50)
        .stroke(MuseumStyle.muted.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
        .frame(width: 90, height: 110).offset(y: -28)
      Path { path in
        path.move(to: CGPoint(x: 62, y: 206))
        path.addLine(to: CGPoint(x: 88, y: 184))
        path.addLine(to: CGPoint(x: 212, y: 184))
        path.addLine(to: CGPoint(x: 238, y: 206))
        path.closeSubpath()
      }.fill(Color.white.opacity(0.75))
      Rectangle().fill(MuseumStyle.stone).frame(width: 176, height: 12).offset(y: 72)
      Rectangle().fill(MuseumStyle.cobalt).frame(width: 24, height: 3).offset(y: 73)
    }
  }
}

private struct CameraArt: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 5).fill(Color.gray)
        .frame(width: 50, height: 11).offset(x: -63, y: -69)
      RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.4))
        .frame(width: 24, height: 12).offset(x: 74, y: -71)
      RoundedRectangle(cornerRadius: 14)
        .fill(
          LinearGradient(
            colors: [Color(white: 0.86), .gray, Color(white: 0.76)], startPoint: .topLeading,
            endPoint: .bottomTrailing)
        )
        .frame(width: 240, height: 140)
      RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.14))
        .frame(width: 236, height: 90).offset(y: 13)
      ForEach(0..<28) { index in
        Path { path in
          path.move(to: CGPoint(x: 33 + index * 8, y: 114))
          path.addLine(to: CGPoint(x: 33 + index * 8, y: 184))
        }.stroke(.white.opacity(0.045), lineWidth: 2)
      }
      RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.18))
        .frame(width: 33, height: 19).offset(x: -84, y: -48)
      RoundedRectangle(cornerRadius: 2).fill(Color(red: 0.20, green: 0.30, blue: 0.31))
        .frame(width: 25, height: 11).offset(x: -84, y: -48)
      Text("CURIO 35").font(.system(size: 8, weight: .semibold, design: .monospaced))
        .foregroundStyle(.black.opacity(0.6)).offset(x: 65, y: -48)
      Circle().fill(.red.opacity(0.8)).frame(width: 9).offset(x: 94, y: -14)
      ZStack {
        Circle().fill(
          LinearGradient(
            colors: [Color(white: 0.7), Color(white: 0.22)], startPoint: .topLeading,
            endPoint: .bottomTrailing)
        )
        .frame(width: 120)
        ForEach(0..<5) { index in
          Circle().stroke(Color(white: Double(index % 2) * 0.13 + 0.12), lineWidth: 4)
            .frame(width: CGFloat(109 - index * 8))
        }
        Circle().fill(
          RadialGradient(
            colors: [Color(red: 0.12, green: 0.3, blue: 0.38), Color(white: 0.02)],
            center: .topLeading, startRadius: 0, endRadius: 48)
        )
        .frame(width: 66)
        Circle().stroke(.white.opacity(0.15), lineWidth: 1).frame(width: 47)
        Ellipse().fill(.white.opacity(0.23)).frame(width: 15, height: 25).rotationEffect(
          .degrees(35)
        ).offset(x: -13, y: -15)
      }.offset(x: 7, y: 12)
    }.rotationEffect(.degrees(-7))
  }
}

private struct VesselShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.width * 0.34, y: 0))
    path.addCurve(
      to: CGPoint(x: rect.width * 0.1, y: rect.height * 0.57),
      control1: CGPoint(x: rect.width * 0.44, y: rect.height * 0.3),
      control2: CGPoint(x: 0, y: rect.height * 0.31))
    path.addCurve(
      to: CGPoint(x: rect.width * 0.25, y: rect.height),
      control1: CGPoint(x: rect.width * 0.07, y: rect.height * 0.8),
      control2: CGPoint(x: rect.width * 0.17, y: rect.height * 0.98))
    path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height))
    path.addCurve(
      to: CGPoint(x: rect.width * 0.9, y: rect.height * 0.57),
      control1: CGPoint(x: rect.width * 0.83, y: rect.height * 0.98),
      control2: CGPoint(x: rect.width * 0.93, y: rect.height * 0.8))
    path.addCurve(
      to: CGPoint(x: rect.width * 0.66, y: 0),
      control1: CGPoint(x: rect.width, y: rect.height * 0.31),
      control2: CGPoint(x: rect.width * 0.56, y: rect.height * 0.3))
    path.closeSubpath()
    return path
  }
}

private struct VaseArt: View {
  var body: some View {
    ZStack {
      VesselShape().fill(
        LinearGradient(
          colors: [
            Color(red: 0.48, green: 0.21, blue: 0.10), Color(red: 0.82, green: 0.49, blue: 0.29),
            Color(red: 0.64, green: 0.32, blue: 0.16), Color(red: 0.36, green: 0.14, blue: 0.08),
          ], startPoint: .leading, endPoint: .trailing))
      VStack(spacing: 5) {
        ForEach(0..<30) { _ in
          Rectangle().fill(.white.opacity(0.065)).frame(height: 1)
        }
      }.mask(VesselShape())
      Ellipse().fill(Color(red: 0.28, green: 0.12, blue: 0.07))
        .frame(width: 52, height: 9).offset(y: -102)
      Ellipse().stroke(Color(red: 0.79, green: 0.49, blue: 0.3), lineWidth: 3)
        .frame(width: 53, height: 10).offset(y: -104)
    }.frame(width: 166, height: 209).offset(y: -1)
  }
}

private struct RecordArt: View {
  var body: some View {
    ZStack {
      Rectangle().fill(Color(red: 0.81, green: 0.77, blue: 0.62)).frame(width: 183, height: 200)
        .overlay(alignment: .topLeading) {
          VStack(alignment: .leading, spacing: 1) {
            Text("SUNDAY").font(.system(size: 20, weight: .black, design: .rounded))
            Text("IN BLUE").font(.system(size: 15, weight: .black, design: .rounded))
          }.foregroundStyle(MuseumStyle.cobalt).padding(13)
        }.rotationEffect(.degrees(-10)).offset(x: -27)
      Circle().fill(Color(white: 0.1)).frame(width: 196)
        .overlay {
          ZStack {
            ForEach(0..<18) { index in
              Circle().stroke(Color(white: 0.2).opacity(0.65), lineWidth: 0.7).frame(
                width: CGFloat(187 - index * 6))
            }
            Circle().fill(MuseumStyle.cobalt).frame(width: 60)
            Text("SIDE A").font(.system(size: 8, weight: .bold, design: .monospaced))
              .foregroundStyle(.white).offset(y: -12)
            Circle().fill(MuseumStyle.paper).frame(width: 7)
          }
        }.offset(x: 34, y: 8)
    }
  }
}

private struct ChairArt: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 28).stroke(
        Color(red: 0.48, green: 0.25, blue: 0.10), lineWidth: 12
      )
      .frame(width: 110, height: 125).offset(y: -43)
      RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.69, green: 0.43, blue: 0.2)).frame(
        width: 97, height: 52
      ).offset(y: -71)
      ForEach([-1.0, 1.0], id: \.self) { side in
        RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.42, green: 0.24, blue: 0.11)).frame(
          width: 10, height: 101
        ).rotationEffect(.degrees(side * -8)).offset(x: side * 50, y: 61)
        RoundedRectangle(cornerRadius: 5).fill(Color(red: 0.59, green: 0.34, blue: 0.15)).frame(
          width: 11, height: 89
        ).rotationEffect(.degrees(side * 8)).offset(x: side * 67, y: 65)
      }
      Ellipse().fill(
        LinearGradient(
          colors: [
            Color(red: 0.81, green: 0.58, blue: 0.32), Color(red: 0.5, green: 0.27, blue: 0.11),
          ], startPoint: .top, endPoint: .bottom)
      )
      .frame(width: 166, height: 51).offset(y: 20)
    }.rotationEffect(.degrees(-6))
  }
}

private struct BottleArt: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 27).fill(
        LinearGradient(
          colors: [
            Color(red: 0.04, green: 0.12, blue: 0.52), MuseumStyle.cobalt,
            Color(red: 0.03, green: 0.11, blue: 0.49),
          ], startPoint: .leading, endPoint: .trailing)
      )
      .frame(width: 113, height: 164).offset(y: 21)
      RoundedRectangle(cornerRadius: 8).fill(
        LinearGradient(
          colors: [Color(red: 0.05, green: 0.14, blue: 0.61), MuseumStyle.cobalt],
          startPoint: .leading, endPoint: .trailing)
      )
      .frame(width: 43, height: 76).offset(y: -83)
      Capsule().fill(Color(red: 0.06, green: 0.13, blue: 0.4)).frame(width: 49, height: 9).offset(
        y: -117)
      Capsule().fill(.white.opacity(0.24)).frame(width: 9, height: 111).blur(radius: 2).offset(
        x: -31, y: 23)
      Rectangle().fill(MuseumStyle.paper).frame(width: 84, height: 41).offset(y: 35)
      Text("BLEU\nNº 05").font(.system(size: 11, weight: .medium, design: .serif))
        .multilineTextAlignment(.center).foregroundStyle(MuseumStyle.cobalt).offset(y: 35)
    }
  }
}

private struct BookArt: View {
  var body: some View {
    ZStack {
      Rectangle().fill(Color(red: 0.69, green: 0.65, blue: 0.52)).frame(width: 167, height: 213)
        .offset(x: 4, y: 4)
      Rectangle().fill(Color(red: 0.86, green: 0.39, blue: 0.22)).frame(width: 161, height: 207)
      Rectangle().fill(.black.opacity(0.09)).frame(width: 9, height: 207).offset(x: -70)
      VStack(alignment: .leading, spacing: 7) {
        Text("WAYS\nOF\nSEEING").font(.system(size: 28, weight: .black, design: .rounded))
          .lineSpacing(-3)
        Rectangle().frame(width: 104, height: 2)
        Text("OBJECTS & IDEAS\nVOL. 01").font(
          .system(size: 9, weight: .medium, design: .monospaced))
      }.foregroundStyle(MuseumStyle.ink).offset(x: 6, y: -9)
    }.rotationEffect(.degrees(11))
  }
}
