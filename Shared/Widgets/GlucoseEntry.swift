//
//  TimelineEntry.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/1/24.
//

import WidgetKit
import Dexcom

enum GlucoseEntryError {
    case loggedOut
    case noRecentReadings
    case failedToLoad
}

struct GlucoseEntry<Data: GlucoseEntryData>: TimelineEntry {
    enum State {
        case error(GlucoseEntryError)
        case reading(Data)
    }

    let date: Date
    let state: State

    var isExpired: Bool {
        switch state {
        case .error: false
        case .reading(let reading):
            date.timeIntervalSince(reading.current.date) > 20 * 60
        }
    }
}

extension GlucoseReading {
    static let placeholder = GlucoseReading(
        value: [GlucoseReading].placeholder.last!.value,
        trend: .flat,
        date: [GlucoseReading].placeholder.last!.date
    )
}

extension GlucoseEntryError {
    var buttonImage: String {
        switch self {
        case .loggedOut:
            "arrow.up.right"
        case .failedToLoad, .noRecentReadings:
            "arrow.circlepath"
        }
    }

    var buttonText: String {
        switch self {
        case .loggedOut:
            "Sign In"
        case .failedToLoad, .noRecentReadings:
            "Reload"
        }
    }

    var image: String {
        switch self {
        case .loggedOut:
            "person.slash"
        case .failedToLoad:
            "wifi.slash"
        case .noRecentReadings:
            "icloud.slash"
        }
    }

    var description: String {
        switch self {
        case .loggedOut:
            "No account"
        case .noRecentReadings:
            "No recent readings"
        case .failedToLoad:
            "Network error"
        }
    }
}
