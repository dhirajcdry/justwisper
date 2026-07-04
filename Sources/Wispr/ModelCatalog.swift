import Foundation

/// Metadata for the local Whisper models the user can pick from.
struct WhisperModelInfo: Identifiable, Hashable {
    let id: String      // WhisperKit variant name, e.g. "base.en"
    let name: String    // display name
    let size: String    // approximate download size
    let note: String    // one-line tradeoff description
}

enum ModelCatalog {
    static let all: [WhisperModelInfo] = [
        .init(id: "tiny.en",  name: "Tiny",     size: "~75 MB",  note: "Fastest · English"),
        .init(id: "base.en",  name: "Base",     size: "~150 MB", note: "Balanced · English"),
        .init(id: "small.en", name: "Small",    size: "~480 MB", note: "Accurate · English"),
        .init(id: "large-v3", name: "Large v3", size: "~1.5 GB", note: "Most accurate · Multilingual"),
    ]

    static let ids: [String] = all.map(\.id)

    static func info(_ id: String) -> WhisperModelInfo {
        all.first { $0.id == id } ?? all[1]
    }
}
