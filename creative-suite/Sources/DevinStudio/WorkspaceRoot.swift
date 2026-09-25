import SwiftUI
import DevinCore

struct WorkspaceRoot: View {
    @ObservedObject var session: StudioSession
    var body: some View {
        VStack(spacing: 0) {
            if session.usesProfessionalWorkspace {
                switch session.tool {
                case .pixel: PixelWorkspace(session: session)
                case .form: FormWorkspace(session: session)
                case .press: PressWorkspace(session: session)
                case .motion: MotionWorkspace(session: session)
                case .cut: CutWorkspace(session: session)
                default: EmptyView()
                }
            } else {
                header
                if let workspace = session.workspace, workspace.usesTabs { WorkspaceDocumentTabs(workspace: workspace) }
                Group {
                    if session.tool.isCanvas { CanvasWorkspace(session: session) }
                    else {
                        switch session.tool {
                        case .cut, .sound: MediaWorkspace(session: session)
                        case .folio: PDFWorkspace(session: session)
                        case .code: CodeWorkspace(session: session)
                        case .batch: BatchWorkspace(session: session)
                        case .space: SpatialWorkspace(session: session)
                        default: EmptyView()
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
        }.background(Theme.background).foregroundStyle(Theme.text).preferredColorScheme(.dark)
            .sheet(isPresented: $session.showExport) { ExportSheet(session: session) }
            .sheet(isPresented: $session.showNew) { NewProjectSheet(session: session) }
            .sheet(isPresented: $session.showFeatureInventory) { FeatureInventoryView(initialTool: session.tool) }
            .alert("The operation could not finish", isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })) {
                Button("OK") { session.error = nil }
            } message: { Text(session.error ?? "") }
            .overlay {
                if session.busy {
                    ZStack {
                        Color.black.opacity(0.45)
                        VStack(spacing: 18) {
                            ProgressView().controlSize(.large)
                            Text("Working on your creation…").font(.system(size: 16, weight: .medium))
                            if session.progress > 0 { ProgressView(value: session.progress).frame(width: 260).tint(Theme.accent) }
                            if session.exportTask != nil {
                                Button("Cancel") { session.exportTask?.cancel() }.buttonStyle(StudioButtonStyle(professional: session.usesProfessionalWorkspace))
                            }
                        }.padding(36).background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
    }
    var header: some View {
        HStack(spacing: 15) {
            ToolBadge(tool: session.tool, size: 30)
            Text(session.tool.name).font(.system(size: 13, weight: .semibold))
            Rectangle().fill(Theme.line).frame(width: 1, height: 20)
            TextField("Project name", text: Binding(get: { session.document.title }, set: { title in session.mutate { $0.title = title } }))
                .textFieldStyle(.plain).font(.system(size: 12)).frame(maxWidth: 240)
            if session.isDirty { Circle().fill(Theme.muted).frame(width: 5, height: 5).help("Unsaved changes") }
            Spacer()
            IconButton(symbol: "arrow.uturn.backward", help: "Undo · ⌘Z") { session.undo() }.disabled(session.history.undoStack.isEmpty)
            IconButton(symbol: "arrow.uturn.forward", help: "Redo · ⇧⌘Z") { session.redo() }.disabled(session.history.redoStack.isEmpty)
            Rectangle().fill(Theme.line).frame(width: 1, height: 20)
            Button { session.importFiles() } label: { Label("Import", systemImage: "plus") }.buttonStyle(StudioButtonStyle(professional: session.usesProfessionalWorkspace))
                .disabled(session.tool == .space)
            Button { _ = session.save() } label: { Text("Save") }.buttonStyle(StudioButtonStyle(professional: session.usesProfessionalWorkspace))
            Button { session.showExport = true } label: { HStack(spacing: 12) { Text("Export"); Image(systemName: "arrow.up.right") } }.buttonStyle(StudioButtonStyle(primary: true, professional: session.usesProfessionalWorkspace))
        }.padding(.leading, 86).padding(.trailing, 22).frame(height: 64).background(Theme.sidebar)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
    var footer: some View {
        HStack(spacing: 10) {
            Circle().fill(session.isDirty ? Color(hex: "E0BD82") : Theme.accent).frame(width: 5, height: 5)
            Text(session.isDirty ? "Unsaved changes" : session.fileURL == nil ? "Local project · save to keep your work" : "All changes saved")
            if let message = session.message {
                Rectangle().fill(Theme.line).frame(width: 1, height: 10)
                Text(message).foregroundStyle(Theme.accent)
                if session.lastExportURL != nil { Button("Show in Finder") { session.showInFinder() }.buttonStyle(.plain).foregroundStyle(Theme.accent) }
                Button { session.message = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
            }
            Spacer()
            Text("\(session.tool.category.uppercased())   /   DEVIN CREATIVE").tracking(1)
        }.font(.system(size: 9)).foregroundStyle(Theme.muted).padding(.horizontal, 18).frame(height: 29).background(Theme.sidebar)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

struct NewProjectSheet: View {
    @ObservedObject var session: StudioSession
    @State private var title = "Untitled"
    @State private var width = 1200.0
    @State private var height = 900.0
    @State private var background = Color(hex: "F5F2EB")
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack { if !session.usesProfessionalWorkspace { ToolBadge(tool: session.tool) }; VStack(alignment: .leading, spacing: 4) { Text(session.usesProfessionalWorkspace ? "New Document" : "A fresh start.").font(.system(size: 26, weight: .medium)); Text(session.tool.name).foregroundStyle(Theme.muted) } }
            TextField("Project name", text: $title).textFieldStyle(.roundedBorder)
            if session.tool.isCanvas {
                HStack { NumberField(label: "W", value: $width, range: 16...16384); NumberField(label: "H", value: $height, range: 16...16384) }
                HStack {
                    ForEach(["Landscape", "Portrait", "Square", "HD"], id: \.self) { name in
                        Button(name) {
                            switch name { case "Portrait": width = 840; height = 1120; case "Square": width = 1080; height = 1080; case "HD": width = 1920; height = 1080; default: width = 1200; height = 900 }
                        }.buttonStyle(StudioButtonStyle(professional: session.usesProfessionalWorkspace))
                    }
                }
                ColorPicker("Canvas color", selection: $background, supportsOpacity: false)
            }
            HStack {
                Button("Cancel") { session.showNew = false; session.workspace?.showsNewDocument = false }.buttonStyle(StudioButtonStyle(professional: session.usesProfessionalWorkspace)).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create project") {
                    AppCoordinator.shared.createDocument(from: session, title: title, width: width, height: height, background: background.hex)
                }.buttonStyle(StudioButtonStyle(primary: true, professional: session.usesProfessionalWorkspace)).keyboardShortcut(.defaultAction)
            }
        }.padding(32).frame(width: 480).background(Theme.panel).foregroundStyle(Theme.text).preferredColorScheme(.dark)
    }
}
