import XCTest
import SwiftUI
import AppKit
import CoreText
@testable import Wispr

/// Opt-in renders of real SwiftUI views. All displayed data is fictional.
/// No microphone, hotkey monitor, model load, or user history is involved.
final class ScreenshotTests: XCTestCase {
    @MainActor
    func testRenderPublicScreenshots() throws {
        guard let destination = ProcessInfo.processInfo.environment["WISPR_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set WISPR_SCREENSHOT_DIR to render the public screenshot assets.")
        }
        let output = URL(fileURLWithPath: destination, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        for font in try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Resources/Fonts"), includingPropertiesForKeys: nil)
            where font.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(font as CFURL, .process, nil)
        }
        _ = NSApplication.shared
        let model = AppModel(preview: true)
        model.hasOnboarded = true
        model.accessibilityGranted = true
        model.micGranted = true
        model.modelReady = true
        model.state = .idle
        model.history = [
            Dictation(text: "Let's keep the first version simple. One shortcut, a clear interface, and everything running on your Mac.", date: Date().addingTimeInterval(-300), duration: 11, appName: "Notes"),
            Dictation(text: "Hey team, the prototype is ready for a look. I left a few notes on the interaction and keyboard shortcuts.", date: Date().addingTimeInterval(-1800), duration: 13, appName: "Mail"),
            Dictation(text: "A small idea for tomorrow: spend less time typing and more time making things.", date: Date().addingTimeInterval(-3600), duration: 9, appName: "Notes")
        ]
        model.vocab = [
            VocabEntry(spoken: "whisper kit", written: "WhisperKit"),
            VocabEntry(spoken: "swift you eye", written: "SwiftUI"),
            VocabEntry(spoken: "just whisper", written: "justwisper")
        ]
        model.snippets = [
            SnippetEntry(trigger: "my sign off", expansion: "Thanks for taking a look.\nTalk soon!"),
            SnippetEntry(trigger: "quick update", expansion: "A quick update:\n\nWhat changed:\nWhat's next:")
        ]
        for (screen, name) in [(Screen.home, "home"), (.dictionary, "dictionary"), (.snippets, "snippets"), (.history, "history"), (.insights, "insights"), (.settings, "settings")] {
            model.nav = screen
            try render(ContentView(model: model), size: NSSize(width: 1120, height: 740),
                       to: output.appendingPathComponent("\(name).png"))
        }
        model.state = .recording
        model.elapsed = 7
        model.partialText = "More time making things."
        model.levels = (0..<AppModel.waveformBars).map { Float(0.12 + abs(sin(Double($0) * 0.67)) * 0.7) }
        model.level = 0.65
        for style in FlowBarStyle.allCases {
            model.flowStyle = style
            let size = style.contentSize
            try render(FlowBar(model: model), size: NSSize(width: size.width + 60, height: size.height + 60),
                       to: output.appendingPathComponent("overlay-\(style.rawValue).png"))
        }
    }

    @MainActor
    private func render<V: View>(_ view: V, size: NSSize, to destination: URL) throws {
        let host = NSHostingView(rootView: view
            .environment(\.colorScheme, .light)
            .environment(\.displayScale, 4)
            .frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        window.orderBack(nil)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        // SwiftUI caches glyphs in drawing layers at the window's screen
        // scale. Refresh only those layers at export resolution. Image layers
        // (including SF Symbols) must retain their source contents.
        func setCaptureScale(_ layer: CALayer) {
            if String(describing: type(of: layer)) == "CGDrawingLayer" {
                layer.contentsScale = 4
                layer.setNeedsDisplay()
            }
            for child in layer.sublayers ?? [] { setCaptureScale(child) }
        }
        if let layer = host.layer { setCaptureScale(layer) }
        host.displayIfNeeded()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * 4), pixelsHigh: Int(size.height * 4),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        bitmap.size = size
        host.cacheDisplay(in: host.bounds, to: bitmap)
        XCTAssertEqual(bitmap.pixelsWide, Int(size.width * 4))
        XCTAssertEqual(bitmap.pixelsHigh, Int(size.height * 4))
        let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: destination)
        window.orderOut(nil)
        window.close()
    }
}
