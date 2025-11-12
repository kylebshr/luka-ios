//
//  DexcomHelper.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/25.
//

import Foundation
import Dexcom

enum DexcomHelper {
    static let mockEmail = "demo@pitou.tech"

    static func createService(
        username: String?,
        password: String?,
        existingAccountID: UUID? = nil,
        existingSessionID: UUID? = nil,
        accountLocation: AccountLocation
    ) -> DexcomClientService {
        if username == mockEmail {
            return MockDexcomClient()
        } else {
            return DexcomClient(
                username: username,
                password: password,
                existingAccountID: existingAccountID,
                existingSessionID: existingSessionID,
                accountLocation: accountLocation
            )
        }
    }
}
