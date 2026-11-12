//
//  Keychain.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/12/24.
//

import Security
import KeychainAccess
import Foundation

extension Keychain {
    /// Access credentials through `AccountStore`, which keys them per account.
    static var shared: Keychain {
        Keychain(
            service: "group.com.kylebashour.Glimpse",
            accessGroup: "group.com.kylebashour.Glimpse"
        )
        .synchronizable(true)
        .accessibility(.afterFirstUnlock)
    }
}
