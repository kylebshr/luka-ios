//
//  ReloadWidgetIntent.swift
//  Luka
//
//  Created by Kyle Bashour on 4/24/24.
//

import AppIntents

struct ReloadWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Reload"
    static let description = IntentDescription("Reload")

    init() {}

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
