//
//  StopLiveActivityIntent.swift
//  Luka
//
//  Created by Kyle Bashour on 10/21/25.
//

import AppIntents
import ActivityKit
import Defaults
import TelemetryDeck
import WidgetKit

struct EndLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End Live Activity"
    static var description = IntentDescription("End the currently running Live Activity.")

    init() {}

    func perform() async throws -> some IntentResult {
        for activity in Activity<ReadingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        Defaults[.isLiveActivityRunning] = false
        if #available(iOS 26.0, *) {
            ControlCenter.shared.reloadAllControls()
        }
        TelemetryDeck.signal("LiveActivity.end")
        return .result()
    }
}
