//
//  StopLiveActivityIntent.swift
//  Luka
//
//  Created by Kyle Bashour on 10/21/25.
//

import ActivityKit
import AppIntents
import TelemetryDeck

struct EndLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End Live Activity"
    static let description = IntentDescription("End the currently running Live Activity.")

    @Parameter(
        title: "Account",
        description: "The account whose Live Activity to end. Leave empty to end every account's."
    )
    var account: AccountEntity?

    init() {}

    /// Ends `account`'s activities, or with nil every account's.
    init(account: AccountEntity?) {
        self.account = account
    }

    init(account: DexcomAccount?) {
        self.account = account.map { AccountEntity($0) }
    }

    /// Each ended activity's server session is ended by `LiveActivityManager` as it
    /// observes the activity end, whichever process this runs in.
    func perform() async throws -> some IntentResult {
        var activities = Activity<ReadingAttributes>.activities
        if let account {
            let accounts = AccountStore.shared.accounts
            activities = activities.filter { activity in
                AccountResolution.liveActivity(
                    withAccountID: activity.attributes.accountID,
                    belongsTo: account.id,
                    in: accounts
                )
            }
        }
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        TelemetryDeck.signal(
            "LiveActivity.end",
            parameters: ["activities": String(activities.count), "allAccounts": String(account == nil)]
        )
        return .result()
    }
}
