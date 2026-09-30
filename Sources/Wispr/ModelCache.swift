import Foundation

/// Resolves an already-downloaded Whisper model without searching unrelated
/// package descendants or accepting a similarly named model.
enum ModelCache {
    private static let requiredComponents = [
        "AudioEncoder.mlmodelc",
        "TextDecoder.mlmodelc",
        "MelSpectrogram.mlmodelc"
    ]

    /// Returns the exact `openai_whisper-<model>` folder under `root` when all
    /// compiled model components are present, otherwise nil.
    static func cachedFolder(for model: String, in root: URL) -> URL? {
        guard !model.isEmpty, !model.contains("/") else { return nil }
        // WhisperKit's Hub cache is nested under the repository path. Also
        // accept a directly populated root for manually supplied local models.
        let roots = [root.appendingPathComponent("models/argmaxinc/whisperkit-coreml"), root]
        return roots.map { $0.appendingPathComponent("openai_whisper-\(model)", isDirectory: true) }
            .first(where: isComplete)
    }

    private static func isComplete(_ folder: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { return false }
        return requiredComponents.allSatisfy { component in
            let url = folder.appendingPathComponent(component, isDirectory: true)
            var componentIsDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &componentIsDirectory)
                && componentIsDirectory.boolValue
        }
    }
}
