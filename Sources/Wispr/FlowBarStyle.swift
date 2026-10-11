import Foundation

/// The look of the floating overlay while dictating — the four takes from the
/// Press design sheet ("Live transcript" 3a–3d). User-selectable in Settings.
enum FlowBarStyle: String, CaseIterable, Identifiable, Codable {
    case galley   // 3a — compact bar, the line sets itself right-to-left
    case column   // 3b — editorial column, words wrap and rise like set type
    case ticker   // 3c — slim dark tape, one mono line
    case caption  // 3d — no chrome at all: just the live words, floating

    var id: String { rawValue }

    /// Reads a saved style, mapping retired ones forward (Proof → Caption).
    init?(stored raw: String) {
        self.init(rawValue: raw == "proof" ? "caption" : raw)
    }

    var label: String {
        switch self {
        case .galley: return "Galley"
        case .column: return "Column"
        case .ticker: return "Ticker"
        case .caption: return "Caption"
        }
    }

    var blurb: String {
        switch self {
        case .galley: return "Compact bar — the line sets itself right-to-left as you talk."
        case .column: return "Editorial column — words wrap and rise like set type."
        case .ticker: return "Menubar tape — one dark line, ultra minimal."
        case .caption: return "Just the words — floating text, nothing else on screen."
        }
    }

    /// Exact size the FlowBar draws at for this style (the overlay panel adds
    /// its transparent shadow margin around this).
    var contentSize: CGSize {
        switch self {
        case .galley: return CGSize(width: 440, height: 44)
        case .column: return CGSize(width: 340, height: 230)
        case .ticker: return CGSize(width: 460, height: 40)
        case .caption: return CGSize(width: 520, height: 40)
        }
    }
}
