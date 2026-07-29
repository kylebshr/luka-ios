//
//  DeltaView.swift
//  Luka
//
//  Created by Kyle Bashour on 07/29/26.
//

import Dexcom
import Defaults
import SwiftUI

/// The trend arrow and the change since the previous reading — e.g. "↗ +5" —
/// knocked out of a capsule tinted with the reading's color.
///
/// The view sizes itself entirely from the inherited font: it measures its own
/// text and derives the capsule's margins from that height, so it stays
/// proportional at any font size or Dynamic Type setting. Callers only need to
/// set `.font(_:)`; the weight and design are applied here so the pill looks the
/// same everywhere it's used.
struct DeltaView: View {
    /// The trend to draw an arrow for. No arrow is drawn when this is nil or
    /// when the trend has no meaningful direction.
    var trend: TrendDirection?

    /// The change since the previous reading, in mg/dL. Hidden when nil.
    var delta: Int?

    /// The capsule's fill, normally derived from the reading's target range.
    var color: Color

    @Default(.unit) private var unit

    /// Height of the unpadded content, used to keep the capsule's margins
    /// proportional to the font the view is rendered with.
    @State private var contentHeight: CGFloat = 0

    private var image: Image? {
        trend?.image
    }

    var body: some View {
        if image != nil || delta != nil {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 0) {
            if let image {
                image
                    .id(trend)
                    .transition(.blurReplace)
                    .fontWeight(.semibold)
            }

            if let delta {
                Text(verbatim: image == nil ? text(for: delta) : " " + text(for: delta))
                    .contentTransition(.numericText(value: Double(delta)))
            }
        }
        .imageScale(.small)
        .drawingGroup()
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .padding(.horizontal, contentHeight * Self.horizontalPaddingRatio)
        .padding(.vertical, contentHeight * Self.verticalPaddingRatio)
        // The text punches through the capsule rather than sitting on top of it,
        // so the pill reads as a single tinted shape over any background. The
        // compositing group keeps the knockout from punching through whatever is
        // drawn behind the pill.
        .blendMode(.destinationOut)
        .background { Capsule().fill(color.gradient) }
        .compositingGroup()
    }

    private func text(for delta: Int) -> String {
        let sign = delta < 0 ? "-" : "+"
        return sign + abs(delta).formatted(.glucose(unit, usesOutOfRangeText: false))
    }

    /// Margins as a fraction of the content's height, tuned so the capsule hugs
    /// the text the same way at every font size.
    private static let horizontalPaddingRatio: CGFloat = 0.3
    private static let verticalPaddingRatio: CGFloat = 0.1
}

#Preview {
    VStack(spacing: .spacing8) {
        DeltaView(trend: .fortyFiveUp, delta: 5, color: .inRangeColor)
            .font(.footnote)

        DeltaView(trend: .doubleDown, delta: -12, color: .lowColor)
            .font(.title3)

        DeltaView(trend: .flat, delta: 0, color: .highColor)
            .font(.largeTitle)

        DeltaView(trend: TrendDirection.none, delta: 5, color: .inRangeColor)
            .font(.title3)

        DeltaView(trend: .singleUp, delta: nil, color: .inRangeColor)
            .font(.title3)
    }
    .padding()
    .background(.black)
}
