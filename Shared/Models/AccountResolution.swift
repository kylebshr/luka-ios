//
//  AccountResolution.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import Foundation

/// Which signed-in account a stored account reference (a widget's configuration,
/// a Live Activity's attributes) points at. Pure, so it's testable without the
/// keychain.
enum AccountResolution {
    /// The referenced account, or the primary when unset (e.g. data recorded
    /// before multi-account) or no longer signed in.
    static func accountOrPrimary(
        for id: DexcomAccount.ID?,
        in accounts: [DexcomAccount]
    ) -> DexcomAccount? {
        if let id, let account = accounts.first(where: { $0.id == id }) {
            return account
        }
        return accounts.first
    }

    /// The accounts a widget shows. With a single signed-in account that's always
    /// the one, whatever is configured. Otherwise the configured accounts still
    /// signed in, in configured order, up to `capacity`; or just the primary when
    /// none are configured (every widget added before multi-account) or none are
    /// left.
    static func widgetAccounts(
        configured ids: [DexcomAccount.ID],
        in accounts: [DexcomAccount],
        capacity: Int
    ) -> [DexcomAccount] {
        guard accounts.count > 1 else { return accounts }

        var seen = Set<DexcomAccount.ID>()
        let configured = ids
            .filter { seen.insert($0).inserted }
            .compactMap { id in accounts.first { $0.id == id } }
            .prefix(max(capacity, 1))

        return configured.isEmpty ? [accounts[0]] : Array(configured)
    }

    /// The account's name, short enough for a widget cell or the Dynamic Island:
    /// an unnamed account's username (usually an email address) without its domain.
    static func shortName(displayName: String, username: String) -> String {
        if !displayName.isEmpty {
            return displayName
        }
        return username.split(separator: "@", maxSplits: 1).first.map(String.init) ?? username
    }

    enum LiveActivityOwner: Equatable {
        case account(DexcomAccount)
        /// The activity names an account that's no longer signed in. Its credentials
        /// are gone, so it must not be registered under another account's.
        case orphaned
        /// No accounts could be read. Not proof of being signed out: before first
        /// unlock the account list reads as empty too.
        case unavailable
    }

    /// The account a Live Activity belongs to. A nil `id` comes from an activity
    /// started before multi-account (or a server restart replaying its attributes):
    /// that build used the account the migration later gave `legacyAccountID`, so
    /// prefer it over the primary, which can change when accounts are reordered.
    static func liveActivityOwner(
        for id: DexcomAccount.ID?,
        in accounts: [DexcomAccount],
        legacyAccountID: DexcomAccount.ID = AccountStore.legacyAccountID
    ) -> LiveActivityOwner {
        guard let primary = accounts.first else {
            return .unavailable
        }
        guard let id else {
            return .account(accounts.first { $0.id == legacyAccountID } ?? primary)
        }
        if let account = accounts.first(where: { $0.id == id }) {
            return .account(account)
        }
        return .orphaned
    }

    /// Whether a Live Activity naming `activityAccountID` belongs to the account
    /// `accountID`. An orphaned activity still belongs to the account it names,
    /// so ending that account's activities clears it too.
    static func liveActivity(
        withAccountID activityAccountID: DexcomAccount.ID?,
        belongsTo accountID: DexcomAccount.ID,
        in accounts: [DexcomAccount],
        legacyAccountID: DexcomAccount.ID = AccountStore.legacyAccountID
    ) -> Bool {
        if activityAccountID == accountID {
            return true
        }
        guard case .account(let owner) = liveActivityOwner(
            for: activityAccountID, in: accounts, legacyAccountID: legacyAccountID
        ) else {
            return false
        }
        return owner.id == accountID
    }

    /// The signed-in accounts that own at least one of the running activities,
    /// given each one's `ReadingAttributes.accountID`. Orphaned activities count
    /// for nobody. Nil when there are running activities but no accounts could
    /// be read (before first unlock), so the caller keeps what it last knew.
    static func liveActivityAccountIDs(
        owningActivitiesWith activityAccountIDs: [DexcomAccount.ID?],
        in accounts: [DexcomAccount],
        legacyAccountID: DexcomAccount.ID = AccountStore.legacyAccountID
    ) -> Set<DexcomAccount.ID>? {
        guard !activityAccountIDs.isEmpty else { return [] }
        guard !accounts.isEmpty else { return nil }

        var ids = Set<DexcomAccount.ID>()
        for activityAccountID in activityAccountIDs {
            if case .account(let owner) = liveActivityOwner(
                for: activityAccountID, in: accounts, legacyAccountID: legacyAccountID
            ) {
                ids.insert(owner.id)
            }
        }
        return ids
    }
}
