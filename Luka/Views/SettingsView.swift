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
                    HStack {
                        Text("Share Luka")
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                ShareLink(item: URL(string: "https://apps.apple.com/us/app/luka-mini-glucose-readings/id6497405885")!,
                    label: {
                        HStack {
                            Text("Luka for macOS")
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                )

                Link(
                    destination: URL(string: "itms-apps://itunes.apple.com/gb/app/id6499279663?action=write-review&mt=8")!,
                    label: {
                        HStack {
                            Text("Leave a Review")
                            Spacer()
                            Image(systemName: "star")
                        }
                    }
                )

                Link(
                    destination: URL(string: "mailto:kylebshr@me.com")!,
                    label: {
                        HStack {
                            Text("Email Me")
                            Spacer()
                            Image(systemName: "envelope")
                        }
                    }
                )
            }
            .fontWeight(.medium)

            Section {
                Button {
                    viewModel.signOut()
                } label: {
                    HStack {
                        Text("Sign Out")
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            } header: {
                if let username {
                    AccountHeaderView(username: username)
                        .padding(.bottom, .spacing4)
                }
            } footer: {
                Text("Version \(Bundle.main.fullVersion)")
                    .font(.footnote.weight(.medium))
                    .fontDesign(.monospaced)
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

private struct AccountHeaderView: View {
    var username: String

    var body: some View {
        HStack(spacing: .spacing6) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.accent)

            VStack(alignment: .leading, spacing: .spacing1) {
                Text("Signed in as")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(username)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.top, .spacing4)
    }
}

private struct GraphSliderView: View {
    var title: String
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
