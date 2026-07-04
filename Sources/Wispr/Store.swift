import Foundation

/// A custom-vocabulary entry: how a term is heard vs. how it should be written.
struct VocabEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var spoken: String
    var written: String
}

/// A snippet: say the trigger phrase, get the (possibly multi-line) expansion.
struct SnippetEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var trigger: String
    var expansion: String
}

/// A per-app style pin: dictations landing in this app always use this mode,
/// beating the global Style picker and auto-resolution.
struct AppStyleEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var bundleID: String
    var appName: String
    var mode: FormatMode
}

/// Tiny JSON persistence in Application Support/Wispr.
enum Persist {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let d = base.appendingPathComponent("Wispr", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = dir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        let url = dir.appendingPathComponent(name)
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
