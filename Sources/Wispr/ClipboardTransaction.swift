import AppKit

/// A short-lived clipboard replacement. Retains rich formats and only restores
/// if nobody has copied anything since our write (even the same string again).
///
/// The transcript is written as a *promise* (lazy pasteboard data), so we learn
/// the moment an app actually reads it. That turns a blind ⌘V into a verified
/// delivery, and lets us restore the user's clipboard only after the paste has
/// consumed it — never before a slow app (Discord, a busy browser tab) got to it.
@MainActor
final class ClipboardTransaction: NSObject, NSPasteboardItemDataProvider {
    private let pasteboard: NSPasteboard
    private let originalItems: [NSPasteboardItem]
    private let text: String
    private var writeCount = 0
    private var finished = false
    /// Some app has read the transcript off the clipboard.
    private(set) var wasRead = false

    private init(pasteboard: NSPasteboard, originalItems: [NSPasteboardItem], text: String) {
        self.pasteboard = pasteboard
        self.originalItems = originalItems
        self.text = text
    }

    static func begin(text: String, on pasteboard: NSPasteboard) -> ClipboardTransaction? {
        let originalCount = pasteboard.changeCount
        var originals: [NSPasteboardItem] = []
        for item in pasteboard.pasteboardItems ?? [] {
            let copy = NSPasteboardItem()
            for type in item.types {
                // Don't destroy an item whose advertised data we can't preserve.
                guard let data = item.data(forType: type), copy.setData(data, forType: type) else { return nil }
            }
            originals.append(copy)
        }
        guard pasteboard.changeCount == originalCount else { return nil }
        let transaction = ClipboardTransaction(pasteboard: pasteboard, originalItems: originals, text: text)
        let promise = NSPasteboardItem()
        guard promise.setDataProvider(transaction, forTypes: [.string]) else { return nil }
        pasteboard.clearContents()
        let wrote = pasteboard.writeObjects([promise])
        transaction.writeCount = pasteboard.changeCount
        guard wrote else {
            transaction.restoreIfUnchanged()
            return nil
        }
        return transaction
    }

    var stillOwnsClipboard: Bool { !finished && pasteboard.changeCount == writeCount }

    /// Wait until an app reads the transcript, or `timeout` passes.
    func waitUntilRead(timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !wasRead, ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(15))
        }
        return wasRead
    }

    func restoreIfUnchanged() {
        guard stillOwnsClipboard else { finished = true; return }
        finished = true
        pasteboard.clearContents()
        if !originalItems.isEmpty { pasteboard.writeObjects(originalItems) }
    }

    /// The paste never happened: leave the transcript on the clipboard as plain
    /// text, so the user's own ⌘V works.
    func keepTranscript() {
        guard stillOwnsClipboard else { finished = true; return }
        finished = true
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: NSPasteboardItemDataProvider

    nonisolated func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem,
                                provideDataForType type: NSPasteboard.PasteboardType) {
        MainActor.assumeIsolated {
            item.setString(text, forType: type)
            wasRead = true
        }
    }
}
