import SwiftUI

/// Printed-spectrogram waveform: thin vertical bars, newest sample on the right,
/// mirrored around the vertical center. Driven by a rolling 0...1 level buffer.
struct WaveformView: View {
    var levels: [Float]
    var color: Color
    var barWidth: CGFloat = 2.5
    var minBar: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let count = max(levels.count, 1)
            let gap = max(1.5, (geo.size.width - barWidth * CGFloat(count)) / CGFloat(count))
            HStack(alignment: .center, spacing: gap) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, value in
                    Capsule()
                        .fill(color)
                        .frame(width: barWidth, height: height(value, geo.size.height))
                        .animation(.spring(response: 0.24, dampingFraction: 0.7), value: value)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func height(_ value: Float, _ maxHeight: CGFloat) -> CGFloat {
        max(minBar, CGFloat(value) * maxHeight)
    }
}

/// Slow breathing placeholder so the spectrogram is alive when idle.
struct IdleWaveform: View {
    var color: Color
    var barWidth: CGFloat = 2.5

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let levels = (0..<AppModel.waveformBars).map { i -> Float in
                let x = Double(i) / Double(AppModel.waveformBars)
                let wave = sin(t * 1.4 + x * 7) * 0.5 + 0.5
                return Float(0.05 + wave * 0.09)
            }
            WaveformView(levels: levels, color: color, barWidth: barWidth)
        }
    }
}
