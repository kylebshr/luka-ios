//
//  MultiAccountReadingWidgetView.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import Defaults
import Dexcom
import SwiftUI
import WidgetKit

#if os(iOS)
/// A reading widget showing several accounts: a tile per account on the Home
/// Screen, a row per account on the Lock Screen.
struct MultiAccountReadingWidgetView: View {
    let entry: ReadingTimelineProvider.Entry

    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetContentMargins) private var margins

    /// Gap between tiles, and between the tiles and the widget's edge.
    private let tileSpacing: CGFloat = .spacing3

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                ForEach(entry.accounts.indices, id: \.self) { index in
                    AccountReadingRow(entry: entry.account(at: index))
                        .frame(maxHeight: .infinity)
                }
            }
            .containerBackground(.background, for: .widget)
        default:
            // The tiles are drawn in the container background, which always fills
            // the widget, so they can sit closer to the edge than the content
            // margins allow; pulling the content out with negative padding
            // overflowed on a real Home Screen. The content is spaced so each
            // account sits the same distance inside its own tile on every side.
            cells(
                horizontalSpacing: margins.leading + margins.trailing - tileSpacing,
                verticalSpacing: margins.top + margins.bottom - tileSpacing
            ) { index in
                AccountReadingTile(entry: entry.account(at: index))
            }
            .containerBackground(for: .widget) {
                cells(horizontalSpacing: tileSpacing, verticalSpacing: tileSpacing) { index in
                    AccountReadingTileBackground(entry: entry.account(at: index))
                }
                .padding(tileSpacing)
                .background(.background)
            }
        }
    }

    /// One equal cell per account: side by side on medium, stacked on small and
    /// large, and a 2x2 grid for four.
    @ViewBuilder private func cells<Cell: View>(
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat,
        @ViewBuilder cell: @escaping (Int) -> Cell
    ) -> some View {
        let indices = Array(entry.accounts.indices)

        if family == .systemLarge && indices.count > 3 {
            VStack(spacing: verticalSpacing) {
                ForEach(Array(stride(from: 0, to: indices.count, by: 2)), id: \.self) { start in
                    HStack(spacing: horizontalSpacing) {
                        ForEach(indices[start..<min(start + 2, indices.count)], id: \.self) { index in
                            cell(index).frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        } else if family == .systemLarge || family == .systemSmall {
            VStack(spacing: verticalSpacing) {
                ForEach(indices, id: \.self) { index in
                    cell(index).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        } else {
            HStack(spacing: horizontalSpacing) {
                ForEach(indices, id: \.self) { index in
                    cell(index).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

/// The tile behind one account: its reading's colour, or neutral when there is
/// no reading to show.
private struct AccountReadingTileBackground: View {
    let entry: ReadingTimelineProvider.Entry

    @Default(.targetRangeLowerBound) private var targetLower
    @Default(.targetRangeUpperBound) private var targetUpper

    var body: some View {
        if case .reading(let reading) = entry.state {
            ContainerRelativeShape().fill(reading.color(target: targetLower...targetUpper).gradient)
        } else {
            ContainerRelativeShape().fill(.fill.tertiary)
        }
    }
}

/// One account's tile: the single-account widget in miniature, plus the
/// account's name.
private struct AccountReadingTile: View {
    let entry: ReadingTimelineProvider.Entry

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.widgetURL == nil {
                Button(intent: ReloadWidgetIntent()) {
                    content
                }
            } else {
                content
            }
        }
        .buttonStyle(.plain)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let name = entry.accountName {
                Text(verbatim: name)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .unredacted()
            }

            Spacer(minLength: 0)

            switch entry.state {
            case .reading(let reading):
                readingContent(reading)
                    .redacted(reason: entry.isExpired ? .placeholder : [])
            case .error(let error):
                errorContent(error)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(foreground)
    }

    private func readingContent(_ reading: GlucoseReading) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ReadingView(reading: reading)
                .font(.system(family == .systemSmall ? .title : .largeTitle, design: .rounded))
                .invalidatableContent()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .widgetAccentable()

            WidgetButtonContent(
                text: reading.timestamp(for: entry.date, style: family == .systemSmall ? .abbreviated : .short),
                image: entry.shouldRefresh ? "arrow.triangle.2.circlepath" : nil
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(.secondary)
        }
    }

    private func errorContent(_ error: GlucoseEntryError) -> some View {
        VStack(alignment: .leading, spacing: .spacing1) {
            Image(systemName: error.image)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
            Text(error.description)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.secondary)
    }

    /// Black on the reading's colour, which is only there when the system
    /// shows the container background (not in tinted mode or StandBy).
    private var foreground: Color {
        if case .reading = entry.state, renderingMode == .fullColor, showsBackground {
            .black
        } else {
            .primary
        }
    }
}

/// One account's line on the Lock Screen: reading and trend, then name and age.
private struct AccountReadingRow: View {
    let entry: ReadingTimelineProvider.Entry

    var body: some View {
        Group {
            if entry.widgetURL == nil {
                Button(intent: ReloadWidgetIntent()) {
                    content
                }
            } else {
                content
            }
        }
        .buttonStyle(.plain)
        .font(.system(.headline, design: .rounded))
    }

    private var content: some View {
        HStack(spacing: .spacing3) {
            switch entry.state {
            case .reading(let reading):
                ReadingView(reading: reading)
                    .fontWeight(.semibold)
                    .invalidatableContent()
                    .layoutPriority(1)
                    .redacted(reason: entry.isExpired ? .placeholder : [])
            case .error(let error):
                Image(systemName: error.image)
                    .fontWeight(.semibold)
                    .invalidatableContent()
            }

            Spacer(minLength: 0)

            Text(caption)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var caption: String {
        let name = entry.accountName ?? ""
        switch entry.state {
        case .reading(let reading):
            let age = reading.timestamp(for: entry.date, style: .abbreviated, appendRelativeText: false)
            return "\(name) · \(age)"
        case .error:
            return name
        }
    }
}
#endif
