//
//  LiveActivityDebugView.swift
//  Luka
//
//  Created by Claude on 5/30/26.
//

import ActivityKit
import Defaults
import SwiftUI

struct LiveActivityDebugView: View {
    /// Bumped to force the view to re-read `Activity.activities` and pick up state/content changes.
    @State private var refreshToken = 0

    private var authInfo = ActivityAuthorizationInfo()

    private var activities: [Activity<ReadingAttributes>] {
        // `refreshToken` is read so SwiftUI re-evaluates when we bump it.
        _ = refreshToken
        return Activity<ReadingAttributes>.activities
    }

    var body: some View {
        List {
            Section("Authorization") {
                LabeledContent("Activities enabled", value: authInfo.areActivitiesEnabled ? "Yes" : "No")
                LabeledContent("Frequent pushes", value: authInfo.frequentPushesEnabled ? "Yes" : "No")
                LabeledContent("Running activities", value: "\(activities.count)")
                LabeledContent("isLiveActivityRunning", value: Defaults[.isLiveActivityRunning] ? "true" : "false")
            }

            if activities.isEmpty {
                Section {
                    Text("No Live Activities are currently running.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(activities, id: \.id) { activity in
                activitySection(activity)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Live Activity Debug")
        .fontDesign(.rounded)
        .toolbar {
            Button {
                refreshToken += 1
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
        .task {
            // Refresh when activities are added or removed.
            for await _ in Activity<ReadingAttributes>.activityUpdates {
                refreshToken += 1
            }
        }
        .task {
            // Poll so state/content changes (and stale-date crossings) stay current.
            while !Task.isCancelled {
                refreshToken += 1
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    @ViewBuilder
    private func activitySection(_ activity: Activity<ReadingAttributes>) -> some View {
        let content = activity.content
        let state = content.state

        Section {
            LabeledContent("ID") {
                Text(activity.id)
                    .font(.caption.monospaced())
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("State", value: stateDescription(activity.activityState))
            LabeledContent("Attributes range", value: "\(activity.attributes.range)")

            if let staleDate = content.staleDate {
                LabeledContent("Stale date", value: staleDate.formatted(date: .omitted, time: .standard))
            } else {
                LabeledContent("Stale date", value: "none")
            }

            LabeledContent("Relevance score", value: content.relevanceScore.formatted())

            LabeledContent("Push token") {
                Text(activity.pushToken.map { token in
                    token.map { String(format: "%02x", $0) }.joined()
                } ?? "none")
                    .font(.caption.monospaced())
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Activity")
        }

        Section("Content State") {
            if let current = state.c {
                LabeledContent("Current value", value: "\(current.value)")
                LabeledContent("Current trend", value: "\(current.trend)")
                LabeledContent("Current date", value: current.date.formatted(date: .omitted, time: .standard))
            } else {
                LabeledContent("Current value", value: "nil")
            }

            LabeledContent("History count", value: "\(state.h.count)")
            LabeledContent("Stale level", value: state.s.map { "\($0)" } ?? "nil")
            LabeledContent("Session expired", value: state.se.map { "\($0)" } ?? "nil")
            LabeledContent("Session start", value: dateOrNil(state.sd))
            LabeledContent("Token start", value: dateOrNil(state.td))
            LabeledContent("Token count", value: state.tc.map { "\($0)" } ?? "nil")
            LabeledContent("Push date", value: dateOrNil(state.pd))
            LabeledContent("Reason", value: state.r ?? "nil")
        }
    }

    private func stateDescription(_ state: ActivityState) -> String {
        switch state {
        case .active: "active"
        case .pending: "pending"
        case .stale: "stale"
        case .dismissed: "dismissed"
        case .ended: "ended"
        @unknown default: "unknown"
        }
    }

    private func dateOrNil(_ date: Date?) -> String {
        date.map { $0.formatted(date: .omitted, time: .standard) } ?? "nil"
    }
}

#Preview {
    NavigationStack {
        LiveActivityDebugView()
    }
}
