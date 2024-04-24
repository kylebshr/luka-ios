//
//  CloudDefaultsSync.swift
//  Hako
//
//  Created by Kyle Bashour on 3/5/24.
//

import Foundation
import SwiftUI

class CloudDefaults {
    enum ChangeReason {
        case serverChange
        case initialSyncChange
        case quotaViolationChange
        case accountChange

        init?(rawValue: Int) {
            switch rawValue {
            case NSUbiquitousKeyValueStoreServerChange:
                self = .serverChange
            case NSUbiquitousKeyValueStoreInitialSyncChange:
                self = .initialSyncChange
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                self = .quotaViolationChange
            case NSUbiquitousKeyValueStoreAccountChange:
                self = .accountChange
            default:
                assertionFailure("Unknown NSUbiquitousKeyValueStoreChangeReason \(rawValue)")
                return nil
            }
        }
    }

    func initialize() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangeExternally),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: UserDefaults.shared
        )

        if NSUbiquitousKeyValueStore.default.synchronize() == false {
            fatalError("Failed to synchronize NSUbiquitousKeyValueStore")
        }
    }

    func teardown() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func didChangeExternally(notification: Notification) {
        let reasonRaw = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int ?? -1
        let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
        let reason = ChangeReason(rawValue: reasonRaw)

        switch reason {
        case .serverChange, .none:
            syncKeysToDefaults(keys)
        case .initialSyncChange:
            syncAllValuesToDefaults()
        case .accountChange:
            syncAllValuesToDefaults()
        case .quotaViolationChange:
            break
        }
    }

    private func withoutObservingDefaults(_ perform: () -> Void) {
        NotificationCenter.default.removeObserver(
            self,
            name: UserDefaults.didChangeNotification,
            object: UserDefaults.shared
        )

        perform()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: UserDefaults.shared
        )
    }

    private func syncKeysToDefaults(_ keys: [String]) {
        withoutObservingDefaults {
            for key in keys {
                let object = NSUbiquitousKeyValueStore.default.object(forKey: key)
                UserDefaults.shared.set(object, forKey: key)
            }
        }
    }

    private func syncAllValuesToDefaults() {
        withoutObservingDefaults {
            for (key, object) in NSUbiquitousKeyValueStore.default.dictionaryRepresentation {
                UserDefaults.shared.set(object, forKey: key)
            }
        }
    }

    @objc private func userDefaultsDidChange(notification: Notification) {
        guard let defaults = notification.object as? UserDefaults, defaults == .shared else {
            return
        }

        for (key, object) in defaults.dictionaryRepresentation() {
            if key.hasCloudPrefix() {
                NSUbiquitousKeyValueStore.default.set(object, forKey: key)
            }
        }
    }
}
