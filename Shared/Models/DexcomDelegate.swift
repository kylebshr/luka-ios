//
//  DexcomDelegate.swift
//  Luka
//
//  Created by Kyle Bashour on 10/21/25.
//

import Foundation
import Dexcom

/// Persists the Dexcom account and session IDs a client refreshes, for one account.
final class KeychainDexcomDelegate: DexcomClientDelegate, Sendable {
    private let accountID: DexcomAccount.ID
    private let store: AccountStore

    init(accountID: DexcomAccount.ID, store: AccountStore = .shared) {
        self.accountID = accountID
        self.store = store
    }

    func didUpdateAccountID(_ dexcomAccountID: UUID) {
        store.setDexcomAccountID(dexcomAccountID, for: accountID)
    }

    func didUpdateSessionID(_ sessionID: UUID) {
        store.setSessionID(sessionID, for: accountID)
    }
}
