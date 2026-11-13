//
//  StartLiveActivityIntent.swift
//  Luka
//
//  Created by Kyle Bashour on 10/17/25.
//

import ActivityKit
import AppIntents
import Defaults
import Dexcom
import Foundation
import TelemetryDeck

extension DexcomError: @retroactive CustomLocalizedStringResourceConvertible {
    public var localizedStringResource: LocalizedStringResource {
        LocalizedStringResource(stringLiteral: message ?? localizedDescription)
    }
}

struct StartLiveActivityIntent: LiveActivityIntent {
    enum LiveActivityError: Error, CustomLocalizedStringResourceConvertible {
        case disabled
        case loggedOut

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .disabled:
                "Live Activities are disabled."
            case .loggedOut:
                "You’re not logged in."
            }
        }
    }

    static let title: LocalizedStringResource = "Start Live Activity"
    static let description = IntentDescription("Monitor glucose readings in a Live Activity.")

    @Parameter(
        title: "Account",
        description: "The account to follow. Leave empty to start one for every account."
    )
    var account: AccountEntity?

    private var source: String = "none"

    init() {}

    /// Starts `account`'s activity, or with nil one for every account.
    init(source: String, account: DexcomAccount? = nil) {
        self.source = source
        self.account = account.map { AccountEntity($0) }
    }

    func perform() async throws -> some IntentResult {
        try await Self.start(accountIDs: account.map { [$0.id] }, source: source)
        return .result()
    }

    /// Starts one activity for each account in `accountIDs`, or for every account when
    /// nil, replacing the activities those accounts already have; other accounts'
    /// activities keep running. An account that fails (bad password, Dexcom outage)
    /// doesn't stop the others; this only throws when none started.
    static func start(accountIDs: Set<DexcomAccount.ID>?, source: String) async throws {
        let allAccounts = AccountStore.shared.accounts
        let accounts = accountIDs.map { ids in allAccounts.filter { ids.contains($0.id) } } ?? allAccounts
        guard !accounts.isEmpty else {
            throw LiveActivityError.loggedOut
        }

        for activity in Activity<ReadingAttributes>.activities {
            let isReplaced = accountIDs == nil || accounts.contains { account in
                AccountResolution.liveActivity(
                    withAccountID: activity.attributes.accountID,
                    belongsTo: account.id,
                    in: allAccounts
                )
            }
            if isReplaced {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.disabled
        }

        let range: GraphRange = .threeHours
        let showsAccountName = allAccounts.count > 1
        let results = await fetchReadings(for: accounts, range: range)

        var errors: [(any Error)?] = Array(repeating: nil, count: accounts.count)
        // The most recently started activity is listed first, so start the primary last.
        for (index, account) in accounts.enumerated().reversed() {
            do {
                let readings = try results[index].get()
                let attributes = ReadingAttributes(
                    range: range,
                    accountID: account.id,
                    accountName: showsAccountName ? activityName(for: account) : nil
                )
                _ = try Activity.request(
                    attributes: attributes,
                    content: .init(
                        state: LiveActivityState(readings: readings, range: range),
                        staleDate: Date.now.addingTimeInterval(60 * 15)
                    ),
                    pushType: .token
                )
            } catch {
                errors[index] = error
            }
        }

        let failures = errors.compactMap { $0 }
        if failures.count == accounts.count, let error = mostUsefulError(errors) {
            throw error
        }

        // One user action, however many accounts it covered.
        Defaults[.liveActivityStartCount] += 1

        TelemetryDeck.signal(
            "LiveActivity.started",
            parameters: [
                "source": source,
                "accounts": String(accounts.count),
                "failedAccounts": String(failures.count),
                "allAccounts": String(accountIDs == nil),
            ]
        )
    }

    /// Each account's readings, in account order, fetched concurrently.
    private static func fetchReadings(
        for accounts: [DexcomAccount],
        range: GraphRange
    ) async -> [Result<[GlucoseReading], any Error>] {
        await withTaskGroup(of: (Int, Result<[GlucoseReading], any Error>).self) { group in
            for (index, account) in accounts.enumerated() {
                group.addTask {
                    guard let client = await DexcomHelper.createService(for: account) else {
                        return (index, .failure(LiveActivityError.loggedOut))
                    }
                    do {
                        let readings = try await client
                            .getGlucoseReadings(duration: .init(value: range.timeInterval, unit: .seconds))
                            .sorted { $0.date < $1.date }
                        return (index, .success(readings))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }

            var results: [Result<[GlucoseReading], any Error>] = Array(
                repeating: .failure(LiveActivityError.loggedOut),
                count: accounts.count
            )
            for await (index, result) in group {
                results[index] = result
            }
            return results
        }
    }

    private static func activityName(for account: DexcomAccount) -> String {
        AccountResolution.shortName(
            displayName: account.displayName,
            username: AccountStore.shared.credentials(for: account)?.username ?? ""
        )
    }

    /// The error to show when no account started, from per-account errors in
    /// account order: the first real failure (e.g. Dexcom rejecting a password)
    /// over an account whose credentials just couldn't be read.
    static func mostUsefulError(_ errors: [(any Error)?]) -> (any Error)? {
        let errors = errors.compactMap { $0 }
        return errors.first { !($0 is LiveActivityError) } ?? errors.first
    }
}
