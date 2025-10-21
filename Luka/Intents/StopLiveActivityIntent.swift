//
//  StopLiveActivityIntent.swift
//  Luka
//
//  Created by Kyle Bashour on 10/21/25.
//

import AppIntents
import ActivityKit

struct EndLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Live Activity"
    static var description = IntentDescription("End the currently running Live Activity.")

    init() {}

    func perform() async throws -> some IntentResult {
        for activity in Activity<ReadingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        return .result()
    }
}
