//
//  WatchWidget.swift
//  WatchWidget
//
//  Created by Kyle Bashour on 4/23/24.
//

import WidgetKit
import SwiftUI
import Dexcom
import KeychainAccess

struct Provider: AppIntentTimelineProvider {
    class Delegate: DexcomClientDelegate {
        func didUpdateAccountID(_ accountID: UUID) {
            UserDefaults.shared.accountID = accountID
        }

        func didUpdateSessionID(_ sessionID: UUID) {
            UserDefaults.shared.sessionID = sessionID
        }
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), state: .reading(.placeholder))
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let state = await makeState(outsideUS: configuration.outsideUS)
        return SimpleEntry(date: Date(), state: state)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let state = await makeState(outsideUS: configuration.outsideUS)
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!

        switch state {
        case .loggedOut, .expired:
            return Timeline(entries: [SimpleEntry(date: .now, state: state)], policy: .after(refreshDate))
        case .reading(let glucoseReading):
            if let glucoseReading {
                let entries = (1...15).map {
                    let date = Calendar.current.date(byAdding: .minute, value: $0, to: currentDate)!
                    return SimpleEntry(date: date, state: .reading(glucoseReading))
                }

                let expired = SimpleEntry(
                    date: Calendar.current.date(byAdding: .minute, value: 20, to: currentDate)!,
                    state: .expired
                )

                return Timeline(entries: entries + [expired], policy: .after(refreshDate))
            } else {
                return Timeline(entries: [SimpleEntry(date: .now, state: state)], policy: .after(refreshDate))
            }
        }
    }

    func recommendations() -> [AppIntentRecommendation<ConfigurationAppIntent>] {
        let outsideUS = ConfigurationAppIntent()
        outsideUS.outsideUS = true

        return [
            AppIntentRecommendation(intent: ConfigurationAppIntent(), description: "Inside US"),
            AppIntentRecommendation(intent: outsideUS, description: "Outside US"),
        ]
    }

    func makeState(outsideUS: Bool) async -> SimpleEntry.State {
        guard let username = UserDefaults.shared.username, let password = UserDefaults.shared.password else {
            return .loggedOut
        }

        let client = DexcomClient(
            username: username,
            password: password,
            existingAccountID: UserDefaults.shared.accountID,
            existingSessionID: UserDefaults.shared.sessionID,
            outsideUS: outsideUS
        )

        do {
            return try await .reading(client.getCurrentGlucoseReading())
        } catch {
            return .reading(nil)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    enum State {
        case loggedOut
        case expired
        case reading(GlucoseReading?)
    }

    let date: Date
    let state: State
}

struct WatchWidgetEntryView : View {
    var entry: Provider.Entry

    private var formatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        return formatter
    }

    var body: some View {
        switch entry.state {
        case .reading(let reading):
            if let reading {
                readingView(reading: reading)
            } else {
                imageView(systemName: "icloud.slash")
            }
        case .loggedOut:
            imageView(systemName: "person.slash")
        case .expired:
            imageView(systemName: "exclamationmark.arrow.circlepath")
        }
    }

    private func imageView(systemName: String) -> some View {
        ZStack {
            Circle().fill(.fill.secondary)
            Image(systemName: systemName)
                .font(.title3)
                .fontDesign(.rounded)
                .fontWeight(.semibold)
        }
    }

    private func readingView(reading: GlucoseReading) -> some View {
        Gauge(
            value: 0,
            label: {},
            currentValueLabel: {
                VStack(spacing: -4) {
                    Text("\(reading.value)")
                        .minimumScaleFactor(0.8)
                    Text(timestamp(for: reading.date))
                        .foregroundStyle(.secondary)
                }
                .padding(-2)
            }
        )
        .gaugeStyle(.accessoryCircularCapacity)
        .overlay {
            if let rotationDegrees = rotationDegrees(for: reading.trend) {
                arrow(degrees: rotationDegrees)

                switch reading.trend {
                case .doubleUp, .doubleDown:
                    arrow(degrees: rotationDegrees)
                        .padding(3)
                default:
                    EmptyView()
                }
            }
        }
    }

    private func rotationDegrees(for trend: TrendDirection) -> Double? {
        switch trend {
        case .none, .notComputable, .rateOutOfRange:
            nil
        case .doubleUp, .singleUp:
            0
        case .fortyFiveUp:
            45
        case .flat:
            90
        case .fortyFiveDown:
            135
        case .singleDown, .doubleDown:
            180
        }
    }

    private func arrow(degrees: Double) -> some View {
        Rectangle()
            .fill(.clear)
            .overlay(alignment: .top) {
                Image(systemName: "chevron.compact.up")
                    .font(.system(size: 13))
                    .fontWeight(.bold)
            }
            .rotationEffect(.degrees(degrees))
    }

    private func timestamp(for date: Date) -> String {
        if entry.date.timeIntervalSince(date) < 60 {
            return "now"
        } else {
            return formatter.string(from: date, to: entry.date)!
        }
    }
}

@main
struct WatchWidget: Widget {
    let kind: String = "WatchWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            WatchWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.accessoryCircular])
    }
}

extension GlucoseReading {
    static let placeholder = GlucoseReading(value: 104, trend: .flat, date: .now)
}

#Preview(as: .accessoryCircular) {
    WatchWidget()
} timeline: {
    SimpleEntry(date: .now, state: .reading(.placeholder))
    SimpleEntry(date: .now, state: .reading(.init(value: 94, trend: .fortyFiveUp, date: .now - 60)))
    SimpleEntry(date: .now, state: .reading(.init(value: 102, trend: .doubleDown, date: .now - 400)))
    SimpleEntry(date: .now, state: .reading(.init(value: 183, trend: .doubleUp, date: .now - 900)))
    SimpleEntry(date: .now, state: .reading(nil))
    SimpleEntry(date: .now, state: .loggedOut)
}
