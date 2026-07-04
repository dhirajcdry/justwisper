import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device AI rewrite of raw dictation into clean, tone-matched prose using
/// Apple's built-in Foundation Models LLM (macOS 26+, Apple Intelligence).
/// Fully local, no network, no download. Returns nil when the model isn't
/// usable so callers fall back to the deterministic pipeline.
actor AIFormatter {
    enum Availability: Equatable {
        case ready
        case needsAppleIntelligence   // supported, but the user hasn't turned it on
        case notSupported             // OS too old / device ineligible / no model

        var blurb: String {
            switch self {
            case .ready: return "On-device AI · runs offline"
            case .needsAppleIntelligence: return "Turn on Apple Intelligence in System Settings"
            case .notSupported: return "Not available on this Mac — using fast rule-based cleanup"
            }
        }
    }

    var availability: Availability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .ready
            case .unavailable(.appleIntelligenceNotEnabled):
                return .needsAppleIntelligence
            default:
                return .notSupported
            }
        }
        #endif
        return .notSupported
    }

    /// Rewrite `text` for the given tone. Returns nil if the model isn't usable
    /// or the output looks unusable, so the caller keeps the rule-based result.
    func format(_ text: String, mode: FormatMode) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, mode != .raw else { return nil }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), case .available = SystemLanguageModel.default.availability {
            do {
                let session = LanguageModelSession(instructions: mode.instructions)
                let response = try await session.respond(
                    to: trimmed,
                    options: GenerationOptions(temperature: 0.2)
                )
                let out = Self.sanitize(response.content, original: trimmed)
                return out.isEmpty ? nil : out
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    /// Guard against the model wrapping its answer in quotes/preamble or going
    /// badly off the rails (wildly longer output = probably hallucinated).
    private static func sanitize(_ raw: String, original: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count > 1, s.hasPrefix("\""), s.hasSuffix("\"") {
            s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // If the rewrite ballooned to >3x the input, the model likely answered
        // instead of reformatting — reject it.
        if s.count > max(60, original.count * 3) { return "" }
        return s
    }
}
