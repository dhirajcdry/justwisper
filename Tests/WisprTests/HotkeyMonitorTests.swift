import XCTest
import AppKit
@testable import Wispr

final class HotkeyMonitorTests: XCTestCase {
    func testResetWhileDownIgnoresFollowingRelease() {
        let monitor = HotkeyMonitor()
        var starts = 0
        monitor.onStart = { starts += 1 }
        send(monitor, 10, true)
        drain()
        monitor.reset()
        send(monitor, 10.1, false)
        drain()
        XCTAssertEqual(starts, 1)
    }

    func testHoldUsesEventTimeEvenWhenCallbacksArriveTogether() {
        let monitor = HotkeyMonitor()
        var stops = 0
        monitor.onStop = { stops += 1 }
        send(monitor, 1, true)
        send(monitor, 1.5, false)
        drain()
        XCTAssertEqual(stops, 1)
    }

    func testDoubleTapLatchesAndCancelsPendingStop() {
        let monitor = HotkeyMonitor()
        var latch = false
        var stops = 0
        monitor.onHandsFreeChange = { latch = $0 }
        monitor.onStop = { stops += 1 }
        send(monitor, 1, true)
        send(monitor, 1.05, false)
        send(monitor, 1.3, true)
        send(monitor, 1.35, false)
        drain(0.5)
        XCTAssertTrue(latch)
        XCTAssertEqual(stops, 0)
    }

    func testLeftOptionHeldDoesNotHideRightRelease() {
        let monitor = HotkeyMonitor()
        var stops = 0
        monitor.onStop = { stops += 1 }
        send(monitor, 1, true, left: true)
        send(monitor, 1.5, false, left: true)
        drain()
        XCTAssertEqual(stops, 1)
    }

    func testLateSecondPressContinuesTakeWithoutLatchingOrRestarting() {
        let monitor = HotkeyMonitor()
        var starts = 0
        var stops = 0
        var latch = false
        monitor.onStart = { starts += 1 }
        monitor.onStop = { stops += 1 }
        monitor.onHandsFreeChange = { latch = $0 }
        send(monitor, 1, true)
        send(monitor, 1.1, false)
        // Simulate a delayed timer while events with a long physical gap queue up.
        send(monitor, 2, true)
        send(monitor, 2.05, false)
        drain()
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(stops, 0) // second press was a tap, not a one-second hold
        XCTAssertFalse(latch)
        drain(0.5)
        XCTAssertEqual(stops, 1)
    }

    func testStopTapResetDoesNotRestartOnRelease() {
        let monitor = HotkeyMonitor()
        var starts = 0
        var stops = 0
        monitor.onStart = { starts += 1 }
        monitor.onStop = {
            stops += 1
            monitor.reset() // AppModel does this synchronously when stopping.
        }
        send(monitor, 1, true)
        send(monitor, 1.05, false)
        send(monitor, 1.2, true)
        send(monitor, 1.25, false)
        drain()
        send(monitor, 2, true)
        drain()
        send(monitor, 2.1, false)
        drain()
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(stops, 1)
        monitor.onStop = {} // release the test closure's capture
    }

    func testDuplicateDownDoesNotResetHoldDuration() {
        let monitor = HotkeyMonitor()
        var starts = 0
        var stops = 0
        monitor.onStart = { starts += 1 }
        monitor.onStop = { stops += 1 }
        send(monitor, 1, true)
        send(monitor, 1, true)
        send(monitor, 1.4, true)
        send(monitor, 1.5, false)
        drain()
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(stops, 1)
    }

    private func drain(_ seconds: TimeInterval = 0.03) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func send(_ monitor: HotkeyMonitor, _ timestamp: TimeInterval,
                      _ right: Bool, left: Bool = false) {
        var flags: UInt = right ? 0x40 : 0 // NX_DEVICERALTKEYMASK
        if left { flags |= 0x20 } // NX_DEVICELALTKEYMASK
        if left || right { flags |= NSEvent.ModifierFlags.option.rawValue }
        let event = NSEvent.keyEvent(with: .flagsChanged, location: .zero,
                                    modifierFlags: .init(rawValue: flags),
                                    timestamp: timestamp, windowNumber: 0,
                                    context: nil, characters: "", charactersIgnoringModifiers: "",
                                    isARepeat: false, keyCode: 61)!
        monitor.handleForTesting(event)
    }
}
