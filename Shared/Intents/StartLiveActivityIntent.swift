//
//  StartLiveActivityIntent.swift
//  Luka
//
//  Created by Kyle Bashour on 10/17/25.
//

import ActivityKit
import AppIntents
import Defaults
import Dexcom
import Foundation
import TelemetryDeck

struct StartLiveActivityIntent: LiveActivityIntent {
    enum LiveActivityError: Error, CustomLocalizedStringResourceConvertible {
        case disabled

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .disabled:
                "Live Activities are disabled."
            }
        }
    }

    static let title: LocalizedStringResource = "Start Live Activity"
    static let description = IntentDescription("Monitor glucose readings in a Live Activity.")

    private var source: String = "none"

    init() {}

    init(source: String) {
        self.source = source
    }

    func perform() async throws -> some IntentResult {
        for activity in Activity<ReadingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.disabled
        }

        let range: GraphRange = .threeHours

        // Load cached readings from G7 sensor if available
        let cachedReadings = Defaults[.g7Readings] ?? []
        let cutoff = Date.now.addingTimeInterval(-range.timeInterval)
        let readings = cachedReadings.filter { $0.date >= cutoff }

        let attributes = ReadingAttributes(range: range)
        let initialState = LiveActivityState(readings: readings, range: range)

        _ = try Activity.request(
            attributes: attributes,
            content: .init(
                state: initialState,
                staleDate: initialState.c?.date.addingTimeInterval(10 * 60)
            ),
            pushType: nil
        )

        TelemetryDeck.signal(
            "LiveActivity.started",
            parameters: ["source": source]
        )

        return .result()
    }
}
