import SwiftUI
import UIKit

struct StudioView: View {
  @StateObject private var studio = Studio()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var galleryOpen = false
  @State private var settingsOpen = false
  @State private var shareContent: ShareContent?
  @State private var previousTick = Date()
  @State private var reveal = false
  private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        StudioBackdrop(warm: studio.stage == .heat || studio.stage == .spin)
        VStack(spacing: 0) {
          navigation
          switch studio.stage {
          case .home: home(compact: geometry.size.height < 730)
          case .heat, .spin, .shape: play
          case .result: result(compact: geometry.size.height < 730)
          }
        }
        .padding(.horizontal, geometry.size.width < 390 ? 22 : 28)
        .padding(.bottom, 12)
        if studio.tutorial { tutorial }
        if studio.paused { pause }
      }
      .foregroundStyle(Palette.cream)
      .font(StudioType.body(14))
    }
    .onReceive(timer) { date in
      let delta = date.timeIntervalSince(previousTick)
      previousTick = date
      studio.tick(delta: delta)
    }
    .onChange(of: scenePhase) { _, value in
      if value != .active { studio.suspend() }
      previousTick = Date()
    }
    .onChange(of: studio.stage) { _, stage in
      reveal = false
      if stage == .result {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 1.6)) { reveal = true }
      }
    }
    .sheet(isPresented: $galleryOpen) { gallery }
    .sheet(isPresented: $settingsOpen) { settings }
    .sheet(item: $shareContent) { content in
      ShareSheet(image: content.image, text: content.text)
    }
  }

  private var navigation: some View {
    HStack {
      HStack(spacing: 9) {
        MakerMark().stroke(Palette.brass, lineWidth: 1.1).frame(width: 25, height: 29)
        Text("THE GLASS STUDIO").font(StudioType.label(8)).tracking(2)
          .foregroundStyle(Palette.muted)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Emberglass studio")
      Spacer()
      if studio.stage.isPlaying {
        ZStack {
          Circle().stroke(Palette.surface, lineWidth: 2)
          Circle().trim(from: 0, to: Double(studio.remaining) / studio.stage.duration)
            .stroke(Palette.brass, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(-90))
          Text("\(studio.remaining)").font(.system(size: 12, weight: .medium, design: .monospaced))
            .contentTransition(.numericText())
        }.frame(width: 34, height: 34)
          .accessibilityLabel("\(studio.remaining) seconds remaining")
        icon("pause", label: "Pause session", identifier: "pauseButton") { studio.suspend() }
      } else {
        icon("square.grid.2x2", label: "Open gallery", identifier: "galleryButton") {
          galleryOpen = true
        }
        icon("slider.horizontal.3", label: "Settings", identifier: "settingsButton") {
          settingsOpen = true
        }
      }
    }
    .frame(height: 48)
  }

  private func home(compact: Bool) -> some View {
    VStack(spacing: compact ? 8 : 14) {
      VStack(spacing: 3) {
        Text("Emberglass")
          .font(StudioType.display(compact ? 42 : 51))
          .tracking(-2.5)
        HStack(spacing: 12) {
          Rectangle().fill(Palette.brass.opacity(0.45)).frame(width: 24, height: 0.5)
          Text("fire into form").font(StudioType.italic(17)).foregroundStyle(Palette.brass)
          Rectangle().fill(Palette.brass.opacity(0.45)).frame(width: 24, height: 0.5)
        }
      }
      .padding(.top, compact ? 2 : 8)
      centerpiece(profile: studio.commission.radii, commission: studio.commission, molten: false)
        .frame(maxHeight: .infinity)
      VStack(spacing: compact ? 10 : 14) {
        HStack {
          HStack(spacing: 5) {
            ForEach(Commission.allCases, id: \.rawValue) { commission in
              Capsule()
                .fill(commission == studio.commission ? Palette.brass : Palette.surface)
                .frame(width: commission == studio.commission ? 20 : 5, height: 3)
            }
          }
          Spacer()
          Text(studio.archive.best > 0 ? "BEST \(studio.archive.best)" : "FIRST FIRING")
            .font(StudioType.label(9)).tracking(1.5).foregroundStyle(Palette.muted)
        }
        HStack(spacing: 13) {
          Text(String(format: "%02d", studio.commission.rawValue + 1))
            .font(StudioType.display(34)).foregroundStyle(Palette.brass.opacity(0.65))
          Rectangle().fill(Palette.brass.opacity(0.3)).frame(width: 1, height: 35)
          VStack(alignment: .leading, spacing: 4) {
            Text(studio.commission.title).font(StudioType.display(27))
            Text(studio.commission.subtitle).font(StudioType.body(11))
              .foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 4)
          Button {
            let next = (studio.commission.rawValue + 1) % (studio.archive.unlocked + 1)
            studio.commission = Commission(rawValue: next) ?? .tide
            studio.feedback()
          } label: {
            Image(systemName: studio.archive.unlocked == 0 ? "lock" : "arrow.right")
              .font(.system(size: 15)).frame(width: 44, height: 44)
              .background(Circle().fill(Palette.surface.opacity(0.5)))
              .overlay(Circle().stroke(Palette.brass.opacity(0.25), lineWidth: 0.7))
          }
          .disabled(studio.archive.unlocked == 0)
          .accessibilityLabel(
            studio.archive.unlocked == 0
              ? "More commissions unlock at 55 points" : "Next commission"
          )
          .accessibilityIdentifier("nextCommissionButton")
        }
        primary("Begin firing", symbol: "arrow.right", identifier: "startButton") {
          studio.start()
        }
        HStack(spacing: 6) {
          Text("Heat").foregroundStyle(Palette.ember)
          Text("·")
          Text("Spin")
          Text("·")
          Text("Shape")
          Spacer()
          Image(systemName: "clock").font(.system(size: 9))
          Text("One minute of craft")
        }
        .font(StudioType.body(11)).foregroundStyle(Palette.muted)
      }
    }
  }

  private func centerpiece(profile: [Double], commission: Commission, molten: Bool) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .bottom) {
        ExhibitionNiche(warm: molten)
          .padding(.horizontal, 4).padding(.bottom, 20)
        GlassDisplay(
          profile: profile, commission: commission, molten: molten,
          paused: reduceMotion || studio.paused || studio.tutorial || scenePhase != .active
        ).padding(.bottom, 16)
        Text(molten ? "FURNACE • \(Int(studio.temperature * 900 + 500))°" : commission.collection)
          .font(StudioType.label(8)).tracking(2.1).foregroundStyle(Palette.muted)
          .padding(.bottom, 2)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
  }

  private var play: some View {
    VStack(spacing: 12) {
      HStack(spacing: 8) {
        ForEach([Stage.heat, .spin, .shape], id: \.rawValue) { stage in
          HStack(spacing: 6) {
            Circle().fill(stage == studio.stage ? Palette.ember : Palette.surface)
              .frame(width: 4, height: 4)
            Text(stage.rawValue.capitalized).font(StudioType.label(10))
              .foregroundStyle(stage == studio.stage ? Palette.cream : Palette.muted)
            Rectangle().fill(stage == studio.stage ? Palette.brass : Palette.surface)
              .frame(height: 0.5)
          }
        }
      }
      VStack(spacing: 7) {
        Text(studio.stage.title).font(StudioType.display(34)).tracking(-1)
        Text(instruction).font(StudioType.body(12)).foregroundStyle(Palette.muted)
          .multilineTextAlignment(.center)
      }
      .padding(.top, 4)
      if studio.stage == .shape {
        shaping
      } else {
        centerpiece(profile: studio.commission.radii, commission: studio.commission, molten: true)
      }
      stageControls
    }
  }

  private var instruction: String {
    switch studio.stage {
    case .heat: "Hold to warm. Release to cool. Follow the glow."
    case .spin: "Slide the dial into the moving balance window."
    case .shape: "Trace the right edge. Amber dots need refining."
    default: ""
    }
  }

  private var shaping: some View {
    GeometryReader { geometry in
      let width = min(geometry.size.width * 0.90, geometry.size.height * 0.94)
      let height = geometry.size.height - 18
      let origin = (geometry.size.width - width) / 2
      let top = height * 0.09
      let step = height * 0.79 / 7
      ZStack {
        GlassDisplay(
          profile: studio.profile, commission: studio.commission,
          paused: true, tracing: true
        )
        .frame(width: width, height: height)
        .position(x: geometry.size.width / 2, y: height / 2)
        VesselShape(profile: studio.commission.radii)
          .stroke(Palette.cream.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
          .frame(width: width, height: height)
          .position(x: geometry.size.width / 2, y: height / 2)
        ForEach(0..<8) { index in
          let x = origin + width / 2 + width * 0.48 * studio.commission.radii[index]
          let y = top + Double(index) * step
          let touched = studio.touched.contains(index)
          let matched =
            touched && abs(studio.profile[index] - studio.commission.radii[index]) <= 0.04
          let color = matched ? Palette.mint : touched ? Palette.ember : Palette.cream
          Circle()
            .fill(matched ? color : Palette.background)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(color, lineWidth: 2))
            .overlay(Circle().stroke(color.opacity(0.2), lineWidth: 7))
            .position(x: x, y: y)
            .accessibilityHidden(true)
        }
        Text("LIP").position(x: 24, y: top)
        Text("BASE").position(x: 24, y: top + 7 * step)
        Path { path in
          path.move(to: CGPoint(x: 24, y: top + 16))
          path.addLine(to: CGPoint(x: 24, y: top + 7 * step - 16))
        }.stroke(Palette.brass.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
      }
      .font(.system(size: 8, design: .monospaced)).tracking(2).foregroundStyle(Palette.muted)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0).onChanged { value in
          let index = Int(((value.location.y - top) / step).rounded())
          let radius = (value.location.x - geometry.size.width / 2) / (width * 0.48)
          studio.trace(index: index, radius: radius)
        }
      )
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Vessel shaping canvas")
      .accessibilityHint(
        "Trace the eight dots down the right edge. With VoiceOver, use the guided shaping controls below."
      )
      .accessibilityIdentifier("shapingCanvas")
    }
  }

  @ViewBuilder
  private var stageControls: some View {
    VStack(spacing: 12) {
      HStack {
        eyebrow(studio.stage == .shape ? "FORM ACCURACY" : "LIVE PRECISION")
        Spacer()
        if studio.stage != .shape {
          Text(
            studio.stage == .heat
              ? "\(Int(studio.temperature * 900 + 500))°" : "\(Int(studio.rotation * 50 + 10)) RPM"
          )
          .font(.system(size: 13, design: .monospaced))
          .foregroundStyle(Palette.ember)
          Spacer()
        }
        Text("\(studio.liveQuality)%")
          .font(.system(size: 13, weight: .medium, design: .monospaced))
          .foregroundStyle(studio.liveQuality >= 55 ? Palette.mint : Palette.ember)
      }
      if studio.stage == .heat {
        gauge(value: studio.temperature, target: studio.heatTarget)
        HStack(spacing: 12) {
          ZStack {
            Circle().stroke(Palette.ember.opacity(0.6), lineWidth: 1).frame(width: 28, height: 28)
            Circle().fill(Palette.ember).frame(width: 8, height: 8)
              .shadow(color: Palette.ember.opacity(studio.holding ? 1 : 0), radius: 9)
          }
          Text(studio.holding ? "Release to cool" : "Hold to heat")
            .font(StudioType.label(14))
          Spacer()
          Image(systemName: studio.holding ? "arrow.down" : "arrow.up")
            .font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 19).frame(height: 60)
        .frame(maxWidth: .infinity)
        .background(
          LinearGradient(
            colors: [Palette.ember.opacity(studio.holding ? 0.28 : 0.12), Palette.surface],
            startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .foregroundStyle(Palette.cream)
        .overlay(
          RoundedRectangle(cornerRadius: 15).stroke(Palette.ember.opacity(0.5), lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0).onChanged { _ in
            studio.holding = true
          }.onEnded { _ in studio.holding = false }
        )
        .accessibilityElement()
        .accessibilityLabel(
          studio.holding ? "Heating, activate to cool" : "Hold to heat, activate to toggle"
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { studio.holding.toggle() }
        .accessibilityIdentifier("heatControl")
      } else if studio.stage == .spin {
        gauge(value: studio.rotation, target: studio.spinTarget)
        RotationControl(value: $studio.rotation, target: studio.spinTarget)
      } else {
        HStack {
          let matched = studio.touched.filter {
            abs(studio.profile[$0] - studio.commission.radii[$0]) <= 0.04
          }.count
          Text("\(matched) matched · \(studio.touched.count)/8 traced")
            .font(.system(size: 12)).foregroundStyle(Palette.muted)
          Spacer()
          Button("Reset curve") {
            studio.profile = studio.commission.radii.map { $0 * 0.73 }
            studio.touched = []
          }
          .font(.system(size: 12)).foregroundStyle(Palette.cream)
          .frame(minHeight: 44)
          .accessibilityIdentifier("resetCurveButton")
        }
        primary("Cool & reveal", symbol: "arrow.right", identifier: "finishButton") {
          studio.finish()
        }
        accessibleShaping
      }
    }
    .padding(.bottom, 5)
  }

  @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
  @State private var selectedPoint = 0

  @ViewBuilder
  private var accessibleShaping: some View {
    if voiceOver {
      Stepper("Point \(selectedPoint + 1)", value: $selectedPoint, in: 0...7)
      Slider(
        value: Binding(
          get: { studio.profile[selectedPoint] },
          set: { studio.trace(index: selectedPoint, radius: $0) }
        ), in: 0.18...0.94
      )
      .accessibilityLabel(
        "Shape point \(selectedPoint + 1). Target \(Int(studio.commission.radii[selectedPoint] * 100))"
      )
      .accessibilityValue("\(Int(studio.profile[selectedPoint] * 100))")
    }
  }

  private func gauge(value: Double, target: Double) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Canvas { context, size in
          for index in 0...40 {
            let x = Double(index) / 40 * size.width
            var line = Path()
            line.move(to: CGPoint(x: x, y: index % 5 == 0 ? 10 : 16))
            line.addLine(to: CGPoint(x: x, y: 30))
            context.stroke(
              line, with: .color(Palette.muted.opacity(index % 5 == 0 ? 0.6 : 0.25)),
              lineWidth: 1)
          }
        }
        RoundedRectangle(cornerRadius: 4)
          .fill(Palette.mint.opacity(0.16))
          .overlay(
            RoundedRectangle(cornerRadius: 4).stroke(Palette.mint.opacity(0.7), lineWidth: 0.8)
          )
          .frame(width: geometry.size.width * 0.20, height: 34)
          .offset(x: geometry.size.width * (target - 0.1))
        VStack(spacing: 2) {
          Rectangle().fill(Palette.cream).frame(width: 6, height: 6).rotationEffect(.degrees(45))
          Rectangle().fill(Palette.cream).frame(width: 1.5, height: 25)
        }
        .shadow(color: Palette.cream.opacity(0.3), radius: 4)
        .offset(x: (geometry.size.width - 6) * value)
      }
      .frame(height: 38)
    }
    .frame(height: 38)
    .accessibilityLabel("Precision gauge")
    .accessibilityValue("\(Int(value * 100)), target \(Int(target * 100))")
  }

  @ViewBuilder
  private func result(compact: Bool) -> some View {
    if let piece = studio.result {
      VStack(spacing: compact ? 7 : 12) {
        eyebrow(
          piece.collected ? "A NEW PIECE FOR YOUR GALLERY" : "EVERY MASTER BEGINS WITH A STUDY",
          color: Palette.brass
        )
        .padding(.top, 8)
        Text(piece.collected ? "From fire, a jewel." : "Return to the fire.")
          .font(StudioType.display(compact ? 31 : 38)).tracking(-1)
        centerpiece(profile: piece.profile, commission: piece.commission, molten: false)
          .frame(maxHeight: .infinity)
          .scaleEffect(reveal || reduceMotion ? 1 : 0.96)
          .opacity(reveal || reduceMotion ? 1 : 0.35)
        HStack(alignment: .center, spacing: 14) {
          GradeSeal(score: piece.score).frame(width: 65, height: 65)
          VStack(alignment: .leading, spacing: 5) {
            eyebrow(piece.grade, color: piece.collected ? Palette.brass : Palette.muted)
            Text(piece.commission.title).font(StudioType.display(27))
            Text("Firing \(piece.id.uuidString.prefix(6).uppercased())")
              .font(StudioType.body(10)).foregroundStyle(Palette.muted)
          }
          Spacer()
        }
        Rectangle().fill(Palette.brass.opacity(0.25)).frame(height: 0.5)
        HStack {
          metric("HEAT", value: piece.heat)
          Spacer()
          metric("BALANCE", value: piece.spin)
          Spacer()
          metric("FORM", value: piece.shape)
        }
        Text(resultAdvice(piece))
          .font(StudioType.body(12)).foregroundStyle(Palette.muted)
          .multilineTextAlignment(.center).frame(minHeight: 32)
        HStack(spacing: 12) {
          primary("Fire again", symbol: "arrow.clockwise", identifier: "retryButton") {
            studio.start()
          }
          Button {
            share(piece)
          } label: {
            Image(systemName: "square.and.arrow.up")
              .font(.system(size: 19)).frame(width: 56, height: 56)
              .background(RoundedRectangle(cornerRadius: 15).fill(Palette.surface))
              .overlay(
                RoundedRectangle(cornerRadius: 15).stroke(
                  Palette.brass.opacity(0.3), lineWidth: 0.7))
          }
          .accessibilityLabel("Share finished vessel").accessibilityIdentifier("shareButton")
        }
        Button("Return to studio") { studio.home() }
          .font(.system(size: 12)).foregroundStyle(Palette.muted).frame(height: 38)
          .accessibilityIdentifier("homeButton")
      }
    }
  }

  private func resultAdvice(_ piece: GalleryPiece) -> String {
    if piece.collected {
      return piece.commission == .spire
        ? "Collected. Chase 90 to earn a Masterwork."
        : "Collected. Your next commission is unlocked."
    }
    if piece.shape < min(piece.heat, piece.spin) {
      return "Trace all eight points more closely. 55 earns a gallery piece."
    }
    return "Stay inside the glowing windows longer. 55 earns a gallery piece."
  }

  private func metric(_ title: String, value: Int) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      eyebrow(title)
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text("\(value)").font(StudioType.body(21))
        Text("%").font(StudioType.body(10)).foregroundStyle(Palette.muted)
      }
      GeometryReader { geometry in
        Capsule().fill(Palette.surface)
          .overlay(alignment: .leading) {
            Capsule().fill(Palette.brass.opacity(0.65))
              .frame(width: geometry.size.width * Double(value) / 100)
          }
      }.frame(width: 72, height: 2)
    }
  }

  private var tutorial: some View {
    ZStack {
      Palette.background.opacity(0.94).ignoresSafeArea()
      VStack(alignment: .leading, spacing: 22) {
        HStack(spacing: 16) {
          Text(studio.stage == .heat ? "I" : studio.stage == .spin ? "II" : "III")
            .font(StudioType.display(36))
            .foregroundStyle(Palette.brass)
          eyebrow("YOUR FIRST \(studio.stage.rawValue.uppercased())")
        }
        Text(studio.stage.title).font(StudioType.display(39))
        if studio.stage != .shape {
          gauge(value: 0.5, target: 0.5)
          HStack {
            Image(systemName: studio.stage == .heat ? "hand.point.up.left" : "arrow.left.and.right")
            Text(studio.stage == .heat ? "HOLD ↑  /  RELEASE ↓" : "SLIDE TO FOLLOW THE GLOW")
          }
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(Palette.mint)
          .accessibilityHidden(true)
        }
        Text(tutorialCopy)
          .font(StudioType.body(16)).lineSpacing(5).foregroundStyle(Palette.muted)
        Rectangle().fill(Palette.cream.opacity(0.2)).frame(height: 1)
        Text(
          studio.stage == .shape
            ? "Form is 44% of your final grade." : "This stage is 28% of your final grade."
        )
        .font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.mint)
        primary(
          "Begin \(studio.stage.rawValue)", symbol: "arrow.right",
          identifier: "tutorialContinueButton"
        ) {
          studio.dismissTutorial()
        }
      }
      .padding(32)
    }
    .accessibilityAddTraits(.isModal)
  }

  private var tutorialCopy: String {
    switch studio.stage {
    case .heat:
      "Hold the heat pad to raise the white temperature marker. Release to let it fall.\n\nKeep that marker inside the moving green window for 14 seconds."
    case .spin:
      "Slide the rotation dial left or right. Keep the white marker inside the moving green window.\n\nA steady hand gives the glass its symmetry."
    case .shape:
      "Trace the eight glowing dots along the right edge of the vessel. The left side mirrors your hand.\n\nYou have 26 seconds. Tap Cool & reveal when your curve is ready."
    default: ""
    }
  }

  private var pause: some View {
    ZStack {
      Palette.background.opacity(0.97).ignoresSafeArea()
      VStack(spacing: 23) {
        eyebrow("THE FIRE CAN WAIT", color: Palette.ember)
        MakerMark().stroke(Palette.brass, lineWidth: 1).frame(width: 38, height: 48)
        Text("A moment of stillness.").font(StudioType.display(31))
        primary("Resume", symbol: "play", identifier: "resumeButton") {
          previousTick = Date()
          studio.paused = false
        }
        Button("Restart commission") { studio.start() }
          .frame(height: 44).accessibilityIdentifier("restartButton")
        Button("Leave furnace") { studio.home() }
          .foregroundStyle(Palette.muted).frame(height: 44)
          .accessibilityIdentifier("leaveButton")
      }.padding(30)
    }
    .accessibilityAddTraits(.isModal)
  }

  private var gallery: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 24) {
          Text("The collection").font(StudioType.display(36))
          Text("Your last 24 firings. Collect at 55. Master at 90.")
            .font(.system(size: 13)).foregroundStyle(Palette.muted)
          if studio.archive.pieces.isEmpty {
            Image(uiImage: GlassStudio.portrait(profile: Commission.tide.radii, commission: .tide))
              .resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 250).opacity(0.65)
            Text("A place for things you make.")
              .font(StudioType.display(25))
            Text("Your first vessel is waiting in the fire.").foregroundStyle(Palette.muted)
          }
          ForEach(studio.archive.pieces) { piece in
            HStack(spacing: 24) {
              Image(
                uiImage: GlassStudio.portrait(profile: piece.profile, commission: piece.commission)
              )
              .resizable().scaledToFit().frame(width: 96, height: 130)
              VStack(alignment: .leading, spacing: 9) {
                eyebrow(piece.collected ? piece.grade : "STUDY", color: Palette.mint)
                Text(piece.commission.title).font(StudioType.display(24))
                Text(
                  "\(piece.score) / 100  ·  \(piece.date.formatted(date: .abbreviated, time: .omitted))"
                )
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted)
              }
            }
            .accessibilityElement(children: .combine)
            Rectangle().fill(Palette.cream.opacity(0.12)).frame(height: 1)
          }
        }.padding(26)
      }
      .background(Palette.background)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { galleryOpen = false }.accessibilityIdentifier("closeGalleryButton")
        }
      }
    }
    .tint(Palette.cream)
    .presentationDragIndicator(.visible)
  }

  private var settings: some View {
    NavigationStack {
      Form {
        Section("In the studio") {
          Toggle("Haptic feedback", isOn: $studio.haptics).accessibilityIdentifier("hapticsToggle")
          Text(
            "A quiet studio. Emberglass has no audio. Motion follows your iPhone’s Reduce Motion setting."
          )
          .font(.footnote).foregroundStyle(.secondary)
        }
        Section("Learning") {
          Button("Show the stage guides again") {
            for stage in [Stage.heat, .spin, .shape] {
              UserDefaults.standard.set(false, forKey: "learned.\(stage.rawValue)")
            }
            settingsOpen = false
          }.accessibilityIdentifier("resetTutorialButton")
        }
        Section("Craft") {
          Text("Heat 28% · Balance 28% · Form 44%\n55 Collectible · 75 Exquisite · 90 Masterwork")
            .font(.footnote)
          Text("Progress stays on this device. No account, no network, just glass.")
            .font(.footnote).foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Studio settings")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("Done") { settingsOpen = false } }
      }
    }
    .tint(Palette.ember)
  }

  private func share(_ piece: GalleryPiece) {
    let renderer = ImageRenderer(content: ResultPrint(piece: piece))
    renderer.scale = 2
    if let image = renderer.uiImage {
      shareContent = ShareContent(
        image: image,
        text:
          "I made \(piece.commission.title) in Emberglass. \(piece.grade) · \(piece.score)/100. Made of fire. Finished by hand."
      )
    }
  }

  private func icon(
    _ symbol: String, label: String, identifier: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(size: 16, weight: .light)).frame(width: 42, height: 44)
        .foregroundStyle(Palette.cream)
    }
    .accessibilityLabel(label).accessibilityIdentifier(identifier)
  }

  private func primary(
    _ title: String, symbol: String, identifier: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Text(title).font(StudioType.label(15))
        Spacer()
        Image(systemName: symbol).font(.system(size: 14, weight: .medium))
          .frame(width: 29, height: 29)
          .overlay(Circle().stroke(Palette.background.opacity(0.25), lineWidth: 0.7))
      }
      .padding(.horizontal, 19).frame(height: 56)
      .background(
        LinearGradient(
          colors: [Palette.cream, Palette.brass], startPoint: .topLeading, endPoint: .bottomTrailing
        )
      )
      .foregroundStyle(Palette.background)
      .overlay(
        RoundedRectangle(cornerRadius: 15).stroke(Palette.cream.opacity(0.5), lineWidth: 0.7)
      )
      .clipShape(RoundedRectangle(cornerRadius: 15))
    }
    .buttonStyle(PressStyle()).accessibilityIdentifier(identifier)
  }

  private func eyebrow(_ title: String, color: Color = Palette.muted) -> some View {
    Text(title).font(StudioType.label(9))
      .tracking(1.4).foregroundStyle(color)
  }
}

struct ResultPrint: View {
  let piece: GalleryPiece

  var body: some View {
    VStack(spacing: 12) {
      MakerMark().stroke(Palette.brass, lineWidth: 1).frame(width: 24, height: 30)
      Text("Emberglass").font(StudioType.display(32)).tracking(-1)
      Text("fire into form").font(StudioType.italic(16)).foregroundStyle(Palette.brass)
      Image(uiImage: GlassStudio.portrait(profile: piece.profile, commission: piece.commission))
        .resizable().scaledToFit().frame(width: 310, height: 330)
      HStack(spacing: 15) {
        GradeSeal(score: piece.score).frame(width: 65, height: 65)
        VStack(alignment: .leading, spacing: 5) {
          Text(piece.grade).font(StudioType.label(9)).tracking(1.8).foregroundStyle(Palette.brass)
          Text(piece.commission.title).font(StudioType.display(26))
          Text("FIRING \(piece.id.uuidString.prefix(6).uppercased())")
            .font(StudioType.body(9)).tracking(1).foregroundStyle(Palette.muted)
        }
      }
      Rectangle().fill(Palette.brass.opacity(0.3)).frame(height: 0.5).padding(.top, 8)
      Text("Made of fire. Finished by hand.")
        .font(StudioType.body(11)).foregroundStyle(Palette.muted)
    }
    .padding(30).frame(width: 390, height: 680)
    .foregroundStyle(Palette.cream).background(Palette.background)
    .overlay(Rectangle().stroke(Palette.brass.opacity(0.25), lineWidth: 0.5).padding(14))
  }
}

struct ShareContent: Identifiable {
  let id = UUID()
  let image: UIImage
  let text: String
}

struct ShareSheet: UIViewControllerRepresentable {
  let image: UIImage
  let text: String

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [image, text], applicationActivities: nil)
  }

  func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
