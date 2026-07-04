import Foundation

/// Deterministic, instant text transforms applied before (and independent of)
/// the AI rewrite: spoken voice commands, filler removal, snippet expansion,
/// user dictionary, and light casing/spacing repair. Pure — no I/O.
///
/// This is both a pre-pass for the LLM and the complete fallback when on-device
/// AI isn't available, so it must produce sensible text on its own.
struct TextFormatter {
    var removeFillers: Bool
    var voiceCommands: Bool
    var dictionary: [VocabEntry]
    var snippets: [SnippetEntry]

    func process(_ input: String) -> String {
        var t = input
        if voiceCommands { t = applyVoiceCommands(t) }
        if removeFillers {
            t = stripFillers(t)
            t = removeStutters(t)
        }
        t = applyReplacements(t, snippets.map { ($0.trigger, $0.expansion) })
        t = applyReplacements(t, dictionary.map { ($0.spoken, $0.written) })
        t = fixCasing(t)
        return tidy(t)
    }

    // MARK: - Stutters

    /// Function words that Whisper sometimes doubles ("the the", "to to") but are
    /// almost never legitimately repeated. Deliberately excludes words like
    /// "that"/"had" where a real double is grammatical.
    private static let stutterWords: Set<String> = [
        "the", "a", "an", "and", "to", "of", "in", "on", "is", "it", "so",
        "but", "we", "i", "you", "my", "for", "with", "at", "or", "as"
    ]

    /// Collapse an immediate repeat of a common function word, case-insensitively.
    private func removeStutters(_ input: String) -> String {
        input.replacingOccurrences(
            of: "\\b(\(Self.stutterWords.joined(separator: "|")))\\s+\\1\\b",
            with: "$1",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    // MARK: - Voice commands

    /// Spoken editing commands → real structure/punctuation. Whisper won't insert
    /// line breaks or bullets on its own, so these are the high-value ones.
    private func applyVoiceCommands(_ input: String) -> String {
        var t = input

        // "scratch that" / "delete that": drop the clause since the last boundary.
        t = applyScratchThat(t)

        let map: [(String, String)] = [
            ("new paragraph", "\n\n"),
            ("new line", "\n"),
            ("next line", "\n"),
            ("bullet point", "\n- "),
            ("new bullet", "\n- "),
            ("open quote", " \""),
            ("close quote", "\" "),
            ("open parenthesis", " ("),
            ("close parenthesis", ") "),
            ("question mark", "?"),
            ("exclamation mark", "!"),
            ("exclamation point", "!"),
            ("ellipsis", "…"),
        ]
        for (phrase, replacement) in map {
            t = replaceWord(phrase, with: replacement, in: t)
        }
        return t
    }

    private func applyScratchThat(_ input: String) -> String {
        let markers = ["scratch that", "delete that"]
        var t = input
        for marker in markers {
            while let r = t.range(of: marker, options: .caseInsensitive) {
                // Find the previous boundary (sentence end or newline) before the marker.
                let before = t[..<r.lowerBound]
                let boundary = before.rangeOfCharacter(from: CharacterSet(charactersIn: ".!?\n"), options: .backwards)
                let cutStart = boundary?.upperBound ?? before.startIndex
                t.removeSubrange(cutStart..<r.upperBound)
            }
        }
        return t
    }

    // MARK: - Fillers

    private static let fillers = ["um", "uh", "uhm", "erm", "er", "hmm", "mm", "mhm", "you know", "i mean"]

    private func stripFillers(_ input: String) -> String {
        var t = input
        for filler in Self.fillers {
            t = replaceWord(filler, with: "", in: t)
        }
        return t
    }

    // MARK: - Dictionary / snippets

    private func applyReplacements(_ input: String, _ pairs: [(String, String)]) -> String {
        var t = input
        for (pattern, value) in pairs where !pattern.trimmingCharacters(in: .whitespaces).isEmpty {
            t = replaceWord(pattern, with: value, in: t)
        }
        return t
    }

    /// Whole-word, case-insensitive replacement via regex word boundaries.
    private func replaceWord(_ pattern: String, with value: String, in text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
        guard let regex = try? NSRegularExpression(pattern: "\\b\(escaped)\\b", options: [.caseInsensitive])
        else { return text }
        let template = NSRegularExpression.escapedTemplate(for: value)
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    // MARK: - Casing

    /// Capitalize the first letter of each sentence and standalone "i".
    private func fixCasing(_ input: String) -> String {
        var chars = Array(input)
        var capitalizeNext = true
        for i in chars.indices {
            let ch = chars[i]
            if capitalizeNext, ch.isLetter {
                chars[i] = Character(ch.uppercased())
                capitalizeNext = false
            } else if ".!?\n".contains(ch) {
                capitalizeNext = true
            } else if ch.isLetter || ch.isNumber {
                capitalizeNext = false
            }
        }
        var t = String(chars)
        // Standalone "i" → "I".
        t = t.replacingOccurrences(of: "\\bi\\b", with: "I", options: .regularExpression)
        return t
    }

    // MARK: - Tidy

    private func tidy(_ input: String) -> String {
        var t = input
        t = t.replacingOccurrences(of: " +([,.!?;:])", with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "[ \\t]*\\n[ \\t]*", with: "\n", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
