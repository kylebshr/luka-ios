//
//  RootViewModel.swift
//  Luka
//
//  Created by Kyle Bashour on 4/26/24.
//

import SwiftUI
import Dexcom
import Defaults
#if os(iOS)
import UIKit
#endif

@Observable @MainActor class RootViewModel {
    private static let bannersURL = URL(string: "https://raw.githubusercontent.com/kylebshr/luka-meta/refs/heads/main/meta.json")!

    @ObservationIgnored let store: AccountStore

    /// Signed-in accounts, primary first.
    private(set) var accounts: [DexcomAccount] = []

    var primaryAccount: DexcomAccount? {
        accounts.first
    }

    /// True once we've read the accounts while storage was trustworthy.
    /// Prewarming can launch the app before first unlock, where keychain items
    /// and the shared-suite plist don't just fail to read — they read as empty.
    /// Until we get a trustworthy read we must not treat "no accounts" as
    /// "signed out".
    private(set) var didLoadCredentials = false

    @ObservationIgnored private var protectedDataObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var accountUpdatesTask: Task<Void, Never>?

    init(store: AccountStore = .shared) {
        self.store = store
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

        // Picks up changes arriving via iCloud defaults sync.
        accountUpdatesTask = Task { [weak self, store] in
            for await _ in store.accountListUpdates() {
                self?.loadCredentials()
            }
        }
    }

    /// Re-reads the account list. An empty read only counts as "signed out"
    /// once protected data is available, and a failed read never changes
    /// state. Safe to call repeatedly (on foreground, after an unlock) to pick
    /// up changes made by extensions or other devices.
    func loadCredentials() {
        let loaded: [DexcomAccount]
        do {
            loaded = try store.loadAccounts()
        } catch {
            // Keychain not yet readable (likely just rebooted). Leave state
            // as-is; we retry when protected data becomes available and when
            // the app becomes active.
            print("Accounts not ready, will retry: \(error)")
            return
        }

        if loaded.isEmpty, !Self.isProtectedDataAvailable {
            return
        }

        if loaded != accounts {
            accounts = loaded
        }
        didLoadCredentials = true
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
        !accounts.isEmpty
    }

    func loadBanners() async {
        do {
            var request = URLRequest(url: Self.bannersURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(Banners.self, from: data)
            self.banners = decoded
            // Persisted only on a successful fetch, so a failed one keeps the last known value.
            Defaults[.cloudflareRollout] = Backend.sanitizedRollout(decoded.cloudflareRollout)
        } catch {
            print("Failed to load banners: \(error)")
        }
    }

    func displayableBanners(dismissedBannerIDs: Set<String>) -> [Banner] {
        guard let banners else { return [] }
        return banners.banners.filter { $0.isWithinVersionRange && !dismissedBannerIDs.contains($0.id) }
    }

    /// Validates the credentials with Dexcom, then appends a new account.
    @discardableResult
    func signIn(
        username: String,
        password: String,
        accountLocation: AccountLocation,
        displayName: String = ""
    ) async throws -> DexcomAccount {
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)

        // Checked before the network round trip as well as by `add`.
        guard !store.isUsernameInUse(username) else {
            throw AccountStore.StoreError.duplicateUsername
        }

        let client = DexcomHelper.createSignInService(
            username: username,
            password: password,
            accountLocation: accountLocation
        )
        let (dexcomAccountID, sessionID) = try await client.createSession()

        let account = try store.add(
            username: username,
            password: password,
            accountLocation: accountLocation,
            displayName: displayName,
            dexcomAccountID: dexcomAccountID,
            sessionID: sessionID
        )
        reloadAfterWrite()
        return account
    }

    /// Removes the account and its stored credentials and cached readings.
    func signOut(_ account: DexcomAccount) {
        do {
            try store.remove(account.id)
        } catch {
            print("Failed to remove account: \(error)")
        }
        reloadAfterWrite()
    }

    func rename(_ account: DexcomAccount, to displayName: String) {
        do {
            try store.rename(account.id, to: displayName)
        } catch {
            print("Failed to rename account: \(error)")
        }
        reloadAfterWrite()
    }

    /// Moves accounts in the list. The first account is the primary one.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var reordered = accounts
        reordered.move(fromOffsets: source, toOffset: destination)
        // Update immediately so the list doesn't snap back before the reload.
        accounts = reordered
        do {
            try store.reorder(reordered.map(\.id))
        } catch {
            print("Failed to reorder accounts: \(error)")
        }
        reloadAfterWrite()
    }

    /// The account's display name, falling back to its username.
    func displayName(for account: DexcomAccount) -> String {
        store.displayName(for: account)
    }

    func username(for account: DexcomAccount) -> String? {
        store.credentials(for: account)?.username
    }

    /// After our own write the list is known-good, even if protected data
    /// reports unavailable (e.g. signing out the last account while locked).
    private func reloadAfterWrite() {
        guard let loaded = try? store.loadAccounts() else { return }
        accounts = loaded
        didLoadCredentials = true
    }
}
