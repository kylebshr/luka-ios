//
//  MultiAccountGraphWidgetView.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import Dexcom
import SwiftUI
import WidgetKit

#if os(iOS)
/// A graph widget showing several accounts: side by side on a medium widget,
/// stacked on a large one, each with its own reading and graph.
struct MultiAccountGraphWidgetView: View {
    let entry: GraphTimelineProvider.Entry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemMedium {
                HStack(spacing: .spacing8) {
                    cells
                }
            } else {
                VStack(spacing: .spacing6) {
                    cells
                }
            }
        }
        .widgetURL(entry.widgetURL)
        .containerBackground(.background, for: .widget)
    }

    private var cells: some View {
        ForEach(entry.accounts.indices, id: \.self) { index in
            AccountGraphCell(entry: entry.account(at: index))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct AccountGraphCell: View {
    let entry: GraphTimelineProvider.Entry

    @Environment(\.widgetFamily) private var family

    private var font: Font {
        .system(.subheadline, design: .rounded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing1) {
            Button(intent: ReloadWidgetIntent()) {
                header
            }
            .buttonStyle(.plain)

            switch entry.state {
            case .reading(let data):
                LineChart(
                    range: data.configuration.graphRange,
                    style: data.configuration.graphStyle,
                    readings: data.history.toLiveActivityReadings(),
                    yRangeMode: .fit
                )
                // The line runs past the start of the range; keep it out of the
                // neighboring cell, but leave room for the current-reading dot.
                .mask(Rectangle().padding(.vertical, -.spacing4).padding(.trailing, -.spacing4))
                .redacted(reason: entry.isExpired ? .placeholder : [])
            case .error(let error):
                Button(intent: ReloadWidgetIntent()) {
                    Label(error.description, systemImage: error.image)
                        .font(font)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.fill.quaternary, in: .rect(cornerRadius: .smallCornerRadius))
                        .invalidatableContent()
                }
                .buttonStyle(.plain)
            }
        }
        .font(font)
    }

    private var header: some View {
        HStack(spacing: .spacing3) {
            if case .reading(let data) = entry.state {
                ReadingView(reading: data.current)
                    .fontWeight(.semibold)
                    .invalidatableContent()
                    .layoutPriority(1)
                    .redacted(reason: entry.isExpired ? .placeholder : [])
            }

            HStack(spacing: .spacing1) {
                if let name = entry.accountName {
                    Text(verbatim: name)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if case .reading(let data) = entry.state {
                    if entry.shouldRefresh {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .imageScale(.small)
                    } else {
                        Text(data.current.timestamp(for: entry.date, style: .abbreviated, appendRelativeText: false))
                            .lineLimit(1)
                            .contentTransition(.numericText())
                    }
                }
            }
            .foregroundStyle(.secondary)
            .fontWeight(.medium)
        }
    }
}
#endif
