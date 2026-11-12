//
//  PreviewAccounts.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

#if DEBUG
import Defaults
import Dexcom
import Foundation

/// Demo accounts for previews, kept in memory so previews never touch the real
/// keychain or account list.
@MainActor enum PreviewAccounts {
    /// Readings shown immediately for preview accounts, so a snapshot doesn't
    /// catch them still loading. Each account's are offset to vary the colors.
    private(set) static var readings: [DexcomAccount.ID: [GlucoseReading]] = [:]
    private static let offsets = [0, 70, -45, 30]

    /// An account store holding one demo account per name. The demo username
    /// may be added any number of times and always yields mock readings.
    static func store(names: [String]) -> AccountStore {
        let suite = UserDefaults(suiteName: "PreviewAccounts.\(UUID().uuidString)")!
        let store = AccountStore(
            accountsKey: .init("accounts", default: nil, suite: suite),
            legacyAccountLocationKey: .init("accountLocation", default: nil, suite: suite),
            credentialStorage: InMemoryCredentialStorage(),
            cacheSuite: suite,
            hasRemoteAccounts: { false }
        )
        for (index, name) in names.enumerated() {
            guard let account = try? store.add(
                username: DexcomHelper.mockEmail,
                password: "password",
                accountLocation: .usa,
                displayName: name
            ) else { continue }
            let offset = offsets[index % offsets.count]
            readings[account.id] = [GlucoseReading].placeholder.map {
                GlucoseReading(value: max(40, $0.value + offset), trend: $0.trend, date: $0.date)
            }
        }
        return store
    }

    static func rootViewModel(names: [String]) -> RootViewModel {
        RootViewModel(store: store(names: names))
    }

    /// A view model showing mock readings for a single demo account.
    static func liveViewModel(name: String = "Mom") -> LiveViewModel {
        let store = store(names: [name])
        let account = store.accounts[0]
        let model = LiveViewModel(account: account, store: store)
        model.showPreviewReadings(readings[account.id] ?? [])
        return model
    }
}

private final class InMemoryCredentialStorage: CredentialStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func string(forKey key: String) throws -> String? {
        lock.withLock { values[key] }
    }

    func setString(_ value: String?, forKey key: String) throws {
        lock.withLock { values[key] = value }
    }
}
#endif
