//
//  ExperimentalView.swift
//  Luka
//
//  Created by Claude on 5/25/26.
//

import SwiftUI
import Defaults

struct ExperimentalView: View {
    @Default(.debugInfo) private var debugInfo
    @Default(.useReadingsProxy) private var useReadingsProxy

    @State private var showCompleteAlert = false

    var body: some View {
        List {
            Section("Live Activities") {
                Toggle("Show debug info", isOn: $debugInfo)
                    .tint(.accent)

                NavigationLink {
                    LiveActivityDebugView()
                } label: {
                    SettingsRow("Live Activity debug info", systemImage: "ladybug")
                }

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
            }

            Section {
                Toggle("Use Luka server for readings", isOn: $useReadingsProxy)
                    .tint(.accent)
            } footer: {
                Text("Fetch glucose readings from the Luka server when a Live Activity is running. Falls back to Dexcom if no cached readings are available.")
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
