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
        .init(id: "tiny.en",  name: "Tiny",  size: "~75 MB",  note: "Fastest · English"),
        .init(id: "base.en",  name: "Base",  size: "~150 MB", note: "Balanced · English"),
        .init(id: "small.en", name: "Small", size: "~480 MB", note: "Accurate · English"),
        // large-v3-turbo: large-v3's encoder + a 4-layer decoder → ~8× faster
        // than large-v3 at nearly the same accuracy. Replaces plain large-v3,
        // which was too slow to be usable. `_626MB` is the quantized build.
        .init(id: "large-v3-v20240930_626MB", name: "Turbo", size: "~630 MB",
              note: "Fast + accurate · Multilingual"),
    ]

    static let ids: [String] = all.map(\.id)

    static func info(_ id: String) -> WhisperModelInfo {
        all.first { $0.id == id } ?? all[1]
    }
}
