import SwiftUI

struct RigView: View {
  @EnvironmentObject var store: AppStore
  @ObservedObject var scene: RigScene
  @State private var showHelp = !UserDefaults.standard.bool(forKey: "pocketdgx.helpSeen")
  @State private var flash = false

  var readout: HUDReadout { scene.readout }

  var body: some View {
    ZStack {
      RigViewContainer(scene: scene).ignoresSafeArea()
      if flash {
        Color.white.ignoresSafeArea().transition(.opacity)
      }
      VStack(spacing: 0) {
        topBar
        Spacer()
        if readout.phase != .off {
          telemetry.transition(.move(edge: .leading).combined(with: .opacity)).padding(.bottom, 14)
        }
        controls
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 10)
      if showHelp {
        HelpCard {
          UserDefaults.standard.set(true, forKey: "pocketdgx.helpSeen")
          withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showHelp = false }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
      }
    }
    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: readout.phase)
  }

  private var topBar: some View {
    HStack(spacing: 10) {
      Button {
        store.leave()
      } label: {
        Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold)).foregroundStyle(
          Palette.mint
        )
        .frame(width: 40, height: 38)
      }
      .background(Chamfer(cut: 8).fill(Palette.ink.opacity(0.75)))
      .overlay(Chamfer(cut: 8).stroke(Palette.green.opacity(0.4), lineWidth: 1))
      .accessibilityLabel("Back to title")
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Circle().fill(scene.isAR ? Palette.mint : Palette.amber).frame(width: 6, height: 6)
            .shadow(color: (scene.isAR ? Palette.mint : Palette.amber).opacity(0.9), radius: 4)
          Text(scene.isAR ? "AR LIVE" : "SHOWROOM").font(.label(11)).tracking(2).foregroundStyle(
            Palette.cream)
          Text("· \(store.kind.title.uppercased())").font(.label(11)).tracking(1).foregroundStyle(
            Palette.muted)
        }
        Text(scene.status).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
      }
      .padding(.horizontal, 12)
      .frame(height: 38)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Chamfer(cut: 8).fill(Palette.ink.opacity(0.75)))
      .overlay(Chamfer(cut: 8).stroke(Palette.green.opacity(0.3), lineWidth: 1))
      iconButton(store.kind == .rack ? "cpu.fill" : "server.rack", label: "Swap rig") {
        store.swap()
      }
      iconButton("questionmark", label: "Help") {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showHelp = true }
      }
    }
  }

  private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(
        Palette.mint
      )
      .frame(width: 40, height: 38)
    }
    .background(Chamfer(cut: 8).fill(Palette.ink.opacity(0.75)))
    .overlay(Chamfer(cut: 8).stroke(Palette.green.opacity(0.4), lineWidth: 1))
    .accessibilityLabel(label)
  }

  private var telemetry: some View {
    HStack {
      VStack(alignment: .leading, spacing: 8) {
        if readout.phase == .booting {
          Text("BOOT SEQUENCE").font(.label(10)).tracking(3).foregroundStyle(Palette.muted)
          Text(BootSequence.line(for: store.kind, progress: readout.transition))
            .font(.mono(12)).foregroundStyle(Palette.mint).frame(
              minHeight: 30, alignment: .topLeading)
          GeometryReader { proxy in
            ZStack(alignment: .leading) {
              Rectangle().fill(Palette.slate)
              Rectangle().fill(Palette.green).frame(width: proxy.size.width * readout.transition)
                .shadow(color: Palette.green, radius: 4)
            }
          }
          .frame(height: 3)
        } else {
          Text(readout.phase == .shuttingDown ? "HALTING" : "THROUGHPUT").font(.label(10)).tracking(
            3
          )
          .foregroundStyle(Palette.muted)
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(Format.tokens(readout.tokensPerSecond)).font(.display(40)).foregroundStyle(
              Palette.mint
            )
            .contentTransition(.numericText()).shadow(color: Palette.green.opacity(0.7), radius: 10)
            Text("tok/s").font(.label(13)).foregroundStyle(Palette.muted)
          }
          Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
            GridRow {
              metric("POWER", Format.watts(readout.watts))
              metric("FANS", "\(Int(readout.fan * 100))%")
            }
            GridRow {
              metric("UPTIME", Format.uptime(readout.uptime))
              metric("SIZE", Format.scale(readout.scale, kind: store.kind))
            }
          }
        }
      }
      .frame(width: 210, alignment: .leading)
      .panel(glow: readout.phase == .running)
      Spacer()
    }
  }

  private func metric(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(label).font(.label(9)).tracking(2).foregroundStyle(Palette.muted)
      Text(value).font(.mono(12)).foregroundStyle(Palette.cream).contentTransition(.numericText())
    }
  }

  private var controls: some View {
    VStack(spacing: 12) {
      HStack(spacing: 6) {
        ForEach(ScalePreset.allCases, id: \.self) { preset in
          let active = ScalePreset.nearest(to: readout.scale) == preset
          Button {
            scene.setScale(preset.multiplier)
          } label: {
            Text(preset.label).font(.label(12)).tracking(1).foregroundStyle(
              active ? Palette.ink : Palette.mint
            )
            .frame(maxWidth: .infinity).frame(height: 34)
            .background(Chamfer(cut: 6).fill(active ? Palette.green : Palette.ink.opacity(0.75)))
            .overlay(Chamfer(cut: 6).stroke(Palette.green.opacity(active ? 0 : 0.4), lineWidth: 1))
          }
          .accessibilityLabel("Scale \(preset.label)")
        }
      }
      HStack(spacing: 12) {
        Button {
          scene.togglePower()
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "power").font(.system(size: 18, weight: .bold))
            Text(readout.phase == .off || readout.phase == .shuttingDown ? "Power on" : "Power off")
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(
          NeonButtonStyle(prominent: readout.phase == .off || readout.phase == .shuttingDown)
        )
        .disabled(!readout.placed)
        .opacity(readout.placed ? 1 : 0.5)
        Button {
          takePhoto()
        } label: {
          Image(systemName: "camera.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(
            Palette.mint
          )
          .frame(width: 60, height: 46)
        }
        .background(Chamfer(cut: 9).fill(Palette.ink.opacity(0.8)))
        .overlay(Chamfer(cut: 9).stroke(Palette.green.opacity(0.7), lineWidth: 1))
        .accessibilityLabel("Take photo")
      }
    }
  }

  private func takePhoto() {
    withAnimation(.easeOut(duration: 0.08)) { flash = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
      withAnimation(.easeIn(duration: 0.25)) { flash = false }
    }
    store.photo()
  }
}

struct HelpCard: View {
  var dismiss: () -> Void
  var body: some View {
    ZStack {
      Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: dismiss)
      VStack(alignment: .leading, spacing: 16) {
        Text("HOW TO PLAY").font(.label(12)).tracking(4).foregroundStyle(Palette.mint)
        row("hand.tap.fill", "Tap the rig", "Power it on. Fans spin, LEDs breathe, tokens fly.")
        row(
          "arrow.up.left.and.arrow.down.right", "Pinch",
          "Scale from desk toy to house-sized monolith.")
        row(
          "hand.draw.fill", "Drag",
          "Orbit in the showroom, or slide the rig across your floor in AR.")
        row("rotate.3d", "Twist", "Two-finger rotate to show off the good side.")
        row("camera.fill", "Shutter", "Snapshot with a caption, then share it anywhere.")
        Button("Let's go", action: dismiss).buttonStyle(NeonButtonStyle()).frame(
          maxWidth: .infinity)
      }
      .padding(22)
      .frame(maxWidth: 340)
      .background(Chamfer(cut: 14).fill(Palette.charcoal.opacity(0.96)))
      .overlay(Chamfer(cut: 14).stroke(Palette.green.opacity(0.6), lineWidth: 1))
      .shadow(color: Palette.green.opacity(0.35), radius: 30)
      .padding(24)
    }
  }
  private func row(_ symbol: String, _ title: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: symbol).font(.system(size: 20, weight: .medium)).foregroundStyle(
        Palette.green
      ).frame(width: 28)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.label(15)).foregroundStyle(Palette.cream)
        Text(text).font(.system(size: 13)).foregroundStyle(Palette.muted)
      }
    }
  }
}
