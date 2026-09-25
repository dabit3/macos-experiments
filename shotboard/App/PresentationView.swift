import Combine
import SwiftUI

struct PresentationView: View {
  let project: Storyboard
  @Environment(\.dismiss) private var dismiss
  @State private var index = 0
  @State private var elapsed = 0
  @State private var playing = false
  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  private var shot: Shot { project.shots[index] }
  private var position: Int { project.shots.prefix(index).reduce(0) { $0 + $1.duration } + elapsed }

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 18) {
        HStack {
          Text("SHOTBOARD / SCREENING ROOM").font(
            .system(size: 10, weight: .medium, design: .monospaced)
          ).tracking(2).foregroundStyle(Palette.muted)
          Spacer()
          Button {
            dismiss()
          } label: {
            Label("Back to studio", systemImage: "xmark").font(.system(size: 13))
          }
          .buttonStyle(StudioButton())
        }
        HStack(alignment: .firstTextBaseline) {
          Text(project.title).font(.system(size: 32, design: .serif))
          Spacer()
          Text(String(format: "%02d / %02d", index + 1, project.shots.count))
            .font(.system(size: 16, design: .monospaced)).foregroundStyle(Palette.yellow)
        }
        GeometryReader { frame in
          let width = min(frame.size.width, frame.size.height * shot.ratio.value)
          InkCanvas(shot: shot).frame(width: width, height: width / shot.ratio.value)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        VStack(spacing: 8) {
          Text(shot.title).font(.system(size: 26, design: .serif))
          Text(
            "\(shot.size.rawValue.uppercased())  /  \(shot.movement.rawValue.uppercased())  /  \(shot.duration) SECONDS"
          )
          .font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2)
          .foregroundStyle(Palette.muted)
          Text(shot.notes).font(.system(size: 14)).foregroundStyle(Palette.muted).lineLimit(2)
            .frame(height: 42)
        }
        VStack(spacing: 18) {
          GeometryReader { bar in
            ZStack(alignment: .leading) {
              Capsule().fill(Palette.elevated)
              Capsule().fill(Palette.yellow).frame(
                width: bar.size.width * Double(position) / Double(max(project.runtime, 1)))
            }
          }.frame(height: 3)
          HStack(spacing: 24) {
            Text("\(Storyboard.timecode(position)) / \(project.runtimeLabel)")
              .font(.system(size: 13, design: .monospaced)).foregroundStyle(Palette.muted)
            Spacer()
            Button {
              previous()
            } label: {
              Image(systemName: "backward.end.fill").frame(width: 44, height: 44)
            }
            .disabled(index == 0).accessibilityLabel("Previous shot")
            Button {
              if position >= project.runtime {
                index = 0
                elapsed = 0
              }
              playing.toggle()
            } label: {
              Label(
                playing ? "Pause" : "Play sequence",
                systemImage: playing ? "pause.fill" : "play.fill"
              )
              .font(.system(size: 14, weight: .semibold)).frame(width: 130)
            }.buttonStyle(StudioButton(accent: true)).keyboardShortcut(.space, modifiers: [])
            Button {
              next()
            } label: {
              Image(systemName: "forward.end.fill").frame(width: 44, height: 44)
            }
            .disabled(index == project.shots.count - 1).accessibilityLabel("Next shot")
            Spacer()
            Button {
              index = 0
              elapsed = 0
              playing = false
            } label: {
              Label("Restart", systemImage: "arrow.counterclockwise").font(.system(size: 12))
            }
            .buttonStyle(StudioButton())
          }
        }
      }.padding(.horizontal, geometry.size.width > 1000 ? 70 : 30).padding(.vertical, 25)
        .background(Palette.background).foregroundStyle(Palette.ivory)
    }
    .onReceive(timer) { _ in
      guard playing else { return }
      elapsed += 1
      if elapsed >= shot.duration {
        if index < project.shots.count - 1 {
          index += 1
          elapsed = 0
        } else {
          elapsed = shot.duration
          playing = false
        }
      }
    }
  }

  private func previous() {
    index = max(index - 1, 0)
    elapsed = 0
  }
  private func next() {
    index = min(index + 1, project.shots.count - 1)
    elapsed = 0
  }
}
