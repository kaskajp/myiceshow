import Foundation

enum CostumeColor: String, CaseIterable, Identifiable, Codable {
    case lilac = "Lilac"
    case seafoam = "Seafoam"
    case sunset = "Sunset"

    var id: String { rawValue }
}

struct ShowContent: Codable, Equatable {
    static let maximumTitleLength = 80

    var title: String
    var clips: [RoutineClip]
    var costume: CostumeColor

    func validate() throws {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, trimmedTitle.count <= Self.maximumTitleLength else {
            throw ShowStorageError.invalidTitle
        }
        guard !clips.isEmpty else { throw ShowStorageError.emptyRoutine }
        guard Set(clips.map(\.id)).count == clips.count else {
            throw ShowStorageError.duplicateIdentifiers
        }
        for clip in clips {
            guard clip.duration.isFinite,
                  clip.duration >= clip.move.minimumDuration,
                  clip.duration <= SkatingMotion.maximumClipDuration else {
                throw ShowStorageError.invalidDuration
            }
        }
        guard SkatingMotion.duration(of: clips) <= SkatingMotion.maximumDuration else {
            throw ShowStorageError.routineTooLong
        }
    }
}

struct SavedShow: Codable, Identifiable, Equatable {
    let id: UUID
    let updatedAt: Date
    let content: ShowContent
}

struct ShowArchive: Codable {
    static let currentVersion = 1

    let version: Int
    let shows: [SavedShow]

    init(shows: [SavedShow]) {
        version = Self.currentVersion
        self.shows = shows
    }

    func validate() throws {
        guard version == Self.currentVersion else { throw ShowStorageError.unsupportedVersion }
        guard Set(shows.map(\.id)).count == shows.count else {
            throw ShowStorageError.duplicateIdentifiers
        }
        for show in shows {
            try show.content.validate()
        }
    }
}

enum ShowStorageError: LocalizedError {
    case invalidTitle
    case emptyRoutine
    case duplicateIdentifiers
    case invalidDuration
    case routineTooLong
    case unsupportedVersion
    case libraryUnavailable
    case missingShow

    var errorDescription: String? {
        switch self {
        case .invalidTitle: "Give your show a name between 1 and 80 characters."
        case .emptyRoutine: "Add at least one move before saving your show."
        case .duplicateIdentifiers: "The saved shows contain duplicate identifiers."
        case .invalidDuration: "A move has a duration outside its supported range."
        case .routineTooLong: "Shows can be up to 60 seconds long."
        case .unsupportedVersion: "These shows use an unsupported save format."
        case .libraryUnavailable: "Saved shows must be loaded successfully before changes can be saved."
        case .missingShow: "This show is no longer in the library. Reopen it before saving."
        }
    }
}
