//
//  TimelineEntry.swift
//  Luka
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
    let widgetURL: URL?
    let tapAction: WidgetTapAction
    let state: State

    var isExpired: Bool {
        switch state {
        case .error: false
        case .reading(let reading):
            reading.current.isExpired(at: date)
        }
    }

    var shouldRefresh: Bool {
        switch state {
        case .error: false
        case .reading(let reading):
            date.timeIntervalSince(reading.current.date) > 10 * 60
        }
    }
}

extension GlucoseEntryError {
    var buttonImage: String {
        switch self {
        case .loggedOut:
            "arrow.up.right"
        case .failedToLoad, .noRecentReadings:
            "arrow.triangle.2.circlepath"
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
            "No Account"
        case .noRecentReadings:
            "No Recent Readings"
        case .failedToLoad:
            "Network Error"
        }
    }
}
