import CourtCore
import SwiftUI
import UniformTypeIdentifiers

struct CourtRoot: View {
    @ObservedObject var store: CourtStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = false
    @State private var pgnSheet = false
    @State private var pgnText = ""
    @State private var pgnImport = true
    @State private var fileImporter = false
    @State private var fileExporter = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                topBar
                if let notice = store.notice ?? store.connection.error {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.circle")
                        Text(notice).frame(maxWidth: .infinity, alignment: .leading)
                        if store.notice != nil {
                            Button("Dismiss") { store.notice = nil }.buttonStyle(.borderless)
                        } else {
                            Button("Reconnect") { store.connect() }.buttonStyle(.borderless)
                        }
                    }
                    .padding(12).background(Color.red.opacity(0.15))
                    .accessibilityElement(children: .combine)
                }
                ScrollView {
                    if store.room != nil || store.review != nil {
                        GameScreen(store: store, wide: geometry.size.width >= 850, availableHeight: geometry.size.height - 170,
                                   export: showExport)
                            .padding(geometry.size.width < 600 ? 12 : 24)
                    } else {
                        LobbyScreen(store: store, wide: geometry.size.width >= 850, openPGN: {
                            pgnImport = true; pgnText = ""; pgnSheet = true
                        })
                        .padding(geometry.size.width < 600 ? 16 : 28)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                if let queue = store.queue {
                    HStack {
                        ProgressView().controlSize(.small)
                        VStack(alignment: .leading) {
                            Text("Finding your next rival").bold()
                            Text("\(queue.timeControl.label) · Queue \(queue.position)\(queue.botAfterMs != nil ? " · Bot fallback enabled" : "")").font(.caption)
                        }
                        Spacer()
                        Button("Cancel") { store.action(.cancelPair) }.disabled(store.busy)
                    }
                    .padding().background(Arcade.royal).foregroundStyle(.white)
                }
            }
            .background(scheme == .dark ? Arcade.midnight : Color(hex: 0xEDF2FF))
        }
        .sheet(isPresented: $settings) { SettingsSheet(store: store) }
        .sheet(isPresented: $pgnSheet) { pgnEditor }
        .sheet(isPresented: Binding(get: { store.promotion != nil }, set: {
            if !$0 {
                store.promotion = nil
            }
        })) {
            promotionPicker
        }
        .fileImporter(isPresented: $fileImporter, allowedContentTypes: [.plainText, .data]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer {
                    if access {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                guard try (url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 1_000_000 else {
                    store.notice = "PGN must be smaller than 1 MB."; return
                }
                pgnText = try String(contentsOf: url, encoding: .utf8)
            } catch { store.notice = error.localizedDescription }
        }
        .fileExporter(isPresented: $fileExporter, document: PGNDocument(text: pgnText), contentType: .plainText, defaultFilename: "gambit-court.pgn") { result in
            if case let .failure(error) = result {
                store.notice = error.localizedDescription
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, store.connection.phase == .offline, store.connection.error == nil {
                store.connect()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Crown().fill(Arcade.midnight).padding(6).frame(width: 42, height: 42)
                .background(Arcade.sunshine, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("GAMBIT").font(Arcade.display(19))
                Text("C O U R T").font(.caption.bold()).foregroundStyle(scheme == .dark ? Arcade.sunshine : Arcade.royal)
            }
            Spacer()
            ViewThatFits {
                HStack(spacing: 8) { connectionLabel; Text(store.name).lineLimit(1).frame(maxWidth: 130) }
                connectionLabel
            }
            Button { store.sound.toggle() } label: { Image(systemName: store.sound ? "speaker.wave.2.fill" : "speaker.slash.fill") }
                .accessibilityLabel(store.sound ? "Mute sound" : "Enable sound")
            Button { settings = true } label: { Image(systemName: "gearshape.fill") }.accessibilityLabel("Settings")
        }
        .buttonStyle(.borderless).padding(.horizontal, 16).padding(.vertical, 12)
        .background(scheme == .dark ? Color(hex: 0x0C173A) : Color(hex: 0xF8FAFF))
    }

    private var connectionLabel: some View {
        Label(store.ready ? "\(store.connection.rttMs) ms" : store.connection.phase.rawValue.capitalized,
              systemImage: store.ready ? "circle.fill" : "wifi.exclamationmark")
            .font(.caption).foregroundStyle(store.ready ? (scheme == .dark ? Arcade.aqua : Color.teal) : .orange)
            .accessibilityLabel("Connection \(store.connection.phase.rawValue)")
    }

    private func showExport() {
        pgnImport = false; pgnText = store.pgn; pgnSheet = true
    }

    private var pgnEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(pgnImport ? "Review a game" : "Export PGN").font(Arcade.display(23))
            Text(pgnImport ? "Paste a PGN or open a file. Comments and variations are skipped; legal mainline moves become a review." : "Save or share the server-confirmed game.")
            if let notice = store.notice {
                Text(notice).foregroundStyle(.red)
            }
            TextEditor(text: $pgnText).font(Arcade.mono(13)).frame(minHeight: 230).border(.secondary.opacity(0.4))
                .accessibilityLabel("PGN text")
            HStack {
                if pgnImport {
                    Button("Open file") { fileImporter = true }
                    Button("Review") {
                        store.importPGN(pgnText)
                        if store.review != nil {
                            pgnSheet = false
                        }
                    }.buttonStyle(CourtButtonStyle(primary: true))
                } else {
                    Button("Copy") { Launch.copy(pgnText) }
                    Button("Save file") { fileExporter = true }
                    ShareLink(item: pgnText) { Label("Share", systemImage: "square.and.arrow.up") }
                }
                Spacer()
                Button("Close") { pgnSheet = false }
            }
        }
        .padding(24).frame(idealWidth: 600).presentationDetents([.large])
    }

    private var promotionPicker: some View {
        VStack(spacing: 24) {
            Text("PROMOTE TO").font(Arcade.display(24))
            HStack {
                ForEach(PieceKind.promotions, id: \.self) { kind in
                    Button {
                        if let move = store.promotion {
                            store.promotion = nil; store.request(from: move.from, to: move.to, promotion: kind)
                        }
                    } label: {
                        VStack {
                            PieceGlyph(piece: Piece(store.mySide ?? .white, kind)).frame(width: 58, height: 58)
                            Text(kind.label).font(.caption)
                        }
                    }.buttonStyle(.plain)
                }
            }
            Button("Cancel") { store.promotion = nil }
        }
        .padding(24).presentationDetents([.height(240)])
    }
}

struct PGNDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.plainText]
    }

    var text: String
    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct SettingsSheet: View {
    @ObservedObject var store: CourtStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var endpoint = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("YOUR COURT").font(Arcade.display(25))
            if let notice = store.notice {
                Text(notice).foregroundStyle(.red)
            }
            Form {
                Section("Player") {
                    TextField("Display name", text: $name)
                    Picker("Appearance", selection: $store.theme) {
                        Text("Midnight").tag("dark"); Text("Daylight").tag("light"); Text("System").tag("system")
                    }
                    Toggle("Sound effects", isOn: $store.sound)
                    #if os(iOS)
                        Toggle("Haptic feedback", isOn: $store.haptics)
                    #endif
                }
                Section("Multiplayer server") {
                    TextField("ws://host:8765/ws", text: $endpoint).autocorrectionDisabled()
                    Text("On an iPhone or iPad, use your server’s LAN address. Internet servers should use wss://.").font(.caption)
                    Text("Your resume identity is kept in this device’s Keychain. Never share a client identity between live devices.").font(.caption)
                }
                Section("Controls") {
                    Text("Tap a piece and its destination, or drag. Choose a move during your opponent’s turn to queue a premove. Escape cancels; F flips; arrow keys browse history while the board is focused.")
                    Text("All legal moves, clocks and results are confirmed by the server.").font(.caption)
                }
            }
            .formStyle(.grouped)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save & reconnect") {
                    guard CourtConnection.endpoint(endpoint) != nil else { store.notice = "Enter a valid ws:// or wss:// server URL."; return }
                    store.setName(name)
                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 24 {
                        return
                    }
                    store.endpoint = endpoint; store.connect(); dismiss()
                }.buttonStyle(CourtButtonStyle(primary: true))
            }
        }
        .padding(24)
        #if os(macOS)
            .frame(width: 560, height: 650)
        #endif
            .onAppear { name = store.name; endpoint = store.endpoint }
    }
}
