import AppKit
import XCTest
@testable import Wispr

final class ClipboardTransactionTests: XCTestCase {
    @MainActor
    func testRestoresAllItemsAndRichFormats() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let first = NSPasteboardItem()
        first.setString("original text", forType: .string)
        let rich = Data("{\\rtf1 original text}".utf8)
        first.setData(rich, forType: .rtf)
        let second = NSPasteboardItem()
        second.setString("file:///tmp/example.txt", forType: .fileURL)
        XCTAssertTrue(board.writeObjects([first, second]))
        let transaction = try XCTUnwrap(ClipboardTransaction.begin(text: "dictation", on: board))
        XCTAssertEqual(board.string(forType: .string), "dictation")
        transaction.restoreIfUnchanged()
        XCTAssertEqual(board.pasteboardItems?.count, 2)
        XCTAssertEqual(board.pasteboardItems?[0].string(forType: .string), "original text")
        XCTAssertEqual(board.pasteboardItems?[0].data(forType: .rtf), rich)
        XCTAssertEqual(board.pasteboardItems?[1].string(forType: .fileURL), "file:///tmp/example.txt")
    }

    @MainActor
    func testRestoresAnInitiallyEmptyClipboard() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.clearContents()
        let transaction = try XCTUnwrap(ClipboardTransaction.begin(text: "dictation", on: board))
        transaction.restoreIfUnchanged()
        XCTAssertTrue(board.pasteboardItems?.isEmpty ?? true)
    }

    @MainActor
    func testDoesNotOverwriteANewerCopy() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("original", forType: .string)
        let transaction = try XCTUnwrap(ClipboardTransaction.begin(text: "dictation", on: board))
        board.clearContents()
        board.setString("new user copy", forType: .string)
        XCTAssertFalse(transaction.stillOwnsClipboard)
        transaction.restoreIfUnchanged()
        XCTAssertEqual(board.string(forType: .string), "new user copy")
    }

    @MainActor
    func testCopyingTheSameTextIsStillANewerCopy() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("original", forType: .string)
        let transaction = try XCTUnwrap(ClipboardTransaction.begin(text: "dictation", on: board))
        board.clearContents()
        board.setString("dictation", forType: .string)
        transaction.restoreIfUnchanged()
        XCTAssertEqual(board.string(forType: .string), "dictation")
    }

    @MainActor
    func testRestorationCanOnlyHappenOnce() throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("original", forType: .string)
        let transaction = try XCTUnwrap(ClipboardTransaction.begin(text: "dictation", on: board))
        transaction.restoreIfUnchanged()
        let restoredCount = board.changeCount
        transaction.restoreIfUnchanged()
        XCTAssertEqual(board.changeCount, restoredCount)
        XCTAssertFalse(transaction.stillOwnsClipboard)
    }
}
