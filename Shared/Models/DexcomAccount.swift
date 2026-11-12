//
//  DexcomAccount.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import Defaults
import Dexcom
import Foundation

/// A signed-in Dexcom account. Only non-secret details live here (and sync via
/// iCloud defaults); credentials are in the keychain, keyed by `id`.
struct DexcomAccount: Codable, Hashable, Identifiable, Sendable, Defaults.Serializable {
    var id: UUID
    /// User-chosen name; empty means "use the username".
    var displayName: String
    var accountLocation: AccountLocation

    init(id: UUID = UUID(), displayName: String = "", accountLocation: AccountLocation) {
        self.id = id
        self.displayName = displayName
        self.accountLocation = accountLocation
    }
}

struct DexcomCredentials: Hashable, Sendable {
    var username: String
    var password: String
    /// Dexcom's own account ID (not `DexcomAccount.id`), cached to skip a login round trip.
    var dexcomAccountID: UUID?
    var sessionID: UUID?

    var isMock: Bool {
        username == DexcomHelper.mockEmail
    }
}
