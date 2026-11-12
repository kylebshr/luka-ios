//
//  AccountCard.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import Defaults
import Dexcom
import SwiftUI

/// A compact summary of one account in the account list: its name, current
/// reading and a sparkline of the selected graph range.
struct AccountCard: View {
    var name: String
    var liveViewModel: LiveViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Default(.selectedRange) private var range
    @Default(.appGraphStyle) private var graphStyle

    private var readings: [GlucoseReading] {
        liveViewModel.readings
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: .spacing6))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: .spacing8))

        VStack(alignment: .leading, spacing: .spacing4) {
            HStack(spacing: .spacing4) {
                Text(name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            layout {
                ReadingSummaryView(
                    reading: readings.last,
                    delta: readings.last.flatMap { readings.delta(at: $0) },
                    subtitle: liveViewModel.message,
                    isRedacted: liveViewModel.isStale,
                    readingFont: .largeTitle.weight(.semibold),
                    deltaFont: .title3
                )
                .layoutPriority(1)

                sparkline
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .padding(.bottom, .spacing1)
            }
        }
        .contentShape(.rect)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the full graph")
    }

    @ViewBuilder private var sparkline: some View {
        if readings.isEmpty {
            LineChart(range: range, style: .line, readings: .placeholder)
                .redacted(reason: .placeholder)
                .opacity(0.3)
                .accessibilityHidden(true)
        } else {
            LineChart(
                range: range,
                style: graphStyle,
                readings: readings.toLiveActivityReadings(),
                lineWidth: graphStyle == .line ? 2.5 : 1.5
            )
            .opacity(liveViewModel.isStale ? 0.5 : 1)
            .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var model = PreviewAccounts.liveViewModel(name: "Alex")

    VStack {
        AccountCard(name: "Alex", liveViewModel: model)
        Spacer()
    }
    .padding()
    .fontDesign(.rounded)
}
#endif
