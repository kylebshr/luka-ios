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
    static var kind: AccountWidgetKind { get }
}

private enum AccountFetch<Value: Sendable>: Sendable {
    case loggedOut
    case failed
    case loaded(Value)
}

extension DexcomTimelineProvider {
    /// The accounts a widget shows, each loaded concurrently with `fetch` and
    /// turned into its own state by `makeState`, so one account failing doesn't
    /// blank the others. With no accounts signed in, a single signed-out slot.
    func makeAccounts<Data, Value: Sendable>(
        for configuration: some AccountWidgetConfiguration,
        family: WidgetFamily,
        fetch: @escaping @Sendable (DexcomClientService) async throws -> Value,
        makeState: (Value) -> GlucoseEntry<Data>.State
    ) async -> [GlucoseEntry<Data>.Account] {
        let store = AccountStore.shared
        let signedIn = store.accounts
        let accounts = AccountResolution.widgetAccounts(
            configured: (configuration.accounts ?? []).map(\.id),
            in: signedIn,
            capacity: Self.kind.capacity(for: IntentWidgetFamily(family))
        )

        guard !accounts.isEmpty else {
            return [.init(state: .error(.loggedOut))]
        }

        let results = await withTaskGroup(of: (Int, AccountFetch<Value>).self) { group in
            for (index, account) in accounts.enumerated() {
                group.addTask {
                    guard let client = await DexcomHelper.createService(for: account) else {
                        return (index, .loggedOut)
                    }
                    do {
                        return (index, .loaded(try await fetch(client)))
                    } catch {
                        return (index, .failed)
                    }
                }
            }

            var results = [AccountFetch<Value>](repeating: .loggedOut, count: accounts.count)
            for await (index, result) in group {
                results[index] = result
            }
            return results
        }

        return zip(accounts, results).map { account, result in
            let name = signedIn.count > 1 ? AccountResolution.shortName(
                displayName: account.displayName,
                username: store.credentials(for: account)?.username ?? ""
            ) : nil

            let state: GlucoseEntry<Data>.State = switch result {
            case .loggedOut: .error(.loggedOut)
            case .failed: .error(.failedToLoad)
            case .loaded(let value): makeState(value)
            }
            return .init(name: name, state: state)
        }
    }

    func buildTimeline<Data>(
        for accounts: [GlucoseEntry<Data>.Account],
        widgetURL: URL?
    ) -> Timeline<GlucoseEntry<Data>> {
        let now = Date.now
        let readingDates = accounts.compactMap { account -> Date? in
            if case .reading(let data) = account.state { data.current.date } else { nil }
        }

        guard let freshest = readingDates.max(), let oldest = readingDates.min() else {
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
            let entry = GlucoseEntry(date: now, widgetURL: widgetURL, accounts: accounts)
            return Timeline(entries: [entry], policy: .after(refreshDate))
        }

        // Per-minute entries keep the relative timestamps and staleness current.
        let entries = (1...30).map {
            let date = Calendar.current.date(byAdding: .minute, value: $0, to: freshest)!
            return GlucoseEntry(date: date, widgetURL: widgetURL, accounts: accounts)
        }.filter {
            $0.date > .now
        }

        // Reload when the account that's been waiting longest is due a new
        // reading; the 10-minute floor keeps several accounts from reloading
        // more often than one does.
        let minimumRefresh = Calendar.current.date(byAdding: .minute, value: 10, to: .now)!
        let readingBasedRefresh = Calendar.current.date(
            byAdding: .second,
            value: Int(15.5 * 60),
            to: oldest
        )!

        let refreshDate = max(readingBasedRefresh, minimumRefresh)
        return Timeline(entries: entries, policy: .after(refreshDate))
    }
}

extension IntentWidgetFamily {
    init(_ family: WidgetFamily) {
        switch family {
        #if os(iOS)
        case .systemSmall: self = .systemSmall
        case .systemMedium: self = .systemMedium
        case .systemLarge: self = .systemLarge
        #endif
        case .accessoryCircular: self = .accessoryCircular
        case .accessoryRectangular: self = .accessoryRectangular
        case .accessoryInline: self = .accessoryInline
        #if os(watchOS)
        case .accessoryCorner: self = .accessoryCorner
        #endif
        default: self = .systemExtraLarge
        }
    }
}
