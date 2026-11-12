//
//  StopLiveActivityIntent.swift
//  Luka
//
//  Created by Kyle Bashour on 10/21/25.
//

import ActivityKit
import AppIntents
import TelemetryDeck

struct EndLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Live Activity"
    static let description = IntentDescription("End the currently running Live Activity.")

    init() {}

    /// Ends every account's activity. Each one's server session is ended by
    /// `LiveActivityManager` as it observes the activity end.
    func perform() async throws -> some IntentResult {
        let activities = Activity<ReadingAttributes>.activities
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        TelemetryDeck.signal("LiveActivity.end", parameters: ["activities": String(activities.count)])
        return .result()
    }
}
