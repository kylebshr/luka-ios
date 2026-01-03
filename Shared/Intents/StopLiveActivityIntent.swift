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
    static var title: LocalizedStringResource = "End Live Activity"
    static var description = IntentDescription("End the currently running Live Activity.")

    init() {}

    func perform() async throws -> some IntentResult {
        for activity in Activity<ReadingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        TelemetryDeck.signal("LiveActivity.end")
        return .result()
    }
}
