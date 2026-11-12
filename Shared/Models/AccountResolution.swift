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
    /// The referenced account, or the primary when unset (e.g. widgets configured
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
}
