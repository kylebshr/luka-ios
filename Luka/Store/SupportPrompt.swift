//
//  SupportPrompt.swift
//  Luka
//
//  Created by Claude on 9/7/26.
//

import Foundation

/// Decides when to ask the user to support Luka after starting a Live Activity.
enum SupportPrompt {
    /// Starts before the first ask; the first Live Activity should be free of nagging.
    static let minimumStartCount = 2

    /// How long to wait before asking again after a dismissed prompt.
    static let repromptInterval: TimeInterval = 30 * 24 * 60 * 60

    static func shouldShow(
        startCount: Int,
        isSupporter: Bool,
        lastPromptDate: Date?,
        now: Date = .now
    ) -> Bool {
        guard !isSupporter, startCount >= minimumStartCount else {
            return false
        }

        guard let lastPromptDate else {
            return true
        }

        return now.timeIntervalSince(lastPromptDate) >= repromptInterval
    }
}
