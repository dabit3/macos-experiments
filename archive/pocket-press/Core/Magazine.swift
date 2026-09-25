import Foundation

enum PageKind: String, Codable, CaseIterable, Identifiable {
    case cover, photograph, story, fieldNotes

    var id: String { rawValue }
    var title: String {
        switch self {
        case .cover: "Cover"
        case .photograph: "Photo essay"
        case .story: "Story"
        case .fieldNotes: "Field notes"
        }
    }
    var subtitle: String {
        switch self {
        case .cover: "The beginning of something"
        case .photograph: "Let a photograph do the talking"
        case .story: "A little room for your words"
        case .fieldNotes: "The details worth keeping"
        }
    }
    var symbol: String {
        switch self {
        case .cover: "book.closed"
        case .photograph: "photo"
        case .story: "text.alignleft"
        case .fieldNotes: "list.bullet"
        }
    }
}

enum PressTheme: String, Codable, CaseIterable, Identifiable {
    case riviera, terracotta, nocturne

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var description: String {
        switch self {
        case .riviera: "Cobalt / warm paper / editorial serif"
        case .terracotta: "Rust / soft ivory / humanist serif"
        case .nocturne: "Chartreuse / midnight / modern sans"
        }
    }
}

struct MagazinePage: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: PageKind
    var title: String
    var caption: String
    var body: String
    var location: String
    var imageName: String

    static let titleLimit = 48
    static let captionLimit = 150
    static let bodyLimit = 850
    static let locationLimit = 42

    var validationMessage: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Give this page a title before saving."
        }
        if title.count > Self.titleLimit { return "Keep the title to 48 characters." }
        if caption.count > Self.captionLimit { return "Keep the caption to 150 characters." }
        if body.count > Self.bodyLimit { return "Keep the story to 850 characters for this page." }
        if location.count > Self.locationLimit { return "Keep the place to 42 characters." }
        if kind == .fieldNotes {
            let entries = body.split(separator: "\n")
            if entries.count > 6 || entries.contains(where: { $0.count > 150 }) {
                return "Use up to 6 notes, each under 151 characters."
            }
        } else if body.components(separatedBy: "\n").count > 20 {
            return "Use up to 20 lines of story text per page."
        }
        return nil
    }

    static func sample(_ kind: PageKind) -> MagazinePage {
        switch kind {
        case .cover:
            MagazinePage(
                kind: .cover, title: "Somewhere\nslow.",
                caption: "Five villages. No hurry. A small journal of the Italian coast.",
                body: "", location: "CINQUE TERRE, ITALY", imageName: "manarola")
        case .photograph:
            MagazinePage(
                kind: .photograph, title: "The sea\nbetween us",
                caption: "Late light, salt on our skin, and nowhere else we needed to be.",
                body: "", location: "MANAROLA • 18:42", imageName: "harbour")
        case .story:
            MagazinePage(
                kind: .story, title: "Taking the\nlong way",
                caption: "A NOTE ON GETTING LOST",
                body:
                    "We missed the train on purpose. At least, that is how we tell it now.\n\nThe path climbed above the village, past lemon trees and shutters painted the color of the sea. Below us, someone was setting a table for lunch.\n\nThere are places that ask you to do less. To sit on the warm stone. To order another coffee. To leave a little space between one thing and the next.\n\nBy evening, we had walked very little and seen everything.",
                location: "FROM THE COAST", imageName: "manarola")
        case .fieldNotes:
            MagazinePage(
                kind: .fieldNotes, title: "Small things,\nkept.",
                caption: "A few coordinates for a slower kind of day.",
                body:
                    "09:00 — An espresso at the counter. No plans yet.\n11:30 — Follow the blue trail above the village.\n14:00 — Focaccia, still warm, eaten by the water.\n18:42 — Stay until the houses turn gold.",
                location: "THE POCKET GUIDE", imageName: "harbour")
        }
    }
}

struct Magazine: Codable, Identifiable, Equatable {
    var id = UUID()
    var theme: PressTheme = .riviera
    var pages: [MagazinePage]
    var modifiedAt = Date()
    static let maximumPages = 24

    var title: String { pages.first?.title.replacingOccurrences(of: "\n", with: " ") ?? "Untitled" }

    static func coastal() -> Magazine {
        Magazine(pages: PageKind.allCases.map(MagazinePage.sample))
    }

    mutating func replace(_ page: MagazinePage) throws {
        guard page.validationMessage == nil else { throw MagazineError.invalidPage }
        guard let index = pages.firstIndex(where: { $0.id == page.id }),
            pages[index].kind == page.kind
        else { throw MagazineError.invalidPage }
        pages[index] = page
        modifiedAt = Date()
    }

    mutating func add(_ kind: PageKind) throws -> UUID {
        guard kind != .cover, pages.count < Self.maximumPages else { throw MagazineError.pageLimit }
        let page = MagazinePage.sample(kind)
        pages.append(page)
        modifiedAt = Date()
        return page.id
    }

    mutating func move(_ id: UUID, by offset: Int) {
        guard let source = pages.firstIndex(where: { $0.id == id }), source > 0 else { return }
        let destination = source + offset
        guard destination > 0, destination < pages.count else { return }
        pages.swapAt(source, destination)
        modifiedAt = Date()
    }

    mutating func remove(_ id: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == id }), index > 0 else { return }
        pages.remove(at: index)
        modifiedAt = Date()
    }

    var isValid: Bool {
        !pages.isEmpty && pages.count <= Self.maximumPages && pages.first?.kind == .cover
            && pages.dropFirst().allSatisfy { $0.kind != .cover }
            && Set(pages.map(\.id)).count == pages.count
            && pages.allSatisfy { $0.validationMessage == nil }
    }

    var exportFilename: String {
        let cleaned = title.unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "-"
        }.joined().split(separator: "-").joined(separator: "-")
        return "\(cleaned.isEmpty ? "Pocket-Press" : cleaned)-\(id.uuidString.prefix(8)).pdf"
    }
}

enum MagazineError: Error, LocalizedError {
    case invalidPage, pageLimit, invalidLibrary
    var errorDescription: String? {
        switch self {
        case .invalidPage: "This page could not be saved. Please check its title and text."
        case .pageLimit: "An issue holds one cover and up to 23 interior pages."
        case .invalidLibrary: "The saved library could not be read. Your original file is preserved."
        }
    }
}

struct PressLibrary: Codable, Equatable {
    var version = 1
    var issues: [Magazine]

    static func decode(_ data: Data) throws -> PressLibrary {
        let library = try JSONDecoder().decode(PressLibrary.self, from: data)
        guard library.version == 1, library.issues.allSatisfy(\.isValid),
            Set(library.issues.map(\.id)).count == library.issues.count
        else { throw MagazineError.invalidLibrary }
        return library
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
