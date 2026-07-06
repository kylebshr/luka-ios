//
//  SettingsView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/28/24.
//

import SwiftUI
import Defaults
import Dexcom
import KeychainAccess

struct SettingsView: View {
    @Environment(RootViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @Default(.targetRangeLowerBound) private var lowerTargetRange
    @Default(.targetRangeUpperBound) private var upperTargetRange
    @Default(.graphUpperBound) private var upperGraphRange
    @Default(.showChartLiveActivity) private var showChartLiveActivity
    @Default(.liveActivityAlertsEnabled) private var liveActivityAlertsEnabled
    @Default(.autoRestartLiveActivity) private var autoRestartLiveActivity
    @Default(.liveActivityTapApp) private var liveActivityTapApp
    @Default(.appGraphStyle) private var appGraphStyle
    @Default(.liveActivityGraphStyle) private var liveActivityGraphStyle
    @Default(.unit) private var unit
    @Default(.sessionHistory) private var sessionHistory
    @Default(.pushToStartToken) private var pushToStartToken
    @Default(.appMode) private var appMode

    @State private var isConfirmingSwitchToDirect = false
    @State private var isConfirmingSwitchToCloud = false

    private var username: String? {
        Keychain.shared.username
    }

    private var isDirectMode: Bool {
        appMode == .direct
    }

    /// Auto-restart works by handing the server a push-to-start token, so it's only
    /// meaningful once the device has received one. Absence means push-to-start isn't
    /// available yet (e.g. Live Activities disabled, or none started since install).
    private var pushToStartEnabled: Bool {
        pushToStartToken != nil
    }

    var body: some View {
        List {
            Section("General") {
                Picker("Units", selection: $unit) {
                    Text(GlucoseFormatter.Unit.mgdl.text)
                        .tag(GlucoseFormatter.Unit.mgdl)
                    Text(GlucoseFormatter.Unit.mmolL.text)
                        .tag(GlucoseFormatter.Unit.mmolL)
                }
                .pickerStyle(.menu)

                Picker("In-app graph style", selection: $appGraphStyle) {
                    Text("Dots").tag(GraphStyle.dots)
                    Text("Line").tag(GraphStyle.line)
                }
                .pickerStyle(.menu)

                GraphSliderView(
                    title: "Graph upper bound",
                    currentValue: $upperGraphRange,
                    range: 250...400
                )

                GraphSliderView(
                    title: "Upper target range",
                    currentValue: $upperTargetRange,
                    range: 120...220
                )

                GraphSliderView(
                    title: "Lower target range",
                    currentValue: $lowerTargetRange,
                    range: 55...110
                )
            }

            Section("Live Activities") {
                Toggle("Show graph in Live Activity", isOn: $showChartLiveActivity)
                    .tint(.accent)

                if showChartLiveActivity {
                    Picker("Live Activity graph style", selection: $liveActivityGraphStyle) {
                        Text("Dots").tag(GraphStyle.dots)
                        Text("Line").tag(GraphStyle.line)
                    }
                    .pickerStyle(.menu)
                }

                Picker("Launch on tap", selection: $liveActivityTapApp) {
                    ForEach(LaunchableApp.allCases) { app in
                        Text(app.localizedStringResource).tag(app)
                    }
                }
                .pickerStyle(.menu)
            }

            // Auto-restart and alerts are driven by the Luka server's pushes,
            // which don't exist in Direct to G7 mode.
            if pushToStartEnabled && !isDirectMode {
                Section {
                    Toggle("Automatically restart Live Activity", isOn: $autoRestartLiveActivity)
                        .tint(.accent)
                } footer: {
                    Text("Live Activities have a maximum duration of about eight hours, but Luka can automatically start a new Live Activity when one ends.")
                }
            }

            if !isDirectMode {
                Section {
                    Toggle("Live Activity alerts", isOn: $liveActivityAlertsEnabled)
                        .tint(.accent)
                } footer: {
                    Text("Live Activities can send alerts when glucose levels are rising or dropping quickly, or when you leave or enter your target range. When enabled, they will play a sound and show the activity if it’s hidden.")
                }
            }

            Section {
                ShareLink(item: URL(string: "https://apps.apple.com/us/app/luka-blood-glucose-readings/id6499279663")!) {
                    SettingsRow("Share Luka", systemImage: "square.and.arrow.up")
                }

                ShareLink(item: URL(string: "https://apps.apple.com/us/app/luka-mini-glucose-readings/id6497405885")!) {
                    SettingsRow("Luka for macOS", systemImage: "square.and.arrow.up")
                }

                Link(destination: URL(string: "itms-apps://itunes.apple.com/gb/app/id6499279663?action=write-review&mt=8")!) {
                    SettingsRow("Leave a review", systemImage: "star")
                }

                Link(destination: URL(string: "mailto:kylebshr@me.com")!) {
                    SettingsRow("Email me", systemImage: "envelope")
                }
            }
            .fontWeight(.medium)

            Section {
                if isDirectMode {
                    NavigationLink {
                        DirectSensorSettingsView()
                    } label: {
                        LabeledContent("Direct to G7") {
                            Text("Sensor")
                        }
                    }
                } else {
                    Button("Switch to Direct to G7") {
                        isConfirmingSwitchToDirect = true
                    }
                }
            } header: {
                Text("Data Source")
            } footer: {
                if isDirectMode {
                    Text("Luka reads your G7 directly over Bluetooth on this iPhone.")
                } else {
                    Text("Read your G7 directly over Bluetooth on this iPhone instead of using Dexcom Share.")
                }
            }
            .fontWeight(.medium)

            Section {
                NavigationLink {
                    ExperimentalView()
                } label: {
                    Text("Advanced")
                        .foregroundStyle(.tint)
                }
            }
            .fontWeight(.medium)

            Section {
                if isDirectMode {
                    Button {
                        isConfirmingSwitchToCloud = true
                    } label: {
                        SettingsRow("Switch to Dexcom Share", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } else {
                    Button {
                        viewModel.signOut()
                    } label: {
                        SettingsRow("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } header: {
                if let username, !isDirectMode {
                    Text("Signed in as \(username)", comment: "Settings section header showing current user")
                }
            } footer: {
                Text("Luka \(Bundle.main.fullVersion)", comment: "Settings footer showing app version")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical)
            }
            .fontWeight(.medium)
        }
        .confirmationDialog(
            "Switch to Direct to G7?",
            isPresented: $isConfirmingSwitchToDirect,
            titleVisibility: .visible
        ) {
            Button("Switch", role: .destructive) {
                viewModel.signOut()
                DirectToG7Manager.shared.switchToDirectMode()
                dismiss()
            }
        } message: {
            Text("Luka will read your G7 over Bluetooth on this iPhone. This signs you out of Dexcom Share on all your devices — your Apple Watch will get readings from this iPhone instead. The Dexcom app must be running your sensor session.")
        }
        .confirmationDialog(
            "Switch to Dexcom Share?",
            isPresented: $isConfirmingSwitchToCloud,
            titleVisibility: .visible
        ) {
            Button("Switch", role: .destructive) {
                DirectToG7Manager.shared.leaveDirectMode()
                dismiss()
            }
        } message: {
            Text("Luka will stop reading your sensor over Bluetooth and forget it. You'll sign in with your Dexcom account instead.")
        }
        .animation(.default, value: showChartLiveActivity)
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .toolbar {
            if #available(iOS 26, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .fontDesign(.rounded)
    }
}

private struct GraphSliderView: View {
    var title: LocalizedStringKey
    @Binding var currentValue: Double
    var range: ClosedRange<Double>

    @Default(.unit) private var unit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(Int(currentValue).formatted(.glucose(unit)))
            }

            Slider(
                value: $currentValue,
                in: range,
                step: 5,
                label: {
                    Text(title)
                }
            )
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView().environment(RootViewModel())
    }
}
