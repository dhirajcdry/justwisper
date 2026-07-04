import AppKit

/// Custom-drawn menu bar icons: the Wispr waveform mark, in four states.
/// Template images tint with the menu bar (dark/light, active/inactive) like
/// native macOS status items; only the recording state carries color.
enum StatusIcon {
    /// The mark: five capsules rising and falling, like a held take.
    private static let waveHeights: [CGFloat] = [5.5, 10.5, 15, 9, 5.5]
    private static let canvas = NSSize(width: 21, height: 16)
    private static let vermillion = NSColor(srgbRed: 0.898, green: 0.251, blue: 0.106, alpha: 1)

    /// Ready — full mark, tints with the menu bar.
    static let idle: NSImage = bars()

    /// Loading / transcribing / polishing — the mark at half strength.
    static let busy: NSImage = bars(alpha: 0.42)

    /// Recording — the mark goes hot vermillion (deliberately not template).
    static let recording: NSImage = bars(color: vermillion, template: false,
                                         heights: [7, 12, 16, 11, 7])

    /// Something needs attention — dimmed mark with a full-strength ! where
    /// the last bar would be. Template, so it stays native-looking.
    static let alert: NSImage = {
        let image = NSImage(size: canvas, flipped: false) { rect in
            drawBars(in: rect, color: .black, alpha: 0.35,
                     heights: Array(waveHeights.prefix(4)), count: 5)
            // Exclamation in the fifth slot: stem + dot.
            let barW: CGFloat = 2.8
            let x = slotX(4, in: rect, barW: barW)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: rect.height - 11.5, width: barW, height: 8),
                         xRadius: barW / 2, yRadius: barW / 2).fill()
            NSBezierPath(ovalIn: NSRect(x: x, y: rect.height - 15.3, width: barW, height: barW)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()

    // MARK: - Drawing

    private static func bars(color: NSColor = .black, alpha: CGFloat = 1,
                             template: Bool = true, heights: [CGFloat]? = nil) -> NSImage {
        let h = heights ?? waveHeights
        let image = NSImage(size: canvas, flipped: false) { rect in
            drawBars(in: rect, color: color, alpha: alpha, heights: h, count: h.count)
            return true
        }
        image.isTemplate = template
        return image
    }

    private static func drawBars(in rect: NSRect, color: NSColor, alpha: CGFloat,
                                 heights: [CGFloat], count: Int) {
        color.withAlphaComponent(alpha).setFill()
        let barW: CGFloat = 2.8
        for (i, h) in heights.enumerated() {
            let x = slotX(i, in: rect, barW: barW, count: count)
            let y = (rect.height - h) / 2
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barW, height: h),
                         xRadius: barW / 2, yRadius: barW / 2).fill()
        }
    }

    /// X-origin of bar `i` with the five slots spread evenly across the canvas.
    private static func slotX(_ i: Int, in rect: NSRect, barW: CGFloat, count: Int = 5) -> CGFloat {
        let gap = (rect.width - barW * CGFloat(count)) / CGFloat(count - 1)
        return CGFloat(i) * (barW + gap)
    }
}
