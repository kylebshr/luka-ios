//
//  ClientEventRequest.swift
//  Luka
//
//  Created by Claude on 9/12/26.
//

import Defaults
import Foundation

/// A batch of Live Activity lifecycle observations posted to `client-event`, so what the
/// device saw lands in the server's telemetry next to what the server did — with the
/// device's own timestamps, since a batch from a background wake can be sent later.
struct ClientEventRequest: Codable {
    struct Event: Codable, Defaults.Serializable, Equatable {
        var name: String
        /// Seconds since 1970 on the device clock, when the event happened.
        var occurredAt: Double
        var activityID: String?
        var attributes: [String: String]?
    }

    var username: String
    var systemVersion: String?
    var deviceModel: String?
    var events: [Event]
}
