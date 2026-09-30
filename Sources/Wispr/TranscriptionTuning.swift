import WhisperKit

/// Preview speed must not change the quality or length of the final transcript.
enum TranscriptionTuning {
    static let previewSampleLimit = 12 * 16_000

    static func options(for mode: TranscribeMode) -> DecodingOptions? {
        switch mode {
        case .final:
            return nil // Preserve WhisperKit's full-quality defaults.
        case .streaming:
            return DecodingOptions(
                temperatureFallbackCount: 0,
                sampleLength: 128,
                skipSpecialTokens: true,
                withoutTimestamps: true,
                wordTimestamps: false
            )
        }
    }
}
