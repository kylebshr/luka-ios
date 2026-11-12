//
//  Backend.swift
//  Luka
//
//  Created by Kyle Bashour on 12/18/25.
//

import Defaults
import Foundation

/// The Luka servers. Hosts are compiled in, never remotely configured: the app sends
/// Dexcom credentials to them, so remote config may only choose between these.
enum Backend: String, CaseIterable, Codable, Defaults.Serializable {
    case fly
    case cloudflare
    case local

    // PLACEHOLDER: replace with the Worker's production URL before shipping.
    static let cloudflareURL = URL(string: "https://luka.example.workers.dev")!

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
            bucket: rolloutBucket
        )
    }

    static func resolve(preference: BackendPreference, rollout: Double, bucket: Double) -> Backend {
        switch preference {
        case .automatic: bucket < rollout ? .cloudflare : .fly
        case .cloudflare: .cloudflare
        case .fly: .fly
        }
    }

    /// The fraction of installs to move to Cloudflare, from meta.json's `cloudflareRollout`.
    /// Missing counts as none; out-of-range values are clamped.
    static func sanitizedRollout(_ value: Double?) -> Double {
        guard let value, !value.isNaN else { return 0 }
        return min(max(value, 0), 1)
    }

    /// This install's stable position in the rollout, in `0..<1`.
    static var rolloutBucket: Double {
        if let bucket = Defaults[.backendRolloutBucket] {
            return bucket
        }
        let bucket = Double.random(in: 0..<1)
        Defaults[.backendRolloutBucket] = bucket
        return bucket
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
