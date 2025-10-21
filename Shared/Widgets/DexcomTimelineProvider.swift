//
//  DexcomTimelineProvider.swift
//  Luka
//
//  Created by Kyle Bashour on 5/1/24.
//

import Dexcom
import Foundation
import KeychainAccess
import WidgetKit
import Defaults

class DexcomDelegate: DexcomClientDelegate {
    func didUpdateAccountID(_ accountID: UUID) {
        Keychain.shared.accountID = accountID
    }

    func didUpdateSessionID(_ sessionID: UUID) {
        Keychain.shared.sessionID = sessionID
        DexcomSessionHistory.record(sessionID: sessionID)
    }
}

protocol DexcomTimelineProvider {
    associatedtype Entry

    var delegate: DexcomDelegate { get }
}

extension DexcomTimelineProvider {
    func makeClient(username: String, password: String, accountLocation: AccountLocation) -> DexcomClient {
        let client = DexcomClient(
            username: username,
            password: password,
            existingAccountID: Keychain.shared.accountID,
            existingSessionID: Keychain.shared.sessionID,
            accountLocation: accountLocation
        )

        client.delegate = delegate
        return client
    }

    func recordSessionIfNeeded() {
        if let sessionID = Keychain.shared.sessionID {
            DexcomSessionHistory.record(sessionID: sessionID)
        }
    }

    func buildTimeline<Data>(for state: GlucoseEntry<Data>.State, widgetURL: URL?) -> Timeline<GlucoseEntry<Data>> {
        let now = Date.now

        switch state {
        case .error:
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
            let entry = GlucoseEntry(date: now, widgetURL: widgetURL, state: state)
            return Timeline(entries: [entry], policy: .after(refreshDate))
        case .reading(let data):
            let entries = (1...21).map {
                let date = Calendar.current.date(byAdding: .minute, value: $0, to: data.current.date)!
                return GlucoseEntry(date: date, widgetURL: widgetURL, state: state)
            }.filter {
                $0.date > .now
            }

            let minimumRefresh = Calendar.current.date(byAdding: .minute, value: 10, to: .now)!
            let readingBasedRefresh = Calendar.current.date(
                byAdding: .second,
                value: Int(10.5 * 60),
                to: data.current.date
            )!

            let refreshDate = max(readingBasedRefresh, minimumRefresh)
            return Timeline(entries: entries, policy: .after(refreshDate))
        }
    }
}
