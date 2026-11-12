//
//  ClientEventReporter.swift
//  Luka
//
//  Created by Claude on 9/12/26.
//

import Defaults
import Foundation
import UIKit

extension Defaults.Keys {
    // Device-local queue of Live Activity lifecycle observations not yet posted to the
    // server. Persisted so a background wake that gets suspended before its upload
    // finishes doesn't lose what it saw. Lives here (app target only) because the shared
    // Defaults file is compiled by targets that don't include the request model.
    static let pendingClientEvents = Key<[QueuedClientEvent]>("pendingClientEvents", default: [], suite: .shared)
}

/// A queued event and the account it's about. Encodes as the event's own fields plus
/// `accountID`, so a queue persisted by an older build (bare events) still decodes.
struct QueuedClientEvent: Codable, Defaults.Serializable, Equatable {
    var event: ClientEventRequest.Event
    /// The account whose activity the event is about; nil for device-level events.
    var accountID: UUID?

    private enum CodingKeys: String, CodingKey {
        case accountID
    }

    init(event: ClientEventRequest.Event, accountID: UUID?) {
        self.event = event
        self.accountID = accountID
    }

    init(from decoder: any Decoder) throws {
        event = try ClientEventRequest.Event(from: decoder)
        accountID = try decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(UUID.self, forKey: .accountID)
    }

    func encode(to encoder: any Encoder) throws {
        try event.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(accountID, forKey: .accountID)
    }
}

/// Records Live Activity lifecycle observations and ships them to the server in batches.
///
/// Events are appended to a persisted queue first, so an observation made during a short
/// background wake survives even if the process is suspended before the upload finishes;
/// it goes out with the next batch. A flush is debounced briefly so the burst of events
/// from one wake (activity observed → token received → registered) becomes one request,
/// and runs under a background task assertion so it completes after the app leaves the
/// foreground.
@MainActor
final class ClientEventReporter {
    private static let maxQueued = 200
    private static let flushDelay: Duration = .seconds(1.5)

    private let client = HTTPClient()
    private var flushTask: Task<Void, Never>?

    /// Records an event. Pass `accountID` for events about one account's activity so
    /// they're reported under that account's username (the server keys sessions and
    /// restart bookkeeping by username); device-level events go under the primary's.
    func record(
        _ name: String,
        activityID: String? = nil,
        accountID: UUID? = nil,
        _ attributes: [String: String] = [:]
    ) {
        let event = ClientEventRequest.Event(
            name: name,
            occurredAt: Date.now.timeIntervalSince1970,
            activityID: activityID,
            // The backend at the time of the observation, so a rollout problem can be
            // attributed even when the event is delivered to the other server.
            attributes: attributes.merging(["backend": Backend.active.rawValue]) { recorded, _ in recorded }
        )
        var queued = Defaults[.pendingClientEvents]
        queued.append(QueuedClientEvent(event: event, accountID: accountID))
        if queued.count > Self.maxQueued {
            queued.removeFirst(queued.count - Self.maxQueued)
        }
        Defaults[.pendingClientEvents] = queued
        scheduleFlush()
    }

    func flushNow() async {
        flushTask?.cancel()
        flushTask = nil
        await flush()
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task {
            try? await Task.sleep(for: Self.flushDelay)
            guard !Task.isCancelled else { return }
            flushTask = nil
            await flush()
        }
    }

    private func flush() async {
        let queued = Defaults[.pendingClientEvents]
        guard !queued.isEmpty else { return }

        // Only a signed-in username makes an event attributable; events whose username
        // can't be read stay queued for a later flush (e.g. after first unlock).
        let accounts = AccountStore.shared.accounts
        var batches: [String: [QueuedClientEvent]] = [:]
        var demoEvents: [QueuedClientEvent] = []
        for item in queued {
            // An account that's since been removed falls back to the primary.
            let account = AccountResolution.accountOrPrimary(for: item.accountID, in: accounts)
            guard let username = account.flatMap({ AccountStore.shared.credentials(for: $0)?.username }) else {
                continue
            }
            if username == DexcomHelper.mockEmail {
                demoEvents.append(item)
            } else {
                batches[username, default: []].append(item)
            }
        }
        // The demo account never registers with the server; its events would otherwise
        // sit in the queue forever.
        if !demoEvents.isEmpty {
            Defaults[.pendingClientEvents].removeAll { demoEvents.contains($0) }
        }

        for (username, batch) in batches {
            let payload = ClientEventRequest(
                username: username,
                systemVersion: UIDevice.current.systemVersion,
                deviceModel: Self.deviceModel,
                events: batch.map(\.event)
            )

            await client.withBackgroundTask(name: "LiveActivity.clientEvents") {
                do {
                    let request = try client.makePostRequest("client-event", body: payload)
                    try await client.send(request)
                    // Drop exactly what was sent; anything recorded mid-flight stays queued.
                    Defaults[.pendingClientEvents].removeAll { batch.contains($0) }
                } catch {
                    // Leave the queue intact for the next flush.
                }
            }
        }
    }

    private static let deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }()
}
