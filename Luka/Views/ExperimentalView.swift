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

    var body: some View {
        List {
            Section("Live Activities") {
                Toggle("Debug info", isOn: $debugInfo)
                    .tint(.accent)
            }

            Section {
                Button {
                    Task {
                        await LiveActivityManager.shared.endLiveActivityOnServer()
                    }
                } label: {
                    SettingsRow("End Live Activity on server", systemImage: "antenna.radiowaves.left.and.right.slash")
                }

                Button {
                    Task {
                        await LiveActivityManager.shared.endAllLiveActivitiesOnServer()
                    }
                } label: {
                    SettingsRow("End all Live Activities", systemImage: "xmark.circle")
                }
            }
            .fontWeight(.medium)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Experimental")
        .fontDesign(.rounded)
    }
}

#Preview {
    NavigationStack {
        ExperimentalView()
    }
}
