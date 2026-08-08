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
#if os(iOS)
import UIKit
#endif

@Observable @MainActor class RootViewModel {
    private let keychain = Keychain.shared

    private static let bannersURL = URL(string: "https://raw.githubusercontent.com/kylebshr/luka-meta/refs/heads/main/meta.json")!

    /// Suppresses the keychain writes in `didSet` while restoring values *from*
    /// the keychain, so an untrusted read can never delete stored credentials.
    @ObservationIgnored private var isRestoringCredentials = false

    var username: String? {
        didSet {
            guard !isRestoringCredentials else { return }
            keychain.username = username
        }
    }

    var password: String? {
        didSet {
            guard !isRestoringCredentials else { return }
            keychain.password = password
        }
    }

    var accountLocation: AccountLocation? = Defaults[.accountLocation] {
        didSet { Defaults[.accountLocation] = accountLocation }
    }

    var provider: CGMProvider = Defaults[.cgmProvider] {
        didSet { Defaults[.cgmProvider] = provider }
    }

    var accountID: UUID? {
        didSet {
            guard !isRestoringCredentials else { return }
            keychain.accountID = accountID
        }
    }

    var sessionID: UUID? {
        didSet {
            guard !isRestoringCredentials else { return }
            keychain.sessionID = sessionID
        }
    }

    /// True once we've read the keychain while it was trustworthy. Prewarming
    /// can launch the app before first unlock, where items don't just fail to
    /// read — they're reported as not-found. Until we get a trustworthy read we
    /// must not treat missing credentials as "signed out".
    private(set) var didLoadCredentials = false

    @ObservationIgnored private var protectedDataObserver: (any NSObjectProtocol)?

    init() {
        loadCredentials()

        #if os(iOS)
        protectedDataObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadCredentials()
            }
        }
        #endif
    }

    /// Reads credentials from the keychain. A locked keychain can either throw
    /// or report items as not-found, so an empty read only counts as "signed
    /// out" once protected data is available. Safe to call repeatedly; it
    /// no-ops after the first trustworthy read.
    func loadCredentials() {
        guard !didLoadCredentials else { return }

        do {
            let username = try keychain.getString(.usernameKey)
            let password = try keychain.getString(.passwordKey)
            let accountID = try keychain.getString(.accountIDKey).flatMap(UUID.init(uuidString:))
            let sessionID = try keychain.getString(.sessionIDKey).flatMap(UUID.init(uuidString:))

            if username == nil || password == nil, !Self.isProtectedDataAvailable {
                return
            }

            isRestoringCredentials = true
            defer { isRestoringCredentials = false }

            self.username = username
            self.password = password
            self.accountID = accountID
            self.sessionID = sessionID
            // The shared-suite plist is also unreadable before first unlock, so
            // the values captured by the property initializers may be missing.
            self.accountLocation = Defaults[.accountLocation]
            self.provider = Defaults[.cgmProvider]
            didLoadCredentials = true
        } catch {
            // Keychain not yet readable (likely just rebooted). Leave state
            // as-is; we retry when protected data becomes available and when
            // the app becomes active.
            print("Keychain not ready, will retry: \(error)")
        }
    }

    private static var isProtectedDataAvailable: Bool {
        #if os(iOS)
        UIApplication.shared.isProtectedDataAvailable
        #else
        true
        #endif
    }

    private(set) var banners: Banners?

    var requiresForceUpgrade: Bool {
        banners?.requiresForceUpgrade ?? false
    }

    var isSignedIn: Bool {
        username != nil && password != nil && (provider == .libre || accountLocation != nil)
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
        provider: CGMProvider,
        username: String,
        password: String,
        accountLocation: AccountLocation? = nil
    ) async throws {
        let client = CGMHelper.createService(
            for: CGMHelper.Credentials(
                provider: provider,
                username: username,
                password: password,
                accountLocation: accountLocation
            )
        )

        // Validates the credentials; the resulting session is persisted to the
        // keychain by the client's onSessionChange.
        try await client.createSession()

        self.username = username
        self.password = password
        self.accountLocation = accountLocation
        self.provider = provider
    }

    func signOut() {
        username = nil
        password = nil
        accountID = nil
        sessionID = nil
        Keychain.shared.libreSession = nil
        provider = .dexcom
    }
}
