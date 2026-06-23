//
//  Defaults.swift
//  Luka
//
//  Created by Kyle Bashour on 4/24/24.
//

import Foundation
import Dexcom
import Defaults

extension UserDefaults {
    /// UserDefaults is thread-safe for reads/writes
    nonisolated(unsafe) static let shared = UserDefaults(suiteName: "group.com.kylebashour.Glimpse")!
}

extension Defaults.Keys {
    static let targetRangeLowerBound = Key<Double>(.targetRangeLowerBound, default: 70, suite: .shared, iCloud: true)
    static let targetRangeUpperBound = Key<Double>(.targetRangeUpperBound, default: 180, suite: .shared, iCloud: true)
    static let graphUpperBound = Key<Double>(.graphUpperBound, default: 300, suite: .shared, iCloud: true)
    static let accountLocation = Key<AccountLocation?>(.accountLocation, default: nil, suite: .shared, iCloud: true)
    static let unit = Key<GlucoseFormatter.Unit>("unit", default: .mgdl, suite: .shared, iCloud: true)
    static let showChartLiveActivity = Key<Bool>(.showChartLiveActivity, default: true, suite: .shared, iCloud: true)
    static let appGraphStyle = Key<GraphStyle>("appGraphStyle", default: .dots, suite: .shared, iCloud: true)
    static let liveActivityGraphStyle = Key<GraphStyle>("liveActivityGraphStyle", default: .dots, suite: .shared, iCloud: true)
    static let liveActivityAlertsEnabled = Key<Bool>("liveActivityAlertsEnabled", default: true, suite: .shared, iCloud: true)
    static let liveActivityTapApp = Key<LaunchableApp>("liveActivityTapApp", default: .luka, suite: .shared, iCloud: true)

    static let selectedRange = Key("selectedRange", default: GraphRange.eightHours, iCloud: true)
    static let selectedLandscapeRange = Key("landscapeRange", default: GraphRange.twentyFourHours, iCloud: true)
    static let dismissedBannerIDs = Key<Set<String>>("dismissedBannerIDs", default: [], suite: .shared, iCloud: true)
    static let sessionHistory = Key<[DexcomSessionHistoryEntry]>(
        .sessionHistory,
        default: [],
        suite: .shared,
        iCloud: true
    )
    static let launchCount = Key<Int>("launchCount", default: 0, suite: .shared, iCloud: true)
    static let isLiveActivityRunning = Key<Bool>("isLiveActivityRunning", default: false, suite: .shared)
    static let cachedReadings = Key<GlucoseReadingsCache?>("cachedReadings", default: nil, suite: .shared)
    static let useReadingsProxy = Key<Bool>("useReadingsProxy", default: true, suite: .shared, iCloud: true)
    static let debugInfo = Key<Bool>("debugInfo", default: false, suite: .shared)
    static let autoRestartLiveActivity = Key<Bool>("autoRestartLiveActivity", default: false, suite: .shared, iCloud: true)
    // Device-local (not iCloud-synced): the push-to-start token is per-install and must
    // not leak to another device. Persisted so a token rotation that background-relaunches
    // the app can still hand it to the server before the PTS stream re-yields.
    static let pushToStartToken = Key<String?>("pushToStartToken", default: nil, suite: .shared)
}

extension AccountLocation: Defaults.Serializable {}
extension GlucoseFormatter.Unit: Defaults.Serializable {}

struct DexcomSessionHistoryEntry: Defaults.Serializable, Identifiable, Codable, Equatable {
    var sessionID: UUID
    var recordedAt: Date
    var source: String

    var id: UUID { sessionID }

    init(sessionID: UUID, recordedAt: Date = .now, source: String) {
        self.sessionID = sessionID
        self.recordedAt = recordedAt
        self.source = source

    }
}
