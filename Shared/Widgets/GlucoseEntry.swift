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

    /// One account's slot in the widget.
    struct Account {
        /// Only set when more than one account is signed in.
        var name: String?
        var state: State
    }

    let date: Date
    let widgetURL: URL?
    /// The accounts shown, in order. Never empty.
    let accounts: [Account]

    init(date: Date, widgetURL: URL?, state: State, accountName: String? = nil) {
        self.init(date: date, widgetURL: widgetURL, accounts: [Account(name: accountName, state: state)])
    }

    init(date: Date, widgetURL: URL?, accounts: [Account]) {
        precondition(!accounts.isEmpty)
        self.date = date
        self.widgetURL = widgetURL
        self.accounts = accounts
    }

    /// The first (for a single-account widget, the only) account's state.
    var state: State { accounts[0].state }
    var accountName: String? { accounts[0].name }

    var showsMultipleAccounts: Bool { accounts.count > 1 }

    /// This entry narrowed to one of its accounts, for views that draw one.
    func account(at index: Int) -> GlucoseEntry {
        GlucoseEntry(date: date, widgetURL: widgetURL, accounts: [accounts[index]])
    }

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
            String(localized: "Sign In")
        case .failedToLoad, .noRecentReadings:
            String(localized: "Reload")
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
            String(localized: "No Account")
        case .noRecentReadings:
            String(localized: "No Readings")
        case .failedToLoad:
            String(localized: "Network Error")
        }
    }
}
