import Foundation
import WhisperKit

/// WhisperKit-backed engine. Downloads models with progress into our own
/// Application Support folder, loads them, and transcribes on the Neural Engine.
actor WhisperEngine: TranscriptionEngine {
    nonisolated let displayName = "WhisperKit · Core ML"

    private var pipe: WhisperKit?
    private var loadedModel: String?

    // Actors are reentrant across await: a streaming decode, final decode, and
    // warm-up could otherwise use the same mutable WhisperKit pipeline at once.
    private var pipelineBusy = false
    private var pipelineWaiters: [CheckedContinuation<Void, Never>] = []

    private func acquirePipeline() async {
        if !pipelineBusy {
            pipelineBusy = true
            return
        }
        await withCheckedContinuation { pipelineWaiters.append($0) }
    }

    private func releasePipeline() {
        if pipelineWaiters.isEmpty { pipelineBusy = false }
        else { pipelineWaiters.removeFirst().resume() }
    }

    nonisolated var modelsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Wispr/Models", isDirectory: true)
    }

    nonisolated func modelExistsOnDisk(_ model: String) -> Bool {
        ModelCache.cachedFolder(for: model, in: modelsDirectory) != nil
    }

    func prepare(model: String, progress: @escaping @Sendable (Double) -> Void) async throws {
        await acquirePipeline()
        defer { releasePipeline() }
        try Task.checkCancellation()
        if loadedModel == model, pipe != nil {
            progress(1)
            return
        }
        // Switching models — drop the old pipeline first.
        pipe = nil
        loadedModel = nil

        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        let cachedFolder = ModelCache.cachedFolder(for: model, in: modelsDirectory)
        let folder: URL
        if let cachedFolder {
            folder = cachedFolder
        } else {
            folder = try await WhisperKit.download(variant: model, downloadBase: modelsDirectory) { p in
                progress(p.fractionCompleted)
            }
        }

        let config = WhisperKitConfig(
            model: model,
            modelFolder: folder.path,
            tokenizerFolder: modelsDirectory.appendingPathComponent("Tokenizers", isDirectory: true),
            // Tiny/Base/Small can load directly on repeat launches. Keep the
            // memory-saving load/unload pass for first loads and larger models.
            prewarm: cachedFolder == nil || !["tiny.en", "base.en", "small.en"].contains(model),
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
        await acquirePipeline()
        defer { releasePipeline() }
        try Task.checkCancellation()
        guard let pipe else { throw EngineError.notReady }
        var callback: TranscriptionCallback = nil
        if mode == .streaming {
            // Streaming passes must yield instantly when the user stops talking —
            // otherwise the final pass queues behind them on this actor.
            streamAbort.reset()
            let flag = streamAbort
            callback = { _ in flag.isSet ? false : nil }
        }
        let results = try await pipe.transcribe(audioArray: samples, decodeOptions: TranscriptionTuning.options(for: mode), callback: callback)
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
