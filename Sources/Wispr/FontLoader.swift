import AppKit
import CoreText

/// Registers the bundled Hanken Grotesk + JetBrains Mono fonts at launch so
/// Font.custom(...) can resolve them by PostScript name.
enum FontLoader {
    static func register() {
        guard let resourceURL = Bundle.main.resourceURL else { return }
        let fontsDir = resourceURL.appendingPathComponent("Fonts")
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil) else { return }
        for url in items where ["ttf", "otf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
