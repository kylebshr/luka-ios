//
//  CGMHelper.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/25.
//

import Defaults
import Dexcom
import Foundation
import KeychainAccess
import Libre

enum CGMHelper {
    static let mockEmail = "demo@pitou.tech"

    /// Everything needed to build a client for the signed-in account.
    struct Credentials {
        var provider: CGMProvider
        var username: String
        var password: String
        var accountLocation: AccountLocation?
    }

    /// The signed-in account's credentials from the keychain and shared
    /// defaults, or nil when signed out (or before the keychain is readable).
    static var storedCredentials: Credentials? {
        guard let username = Keychain.shared.username,
              let password = Keychain.shared.password else {
            return nil
        }

        let provider = Defaults[.cgmProvider]
        let accountLocation = Defaults[.accountLocation]

        // A Dexcom account isn't usable without its location.
        if provider == .dexcom, accountLocation == nil, username != mockEmail {
            return nil
        }

        return Credentials(
            provider: provider,
            username: username,
            password: password,
            accountLocation: accountLocation
        )
    }

    /// Builds the service for some credentials, wiring session persistence to
    /// the keychain and wrapping it in the caching and server-proxy layers.
    static func createService(for credentials: Credentials) -> any GlucoseClientService {
        guard credentials.username != mockEmail else {
            return MockGlucoseClient()
        }

        let service: any GlucoseClientService = switch credentials.provider {
        case .dexcom:
            DexcomService(
                client: DexcomClient(
                    username: credentials.username,
                    password: credentials.password,
                    existingSession: Keychain.shared.dexcomSession,
                    accountLocation: credentials.accountLocation ?? .usa,
                    onSessionChange: { Keychain.shared.dexcomSession = $0 }
                )
            )
        case .libre:
            LibreService(
                client: LibreClient(
                    email: credentials.username,
                    password: credentials.password,
                    existingSession: Keychain.shared.libreSession,
                    onSessionChange: { Keychain.shared.libreSession = $0 }
                )
            )
        }

        let caching = CachingGlucoseClient(wrapping: service)

        if Defaults[.useReadingsProxy] {
            return ProxyGlucoseClient(
                wrapping: caching,
                username: credentials.username,
                password: credentials.password
            )
        }

        return caching
    }
}
