import AppKit

// Renders the Wisper app icon (cream squircle, bold black "w", vermillion dot)
// at 1024×1024, then `iconutil` (see below) builds the .icns.
let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Tile — a rounded square with a little padding, like a macOS app icon.
let pad: CGFloat = 84
let rect = CGRect(x: pad, y: pad, width: S - 2 * pad, height: S - 2 * pad)
let radius: CGFloat = (S - 2 * pad) * 0.235   // continuous-corner feel
let tile = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(tile)
ctx.setFillColor(NSColor(srgbRed: 0.929, green: 0.909, blue: 0.847, alpha: 1).cgColor) // cream paper
ctx.fillPath()

// Bold lowercase "w", optically centered.
let w = "w" as NSString
let font = NSFont.systemFont(ofSize: 560, weight: .heavy)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(srgbRed: 0.10, green: 0.09, blue: 0.07, alpha: 1) // near-black ink
]
let ws = w.size(withAttributes: attrs)
w.draw(at: NSPoint(x: rect.midX - ws.width / 2, y: rect.midY - ws.height / 2 - 6), withAttributes: attrs)

// Vermillion dot, top-right.
let dotR: CGFloat = 66
let cx = rect.maxX - 150
let cy = rect.maxY - 150
ctx.setFillColor(NSColor(srgbRed: 0.898, green: 0.251, blue: 0.106, alpha: 1).cgColor) // vermillion
ctx.fillEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2))

img.unlockFocus()

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"))
