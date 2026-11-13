//
//  LiveActivityButton.swift
//  Luka
//
//  Created by Kyle Bashour on 11/12/26.
//

import Defaults
import SwiftUI

/// Starts and ends Live Activities: one account's, or with a nil account every
/// account's. With every account, any running activity makes it an end button,
/// so it never starts the rest while some are running.
@MainActor struct LiveActivityToggle {
    var account: DexcomAccount?

    func isRunning(anyRunning: Bool, runningAccountIDs: Set<DexcomAccount.ID>) -> Bool {
        if let account {
            runningAccountIDs.contains(account.id)
        } else {
            anyRunning
        }
    }

    /// Ends the running activities, or starts them when none are. Returns whether it started.
    func toggle(isRunning: Bool) async throws -> Bool {
        if isRunning {
            _ = try await EndLiveActivityIntent(account: account).perform()
        } else {
            _ = try await StartLiveActivityIntent(source: "App", account: account).perform()
        }
        LiveActivityManager.shared.syncState()
        return !isRunning
    }

    /// `toggle(isRunning:)` with haptic feedback. Errors are reported only by the haptic.
    func toggleWithFeedback(isRunning: Bool, onStart: () -> Void) async {
        do {
            let didStart = try await toggle(isRunning: isRunning)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if didStart {
                onStart()
            }
        } catch {
            print("Failed to toggle Live Activity: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

/// The prominent capsule button pinned to the bottom of the main screen and of
/// a pushed account detail.
struct LiveActivityButton: View {
    /// Nil for every account.
    var account: DexcomAccount?
    /// Called after a start, e.g. to ask for support.
    var onStart: () -> Void = {}

    @Default(.isLiveActivityRunning) private var anyRunning
    @Default(.liveActivityAccountIDs) private var runningAccountIDs

    @State private var isLoading = false

    private var toggle: LiveActivityToggle {
        LiveActivityToggle(account: account)
    }

    private var isRunning: Bool {
        toggle.isRunning(anyRunning: anyRunning, runningAccountIDs: runningAccountIDs)
    }

    var body: some View {
        Button {
            Task {
                guard !isLoading else { return }
                isLoading = true
                defer { isLoading = false }
                await toggle.toggleWithFeedback(isRunning: isRunning, onStart: onStart)
            }
        } label: {
            HStack {
                ZStack {
                    Image(systemName: "stop.fill").opacity(isRunning ? 1 : 0)
                    Image(systemName: "bolt.fill").opacity(isRunning ? 0 : 1)
                }
                Text(isRunning ? "End Live Activity" : "Start Live Activity")
            }
            .animation(nil, value: isLoading)
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    ProgressView().tint(.primary)
                }
            }
            .foregroundStyle(isRunning ? .white : Color(.label))
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .modifier {
            if #available(iOS 26, *) {
                $0.buttonStyle(.glassProminent)
            } else {
                $0.buttonStyle(.borderedProminent)
            }
        }
        .tint(isRunning ? .accent : inactiveTintColor)
        .withReadableWidth()
        .padding()
        .frame(maxWidth: .infinity)
        .buttonBorderShape(.capsule)
    }

    private var inactiveTintColor: Color {
        if #available(iOS 26, *) {
            .clear
        } else {
            Color(.systemGroupedBackground)
        }
    }
}
