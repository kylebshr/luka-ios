//
//  DexcomTimelineProvider.swift
//  Luka
//
//  Created by Kyle Bashour on 5/1/24.
//

import AppIntents
import Dexcom
import Foundation
import WidgetKit
import Defaults

protocol DexcomTimelineProvider {
    associatedtype Entry
}

extension DexcomTimelineProvider {
    /// The account a widget shows: its configured account, or the primary one when
    /// unset or no longer signed in.
    func account(for configuration: some AccountWidgetConfiguration) -> DexcomAccount? {
        AccountResolution.accountOrPrimary(for: configuration.account?.id, in: AccountStore.shared.accounts)
    }

    /// The name to label a widget with, only when there's more than one account to
    /// tell apart.
    func accountName(for account: DexcomAccount) -> String? {
        guard AccountStore.shared.accounts.count > 1 else { return nil }
        return AccountStore.shared.displayName(for: account)
    }

    func makeClient(for account: DexcomAccount) async -> DexcomClientService? {
        await DexcomHelper.createService(for: account)
    }

    func buildTimeline<Data>(for state: GlucoseEntry<Data>.State, widgetURL: URL?) -> Timeline<GlucoseEntry<Data>> {
        let now = Date.now

        switch state {
        case .error:
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
            let entry = GlucoseEntry(date: now, widgetURL: widgetURL, state: state)
            return Timeline(entries: [entry], policy: .after(refreshDate))
        case .reading(let data):
            let entries = (1...30).map {
                let date = Calendar.current.date(byAdding: .minute, value: $0, to: data.current.date)!
                return GlucoseEntry(date: date, widgetURL: widgetURL, state: state)
            }.filter {
                $0.date > .now
            }

            let minimumRefresh = Calendar.current.date(byAdding: .minute, value: 10, to: .now)!
            let readingBasedRefresh = Calendar.current.date(
                byAdding: .second,
                value: Int(15.5 * 60),
                to: data.current.date
            )!

            let refreshDate = max(readingBasedRefresh, minimumRefresh)
            return Timeline(entries: entries, policy: .after(refreshDate))
        }
    }
}
