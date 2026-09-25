import AVFoundation
import AppKit
import SwiftUI

@main
struct CutlineApp: App {
  @StateObject private var editor = Editor()

  var body: some Scene {
    WindowGroup("Cutline") {
      EditorView(editor: editor)
        .preferredColorScheme(.dark)
        .frame(minWidth: 1180, minHeight: 800)
        .onAppear {
          NSApplication.shared.setActivationPolicy(.regular)
          NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    .defaultSize(width: 1420, height: 920)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Open Project…", action: editor.openProject).keyboardShortcut("o")
        Button("Save Project As…", action: editor.saveAs).keyboardShortcut("s")
        Button("Import Video…", action: editor.importMedia).keyboardShortcut("i")
      }
      CommandGroup(replacing: .undoRedo) {
        Button("Undo", action: editor.undoFromMenu).keyboardShortcut("z")
      }
    }
  }
}

enum Palette {
  static let base = Color(red: 0.055, green: 0.067, blue: 0.079)
  static let panel = Color(red: 0.083, green: 0.096, blue: 0.109)
  static let raised = Color(red: 0.12, green: 0.135, blue: 0.148)
  static let line = Color.white.opacity(0.085)
  static let muted = Color(red: 0.57, green: 0.62, blue: 0.65)
  static let cyan = Color(red: 0.57, green: 0.87, blue: 0.84)
}

struct EditorView: View {
  @ObservedObject var editor: Editor

  var body: some View {
    VStack(spacing: 0) {
      header
      Rectangle().fill(Palette.line).frame(height: 1)
      HStack(spacing: 0) {
        mediaShelf.frame(width: 230)
        divider
        preview.frame(maxWidth: .infinity, maxHeight: .infinity)
        divider
        Inspector(editor: editor).frame(width: 264)
      }
      .frame(maxHeight: .infinity)
      Rectangle().fill(Palette.line).frame(height: 1)
      timeline.frame(height: 219)
      footer
    }
    .background(Palette.base)
    .tint(Palette.cyan)
    .foregroundStyle(Color.white.opacity(0.93))
    .disabled(editor.busy)
    .overlay {
      if editor.busy {
        ZStack {
          Color.black.opacity(0.6)
          VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text(editor.status).font(.system(size: 17, weight: .medium))
            Text("LOCAL MEDIA · NO CLOUD REQUIRED")
              .font(.system(size: 10, weight: .semibold)).tracking(2).foregroundStyle(Palette.muted)
          }
          .padding(38).background(Palette.panel, in: RoundedRectangle(cornerRadius: 18))
        }
      }
    }
    .alert(
      "A little course correction",
      isPresented: Binding(
        get: { editor.error != nil }, set: { if !$0 { editor.error = nil } }
      )
    ) {
      Button("OK") { editor.error = nil }
    } message: {
      Text(editor.error ?? "")
    }
  }

  var divider: some View { Rectangle().fill(Palette.line).frame(width: 1) }

  var header: some View {
    HStack(spacing: 14) {
      HStack(spacing: 9) {
        Image(systemName: "film.stack").font(.system(size: 19, weight: .light)).foregroundStyle(
          Palette.cyan)
        Text("CUTLINE").font(.system(size: 17, weight: .bold, design: .rounded)).tracking(3)
      }
      Rectangle().fill(Palette.line).frame(width: 1, height: 24).padding(.horizontal, 8)
      VStack(alignment: .leading, spacing: 4) {
        Text(editor.project.name).font(.system(size: 13, weight: .semibold))
        Text("TRAVEL STUDY  /  01").font(.system(size: 9, weight: .medium)).tracking(1.8)
          .foregroundStyle(Palette.muted)
      }
      Spacer()
      ToolButton(icon: "arrow.uturn.backward", label: "Undo", action: editor.undo)
        .disabled(!editor.canUndo)
      ToolButton(icon: "folder", label: "Open", action: editor.openProject)
      ToolButton(icon: "square.and.arrow.down", label: "Save", action: editor.saveAs)
      Button(action: editor.exportMovie) {
        HStack(spacing: 9) {
          Image(systemName: "arrow.up.right")
          Text("Export film").fontWeight(.semibold)
        }
        .font(.system(size: 12)).padding(.horizontal, 17).padding(.vertical, 11)
        .background(Palette.cyan, in: RoundedRectangle(cornerRadius: 7))
        .foregroundStyle(Palette.base)
      }
      .buttonStyle(.plain).disabled(editor.project.clips.isEmpty)
      .accessibilityIdentifier("exportFilm")
    }
    .padding(.leading, 82).padding(.trailing, 24).frame(height: 76)
  }

  var mediaShelf: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        sectionLabel("MEDIA LIBRARY")
        Spacer()
        Text(String(format: "%02d", editor.project.media.count)).foregroundStyle(Palette.muted)
          .font(.system(size: 10, design: .monospaced))
      }
      HStack(spacing: 6) {
        Circle().fill(Palette.cyan).frame(width: 5, height: 5)
        Text("The slow travel collection").font(.system(size: 11)).foregroundStyle(Palette.muted)
      }
      ScrollView {
        VStack(spacing: 18) {
          ForEach(editor.project.media) { media in
            VStack(alignment: .leading, spacing: 8) {
              ZStack(alignment: .bottomTrailing) {
                thumbnail(media.id)
                  .aspectRatio(16 / 9, contentMode: .fit)
                  .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(String(format: "%.1fs", media.duration))
                  .font(.system(size: 9, weight: .semibold, design: .monospaced))
                  .padding(5).background(
                    Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 3)
                  )
                  .padding(6)
              }
              HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                  Text(media.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                  Text(media.detail).font(.system(size: 8, weight: .medium))
                    .tracking(1).foregroundStyle(Palette.muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                Button {
                  editor.append(media)
                } label: {
                  Image(systemName: "plus").font(.system(size: 13))
                    .frame(width: 28, height: 28)
                    .background(Palette.raised, in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain).foregroundStyle(Palette.cyan)
                .accessibilityLabel("Append \(media.name)")
              }
            }
          }
        }
      }.scrollIndicators(.hidden)
      Button(action: editor.importMedia) {
        Label("Import local video", systemImage: "plus")
          .font(.system(size: 11, weight: .medium)).frame(maxWidth: .infinity).padding(
            .vertical, 11
          )
          .background(Palette.raised, in: RoundedRectangle(cornerRadius: 6))
      }.buttonStyle(.plain)
      Text("Original motion studies • 24 fps\nSilent by design. Made to wander.")
        .font(.system(size: 9)).lineSpacing(4).foregroundStyle(Palette.muted)
    }
    .padding(20).background(Palette.panel)
  }

  var preview: some View {
    VStack(spacing: 0) {
      HStack {
        sectionLabel("PROGRAM")
        Spacer()
        Text("FIT  ·  1280 × 720").font(.system(size: 9, weight: .medium, design: .monospaced))
          .foregroundStyle(Palette.muted)
      }.padding(.horizontal, 26).padding(.top, 25)
      Spacer(minLength: 24)
      ZStack {
        PlayerSurface(player: editor.player)
        if editor.project.clips.isEmpty {
          VStack(spacing: 14) {
            Image(systemName: "film").font(.system(size: 36, weight: .ultraLight))
            Text("Every journey starts with a cut.").font(.system(size: 20, design: .serif))
            Text("Append a clip from your media library.")
              .font(.system(size: 12)).foregroundStyle(Palette.muted)
          }
        }
      }
      .aspectRatio(16 / 9, contentMode: .fit)
      .background(Color.black)
      .clipShape(RoundedRectangle(cornerRadius: 3))
      .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.line, lineWidth: 1))
      .shadow(color: .black.opacity(0.35), radius: 22, y: 13)
      .padding(.horizontal, 26)
      Spacer(minLength: 22)
      HStack {
        Text(timecode(editor.time)).foregroundStyle(Palette.cyan)
          .font(.system(size: 12, weight: .medium, design: .monospaced))
        Text("/  \(timecode(editor.project.duration))").font(.system(size: 11, design: .monospaced))
          .foregroundStyle(Palette.muted)
        Spacer()
        Button {
          editor.seek(0)
        } label: {
          Image(systemName: "backward.end.fill").frame(width: 32, height: 32)
        }.buttonStyle(.plain).accessibilityLabel("Go to start")
        Button(action: editor.togglePlayback) {
          Image(systemName: editor.playing ? "pause.fill" : "play.fill")
            .frame(width: 42, height: 34).background(
              Palette.raised, in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).accessibilityLabel(
          editor.playing ? "Pause sequence" : "Play sequence")
        Spacer()
        Text("24").font(.system(size: 11, weight: .semibold, design: .monospaced))
        Text("FPS").font(.system(size: 9)).foregroundStyle(Palette.muted)
      }.padding(.horizontal, 26).padding(.bottom, 12)
      Slider(
        value: Binding(get: { editor.time }, set: { editor.seek($0) }),
        in: 0...max(0.01, editor.project.duration)
      )
      .accessibilityLabel("Scrub sequence").padding(.horizontal, 24).padding(.bottom, 22)
    }
  }

  var timeline: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        sectionLabel("SEQUENCE")
        Text("\(editor.project.clips.count) CLIPS").font(.system(size: 9, design: .monospaced))
          .foregroundStyle(Palette.muted)
        Spacer()
        ToolButton(icon: "arrow.left", label: "Move left") {
          if let id = editor.selected { editor.change { $0.move(id, by: -1) } }
        }.disabled(editor.selected == nil || editor.selected == editor.project.clips.first?.id)
        ToolButton(icon: "arrow.right", label: "Move right") {
          if let id = editor.selected { editor.change { $0.move(id, by: 1) } }
        }.disabled(editor.selected == nil || editor.selected == editor.project.clips.last?.id)
        ToolButton(icon: "trash", label: "Remove", action: editor.removeSelected).disabled(
          editor.selected == nil)
        Rectangle().fill(Palette.line).frame(width: 1, height: 18)
        Button("Clear", action: editor.clearTimeline).buttonStyle(.plain)
          .font(.system(size: 11)).foregroundStyle(Palette.muted).disabled(
            editor.project.clips.isEmpty)
      }.padding(.horizontal, 24).frame(height: 50)
      HStack(spacing: 12) {
        VStack(spacing: 24) {
          Text("V1").foregroundStyle(Palette.cyan)
          Text("T1").foregroundStyle(Palette.muted)
        }.font(.system(size: 10, weight: .semibold, design: .monospaced)).frame(width: 27)
        GeometryReader { geo in
          let width = max(1, geo.size.width)
          let total = max(0.01, editor.project.duration)
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              ForEach(0..<7) { tick in
                Text(timecode(total * Double(tick) / 6))
                  .font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
                if tick < 6 { Spacer(minLength: 0) }
              }
            }.frame(height: 14)
            HStack(spacing: 3) {
              ForEach(Array(editor.project.clips.enumerated()), id: \.element.id) { index, clip in
                let media = editor.project.media.first { $0.id == clip.mediaID }
                Button {
                  editor.selected = clip.id
                } label: {
                  HStack(spacing: 1) {
                    thumbnail(clip.mediaID)
                    thumbnail(clip.mediaID)
                    thumbnail(clip.mediaID)
                  }
                  .opacity(editor.selected == clip.id ? 0.94 : 0.65)
                  .frame(
                    width: max(
                      1,
                      (width - CGFloat(max(0, editor.project.clips.count - 1)) * 3) * clip.duration
                        / total), height: 70
                  )
                  .clipped()
                  .overlay {
                    LinearGradient(
                      colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                  }
                  .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 6) {
                      Text(String(format: "%02d", index + 1)).foregroundStyle(Palette.cyan)
                      Text(media?.name ?? "Missing clip").lineLimit(1)
                      Spacer(minLength: 0)
                      Text(String(format: "%.1fs", clip.duration)).foregroundStyle(
                        .white.opacity(0.7))
                    }.font(.system(size: 10, weight: .medium)).padding(8)
                  }
                  .clipShape(RoundedRectangle(cornerRadius: 5))
                  .overlay(
                    RoundedRectangle(cornerRadius: 5)
                      .stroke(
                        editor.selected == clip.id ? Palette.cyan : Palette.line,
                        lineWidth: editor.selected == clip.id ? 2 : 1))
                }.buttonStyle(.plain).accessibilityLabel(
                  "Select clip \(index + 1): \(media?.name ?? "missing")")
              }
            }.frame(height: 70)
            if editor.project.titleEnabled && !editor.project.clips.isEmpty {
              HStack(spacing: 6) {
                Image(systemName: "textformat")
                Text(editor.project.title.replacingOccurrences(of: "\n", with: " ")).lineLimit(1)
              }.font(.system(size: 10))
                .padding(.horizontal, 9).frame(
                  width: max(70, width * min(4, editor.project.clips.first?.duration ?? 4) / total),
                  height: 25, alignment: .leading
                )
                .background(Palette.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(Palette.cyan)
            }
          }
          if !editor.project.clips.isEmpty {
            Rectangle().fill(Palette.cyan).frame(width: 1, height: 134)
              .overlay(alignment: .top) {
                Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9)).foregroundStyle(
                  Palette.cyan
                )
                .offset(y: -3)
              }
              .offset(x: min(width - 1, width * editor.time / total), y: 15)
              .allowsHitTesting(false)
          }
        }
      }.padding(.horizontal, 24)
    }.background(Palette.panel)
  }

  var footer: some View {
    HStack(spacing: 7) {
      Circle().fill(Palette.cyan.opacity(0.7)).frame(width: 4, height: 4)
      Text(editor.status).lineLimit(1)
      if let url = editor.exportURL {
        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
          .buttonStyle(.plain).foregroundStyle(Palette.cyan)
      }
      Spacer()
      Text("ONE TRACK. ENDLESS PLACES.").tracking(1.7)
    }.font(.system(size: 9)).foregroundStyle(Palette.muted)
      .padding(.horizontal, 25).frame(height: 32).background(Palette.base)
  }

  @ViewBuilder func thumbnail(_ id: String) -> some View {
    if let image = editor.thumbnails[id] {
      Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
    } else {
      Rectangle().fill(Palette.raised)
    }
  }
}

func sectionLabel(_ text: String) -> some View {
  Text(text).font(.system(size: 10, weight: .semibold)).tracking(1.7).foregroundStyle(Palette.muted)
}

struct ToolButton: View {
  var icon: String
  var label: String
  var action: () -> Void
  var body: some View {
    Button(action: action) {
      Label(label, systemImage: icon).font(.system(size: 11))
        .padding(.horizontal, 8).frame(height: 32).contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(label)
  }
}

struct PlayerSurface: NSViewRepresentable {
  let player: AVPlayer
  func makeNSView(context: Context) -> PlayerLayerView {
    let view = PlayerLayerView()
    view.playerLayer.player = player
    return view
  }
  func updateNSView(_ nsView: PlayerLayerView, context: Context) {}
}

final class PlayerLayerView: NSView {
  let playerLayer = AVPlayerLayer()
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer = playerLayer
    playerLayer.videoGravity = .resizeAspect
    playerLayer.backgroundColor = NSColor.black.cgColor
  }
  required init?(coder: NSCoder) { nil }
}
