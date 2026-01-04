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
    @Default(.unit) private var unit
    @Default(.sessionHistory) private var sessionHistory

    private var username: String? {
        Keychain.shared.username
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

                Toggle("Show Graph in Live Activity", isOn: $showChartLiveActivity)
                    .tint(.accent)
            }

            Section("Graphs") {
                GraphSliderView(
                    title: "Upper bound",
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

            Section {
                ShareLink(item: URL(string: "https://apps.apple.com/us/app/luka-blood-glucose-readings/id6499279663")!) {
                    SettingsRow("Share Luka", systemImage: "square.and.arrow.up")
                }

                ShareLink(item: URL(string: "https://apps.apple.com/us/app/luka-mini-glucose-readings/id6497405885")!) {
                    SettingsRow("Luka for macOS", systemImage: "square.and.arrow.up")
                }

                Link(destination: URL(string: "itms-apps://itunes.apple.com/gb/app/id6499279663?action=write-review&mt=8")!) {
                    SettingsRow("Leave a Review", systemImage: "star")
                }

                Link(destination: URL(string: "mailto:kylebshr@me.com")!) {
                    SettingsRow("Email Me", systemImage: "envelope")
                }
            }
            .fontWeight(.medium)

            Section {
                Button {
                    viewModel.signOut()
                } label: {
                    SettingsRow("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } header: {
                if let username {
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

private struct SettingsRow: View {
    @ScaledMetric private var iconFrameWidth: CGFloat = 24

    var title: LocalizedStringKey
    var systemImage: String

    init(_ title: LocalizedStringKey, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: systemImage)
                .frame(width: iconFrameWidth, alignment: .center)
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

#Preview {
    NavigationStack {
        SettingsView().environment(RootViewModel())
    }
}
