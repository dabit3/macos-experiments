import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class PressStore: ObservableObject {
    @Published private(set) var library: PressLibrary
    @Published private(set) var canUndo = false
    @Published var error: String?
    @Published private(set) var storageUnavailable = false
    private var history: [PressLibrary] = []

    static var directory: URL {
        URL.documentsDirectory.appending(path: "PocketPress", directoryHint: .isDirectory)
    }
    private var libraryURL: URL { Self.directory.appending(path: "library.json") }

    init() {
        library = PressLibrary(issues: [])
        do {
            try FileManager.default.createDirectory(
                at: Self.directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: libraryURL.path) {
                library = try PressLibrary.decode(Data(contentsOf: libraryURL))
            } else {
                library = PressLibrary(issues: [.coastal()])
                try persist(library)
            }
        } catch {
            self.error = error.localizedDescription
            storageUnavailable = true
        }
    }

    func issue(_ id: UUID) -> Magazine? { library.issues.first { $0.id == id } }

    @discardableResult
    func create() -> UUID? {
        let issue = Magazine.coastal()
        return commit { $0.issues.insert(issue, at: 0) } ? issue.id : nil
    }

    func update(_ id: UUID, change: (inout Magazine) throws -> Void) {
        commit { library in
            guard let index = library.issues.firstIndex(where: { $0.id == id }) else { return }
            try change(&library.issues[index])
            library.issues[index].modifiedAt = Date()
        }
    }

    func delete(_ id: UUID) {
        commit { $0.issues.removeAll { $0.id == id } }
    }

    func reset(_ id: UUID) {
        update(id) { issue in
            let preservedID = issue.id
            issue = .coastal()
            issue.id = preservedID
        }
    }

    func undo() {
        guard let previous = history.last else { return }
        do {
            try persist(previous)
            library = previous
            history.removeLast()
            canUndo = !history.isEmpty
        } catch { self.error = error.localizedDescription }
    }

    @discardableResult
    private func commit(_ change: (inout PressLibrary) throws -> Void) -> Bool {
        guard !storageUnavailable else { return false }
        var next = library
        do {
            try change(&next)
            guard next.issues.allSatisfy(\.isValid) else { throw MagazineError.invalidLibrary }
            if next == library { return true }
            try persist(next)
            history.append(library)
            if history.count > 40 { history.removeFirst() }
            library = next
            canUndo = true
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func persist(_ library: PressLibrary) throws {
        try library.encoded().write(to: libraryURL, options: .atomic)
    }

    func importPhoto(_ item: PhotosPickerItem) async throws -> String {
        guard let data = try await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { throw PhotoError.unreadable }
        let size = image.size
        let ratio = min(1, 2048 / max(size.width, size.height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let scaled = UIGraphicsImageRenderer(
            size: CGSize(width: size.width * ratio, height: size.height * ratio), format: format
        ).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: size.width * ratio, height: size.height * ratio))
        }
        guard let jpeg = scaled.jpegData(compressionQuality: 0.88) else { throw PhotoError.unreadable }
        let name = "import-\(UUID().uuidString).jpg"
        try jpeg.write(to: Self.directory.appending(path: name), options: .atomic)
        return name
    }

    enum PhotoError: Error, LocalizedError {
        case unreadable
        var errorDescription: String? { "That image could not be opened. Try another photo." }
    }
}
