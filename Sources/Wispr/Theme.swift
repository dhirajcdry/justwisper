import SwiftUI

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: 1
        )
    }
}

/// "Press" editorial palette — paper, ink & molten vermillion. Ships light + dark.
struct Palette {
    let paper: Color
    let panel: Color
    let ink: Color
    let ink2: Color
    let ink3: Color
    let line: Color
    let sig: Color

    static let light = Palette(
        paper: Color(hex: 0xEFE9DC),
        panel: Color(hex: 0xF5F1E8),
        ink: Color(hex: 0x1A1712),
        ink2: Color(hex: 0x6E6656),
        ink3: Color(hex: 0xA69D89),
        line: Color(hex: 0xD9D1BF),
        sig: Color(hex: 0xE5401B)
    )

    static let dark = Palette(
        paper: Color(hex: 0x15120D),
        panel: Color(hex: 0x1E1A13),
        ink: Color(hex: 0xEFE9DC),
        ink2: Color(hex: 0xA69D89),
        ink3: Color(hex: 0x6E6656),
        line: Color(hex: 0x2E281E),
        sig: Color(hex: 0xFF6A43)
    )

    static func current(_ scheme: ColorScheme) -> Palette {
        scheme == .dark ? .dark : .light
    }
}

/// Bundled type. Hanken Grotesk (display/body) + JetBrains Mono (readouts).
enum F {
    static func extrabold(_ s: CGFloat) -> Font { .custom("HankenGrotesk-Regular_ExtraBold", size: s) }
    static func bold(_ s: CGFloat) -> Font { .custom("HankenGrotesk-Regular_Bold", size: s) }
    static func semibold(_ s: CGFloat) -> Font { .custom("HankenGrotesk-Regular_SemiBold", size: s) }
    static func medium(_ s: CGFloat) -> Font { .custom("HankenGrotesk-Regular_Medium", size: s) }
    static func regular(_ s: CGFloat) -> Font { .custom("HankenGrotesk-Regular", size: s) }

    static func mono(_ s: CGFloat) -> Font { .custom("JetBrainsMono-Regular", size: s) }
    static func monoMed(_ s: CGFloat) -> Font { .custom("JetBrainsMono-Medium", size: s) }
    static func monoSemi(_ s: CGFloat) -> Font { .custom("JetBrainsMono-SemiBold", size: s) }
}
