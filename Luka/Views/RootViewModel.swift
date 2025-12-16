//
//  RootViewModel.swift
//  Luka
//
//  Created by Kyle Bashour on 4/26/24.
//

import SwiftUI
import KeychainAccess
import Dexcom
import Defaults

@Observable @MainActor class RootViewModel {
    private let keychain = Keychain.shared

    private static let bannersURL = URL(string: "https://raw.githubusercontent.com/kylebshr/luka-meta/refs/heads/main/meta.json")!

    var username: String? = Keychain.shared.username {
        didSet { keychain.username = username }
    }

    var password: String? = Keychain.shared.password {
        didSet { keychain.password = password }
    }

    var accountLocation: AccountLocation? = Defaults[.accountLocation] {
        didSet { Defaults[.accountLocation] = accountLocation }
    }

    var accountID: UUID? = Keychain.shared.accountID {
        didSet { keychain.accountID = accountID }
    }

    var sessionID: UUID? = Keychain.shared.sessionID {
        didSet {
            keychain.sessionID = sessionID
        }
    }

    private(set) var banners: Banners?

    var requiresForceUpgrade: Bool {
        banners?.requiresForceUpgrade ?? false
    }

    var isSignedIn: Bool {
        username != nil && password != nil && accountLocation != nil
    }

    func loadBanners() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.bannersURL)
            let decoded = try JSONDecoder().decode(Banners.self, from: data)
            self.banners = decoded
        } catch {
            print("Failed to load banners: \(error)")
        }
    }

    func displayableBanners(dismissedBannerIDs: Set<String>) -> [Banner] {
        guard let banners else { return [] }
        return banners.banners.filter { $0.isWithinVersionRange && !dismissedBannerIDs.contains($0.id) }
    }

    func signIn(
        username: String,
        password: String,
        accountLocation: AccountLocation
    ) async throws {
        let client = DexcomHelper.createService(
            username: username,
            password: password,
            existingAccountID: accountID, 
            existingSessionID: sessionID,
            accountLocation: accountLocation
        )

        (accountID, sessionID) = try await client.createSession()

        self.username = username
        self.password = password
        self.accountLocation = accountLocation
    }

    func signOut() {
        username = nil
        password = nil
        accountID = nil
        sessionID = nil
    }
}
