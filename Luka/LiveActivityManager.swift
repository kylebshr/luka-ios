//
//  LiveActivityManager.swift
//  Luka
//
//  Created by Claude on 1/2/26.
//

import ActivityKit
import Defaults
import Foundation
import WidgetKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var observationTasks: [String: Task<Void, Never>] = [:]
    private var activityUpdatesTask: Task<Void, Never>?

    private init() {
        // Observe existing activities
        for activity in Activity<ReadingAttributes>.activities {
            observeActivity(activity)
        }
        syncState()

        // Observe new activities as they're created
        activityUpdatesTask = Task {
            for await activity in Activity<ReadingAttributes>.activityUpdates {
                observeActivity(activity)
                syncState()
            }
        }
    }

    func syncState() {
        let hasActivities = !Activity<ReadingAttributes>.activities.isEmpty
        if Defaults[.isLiveActivityRunning] != hasActivities {
            Defaults[.isLiveActivityRunning] = hasActivities
            ControlCenter.shared.reloadAllControls()
        }
    }

    private func observeActivity(_ activity: Activity<ReadingAttributes>) {
        guard observationTasks[activity.id] == nil else { return }

        observationTasks[activity.id] = Task {
            for await state in activity.activityStateUpdates {
                switch state {
                case .dismissed, .ended:
                    observationTasks.removeValue(forKey: activity.id)
                    syncState()
                    return
                case .active, .pending, .stale:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}
