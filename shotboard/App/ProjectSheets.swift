import SwiftUI
import UniformTypeIdentifiers

struct ProjectLibrary: View {
  @EnvironmentObject private var store: StudioStore
  @Environment(\.dismiss) private var dismiss
  @State private var projects: [Storyboard] = []
  @State private var importing = false
  @State private var loadError: String?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Text("Stories in the making.").font(.system(size: 34, design: .serif))
          Text("Projects are saved locally and reopen exactly where your story left off.")
            .font(.system(size: 14)).foregroundStyle(Palette.muted)
          HStack {
            Button {
              store.open(.empty())
              dismiss()
            } label: {
              Label("New film", systemImage: "plus")
            }.buttonStyle(StudioButton(accent: true))
            Button {
              importing = true
            } label: {
              Label("Import project", systemImage: "folder")
            }.buttonStyle(StudioButton())
          }
          if let loadError { Text(loadError).foregroundStyle(.orange) }
          ForEach(projects) { project in
            Button {
              store.open(project)
              dismiss()
            } label: {
              HStack(spacing: 20) {
                if let shot = project.shots.first {
                  InkThumbnail(shot: shot).frame(width: 170, height: 90).clipped()
                }
                VStack(alignment: .leading, spacing: 10) {
                  Text(project.title).font(.system(size: 23, design: .serif))
                  Text("\(project.shots.count) shots  /  \(project.runtimeLabel)")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.muted)
                  Text(project.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundStyle(Palette.yellow)
              }.contentShape(Rectangle()).padding(15).background(Palette.panel)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain)
          }
          Button {
            store.open(SampleFilm.make())
            dismiss()
          } label: {
            Label("Start a fresh copy of the sample film", systemImage: "sparkles")
          }
          .font(.system(size: 13)).padding(.top, 10)
          ShareLink(item: store.archive.url(for: store.project.id)) {
            Label("Share current editable project", systemImage: "square.and.arrow.up").font(
              .system(size: 13))
          }
        }.padding(30)
      }
      .background(Palette.background).foregroundStyle(Palette.ivory)
      .navigationTitle("Your films").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
      .onAppear {
        do { projects = try store.archive.list() } catch { loadError = error.localizedDescription }
      }
      .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
        switch result {
        case .success(let url):
          store.importProject(url)
          dismiss()
        case .failure(let error): loadError = error.localizedDescription
        }
      }
    }.presentationDetents([.large])
  }
}

struct SceneSheet: View {
  @EnvironmentObject private var store: StudioStore
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var location = "EXT. / DAY"

  var body: some View {
    NavigationStack {
      Form {
        Section("A new chapter") {
          TextField("Scene title", text: $title)
          TextField("Location / time of day", text: $location)
        }
        Section {
          Text("A blank opening shot will be added to the end of your sequence.")
        }
      }.navigationTitle("Add scene")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Create") {
              store.addScene(
                title: String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)),
                location: String(location.prefix(100)))
              dismiss()
            }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
    }.presentationDetents([.medium])
  }
}

struct ProjectTitleSheet: View {
  @EnvironmentObject private var store: StudioStore
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var subtitle = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("Film title") { TextField("Title", text: $title) }
        Section("Logline") {
          TextField("One sentence about your film", text: $subtitle, axis: .vertical)
        }
      }.navigationTitle("About this film")
        .onAppear {
          title = store.project.title
          subtitle = store.project.subtitle
        }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
              store.edit {
                $0.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
                $0.subtitle = String(subtitle.prefix(200))
              }
              dismiss()
            }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
    }.presentationDetents([.medium])
  }
}
