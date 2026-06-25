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

    var username: String? {
        didSet { keychain.username = username }
    }

    var password: String? {
        didSet { keychain.password = password }
    }

    var accountLocation: AccountLocation? = Defaults[.accountLocation] {
        didSet { Defaults[.accountLocation] = accountLocation }
    }

    var accountID: UUID? {
        didSet { keychain.accountID = accountID }
    }

    var sessionID: UUID? {
        didSet {
            keychain.sessionID = sessionID
        }
    }

    /// True once we've successfully read the keychain at least once. Right after
    /// a reboot the synchronizable keychain can be briefly locked; until we get a
    /// clean read we must not treat missing credentials as "signed out".
    private(set) var didLoadCredentials = false

    init() {
        loadCredentials()
    }

    /// Reads credentials from the keychain, distinguishing a temporarily-locked
    /// keychain (throws → retry later) from a genuinely empty one (returns nil).
    /// Safe to call repeatedly; it no-ops once a clean read has succeeded.
    func loadCredentials() {
        guard !didLoadCredentials else { return }

        do {
            let username = try keychain.getString(.usernameKey)
            let password = try keychain.getString(.passwordKey)
            let accountID = try keychain.getString(.accountIDKey).flatMap(UUID.init(uuidString:))
            let sessionID = try keychain.getString(.sessionIDKey).flatMap(UUID.init(uuidString:))

            self.username = username
            self.password = password
            self.accountID = accountID
            self.sessionID = sessionID
            didLoadCredentials = true
        } catch {
            // Keychain not yet readable (likely just rebooted). Leave state as-is
            // and retry when the app next becomes active.
            print("Keychain not ready, will retry: \(error)")
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
            var request = URLRequest(url: Self.bannersURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: request)
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
