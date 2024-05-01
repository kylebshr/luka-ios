//
//  ReadingTimelineProvider.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/1/24.
//

import WidgetKit
import Dexcom
import KeychainAccess

struct ReadingTimelineProvider: TimelineProvider, DexcomTimelineProvider {
    typealias Entry = GlucoseEntry<GlucoseReading>

    let delegate = DexcomDelegate()

    func placeholder(in context: Context) -> Entry {
        GlucoseEntry(date: .now, state: .reading(.placeholder))
    }
    
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        Task<Void, Never> {
            completion(Entry(date: .now, state: await makeState()))
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task<Void, Never> {
            completion(buildTimeline(for: await makeState()))
        }
    }

    private func makeState() async -> Entry.State {
        guard let username = Keychain.shared.username, let password = Keychain.shared.password else {
            return .error(.loggedOut)
        }

        let client = makeClient(username: username, password: password)

        do {
            if let current = try await client.getLatestGlucoseReading(), Date.now.timeIntervalSince(current.date) < 60 * 15 {
                return .reading(current)
            } else {
                return .error(.noRecentReadings)
            }
        } catch {
            return .error(.failedToLoad)
        }
    }
}
