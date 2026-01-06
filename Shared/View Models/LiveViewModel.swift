//
//  LiveViewModel.swift
//  Luka
//
//  Created by Kyle Bashour on 5/2/24.
//

#if canImport(ActivityKit)
import ActivityKit
#endif
import Defaults
import Dexcom
import Foundation
import KeychainAccess

@MainActor @Observable class LiveViewModel {
    enum State {
        case initial
        case loaded([GlucoseReading], latest: GlucoseReading)
        case noRecentReading
        case error(Error)
    }

    private(set) var state: State = .initial
    private(set) var message: String = LiveViewModel.message(for: .initial)

    @ObservationIgnored private lazy var username: String? = Keychain.shared.username
    @ObservationIgnored private lazy var password: String? = Keychain.shared.password
    @ObservationIgnored private lazy var accountLocation: AccountLocation? = Defaults[.accountLocation]

    @ObservationIgnored private var timestampTimer: Timer?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var client: DexcomClientService?
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private let delegate = KeychainDexcomDelegate()

    var messageValue: TimeInterval {
        switch state {
        case .initial, .noRecentReading, .error: 0
        case .loaded(_, let latest): latest.date.timeIntervalSince1970
        }
    }

    private var shouldRefreshReading: Bool {
        switch state {
        case .initial, .error, .noRecentReading:
            return true
        case .loaded(_, let latest):
            return latest.date.timeIntervalSinceNow < -60 * 5
        }
    }
    init() {
        decoder.dateDecodingStrategy = .iso8601
        timestampTimer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateMessageIfNeeded()
            }
        }
    }

    func setUpClientAndBeginRefreshing() {
        Task {
            if let username, let password, let accountLocation {
                client = DexcomHelper.createService(
                    username: username,
                    password: password,
                    existingAccountID: Keychain.shared.accountID,
                    existingSessionID: Keychain.shared.sessionID,
                    accountLocation: accountLocation
                )
                await client?.setDelegate(delegate)
                beginRefreshing()
            }
        }
    }

    func beginRefreshing() {
        guard let client else { return }

        Task<Void, Never> {
            if shouldRefreshReading {
                print("Refreshing reading")

                do {
                    let readings = try await client.getGlucoseReadings()
                        .sorted { $0.date < $1.date }
                    if let latest = readings.last {
                        state = .loaded(readings, latest: latest)
                        updateLiveActivityIfActive()
                    } else {
                        state = .noRecentReading
                    }
                } catch {
                    state = .error(error)
                }
            }

            updateMessageIfNeeded()

            let refreshTime: TimeInterval? = {
                switch state {
                case .initial:
                    return nil
                case .loaded(_, let latest):
                    // 5:10 after the last reading.
                    let fiveMinuteRefresh = 60 * 5 + latest.date.timeIntervalSinceNow + 10
                    // Refresh 5:10 after reading, then every 10s.
                    return max(10, fiveMinuteRefresh)
                case .noRecentReading:
                    return 5
                case .error(let error):
                    if error is DexcomError {
                        return nil
                    } else {
                        return 5
                    }
                }
            }()

            if let refreshTime {
                // Refresh at least every 60s for the time stamp.
                let refreshTime = min(60, refreshTime)

                print("Scheduling refresh in \(refreshTime / 60) minutes")

                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: refreshTime, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async { [weak self] in
                        self?.beginRefreshing()
                    }
                }
            }
        }
    }

    private func updateMessageIfNeeded() {
        let updated = Self.message(for: state)
        if updated != message {
            message = updated
        }
    }

    private static func message(for state: State) -> String {
        switch state {
        case .initial:
            return "Updating"
        case .loaded(_, let latest):
            return latest.timestamp(for: .now)
        case .noRecentReading:
            return "No recent readings"
        case .error(let error):
            if error is DexcomError {
                // Will not automatically update
                return "Error loading readings"
            } else {
                // Will automatically update
                return "Updating"
            }
        }
    }

    func updateLiveActivityIfActive() {
        #if canImport(ActivityKit)
        guard case .loaded(let readings, let latest) = state else { return }
        guard let activity = Activity<ReadingAttributes>.activities.first else { return }

        // Only update if the activity is not stale (stale means it's offline/disconnected from server)
        guard activity.activityState == .active else { return }

        let newState = LiveActivityState(readings: readings, range: activity.attributes.range)

        let content = ActivityContent(
            state: newState,
            staleDate: latest.date.addingTimeInterval(10 * 60)
        )

        Task {
            await activity.update(content)
        }
        #endif
    }
}
