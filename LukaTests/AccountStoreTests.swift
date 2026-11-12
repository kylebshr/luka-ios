//
//  AccountStoreTests.swift
//  LukaTests
//
//  Created by Kyle Bashour on 11/12/26.
//

import Defaults
import Foundation
import Testing
@testable import Dexcom
@testable import Luka

private final class InMemoryCredentialStorage: CredentialStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]
    /// Simulates a keychain that can't be read yet (before first unlock).
    var isLocked = false

    func string(forKey key: String) throws -> String? {
        try lock.withLock {
            if isLocked { throw CocoaError(.fileReadNoPermission) }
            return values[key]
        }
    }

    func setString(_ value: String?, forKey key: String) throws {
        try lock.withLock {
            if isLocked { throw CocoaError(.fileWriteNoPermission) }
            values[key] = value
        }
    }

    var keys: Set<String> {
        lock.withLock { Set(values.keys) }
    }
}

private struct Fixture {
    let suite: UserDefaults
    let credentials = InMemoryCredentialStorage()
    let accountsKey: Defaults.Key<[DexcomAccount]?>
    let locationKey: Defaults.Key<AccountLocation?>

    init() {
        let name = "AccountStoreTests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: name)!
        accountsKey = .init("accounts", default: nil, suite: suite)
        locationKey = .init("accountLocation", default: nil, suite: suite)
    }

    func makeStore(hasRemoteAccounts: Bool = false) -> AccountStore {
        AccountStore(
            accountsKey: accountsKey,
            legacyAccountLocationKey: locationKey,
            credentialStorage: credentials,
            cacheSuite: suite,
            hasRemoteAccounts: { hasRemoteAccounts }
        )
    }

    func writeLegacyAccount(username: String = "legacy@example.com") throws {
        try credentials.setString(username, forKey: "username")
        try credentials.setString("hunter2", forKey: "password")
        try credentials.setString(UUID().uuidString, forKey: "accountID")
        try credentials.setString(UUID().uuidString, forKey: "sessionID")
        Defaults[locationKey] = .apac
    }
}

struct AccountStoreTests {

    // MARK: Migration

    @Test func test_migratesLegacyAccount() throws {
        let fixture = Fixture()
        try fixture.writeLegacyAccount()
        let legacySessionID = try fixture.credentials.string(forKey: "sessionID")
        let store = fixture.makeStore()

        let accounts = try store.loadAccounts()

        #expect(accounts.count == 1)
        let account = try #require(accounts.first)
        #expect(account.id == AccountStore.legacyAccountID)
        #expect(account.accountLocation == .apac)
        #expect(Defaults[fixture.accountsKey] == accounts)

        let credentials = try #require(store.credentials(for: account))
        #expect(credentials.username == "legacy@example.com")
        #expect(credentials.password == "hunter2")
        #expect(credentials.sessionID?.uuidString == legacySessionID)

        // Legacy items stay for older app versions on other devices.
        #expect(try fixture.credentials.string(forKey: "username") == "legacy@example.com")
    }

    @Test func test_migrationIsIdempotent() throws {
        let fixture = Fixture()
        try fixture.writeLegacyAccount()

        // E.g. the app and a widget extension each migrating.
        let first = try fixture.makeStore().loadAccounts()
        Defaults[fixture.accountsKey] = nil
        let second = try fixture.makeStore().loadAccounts()

        #expect(first == second)
        #expect(second.count == 1)
    }

    @Test func test_noMigrationWithoutLegacyAccount() throws {
        let fixture = Fixture()
        let store = fixture.makeStore()

        #expect(try store.loadAccounts().isEmpty)
        // Nothing written, so a later trustworthy read can still migrate.
        #expect(Defaults[fixture.accountsKey] == nil)
    }

    @Test func test_noMigrationWithoutLegacyLocation() throws {
        let fixture = Fixture()
        try fixture.writeLegacyAccount()
        Defaults[fixture.locationKey] = nil

        #expect(try fixture.makeStore().loadAccounts().isEmpty)
        #expect(Defaults[fixture.accountsKey] == nil)
    }

    @Test func test_lockedKeychainIsUnavailableNotSignedOut() throws {
        let fixture = Fixture()
        try fixture.writeLegacyAccount()
        fixture.credentials.isLocked = true
        let store = fixture.makeStore()

        #expect(throws: AccountStore.StoreError.self) {
            try store.loadAccounts()
        }
        #expect(Defaults[fixture.accountsKey] == nil)

        fixture.credentials.isLocked = false
        #expect(try store.loadAccounts().count == 1)
    }

    @Test func test_skipsMigrationWhenICloudHasAccounts() throws {
        let fixture = Fixture()
        try fixture.writeLegacyAccount()

        #expect(try fixture.makeStore(hasRemoteAccounts: true).loadAccounts().isEmpty)
        #expect(Defaults[fixture.accountsKey] == nil)
    }

    @Test func test_existingListIsNotMigratedOver() throws {
        let fixture = Fixture()
        let store = fixture.makeStore()
        let added = try store.add(username: "new@example.com", password: "pw", accountLocation: .usa)
        try fixture.writeLegacyAccount()

        #expect(try store.loadAccounts() == [added])
    }

    // MARK: Adding

    @Test func test_addAppendsAccounts() throws {
        let store = Fixture().makeStore()

        let first = try store.add(username: "a@example.com", password: "pw", accountLocation: .usa)
        let second = try store.add(username: "b@example.com", password: "pw", accountLocation: .worldwide, displayName: " Kid ")

        #expect(try store.loadAccounts() == [first, second])
        #expect(store.primary == first)
        #expect(second.displayName == "Kid")
        #expect(store.displayName(for: first) == "a@example.com")
        #expect(store.displayName(for: second) == "Kid")
    }

    @Test func test_rejectsDuplicateUsername() throws {
        let store = Fixture().makeStore()
        try store.add(username: "a@example.com", password: "pw", accountLocation: .usa)

        #expect(store.isUsernameInUse("A@Example.com "))
        #expect(throws: AccountStore.StoreError.self) {
            try store.add(username: "A@example.com", password: "other", accountLocation: .usa)
        }
        #expect(store.accounts.count == 1)
    }

    @Test func test_allowsDemoAccountMoreThanOnce() throws {
        let store = Fixture().makeStore()
        try store.add(username: DexcomHelper.mockEmail, password: "pw", accountLocation: .usa)
        try store.add(username: DexcomHelper.mockEmail, password: "pw", accountLocation: .usa)

        #expect(store.accounts.count == 2)
    }

    @Test func test_renameAndSessionWriters() throws {
        let store = Fixture().makeStore()
        let account = try store.add(username: "a@example.com", password: "pw", accountLocation: .usa)
        let other = try store.add(username: "b@example.com", password: "pw", accountLocation: .usa)

        try store.rename(account.id, to: "Sam")
        let sessionID = UUID()
        store.setSessionID(sessionID, for: account.id)

        #expect(store.account(id: account.id)?.displayName == "Sam")
        #expect(store.credentials(for: account)?.sessionID == sessionID)
        #expect(store.credentials(for: other)?.sessionID == nil)
    }

    @Test func test_reorderChangesPrimaryAndKeepsUnlistedAccounts() throws {
        let store = Fixture().makeStore()
        let a = try store.add(username: "a@example.com", password: "pw", accountLocation: .usa)
        let b = try store.add(username: "b@example.com", password: "pw", accountLocation: .usa)
        let c = try store.add(username: "c@example.com", password: "pw", accountLocation: .usa)

        try store.reorder([c.id, a.id])

        #expect(try store.loadAccounts() == [c, a, b])
        #expect(store.primary == c)
    }

    // MARK: Removing

    @Test func test_removeDeletesCredentialsAndCache() throws {
        let fixture = Fixture()
        let store = fixture.makeStore()
        let account = try store.add(username: "a@example.com", password: "pw", accountLocation: .usa)
        let other = try store.add(username: "b@example.com", password: "pw", accountLocation: .usa)
        Defaults[.cachedReadings(for: account.id, suite: fixture.suite)] = GlucoseReadingsCache(readings: [], duration: 60)

        try store.remove(account.id)

        #expect(store.accounts == [other])
        #expect(store.credentials(for: account) == nil)
        #expect(Defaults[.cachedReadings(for: account.id, suite: fixture.suite)] == nil)
        #expect(!fixture.credentials.keys.contains { $0.contains(account.id.uuidString) })
    }

    @Test func test_removingLastAccountClearsLegacyItems() throws {
        let fixture = Fixture()
        try fixture.writeLegacyAccount()
        let store = fixture.makeStore()
        let migrated = try #require(store.loadAccounts().first)

        try store.remove(migrated.id)

        #expect(store.accounts.isEmpty)
        #expect(Defaults[fixture.accountsKey] == [])
        #expect(try fixture.credentials.string(forKey: "username") == nil)
        #expect(try fixture.credentials.string(forKey: "password") == nil)
        // And the migration can't bring it back.
        #expect(try fixture.makeStore().loadAccounts().isEmpty)
    }

    @Test func test_removingOtherAccountKeepsLegacyItems() throws {
        let fixture = Fixture()
        try fixture.writeLegacyAccount()
        let store = fixture.makeStore()
        _ = try store.loadAccounts()
        let added = try store.add(username: "b@example.com", password: "pw", accountLocation: .usa)

        try store.remove(added.id)

        #expect(try fixture.credentials.string(forKey: "username") == "legacy@example.com")
    }

    @Test func test_removingMigratedAccountClearsLegacyItemsEvenWithOthers() throws {
        let fixture = Fixture()
        try fixture.writeLegacyAccount()
        let store = fixture.makeStore()
        let migrated = try #require(store.loadAccounts().first)
        try store.add(username: "b@example.com", password: "pw", accountLocation: .usa)

        try store.remove(migrated.id)

        #expect(store.accounts.count == 1)
        #expect(try fixture.credentials.string(forKey: "username") == nil)
    }
}

// MARK: - Readings cache

private final class StubDexcomClient: DexcomClientService, @unchecked Sendable {
    let readings: [GlucoseReading]
    private(set) var fetchCount = 0

    init(value: Int) {
        readings = [GlucoseReading(value: value, trend: .flat, date: .now.addingTimeInterval(-60))]
    }

    func setDelegate(_ delegate: DexcomClientDelegate?) async {}

    func getGlucoseReadings(duration: Measurement<UnitDuration>, maxCount: Int) async throws -> [GlucoseReading] {
        fetchCount += 1
        return readings
    }

    func getLatestGlucoseReading() async throws -> GlucoseReading? {
        fetchCount += 1
        return readings.last
    }

    func getCurrentGlucoseReading() async throws -> GlucoseReading? {
        try await getLatestGlucoseReading()
    }

    func createSession() async throws -> (accountID: UUID, sessionID: UUID) {
        (UUID(), UUID())
    }
}

struct CachingDexcomClientTests {

    @Test func test_cacheIsIsolatedPerAccount() async throws {
        let suite = UserDefaults(suiteName: "CachingDexcomClientTests.\(UUID().uuidString)")!
        let stubA = StubDexcomClient(value: 100)
        let stubB = StubDexcomClient(value: 200)
        let clientA = CachingDexcomClient(wrapping: stubA, accountID: UUID(), suite: suite)
        let clientB = CachingDexcomClient(wrapping: stubB, accountID: UUID(), suite: suite)

        let readingsA = try await clientA.getGlucoseReadings()
        let readingsB = try await clientB.getGlucoseReadings()

        #expect(readingsA.map(\.value) == [100])
        #expect(readingsB.map(\.value) == [200])
        #expect(stubB.fetchCount == 1)

        // A second read for A is served from A's own cache.
        let cachedA = try await clientA.getLatestGlucoseReading()
        #expect(cachedA?.value == 100)
        #expect(stubA.fetchCount == 1)
    }
}
