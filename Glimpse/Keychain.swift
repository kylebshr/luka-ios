//
//  Keychain.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/12/24.
//

import Security
import KeychainAccess

extension Keychain {
    static var standard: Keychain {
        Keychain(service: "group.com.kylebashour.Glimpse").synchronizable(true)
    }
}
