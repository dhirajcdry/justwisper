import AppKit

/// A short-lived clipboard replacement. Retains rich formats and only restores
/// if nobody has copied anything since our write (even the same string again).
@MainActor
final class ClipboardTransaction {
    private let pasteboard: NSPasteboard
    private let originalItems: [NSPasteboardItem]
    private let writeCount: Int
    private var finished = false

    private init(pasteboard: NSPasteboard, originalItems: [NSPasteboardItem], writeCount: Int) {
        self.pasteboard = pasteboard
        self.originalItems = originalItems
        self.writeCount = writeCount
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
        pasteboard.clearContents()
        let wrote = pasteboard.setString(text, forType: .string)
        let transaction = ClipboardTransaction(pasteboard: pasteboard,
                                               originalItems: originals,
                                               writeCount: pasteboard.changeCount)
        guard wrote else {
            transaction.restoreIfUnchanged()
            return nil
        }
        return transaction
    }

    var stillOwnsClipboard: Bool { !finished && pasteboard.changeCount == writeCount }

    func restoreIfUnchanged() {
        guard stillOwnsClipboard else { finished = true; return }
        finished = true
        pasteboard.clearContents()
        if !originalItems.isEmpty { pasteboard.writeObjects(originalItems) }
    }
}
