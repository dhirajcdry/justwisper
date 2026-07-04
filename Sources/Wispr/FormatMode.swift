import AppKit

/// Tone/target for AI reformatting. `.auto` resolves from the focused app so a
/// Slack message and an email get different treatment. `.raw` disables rewriting.
enum FormatMode: String, CaseIterable, Identifiable, Codable {
    case auto, email, message, document, code, note, raw

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto (match app)"
        case .email: return "Email"
        case .message: return "Chat / message"
        case .document: return "Document"
        case .code: return "Code"
        case .note: return "Notes"
        case .raw: return "Raw (no rewrite)"
        }
    }

    var glyph: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .email: return "envelope"
        case .message: return "bubble.left.and.bubble.right"
        case .document: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .note: return "list.bullet"
        case .raw: return "textformat"
        }
    }

    /// System-prompt instructions for the on-device LLM.
    var instructions: String {
        let base = """
        You turn raw dictated speech into clean written text.
        Rules you must always follow:
        - Output ONLY the rewritten text — no preamble, no quotes, no notes, no explanation.
        - Preserve the speaker's meaning and vocabulary. Never add facts or content that wasn't said.
        - Fix grammar, spelling, capitalization, and punctuation.
        - Remove filler words and false starts, and apply self-corrections (if the speaker corrects themselves, keep only the corrected version).
        - Keep any line breaks and lists that are already present.
        - If the input is a question, keep it a question. Do not answer it.
        """
        switch self {
        case .email:
            return base + "\nStyle: a clear, professional email body in complete sentences and paragraphs. No greeting or sign-off unless dictated."
        case .message:
            return base + "\nStyle: a casual, concise chat message. Keep it natural and human; don't over-formalize."
        case .document:
            return base + "\nStyle: well-structured prose in paragraphs; use lists only where the speaker clearly enumerates."
        case .code:
            return base + "\nContext: this goes into a code editor. Keep it terse and technical. Do not invent or wrap code. Format as a comment or plain identifier text as appropriate."
        case .note:
            return base + "\nStyle: tidy notes. Use short bullet points where the speaker lists things; otherwise brief sentences."
        case .auto, .raw:
            return base
        }
    }

    /// Choose a mode from the frontmost app's bundle id.
    static func resolve(for app: NSRunningApplication?) -> FormatMode {
        guard let id = app?.bundleIdentifier?.lowercased() else { return .document }
        func has(_ needles: [String]) -> Bool { needles.contains { id.contains($0) } }
        if has(["mail", "outlook", "spark", "airmail", "sparrow"]) { return .email }
        if has(["slack", "discord", "messages", "imessage", "whatsapp", "telegram", "signal", "teams", "zoom"]) { return .message }
        if has(["xcode", "vscode", "com.microsoft.vscode", "code", "terminal", "iterm", "jetbrains", "sublime", "nova", "cursor", "zed"]) { return .code }
        if has(["notes", "obsidian", "bear", "notion", "craft", "logseq"]) { return .note }
        return .document
    }
}
