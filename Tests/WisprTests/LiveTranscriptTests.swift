import XCTest
@testable import Wispr

final class LiveTranscriptTests: XCTestCase {
    private func texts(_ t: LiveTranscript) -> [String] { t.words.map(\.text) }

    func testAppendedWordsKeepIdentityAndSettle() {
        var t = LiveTranscript()
        t.ingest("I would not")
        let ids = t.words.map(\.id)
        XCTAssertTrue(t.words.allSatisfy { !$0.settled })

        t.ingest("I would not want this")
        XCTAssertEqual(texts(t), ["I", "would", "not", "want", "this"])
        XCTAssertEqual(Array(t.words.prefix(3).map(\.id)), ids)
        XCTAssertTrue(t.words.prefix(3).allSatisfy(\.settled))
        XCTAssertTrue(t.words.suffix(2).allSatisfy { !$0.settled && !$0.revised })
    }

    func testRevisedWordIsMarkedAndStaggerIsCapped() {
        var t = LiveTranscript()
        t.ingest("create or two")
        t.ingest("create or to add some processing lag and all")
        XCTAssertTrue(t.words[2].revised, "two → to is a revision")
        XCTAssertFalse(t.words[3].revised, "add is a plain arrival")
        XCTAssertEqual(t.words[2].delay, 0)
        XCTAssertEqual(t.words.last!.delay, LiveTranscript.staggerCap)
    }

    func testSlidingWindowKeepsHistoryAndDropsHeadFragment() {
        var t = LiveTranscript()
        t.ingest("so I wonder if there are ways")
        let keptID = t.words[3].id                     // "if"
        t.ingest("der if there are ways to make")      // window slid; head is a fragment
        XCTAssertEqual(texts(t), ["so", "I", "wonder", "if", "there", "are", "ways", "to", "make"])
        XCTAssertEqual(t.words[3].id, keptID)
        XCTAssertFalse(t.words.contains { $0.revised })
    }

    func testSilentPunctuationPassKeepsTheLine() {
        var t = LiveTranscript()
        t.ingest("hey this is good")
        t.ingest("hey this is good")
        let before = t
        t.ingest(".")
        XCTAssertEqual(t, before)
    }

    func testWindowPastAPauseAppendsAfterConfirmedWords() {
        var t = LiveTranscript()
        t.ingest("first thought here")
        t.ingest("first thought here")
        t.ingest("completely new sentence")
        XCTAssertEqual(texts(t), ["first", "thought", "here", "completely", "new", "sentence"])
    }

    func testUnconfirmedFirstGuessIsReplacedNotAppended() {
        var t = LiveTranscript()
        t.ingest("Hey")
        t.ingest("Hi there")
        XCTAssertEqual(texts(t), ["Hi", "there"])
        XCTAssertTrue(t.words[0].revised)
    }

    func testCommonWordAlignsWithMostRecentOccurrence() {
        var t = LiveTranscript()
        t.ingest("the cat sat on the mat")
        t.ingest("the cat sat on the mat")
        t.ingest("the mat was red")
        XCTAssertEqual(texts(t), ["the", "cat", "sat", "on", "the", "mat", "was", "red"])
    }

    func testPunctuationAndCaseChangesKeepTheWord() {
        var t = LiveTranscript()
        t.ingest("hey this is good")
        let id = t.words[0].id
        t.ingest("Hey, this is good.")
        XCTAssertEqual(t.words[0].id, id)
        XCTAssertEqual(t.words[0].text, "Hey,")
        XCTAssertTrue(t.words.allSatisfy(\.settled))
    }

    func testIdenticalPassDoesNotBumpVersionTwiceAndEmptyResets() {
        var t = LiveTranscript()
        t.ingest("hello there")
        t.ingest("hello there")
        let v = t.version
        t.ingest("hello there")                         // already settled; no change
        XCTAssertEqual(t.version, v, "an idle pass must not re-render the bar")
        t.ingest("")
        XCTAssertTrue(t.words.isEmpty)
    }

    @MainActor
    func testModelKeepsLiveWordsInStepWithPartialText() {
        let model = AppModel(preview: true)
        model.partialText = "one two"
        model.partialText = "one two three"
        XCTAssertEqual(model.live.words.map(\.text), ["one", "two", "three"])
        model.partialText = ""
        XCTAssertTrue(model.live.words.isEmpty)
    }
}
