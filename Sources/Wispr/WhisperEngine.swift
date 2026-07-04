import Foundation
import WhisperKit

/// WhisperKit-backed engine. Downloads models with progress into our own
/// Application Support folder, loads them, and transcribes on the Neural Engine.
actor WhisperEngine: TranscriptionEngine {
    nonisolated let displayName = "WhisperKit · Core ML"

    private var pipe: WhisperKit?
    private var loadedModel: String?

    nonisolated var modelsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Wispr/Models", isDirectory: true)
    }

    nonisolated func modelExistsOnDisk(_ model: String) -> Bool {
        let fm = FileManager.default
        guard let items = fm.enumerator(at: modelsDirectory, includingPropertiesForKeys: nil) else { return false }
        for case let url as URL in items {
            if url.pathExtension == "mlmodelc", url.path.contains(model) { return true }
        }
        return false
    }

    func prepare(model: String, progress: @escaping @Sendable (Double) -> Void) async throws {
        if loadedModel == model, pipe != nil {
            progress(1)
            return
        }
        // Switching models — drop the old pipeline first.
        pipe = nil
        loadedModel = nil

        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // Download with progress (skips files already present), then load from disk.
        let folder = try await WhisperKit.download(variant: model, downloadBase: modelsDirectory) { p in
            progress(p.fractionCompleted)
        }

        let config = WhisperKitConfig(
            model: model,
            modelFolder: folder.path,
            prewarm: true,   // compile for the Neural Engine up front, not on first dictation
            load: true,
            download: false
        )
        let pipe = try await WhisperKit(config)
        self.pipe = pipe
        self.loadedModel = model
        progress(1)
    }

    /// Run a throwaway inference so the encoder/decoder path is hot before the
    /// user's first real dictation (the first pass through the ANE is the slow one).
    func warmUp() async {
        _ = try? await transcribe(Array(repeating: 0, count: 16_000), mode: .streaming)
    }

    func transcribe(_ samples: [Float], mode: TranscribeMode) async throws -> TranscriptionResult {
        guard let pipe else { throw EngineError.notReady }
        var callback: TranscriptionCallback = nil
        if mode == .streaming {
            // Streaming passes must yield instantly when the user stops talking —
            // otherwise the final pass queues behind them on this actor.
            streamAbort.reset()
            let flag = streamAbort
            callback = { _ in flag.isSet ? false : nil }
        }
        let results = try await pipe.transcribe(audioArray: samples, decodeOptions: nil, callback: callback)
        let joined = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return TranscriptionResult(text: TranscriptCleaner.clean(joined))
    }

    // MARK: - Streaming abort

    /// Ask any in-flight streaming decode to bail out at the next token so the
    /// final (best-quality) pass can start immediately. Safe to call anytime.
    nonisolated func abortStreaming() { streamAbort.set() }

    private nonisolated let streamAbort = AbortFlag()

    private final class AbortFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        func set() { lock.withLock { value = true } }
        func reset() { lock.withLock { value = false } }
        var isSet: Bool { lock.withLock { value } }
    }
}
