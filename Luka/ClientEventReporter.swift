//
//  ClientEventReporter.swift
//  Luka
//
//  Created by Claude on 9/12/26.
//

import Defaults
import Foundation
import KeychainAccess
import UIKit

extension Defaults.Keys {
    // Device-local queue of Live Activity lifecycle observations not yet posted to the
    // server. Persisted so a background wake that gets suspended before its upload
    // finishes doesn't lose what it saw. Lives here (app target only) because the shared
    // Defaults file is compiled by targets that don't include the request model.
    static let pendingClientEvents = Key<[ClientEventRequest.Event]>("pendingClientEvents", default: [], suite: .shared)
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

    func record(_ name: String, activityID: String? = nil, _ attributes: [String: String] = [:]) {
        let event = ClientEventRequest.Event(
            name: name,
            occurredAt: Date.now.timeIntervalSince1970,
            activityID: activityID,
            attributes: attributes.isEmpty ? nil : attributes
        )
        var queued = Defaults[.pendingClientEvents]
        queued.append(event)
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
        // Only the signed-in username makes an event attributable; without one, keep the
        // queue for a later flush after sign-in.
        guard let username = Keychain.shared.username, username != DexcomHelper.mockEmail else { return }
        let batch = Defaults[.pendingClientEvents]
        guard !batch.isEmpty else { return }

        let payload = ClientEventRequest(
            username: username,
            systemVersion: UIDevice.current.systemVersion,
            deviceModel: Self.deviceModel,
            events: batch
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

    private static let deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }()
}
