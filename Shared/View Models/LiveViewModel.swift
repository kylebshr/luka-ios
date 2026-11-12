//
//  LiveViewModel.swift
//  Luka
//
//  Created by Kyle Bashour on 5/2/24.
//

import Defaults
import Dexcom
import Foundation

@MainActor @Observable class LiveViewModel {
    enum State {
        case initial
        case loaded([GlucoseReading], latest: GlucoseReading)
        case noRecentReading
        case error(Error)
    }

    private(set) var state: State = .initial
    private(set) var message: String = LiveViewModel.message(for: .initial)

    let account: DexcomAccount
    @ObservationIgnored private let store: AccountStore
    @ObservationIgnored private var isStopped = false

    @ObservationIgnored private var timestampTimer: Timer?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var client: DexcomClientService?
    @ObservationIgnored private let decoder = JSONDecoder()

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
    init(account: DexcomAccount, store: AccountStore = .shared) {
        self.account = account
        self.store = store
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
            if let client = await DexcomHelper.createService(for: account, store: store), !isStopped {
                self.client = client
                beginRefreshing()
            }
        }
    }

    /// Stops all timers, e.g. once the account is signed out. The view model
    /// can't be restarted afterwards.
    func stopRefreshing() {
        isStopped = true
        timestampTimer?.invalidate()
        timer?.invalidate()
        client = nil
    }

    func beginRefreshing() {
        guard let client, !isStopped else { return }

        Task<Void, Never> {
            if shouldRefreshReading {
                print("Refreshing reading")

                do {
                    let readings = try await client.getGlucoseReadings()
                        .sorted { $0.date < $1.date }
                    if let latest = readings.last {
                        state = .loaded(readings, latest: latest)
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
}

#if DEBUG
extension LiveViewModel {
    /// Shows `readings` right away instead of fetching, for previews.
    func showPreviewReadings(_ readings: [GlucoseReading]) {
        stopRefreshing()
        state = readings.last.map { .loaded(readings, latest: $0) } ?? .noRecentReading
        updateMessageIfNeeded()
    }
}
#endif
