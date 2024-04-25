//
//  ReloadWidgetIntent.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/24/24.
//

import AppIntents

struct ReloadWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Reload"
    static var description = IntentDescription("Reload")

    init() {}

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
