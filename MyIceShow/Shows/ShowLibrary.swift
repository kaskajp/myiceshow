import Foundation
import Observation

@MainActor
@Observable
final class ShowLibrary {
    private(set) var shows: [SavedShow] = []
    private(set) var loadError: String?
    private(set) var isReady = false

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = URL.applicationSupportDirectory
        .appending(path: "MyIceShow", directoryHint: .isDirectory)
        .appending(path: "shows.json")) {
        self.fileURL = fileURL
        reload()
    }

    func reload() {
        do {
            let data = try Data(contentsOf: fileURL)
            let archive = try JSONDecoder().decode(ShowArchive.self, from: data)
            try archive.validate()
            shows = sorted(archive.shows)
            loadError = nil
            isReady = true
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            shows = []
            loadError = nil
            isReady = true
        } catch {
            loadError = "Your saved shows couldn't be read. Nothing was overwritten. \(error.localizedDescription)"
            isReady = false
        }
    }

    func save(content: ShowContent, id: UUID?, updatedAt: Date = .now) throws -> SavedShow {
        guard isReady else { throw ShowStorageError.libraryUnavailable }
        var content = content
        content.title = content.title.trimmingCharacters(in: .whitespacesAndNewlines)
        try content.validate()
        let savedShow = SavedShow(id: id ?? UUID(), updatedAt: updatedAt, content: content)
        var nextShows = shows
        if let id {
            guard let index = nextShows.firstIndex(where: { $0.id == id }) else {
                throw ShowStorageError.missingShow
            }
            nextShows[index] = savedShow
        } else {
            nextShows.append(savedShow)
        }
        let data = try JSONEncoder().encode(ShowArchive(shows: nextShows))
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
        shows = sorted(nextShows)
        return savedShow
    }

    private func sorted(_ shows: [SavedShow]) -> [SavedShow] {
        shows.sorted { first, second in
            if first.updatedAt != second.updatedAt { return first.updatedAt > second.updatedAt }
            return first.content.title.localizedStandardCompare(second.content.title) == .orderedAscending
        }
    }
}
