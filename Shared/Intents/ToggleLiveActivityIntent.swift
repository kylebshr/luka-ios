//
//  ToggleLiveActivityIntent.swift
//  Luka
//
//  Created by Claude on 1/2/26.
//

import ActivityKit
import AppIntents

@available(iOS 26.0, *)
struct ToggleLiveActivityIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Toggle Live Activity"
    static let description = IntentDescription("Start or stop the glucose Live Activity.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @Parameter(title: "Running")
    var value: Bool

    init() {}

    func perform() async throws -> some IntentResult {
        if value {
            _ = try await StartLiveActivityIntent(source: "Control").perform()
        } else {
            _ = try await EndLiveActivityIntent().perform()
        }
        return .result()
    }
}
