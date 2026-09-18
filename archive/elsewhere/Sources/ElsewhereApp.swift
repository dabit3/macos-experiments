import SwiftUI

@main
struct ElsewhereApp: App {
  @StateObject private var journal = Journal()
  var body: some Scene {
    WindowGroup {
      LibraryView()
        .environmentObject(journal)
        .tint(Ink.blue)
        .preferredColorScheme(.light)
        .alert(
          "Your journal needs attention",
          isPresented: Binding(
            get: { journal.errorMessage != nil },
            set: { if !$0 { journal.errorMessage = nil } }
          )
        ) {
          Button("OK", role: .cancel) { journal.errorMessage = nil }
        } message: {
          Text(journal.errorMessage ?? "")
        }
    }
  }
}
