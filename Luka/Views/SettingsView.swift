//
//  SettingsView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/28/24.
//

import SwiftUI
import Defaults
import Dexcom
import TelemetryDeck
import WidgetKit

struct SettingsView: View {
    @Environment(RootViewModel.self) private var viewModel
    @Environment(SupporterStore.self) private var supporterStore
    @Environment(\.dismiss) private var dismiss

    @State private var isPresentingSupport = false
    @State private var isAddingAccount = false

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

    /// Auto-restart works by handing the server a push-to-start token, so it's only
    /// meaningful once the device has received one. Absence means push-to-start isn't
    /// available yet (e.g. Live Activities disabled, or none started since install).
    private var pushToStartEnabled: Bool {
        pushToStartToken != nil
    }

    var body: some View {
        List {
            accountsSection

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

            if pushToStartEnabled {
                Section {
                    Toggle("Automatically restart Live Activity", isOn: $autoRestartLiveActivity)
                        .tint(.accent)
                } footer: {
                    Text("Live Activities have a maximum duration of about eight hours, but Luka can automatically start a new Live Activity when one ends.")
                }
            }

            Section {
                Toggle("Live Activity alerts", isOn: $liveActivityAlertsEnabled)
                    .tint(.accent)
            } footer: {
                Text("Live Activities can send alerts when glucose levels are rising or dropping quickly, or when you leave or enter your target range. When enabled, they will play a sound and show the activity if it’s hidden.")
            }

            Section {
                if supporterStore.isSupporter {
                    Button {
                        isPresentingSupport = true
                    } label: {
                        SettingsRow("Manage support", systemImage: "heart.fill")
                    }
                } else {
                    Button {
                        isPresentingSupport = true
                    } label: {
                        SettingsRow("Support Luka", systemImage: "heart")
                    }

                    Button {
                        Task {
                            await supporterStore.restore()
                        }
                    } label: {
                        SettingsRow("Restore purchases", systemImage: "arrow.clockwise")
                    }
                }
            } header: {
                Text("Support")
            } footer: {
                if let currentTier = supporterStore.currentTier {
                    Text("\(Text(currentTier.thanks)) It keeps Live Activities running.")
                } else {
                    Text("Live Activities run on a server that costs money. Chip in from \(supporterStore.lowestDisplayPrice)/mo.")
                }
            }
            .fontWeight(.medium)

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
                NavigationLink {
                    ExperimentalView()
                } label: {
                    Text("Advanced")
                        .foregroundStyle(.tint)
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
        .animation(.default, value: showChartLiveActivity)
        .animation(.default, value: supporterStore.isSupporter)
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $isPresentingSupport) {
            SupportView(source: .settings)
        }
        .sheet(isPresented: $isAddingAccount) {
            SignInView { _ in
                TelemetryDeck.signal("Account.added", parameters: ["accountCount": String(viewModel.accounts.count)])
            }
        }
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

extension SettingsView {
    private var accountsSection: some View {
        Section {
            ForEach(viewModel.accounts) { account in
                NavigationLink {
                    AccountSettingsView(account: account)
                } label: {
                    AccountRow(
                        name: viewModel.displayName(for: account),
                        username: account.displayName.isEmpty ? nil : viewModel.username(for: account)
                    )
                }
            }
            .onMove(perform: viewModel.accounts.count > 1 ? moveAccounts : nil)

            Button {
                isAddingAccount = true
            } label: {
                SettingsRow("Add account", systemImage: "plus")
            }
            .fontWeight(.medium)
        } header: {
            Text("Accounts")
        } footer: {
            if viewModel.accounts.count > 1 {
                Text("Touch and hold an account to reorder. Widgets show the first account by default.")
            }
        }
    }

    private var moveAccounts: (IndexSet, Int) -> Void {
        { source, destination in
            viewModel.move(fromOffsets: source, toOffset: destination)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

private struct AccountRow: View {
    var name: String
    var username: String?

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing1) {
            Text(name)
                .fontWeight(.medium)
                .lineLimit(1)

            if let username {
                Text(username)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
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

#if DEBUG
#Preview {
    NavigationStack {
        SettingsView()
            .environment(PreviewAccounts.rootViewModel(names: ["", "Mom", "Alex"]))
            .environment(SupporterStore())
    }
}
#endif
