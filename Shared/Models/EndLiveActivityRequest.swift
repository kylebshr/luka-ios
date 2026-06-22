//
//  EndLiveActivityRequest.swift
//  Luka
//
//  Created by Kyle Bashour on 10/20/25.
//


import Foundation

struct EndLiveActivityRequest: Codable {
    var username: String
    /// Stable per-activity identity (ActivityKit's `Activity.id`); the server's sole match key.
    var activityID: String
}

struct EndLiveActivitiesRequest: Codable {
    var username: String
}

/// Debug-only: asks the server to manually trigger a push-to-start restart for one activity.
struct DebugRestartLiveActivityRequest: Codable {
    var username: String
    /// Stable per-activity identity (ActivityKit's `Activity.id`); the server's sole match key.
    var activityID: String
}
