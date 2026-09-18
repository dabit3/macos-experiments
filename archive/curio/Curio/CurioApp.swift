import SwiftUI

@main
struct CurioApp: App {
  @StateObject private var museum = MuseumStore()

  var body: some Scene {
    WindowGroup {
      MuseumHome()
        .environmentObject(museum)
        .tint(MuseumStyle.cobalt)
        .preferredColorScheme(.light)
        .alert(
          "Couldn’t save your museum",
          isPresented: Binding(
            get: { museum.errorMessage != nil },
            set: { if !$0 { museum.errorMessage = nil } }
          )
        ) {
          Button("OK") { museum.errorMessage = nil }
        } message: {
          Text(museum.errorMessage ?? "")
        }
    }
  }
}

struct Eyebrow: View {
  var text: String
  var color: Color = MuseumStyle.muted
  var body: some View {
    Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(1.5)
      .foregroundStyle(color)
  }
}

struct MuseumButton: ButtonStyle {
  var filled = true
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.subheadline.weight(.semibold))
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 16).padding(.vertical, 14)
      .frame(maxWidth: .infinity, minHeight: 52)
      .foregroundStyle(filled ? .white : MuseumStyle.ink)
      .background(filled ? MuseumStyle.cobalt : MuseumStyle.stone.opacity(0.5))
      .clipShape(RoundedRectangle(cornerRadius: 7))
      .opacity(configuration.isPressed ? 0.7 : 1)
  }
}

struct MuseumHome: View {
  @EnvironmentObject private var museum: MuseumStore
  @State private var createCollection = false
  @State private var showSearch = false
  @State private var showAbout = false
  @ScaledMetric private var titleSize = 45

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "A personal museum", color: MuseumStyle.cobalt)
            Text("Good things.\nKept close.")
              .font(MuseumStyle.serif(titleSize)).tracking(-1.4).lineSpacing(-3)
              .fixedSize(horizontal: false, vertical: true)
            Text("A home for the objects that mean something.")
              .font(.subheadline).foregroundStyle(MuseumStyle.muted)
              .fixedSize(horizontal: false, vertical: true)
          }

          if let featured = museum.collections.first(where: { !$0.isSample })
            ?? museum.collections.first
          {
            NavigationLink {
              CollectionGallery(collectionID: featured.id)
            } label: {
              FeaturedExhibition(
                collection: featured, objects: museum.query(collectionID: featured.id))
            }.buttonStyle(.plain)
          } else {
            VStack(alignment: .leading, spacing: 16) {
              ExhibitArtwork(artifact: .unpictured).frame(height: 180)
              Text("Every collection starts\nwith one good thing.")
                .font(MuseumStyle.serif(29))
              Button("Create your first collection") { createCollection = true }
                .buttonStyle(MuseumButton())
            }.padding(24).background(MuseumStyle.stone.opacity(0.4))
          }

          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Eyebrow(text: "Your collections · \(museum.collections.count)")
              Spacer()
              Button {
                createCollection = true
              } label: {
                Label("New", systemImage: "plus").font(.subheadline.weight(.semibold)).frame(
                  minHeight: 44)
              }.accessibilityLabel("New collection")
            }
            ForEach(museum.collections) { collection in
              NavigationLink {
                CollectionGallery(collectionID: collection.id)
              } label: {
                HStack(spacing: 16) {
                  ExhibitArtwork(
                    artifact: museum.query(collectionID: collection.id).first?.artifact
                      ?? .unpictured,
                    photo: museum.query(collectionID: collection.id).first?.photo
                  )
                  .frame(width: 66, height: 72).background(MuseumStyle.stone.opacity(0.4))
                  VStack(alignment: .leading, spacing: 5) {
                    Text(collection.title).font(.headline).foregroundStyle(MuseumStyle.ink)
                    Text(
                      "\(museum.query(collectionID: collection.id).count) objects\(collection.isSample ? " · Sample collection" : "")"
                    )
                    .font(.caption).foregroundStyle(MuseumStyle.muted)
                  }
                  Spacer(minLength: 0)
                  Image(systemName: "arrow.up.right").font(.subheadline)
                }
              }.buttonStyle(.plain)
              Divider()
            }
            NavigationLink {
              ObjectBrowser(title: "Favorites", favoritesOnly: true)
            } label: {
              HStack {
                Image(systemName: "heart").frame(width: 24)
                Text("The favorites").font(.subheadline.weight(.medium))
                Spacer()
                Text("\(museum.query(favorites: true).count)").font(.caption.monospacedDigit())
                Image(systemName: "arrow.up.right")
              }.frame(minHeight: 48)
            }.buttonStyle(.plain)
          }
          HStack(spacing: 7) {
            Image(systemName: "lock").font(.caption2)
            Text("PRIVATE BY DESIGN. YOURS TO KEEP.")
              .font(.caption2.weight(.medium)).tracking(1)
          }.foregroundStyle(MuseumStyle.muted).frame(maxWidth: .infinity).padding(.bottom, 14)
        }.padding(.horizontal, 25).padding(.top, 18)
      }
      .safeAreaInset(edge: .top, spacing: 0) {
        HStack(spacing: 10) {
          BrandMark()
          Text("Curio").font(MuseumStyle.serif(29))
          Spacer()
          Button {
            showSearch = true
          } label: {
            Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
          }.accessibilityLabel("Search all objects")
          Button {
            showAbout = true
          } label: {
            Image(systemName: "info.circle").frame(width: 44, height: 44)
          }.accessibilityLabel("About your museum")
        }.padding(.horizontal, 25).padding(.vertical, 4)
          .background(MuseumStyle.paper)
          .overlay(alignment: .bottom) { MuseumStyle.stone.opacity(0.7).frame(height: 0.5) }
      }
      .background(MuseumStyle.paper)
      .foregroundStyle(MuseumStyle.ink)
      .toolbar(.hidden, for: .navigationBar)
      .sheet(isPresented: $createCollection) { CollectionEditor() }
      .sheet(isPresented: $showSearch) {
        NavigationStack { ObjectBrowser(title: "Find an object", showClose: true) }
      }
      .sheet(isPresented: $showAbout) { MuseumAbout() }
    }
  }
}

struct FeaturedExhibition: View {
  var collection: MuseumCollection
  var objects: [MuseumObject]
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Eyebrow(text: collection.isSample ? "The sample exhibition" : "In your museum")
        Spacer()
        Text(String(format: "%02d", objects.count)).font(.caption.monospacedDigit())
      }.padding(18)
      ZStack {
        Ellipse().fill(.white.opacity(0.45)).frame(width: 245, height: 160).blur(radius: 24)
        if objects.isEmpty {
          VStack(spacing: 0) {
            ExhibitArtwork(artifact: .unpictured).frame(height: 158)
            Text("Your first object belongs here.")
              .font(.subheadline).foregroundStyle(MuseumStyle.muted)
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, 12)
          }
        } else {
          ExhibitArtwork(artifact: objects.first?.artifact ?? .camera, photo: objects.first?.photo)
            .frame(height: 195).padding(.horizontal, 25)
        }
      }.frame(maxWidth: .infinity, minHeight: 195)
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 8) {
          Text(collection.title).font(MuseumStyle.serif(32)).tracking(-0.7)
          Text("Enter the collection").font(.subheadline)
        }
        Spacer()
        Image(systemName: "arrow.right").font(.title3).foregroundStyle(.white)
          .frame(width: 46, height: 46).background(MuseumStyle.cobalt).clipShape(Circle())
      }.padding(20).padding(.bottom, 4)
    }
    .background(MuseumStyle.stone.opacity(0.6))
    .clipShape(RoundedRectangle(cornerRadius: 3))
    .accessibilityElement(children: .combine)
  }
}

struct MuseumAbout: View {
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 25) {
          BrandMark().padding(.top, 25)
          Text("A little museum.\nEntirely yours.").font(MuseumStyle.serif(36))
          Text(
            "Curio is a private place to collect the stories behind your things. No account, no feed, no hurry."
          )
          .font(.body).foregroundStyle(MuseumStyle.muted)
          Divider()
          Label("Everything stays on this device", systemImage: "lock")
            .font(.headline)
          Text(
            "Your collections and imported photos are saved offline in the app. Deleting the app also deletes its museum. Exported labels are images, not a backup of your collections."
          )
          .foregroundStyle(MuseumStyle.muted)
          Label("A considered starting point", systemImage: "square.stack")
            .font(.headline)
          Text(
            "Everyday icons is an explicitly sample collection. Its stories are fictional and its illustrations were drawn for Curio. Edit or delete it, or begin a collection of your own."
          )
          .foregroundStyle(MuseumStyle.muted)
          Eyebrow(text: "Curio · Version 1.0")
        }.padding(25)
      }.background(MuseumStyle.paper)
        .navigationTitle("About Curio").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MuseumStyle.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
}
