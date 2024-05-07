//
//  DexcomTimelineProvider.swift
//  Glimpse
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

    func buildTimeline<Data>(for state: GlucoseEntry<Data>.State) -> Timeline<GlucoseEntry<Data>> {
        let now = Date.now

        switch state {
        case .error:
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
            let entry = GlucoseEntry(date: now, state: state)
            return Timeline(entries: [entry], policy: .after(refreshDate))
        case .reading(let data):
            let entries = (1...21).map {
                let date = Calendar.current.date(byAdding: .minute, value: $0, to: data.current.date)!
                return GlucoseEntry(date: date, state: state)
            }.filter {
                $0.date > .now
            }

            let refreshDate = Calendar.current.date(byAdding: .minute, value: 11, to: data.current.date)!
            return Timeline(entries: entries, policy: .after(refreshDate))
        }
    }
}
