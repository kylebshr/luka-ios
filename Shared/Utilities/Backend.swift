//
//  Backend.swift
//  Luka
//
//  Created by Kyle Bashour on 12/18/25.
//

import CryptoKit
import Defaults
import Foundation
import KeychainAccess

/// The Luka servers. Hosts are compiled in, never remotely configured: the app sends
/// Dexcom credentials to them, so remote config may only choose between these.
enum Backend: String, CaseIterable, Codable, Defaults.Serializable {
    case fly
    case cloudflare
    case local

    static let cloudflareURL = URL(string: "https://luka.a1c.dev")!

    /// The production backends; either may hold a session for this install.
    static let deployed: [Backend] = [.fly, .cloudflare]

    /// The backend for new Live Activities and for calls not tied to one activity.
    static var current: Self {
//        #if DEBUG
//        return .local
//        #endif
        resolve(
            preference: Defaults[.backendPreference],
            rollout: Defaults[.cloudflareRollout],
            bucket: Keychain.shared.username.map(rolloutBucket(username:))
        )
    }

    /// With no bucket (no signed-in username), Automatic stays on Fly.
    static func resolve(preference: BackendPreference, rollout: Double, bucket: Double?) -> Backend {
        switch preference {
        case .automatic:
            guard let bucket else { return .fly }
            return bucket < rollout ? .cloudflare : .fly
        case .cloudflare:
            return .cloudflare
        case .fly:
            return .fly
        }
    }

    /// The fraction of installs to move to Cloudflare, from meta.json's `cloudflareRollout`.
    /// Missing counts as none; out-of-range values are clamped.
    static func sanitizedRollout(_ value: Double?) -> Double {
        guard let value, !value.isNaN else { return 0 }
        return min(max(value, 0), 1)
    }

    /// The Dexcom account's position in the rollout, in `0..<1`. Derived from the username
    /// rather than per install so every device on an account lands on the same backend:
    /// two backends polling one account doubles its Dexcom request rate.
    static func rolloutBucket(username: String) -> Double {
        let normalized = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let prefix = SHA256.hash(data: Data(normalized.utf8)).prefix(8).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        // The top 53 bits fill a Double's mantissa exactly, so the result is always < 1.
        return Double(prefix >> 11) / Double(UInt64(1) << 53)
    }

    var name: String {
        switch self {
        case .fly: "Fly"
        case .cloudflare: "Cloudflare"
        case .local: "Local"
        }
    }

    var baseURL: URL {
        switch self {
        case .fly:
            URL(string: "https://luka-vapor-v2.fly.dev")!
        case .cloudflare:
            Self.cloudflareURL
        case .local:
            URL(string: "http://localhost:8080")!
        }
    }

    func url(for path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }
}

/// The "Server" setting. An explicit choice overrides the remote rollout either way.
enum BackendPreference: String, CaseIterable, Defaults.Serializable {
    case automatic
    case cloudflare
    case fly
}
