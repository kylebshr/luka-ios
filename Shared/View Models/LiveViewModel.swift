//
//  LiveViewModel.swift
//  Glimpse
//
//  Created by Kyle Bashour on 5/2/24.
//

import Foundation
import KeychainAccess
import Dexcom

@MainActor @Observable class LiveViewModel {
    enum State {
        case initial
        case loaded([GlucoseReading])
        case noRecentReading
        case error(Error)
    }

    var isLoggedIn: Bool {
        username != nil && password != nil
    }

    var outsideUS: Bool = UserDefaults.standard.bool(forKey: .outsideUSKey) {
        didSet {
            if outsideUS != oldValue {
                setUpClientAndBeginRefreshing()
            }
        }
    }

    private(set) var reading: State = .initial
    private(set) var message: String?

    private(set) var username: String? = Keychain.shared[.usernameKey]
    private(set) var password: String? = Keychain.shared[.passwordKey]

    private var client: DexcomClient?
    private let decoder = JSONDecoder()

    private var shouldRefreshReading: Bool {
        switch reading {
        case .initial, .error, .noRecentReading:
            return true
        case .loaded(let readings):
            return readings.last!.date.timeIntervalSinceNow < -60 * 5
        }
    }

    init() {
        decoder.dateDecodingStrategy = .iso8601
        setUpClientAndBeginRefreshing()
    }

    func logIn(username: String, password: String) {
        self.username = username
        self.password = password

        setUpClientAndBeginRefreshing()
    }

    private func setUpClientAndBeginRefreshing() {
        if let username, let password {
            reading = .initial

            client = DexcomClient(
                username: username,
                password: password,
                outsideUS: outsideUS
            )

            beginRefreshing()
        }
    }

    func beginRefreshing() {
        guard let client else { return }

        Task<Void, Never> {
            if shouldRefreshReading {
                print("Refreshing reading")

                do {
                    if let readings = try await client.getChartReadings(duration: .init(value: 24, unit: .hours)) {
                        reading = .loaded(readings)
                    } else {
                        reading = .noRecentReading
                    }
                } catch let error as DexcomError {
                    // Could be too many attempts; stop auto refreshing.
                    reading = .error(error)
                } catch {
                    reading = .error(error)
                }
            }

            updateMessage()

            let refreshTime: TimeInterval? = {
                switch reading {
                case .initial:
                    return nil
                case .loaded(let readings):
                    // 5:10 after the last reading.
                    let fiveMinuteRefresh = 60 * 5 + readings.last!.date.timeIntervalSinceNow + 10
                    // Refresh 5:10 after reading, then every 10s.
                    return max(10, fiveMinuteRefresh)
                case .noRecentReading:
                    return 10
                case .error(let error):
                    if error is DexcomError {
                        return nil
                    } else {
                        return 10
                    }
                }
            }()

            if let refreshTime {
                // Refresh at least every 60s for the time stamp.
                let refreshTime = min(60, refreshTime)

                print("Scheduling refresh in \(refreshTime / 60) minutes")

                Timer.scheduledTimer(withTimeInterval: refreshTime, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async { [weak self] in
                        self?.beginRefreshing()
                    }
                }
            }
        }
    }

    private func updateMessage() {
        switch reading {
        case .initial:
            message = "Loading..."
        case .loaded(let readings):
            if readings.last!.date.timeIntervalSinceNow > -60 {
                message = "Just now"
            } else {
                message = readings.last!.date.formatted(.relative(presentation: .numeric))
            }
        case .noRecentReading:
            message = "No recent glucose readings"
        case .error(let error):
            if error is DexcomError {
                message = "Try refreshing in 10 minutes"
            } else {
                message = "Unknown error"
            }
        }
    }
}
