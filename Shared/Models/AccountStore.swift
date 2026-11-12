//
//  AccountStore.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import Defaults
import Dexcom
import Foundation
import KeychainAccess

/// Secret storage for account credentials. The keychain in production; an
/// in-memory store in tests.
protocol CredentialStorage: Sendable {
    func string(forKey key: String) throws -> String?
    func setString(_ value: String?, forKey key: String) throws
}

struct KeychainCredentialStorage: CredentialStorage {
    func string(forKey key: String) throws -> String? {
        try Keychain.shared.getString(key)
    }

    func setString(_ value: String?, forKey key: String) throws {
        if let value {
            try Keychain.shared.set(value, key: key)
        } else {
            try Keychain.shared.remove(key)
        }
    }
}

/// The list of signed-in Dexcom accounts and their credentials, shared by the
/// app and its extensions. Stateless: every read goes to defaults/keychain, so
/// changes made by another process are always seen.
struct AccountStore: Sendable {
    enum StoreError: LocalizedError {
        /// Credential storage couldn't be read (e.g. before first unlock).
        case unavailable
        case duplicateUsername

        var errorDescription: String? {
            switch self {
            case .unavailable:
                String(localized: "Your accounts can’t be read right now. Try again after unlocking your device.")
            case .duplicateUsername:
                String(localized: "You’re already signed in to this account.")
            }
        }
    }

    static let shared = AccountStore(
        accountsKey: .accounts,
        legacyAccountLocationKey: .accountLocation,
        credentialStorage: KeychainCredentialStorage(),
        cacheSuite: .shared,
        hasRemoteAccounts: {
            // Defaults stores iCloud values under the key's own name.
            NSUbiquitousKeyValueStore.default.object(forKey: Defaults.Keys.accounts.name) != nil
        }
    )

    /// The migrated single account gets a fixed ID, so concurrent migrations
    /// (app and an extension, or two devices) produce identical results.
    static let legacyAccountID = UUID(uuidString: "6C756B61-0000-4000-8000-000000000001")!

    private let accountsKey: Defaults.Key<[DexcomAccount]?>
    private let legacyAccountLocationKey: Defaults.Key<AccountLocation?>
    private let credentialStorage: any CredentialStorage
    // UserDefaults is thread-safe.
    nonisolated(unsafe) private let cacheSuite: UserDefaults
    private let hasRemoteAccounts: @Sendable () -> Bool

    init(
        accountsKey: Defaults.Key<[DexcomAccount]?>,
        legacyAccountLocationKey: Defaults.Key<AccountLocation?>,
        credentialStorage: any CredentialStorage,
        cacheSuite: UserDefaults,
        hasRemoteAccounts: @escaping @Sendable () -> Bool
    ) {
        self.accountsKey = accountsKey
        self.legacyAccountLocationKey = legacyAccountLocationKey
        self.credentialStorage = credentialStorage
        self.cacheSuite = cacheSuite
        self.hasRemoteAccounts = hasRemoteAccounts
    }

    // MARK: - Reading

    /// All accounts, primary first. Migrates the legacy single account the
    /// first time it's needed. Throws `.unavailable` if the keychain can't be
    /// read. An empty result is NOT proof of being signed out before first
    /// unlock: the shared-suite plist reads as empty then too.
    func loadAccounts() throws -> [DexcomAccount] {
        if let accounts = Defaults[accountsKey] {
            return accounts
        }
        return try migrateLegacyAccount()
    }

    /// Best-effort list for callers that treat "unreadable" like "signed out"
    /// (widgets, intents).
    var accounts: [DexcomAccount] {
        (try? loadAccounts()) ?? []
    }

    /// The account used wherever the app still needs a single account.
    var primary: DexcomAccount? {
        accounts.first
    }

    func account(id: DexcomAccount.ID) -> DexcomAccount? {
        accounts.first { $0.id == id }
    }

    func credentials(for id: DexcomAccount.ID) -> DexcomCredentials? {
        let keys = CredentialKeys(id)
        guard let username = try? credentialStorage.string(forKey: keys.username),
              let password = try? credentialStorage.string(forKey: keys.password) else {
            return nil
        }
        return DexcomCredentials(
            username: username,
            password: password,
            dexcomAccountID: uuid(forKey: keys.dexcomAccountID),
            sessionID: uuid(forKey: keys.sessionID)
        )
    }

    func credentials(for account: DexcomAccount) -> DexcomCredentials? {
        credentials(for: account.id)
    }

    /// The account's display name, falling back to its username.
    func displayName(for account: DexcomAccount) -> String {
        if !account.displayName.isEmpty {
            return account.displayName
        }
        return credentials(for: account.id)?.username ?? ""
    }

    /// Whether `username` is already signed in. The Live Activity server keys
    /// sessions by username, so a real account can only be added once; the demo
    /// account may be added any number of times.
    func isUsernameInUse(_ username: String) -> Bool {
        isUsernameInUse(username, among: accounts)
    }

    // MARK: - Writing

    @discardableResult
    func add(
        username: String,
        password: String,
        accountLocation: AccountLocation,
        displayName: String = "",
        dexcomAccountID: UUID? = nil,
        sessionID: UUID? = nil
    ) throws -> DexcomAccount {
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        var accounts = try loadAccounts()

        guard !isUsernameInUse(username, among: accounts) else {
            throw StoreError.duplicateUsername
        }

        let account = DexcomAccount(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            accountLocation: accountLocation
        )
        try writeCredentials(
            DexcomCredentials(
                username: username,
                password: password,
                dexcomAccountID: dexcomAccountID,
                sessionID: sessionID
            ),
            for: account.id
        )

        accounts.append(account)
        Defaults[accountsKey] = accounts
        return account
    }

    /// Replaces the stored non-secret details (name, location) of an existing account.
    func update(_ account: DexcomAccount) throws {
        var accounts = try loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index] = account
        Defaults[accountsKey] = accounts
    }

    func rename(_ id: DexcomAccount.ID, to displayName: String) throws {
        guard var account = try loadAccounts().first(where: { $0.id == id }) else { return }
        account.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        try update(account)
    }

    /// Reorders the accounts to match `ids`. Accounts missing from `ids` (e.g.
    /// just added on another device) keep their relative order at the end.
    func reorder(_ ids: [DexcomAccount.ID]) throws {
        let accounts = try loadAccounts()
        let positions = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let reordered = accounts.enumerated()
            .sorted { lhs, rhs in
                let left = positions[lhs.element.id] ?? ids.count + lhs.offset
                let right = positions[rhs.element.id] ?? ids.count + rhs.offset
                return left < right
            }
            .map(\.element)
        Defaults[accountsKey] = reordered
    }

    func updateCredentials(_ credentials: DexcomCredentials, for id: DexcomAccount.ID) throws {
        try writeCredentials(credentials, for: id)
    }

    /// Removes the account, its credentials and its cached readings.
    func remove(_ id: DexcomAccount.ID) throws {
        var accounts = try loadAccounts()
        let removedUsername = credentials(for: id)?.username

        accounts.removeAll { $0.id == id }
        Defaults[accountsKey] = accounts

        let keys = CredentialKeys(id)
        for key in keys.all {
            try? credentialStorage.setString(nil, forKey: key)
        }
        cacheSuite.removeObject(forKey: GlucoseReadingsCache.defaultsKeyName(for: id))

        // The legacy items are kept for older app versions on the user's other
        // devices, but once that account is gone they must go too, or the
        // migration would resurrect a signed-out account.
        let legacyUsername = try? credentialStorage.string(forKey: .usernameKey)
        if accounts.isEmpty || (legacyUsername != nil && legacyUsername == removedUsername) {
            for key in [String.usernameKey, .passwordKey, .accountIDKey, .sessionIDKey] {
                try? credentialStorage.setString(nil, forKey: key)
            }
        }
    }

    func setDexcomAccountID(_ dexcomAccountID: UUID, for id: DexcomAccount.ID) {
        try? credentialStorage.setString(dexcomAccountID.uuidString, forKey: CredentialKeys(id).dexcomAccountID)
    }

    func setSessionID(_ sessionID: UUID, for id: DexcomAccount.ID) {
        try? credentialStorage.setString(sessionID.uuidString, forKey: CredentialKeys(id).sessionID)
    }

    /// Changes to the account list made in this process or arriving via iCloud
    /// sync. Writes from other processes (extensions) aren't observed; re-read on
    /// foreground for those.
    func accountListUpdates() -> AsyncStream<[DexcomAccount]?> {
        Defaults.updates(accountsKey, initial: false)
    }

    // MARK: - Private

    private func isUsernameInUse(_ username: String, among accounts: [DexcomAccount]) -> Bool {
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard username != DexcomHelper.mockEmail else { return false }
        return accounts.contains {
            credentials(for: $0.id)?.username.caseInsensitiveCompare(username) == .orderedSame
        }
    }

    private func uuid(forKey key: String) -> UUID? {
        (try? credentialStorage.string(forKey: key)).flatMap(UUID.init(uuidString:))
    }

    private func writeCredentials(_ credentials: DexcomCredentials, for id: DexcomAccount.ID) throws {
        let keys = CredentialKeys(id)
        try credentialStorage.setString(credentials.username, forKey: keys.username)
        try credentialStorage.setString(credentials.password, forKey: keys.password)
        try credentialStorage.setString(credentials.dexcomAccountID?.uuidString, forKey: keys.dexcomAccountID)
        try credentialStorage.setString(credentials.sessionID?.uuidString, forKey: keys.sessionID)
    }

    /// Creates an account from the pre-multi-account keychain items, if any.
    /// Only writes after actually reading the legacy credentials, which proves
    /// the keychain (and the same-protection-class defaults plist) is readable.
    private func migrateLegacyAccount() throws -> [DexcomAccount] {
        // Another device already wrote the list; let iCloud sync deliver it
        // rather than overwrite it with just the legacy account.
        guard !hasRemoteAccounts() else { return [] }

        let username: String?
        let password: String?
        do {
            username = try credentialStorage.string(forKey: .usernameKey)
            password = try credentialStorage.string(forKey: .passwordKey)
        } catch {
            throw StoreError.unavailable
        }

        guard let username, !username.isEmpty,
              let password, !password.isEmpty,
              let accountLocation = Defaults[legacyAccountLocationKey] else {
            return []
        }

        let account = DexcomAccount(id: Self.legacyAccountID, accountLocation: accountLocation)
        try writeCredentials(
            DexcomCredentials(
                username: username,
                password: password,
                dexcomAccountID: uuid(forKey: .accountIDKey),
                sessionID: uuid(forKey: .sessionIDKey)
            ),
            for: account.id
        )

        if let current = Defaults[accountsKey] {
            return current
        }
        Defaults[accountsKey] = [account]
        cacheSuite.removeObject(forKey: GlucoseReadingsCache.legacyDefaultsKeyName)
        return [account]
    }
}

private struct CredentialKeys {
    let username: String
    let password: String
    let dexcomAccountID: String
    let sessionID: String

    var all: [String] { [username, password, dexcomAccountID, sessionID] }

    init(_ id: DexcomAccount.ID) {
        let prefix = "account.\(id.uuidString)."
        username = prefix + "username"
        password = prefix + "password"
        dexcomAccountID = prefix + "accountID"
        sessionID = prefix + "sessionID"
    }
}
