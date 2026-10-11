import Foundation

/// One word in the live preview, with an identity that survives re-transcription
/// so the flow bar can animate only what actually changed.
struct LiveWord: Identifiable, Equatable {
    let id: Int
    var text: String
    /// 1 once a later pass confirmed this word; 0 = just heard (tentative).
    var passes: Int = 0
    /// Replaced a different word the previous pass had here (Whisper changed its mind).
    var revised: Bool = false
    /// Stagger for the arrival animation, so a burst of words reads left to right.
    var delay: Double = 0

    var settled: Bool { passes > 0 }
}

/// Turns the stream of whole-window partial transcripts into stable words.
///
/// Every streaming pass re-transcribes only the last few seconds from scratch,
/// so each `partialText` is a full replacement of a sliding window: its head
/// moves on, and Whisper may rewrite words inside it. Each pass is aligned
/// against the tail of what we already show (word-level LCS on normalised words,
/// preferring the most recent match) to recover which words are the same, which
/// are new, and which were revised. Words that slid out of the window stay as
/// history, so a pause never wipes the line. Pure and cheap — once a pass.
struct LiveTranscript: Equatable {
    private(set) var words: [LiveWord] = []
    private(set) var version = 0
    private var nextID = 0

    static let staggerStep = 0.035
    static let staggerCap = 0.14
    /// Old words beyond the incoming window that alignment still considers.
    static let tailSlack = 8
    /// History kept for display; older words are dropped.
    static let maxWords = 160

    mutating func reset() {
        guard !words.isEmpty else { return }
        words = []
        version += 1
    }

    mutating func ingest(_ text: String) {
        let incoming = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !incoming.isEmpty else { reset(); return }
        let newKeys = incoming.map(Self.key)
        // A pass with no actual words ("." or "…" over silence) says nothing.
        guard newKeys.contains(where: { !$0.isEmpty }) || words.isEmpty else { return }

        // Only the recent tail can overlap the window; earlier words are frozen.
        let tailStart = max(0, words.count - incoming.count - Self.tailSlack)
        let frozen = words[..<tailStart]
        let tail = Array(words[tailStart...])
        let pairs = Self.lcs(tail.map { Self.key($0.text) }, newKeys)

        var result = Array(frozen)
        var arrivals = 0

        func arrive(_ text: String, revised: Bool) {
            var w = LiveWord(id: nextID, text: text)
            nextID += 1
            w.revised = revised
            w.delay = min(Double(arrivals) * Self.staggerStep, Self.staggerCap)
            arrivals += 1
            result.append(w)
        }

        if let (firstOld, firstNew) = pairs.first {
            // Leading gap: old words there slid out of the window — keep them as
            // history and drop the new side (usually a cut-off fragment). Only at
            // the very start, with nothing before, are new leading words real.
            result += tail[..<firstOld]
            if result.isEmpty {
                for n in 0..<firstNew { arrive(incoming[n], revised: false) }
            }
            var oi = firstOld, ni = firstNew
            for (o, n) in pairs {
                // Between anchors, new words replace whatever old words sat there.
                var replaceable = o - oi
                while ni < n { arrive(incoming[ni], revised: replaceable > 0); replaceable -= 1; ni += 1 }
                var kept = tail[o]
                kept.text = incoming[n]          // punctuation/case may have shifted
                kept.passes = 1                  // settled; capped so idle passes are no-ops
                kept.revised = false
                kept.delay = 0
                result.append(kept)
                oi = o + 1; ni = n + 1
            }
            var replaceable = tail.count - oi
            while ni < incoming.count { arrive(incoming[ni], revised: replaceable > 0); replaceable -= 1; ni += 1 }
        } else if tail.contains(where: \.settled) {
            // No overlap with confirmed words: the window moved past them (e.g.
            // after a pause). Keep them and append the fresh window.
            result += tail
            for w in incoming { arrive(w, revised: false) }
        } else {
            // Nothing confirmed yet — this pass is simply a better first guess.
            for w in incoming { arrive(w, revised: !tail.isEmpty) }
        }

        if result.count > Self.maxWords { result.removeFirst(result.count - Self.maxWords) }
        guard result != words else { return }
        words = result
        version += 1
    }

    /// Case- and punctuation-insensitive identity for alignment.
    static func key(_ word: String) -> String {
        String(word.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == "'"
        }.map(Character.init))
    }

    /// Index pairs (old, new) of a longest common subsequence, in order. Ties
    /// resolve toward the end of both sequences, so a common word ("the") aligns
    /// with its most recent occurrence rather than one far back in history.
    static func lcs(_ a: [String], _ b: [String]) -> [(Int, Int)] {
        let m = a.count, n = b.count
        return forwardLCS(Array(a.reversed()), Array(b.reversed()))
            .map { (m - 1 - $0.0, n - 1 - $0.1) }
            .reversed()
    }

    private static func forwardLCS(_ a: [String], _ b: [String]) -> [(Int, Int)] {
        guard !a.isEmpty, !b.isEmpty else { return [] }
        let m = a.count, n = b.count
        var t = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in stride(from: m - 1, through: 0, by: -1) {
            for j in stride(from: n - 1, through: 0, by: -1) {
                t[i][j] = a[i] == b[j] && !a[i].isEmpty
                    ? t[i + 1][j + 1] + 1
                    : max(t[i + 1][j], t[i][j + 1])
            }
        }
        var out: [(Int, Int)] = []
        var i = 0, j = 0
        while i < m, j < n {
            if a[i] == b[j], !a[i].isEmpty, t[i][j] == t[i + 1][j + 1] + 1 {
                out.append((i, j)); i += 1; j += 1
            } else if t[i + 1][j] >= t[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return out
    }
}
