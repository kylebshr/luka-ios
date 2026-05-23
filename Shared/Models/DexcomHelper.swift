//
//  DexcomHelper.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/25.
//

import Defaults
import Dexcom
import Foundation

enum DexcomHelper {
    static let mockEmail = "demo@pitou.tech"

    static func createService(
        username: String?,
        password: String?,
        existingAccountID: UUID? = nil,
        existingSessionID: UUID? = nil,
        accountLocation: AccountLocation
    ) -> DexcomClientService {
        if username == mockEmail || username == nil {
            return MockDexcomClient()
        } else {
            let client = DexcomClient(
                username: username,
                password: password,
                existingAccountID: existingAccountID,
                existingSessionID: existingSessionID,
                accountLocation: accountLocation
            )
            let caching = CachingDexcomClient(wrapping: client)

            if Defaults[.useReadingsProxy], let username, let password {
                return ProxyDexcomClient(
                    wrapping: caching,
                    username: username,
                    password: password
                )
            }

            return caching
        }
    }
}
