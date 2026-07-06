//
//  ExperimentalView.swift
//  Luka
//
//  Created by Claude on 5/25/26.
//

import SwiftUI
import Defaults
import ActivityKit

struct ExperimentalView: View {
    @Default(.debugInfo) private var debugInfo
    @Default(.useReadingsProxy) private var useReadingsProxy
    @Default(.appMode) private var appMode

    @State private var showCompleteAlert = false

    var body: some View {
        List {
            Section("Live Activities") {
                Toggle("Show debug info", isOn: $debugInfo)
                    .tint(.accent)

                NavigationLink {
                    LiveActivityDebugView()
                } label: {
                    Text("Live Activity debug info")
                }

                Button {
                    Task {
                        for activity in Activity<ReadingAttributes>.activities {
                            let state = activity.content
                            await activity.end(state)
                        }
                    }
                } label: {
                    SettingsRow("End Live Activity locally", systemImage: "stop.circle.fill")
                }
                .fontWeight(.medium)

                Button {
                    Task {
                        await LiveActivityManager.shared.endLiveActivityOnServer()
                        showCompleteAlert = true
                    }
                } label: {
                    SettingsRow("End Live Activity on server", systemImage: "antenna.radiowaves.left.and.right.slash")
                }
                .fontWeight(.medium)

                Button {
                    Task {
                        await LiveActivityManager.shared.endAllLiveActivitiesOnServer()
                        showCompleteAlert = true
                    }
                } label: {
                    SettingsRow("End all Live Activities", systemImage: "xmark.circle")
                }
                .fontWeight(.medium)

                Button {
                    Task {
                        await LiveActivityManager.shared.debugRestartLiveActivityOnServer()
                        showCompleteAlert = true
                    }
                } label: {
                    SettingsRow("Restart via push-to-start", systemImage: "arrow.clockwise.circle")
                }
                .fontWeight(.medium)
            }

            // The readings proxy is part of the cloud pipeline; direct mode
            // never networks for readings.
            if appMode != .direct {
                Section {
                    Toggle("Use Luka server for readings", isOn: $useReadingsProxy)
                        .tint(.accent)
                } footer: {
                    Text("Fetch glucose readings from the Luka server when a Live Activity is running. Falls back to Dexcom if no cached readings are available.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Advanced")
        .fontDesign(.rounded)
        .alert("Ended", isPresented: $showCompleteAlert) {
            Button("OK") {}
        }
    }
}

#Preview {
    NavigationStack {
        ExperimentalView()
    }
}
