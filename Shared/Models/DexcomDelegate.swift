//
//  DexcomDelegate.swift
//  Luka
//
//  Created by Kyle Bashour on 10/21/25.
//

import Foundation
import KeychainAccess
import Dexcom

class DexcomDelegate: DexcomClientDelegate {
    let source: String

    init(source: String) {
        self.source = source
    }

    func didUpdateAccountID(_ accountID: UUID) {
        Keychain.shared.accountID = accountID
    }

    func didUpdateSessionID(_ sessionID: UUID) {
        Keychain.shared.sessionID = sessionID
    }
}
