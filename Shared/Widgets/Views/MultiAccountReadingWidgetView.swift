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
            tiles
                .padding(tileInsets)
                .containerBackground(.background, for: .widget)
        }
    }

    @ViewBuilder private var tiles: some View {
        let indices = Array(entry.accounts.indices)

        if family == .systemLarge && indices.count > 3 {
            Grid(horizontalSpacing: tileSpacing, verticalSpacing: tileSpacing) {
                ForEach(Array(stride(from: 0, to: indices.count, by: 2)), id: \.self) { start in
                    GridRow {
                        ForEach(indices[start..<min(start + 2, indices.count)], id: \.self) { index in
                            tile(at: index)
                        }
                    }
                }
            }
        } else if family == .systemLarge || family == .systemSmall {
            VStack(spacing: tileSpacing) {
                ForEach(indices, id: \.self) { index in
                    tile(at: index)
                }
            }
        } else {
            HStack(spacing: tileSpacing) {
                ForEach(indices, id: \.self) { index in
                    tile(at: index)
                }
            }
        }
    }

    private func tile(at index: Int) -> some View {
        AccountReadingTile(entry: entry.account(at: index))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Tiles sit closer to the edge than the content margins, so their
    /// container-relative corners stay concentric with the widget's.
    private var tileInsets: EdgeInsets {
        EdgeInsets(
            top: tileSpacing - margins.top,
            leading: tileSpacing - margins.leading,
            bottom: tileSpacing - margins.bottom,
            trailing: tileSpacing - margins.trailing
        )
    }
}

/// One account's tile: the single-account widget in miniature, plus the
/// account's name.
private struct AccountReadingTile: View {
    let entry: ReadingTimelineProvider.Entry

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetFamily) private var family

    @Default(.targetRangeLowerBound) private var targetLower
    @Default(.targetRangeUpperBound) private var targetUpper

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
        .padding(.spacing6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(foreground)
        .background(background, in: ContainerRelativeShape())
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

    private var isFullColor: Bool {
        renderingMode == .fullColor
    }

    private var foreground: Color {
        if case .reading = entry.state, isFullColor {
            .black
        } else {
            .primary
        }
    }

    private var background: AnyShapeStyle {
        if case .reading(let reading) = entry.state, isFullColor {
            AnyShapeStyle(reading.color(target: targetLower...targetUpper).gradient)
        } else {
            AnyShapeStyle(.fill.tertiary)
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
