//
//  ReadingSummaryView.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import Defaults
import Dexcom
import SwiftUI

extension LiveViewModel {
    var readings: [GlucoseReading] {
        if case .loaded(let readings, _) = state {
            readings
        } else {
            []
        }
    }

    /// Whether the latest reading is missing or too old to show as current.
    var isStale: Bool {
        switch state {
        case .initial, .noRecentReading, .error:
            true
        case .loaded(_, let latest):
            latest.isExpired(at: .now)
        }
    }
}

extension [GlucoseReading] {
    /// Change from the reading before `reading`, in mg/dL. Nil when there's no
    /// preceding reading, or when the gap between them is too large (a sensor
    /// dropout) for the difference to be meaningful.
    func delta(at reading: GlucoseReading) -> Int? {
        guard let previous = last(where: { $0.date < reading.date }),
              reading.date.timeIntervalSince(previous.date) <= 15 * 60
        else { return nil }
        return reading.value - previous.value
    }
}

/// The reading, its trend and delta pill, and a status line beneath — the
/// header of both the account detail screen and the account cards.
struct ReadingSummaryView: View {
    var reading: GlucoseReading?
    var delta: Int?
    var subtitle: String
    var isRedacted: Bool
    /// Off while scrubbing, so the value tracks the finger without lag.
    var animatesChanges = true
    var readingFont: Font = .largeTitle.weight(.semibold)
    var deltaFont: Font = .title2

    @Default(.targetRangeLowerBound) private var lowerTargetRange
    @Default(.targetRangeUpperBound) private var upperTargetRange
    @Default(.unit) private var unit

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                // The reading hides its inline arrow so the trend only appears
                // once — inside the pill.
                ReadingView(reading: reading, showsTrendArrow: false)
                    .font(readingFont)
                    .id(reading != nil)

                if let reading, !isRedacted {
                    DeltaView(
                        trend: reading.trend,
                        delta: delta,
                        color: reading.vividColor(target: lowerTargetRange...upperTargetRange)
                    )
                    .font(deltaFont)
                    .fontWeight(.medium)
                }
            }

            let unit = isRedacted ? "" : "\(unit.text) • "

            Text("\(unit)\(subtitle)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .animation(animatesChanges ? .default : nil, value: reading)
    }
}
