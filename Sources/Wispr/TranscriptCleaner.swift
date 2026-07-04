import Foundation

/// Strips Whisper's non-speech annotations and stray special tokens from a
/// transcript so only spoken words reach the user.
///
/// Whisper emits sound events in brackets/parens — `[BLANK_AUDIO]`, `[ Silence ]`,
/// `(upbeat music)`, `[INAUDIBLE]`, `(coughs)` — and occasionally leaks `<|...|>`
/// timestamp/format tokens. None of that belongs in dictated text.
enum TranscriptCleaner {
    /// Non-speech words Whisper commonly annotates. Matched case-insensitively
    /// inside brackets or parentheses.
    private static let noiseWords: Set<String> = [
        "blank", "silence", "music", "inaudible", "noise", "applause",
        "laughter", "laughs", "laugh", "coughs", "cough", "sighs", "sigh",
        "sound", "sounds", "beep", "beeping", "static", "wind", "breathing",
        "footsteps", "clears throat", "chuckles", "pause", "no audio",
        "background noise", "audio", "clicking", "typing", "ringing"
    ]

    // <|...|> special tokens (timestamps, task markers) that sometimes leak.
    private static let specialToken = try! NSRegularExpression(pattern: "<\\|[^|]*\\|>")
    // Bracketed [ ... ] or parenthesized ( ... ) groups.
    private static let bracketGroup = try! NSRegularExpression(pattern: "[\\[(][^\\]\\)]*[\\])]")

    static func clean(_ raw: String) -> String {
        var text = raw

        text = replaceAll(specialToken, in: text, with: "")

        // Drop bracketed/parenthesized groups that are non-speech annotations:
        // either fully upper-case (Whisper's sound-event convention) or a known
        // noise word. Leaves genuine dictated parentheticals intact.
        text = replaceMatches(bracketGroup, in: text) { match in
            let inner = String(match.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespaces)
            let lower = inner.lowercased()
            let isUpper = inner == inner.uppercased() && inner.rangeOfCharacter(from: .letters) != nil
            let isNoise = noiseWords.contains(lower)
                || noiseWords.contains(where: { lower == $0 || lower.hasPrefix($0 + " ") || lower.hasSuffix(" " + $0) })
            return (isUpper || isNoise) ? "" : match
        }

        return tidy(text)
    }

    /// Collapse the whitespace/punctuation gaps left behind after removals.
    private static func tidy(_ input: String) -> String {
        var text = input
        // Spaces before punctuation → none.
        text = text.replacingOccurrences(of: " +([,.!?;:])", with: "$1", options: .regularExpression)
        // Runs of whitespace → single space.
        text = text.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        // Blank lines left by removed annotations.
        text = text.replacingOccurrences(of: "\\n[ \\t]*\\n+", with: "\n", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Regex helpers

    private static func replaceAll(_ regex: NSRegularExpression, in text: String, with template: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private static func replaceMatches(_ regex: NSRegularExpression, in text: String,
                                       transform: (String) -> String) -> String {
        let ns = text as NSString
        var result = ""
        var cursor = 0
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: cursor, length: m.range.location - cursor))
            result += transform(ns.substring(with: m.range))
            cursor = m.range.location + m.range.length
        }
        result += ns.substring(from: cursor)
        return result
    }
}
