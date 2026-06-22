//
//  PushEnvironment.swift
//  Luka
//
//  Created by Kyle Bashour on 10/19/25.
//


import Foundation
import Dexcom

enum PushEnvironment: String, Codable {
    case development
    case production

    static var current: Self {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }
}

struct LiveActivityPreferences: Codable {
    var targetRange: ClosedRange<Int>
    var unit: GlucoseFormatter.Unit
    var alertsEnabled: Bool?
}

struct StartLiveActivityRequest: Codable {
    /// Stable per-activity identity (ActivityKit's `Activity.id`). Always sent so the
    /// server can map a rotated push token back to the same activity.
    var activityID: String
    var pushToken: String
    var environment: PushEnvironment
    var username: String?
    var password: String?
    var accountLocation: AccountLocation
    var duration: TimeInterval
    var preferences: LiveActivityPreferences?

    /// Push-to-start token for this device, so the server can auto-restart the
    /// Live Activity when it ends because the time limit was reached.
    var pushToStartToken: String?
    /// The ActivityAttributes type name, replayed by the server in the start push.
    var attributesType: String?
    /// The activity's static attributes, replayed by the server in the start push.
    /// Stored as opaque JSON so this shared model stays decoupled from `ReadingAttributes`
    /// (which isn't a member of every target that compiles this file, e.g. the Watch).
    var attributes: JSONValue?
}

/// A minimal, Foundation-only recursive JSON value. Lets the request carry the activity's
/// attributes opaquely without depending on the `ReadingAttributes` type, mirroring the
/// server. Encode any `Encodable` into one via `init(encoding:)`.
enum JSONValue: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// Builds a `JSONValue` by round-tripping any `Encodable` through JSON.
    init(encoding value: some Encodable) throws {
        let data = try JSONEncoder().encode(value)
        self = try JSONDecoder().decode(JSONValue.self, from: data)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
