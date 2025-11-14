//
//  SettingsView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/28/24.
//

import SwiftUI
import Defaults
import Dexcom

struct SettingsView: View {
    @Environment(RootViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @Default(.targetRangeLowerBound) private var lowerTargetRange
    @Default(.targetRangeUpperBound) private var upperTargetRange
    @Default(.graphUpperBound) private var upperGraphRange
    @Default(.showChartLiveActivity) private var showChartLiveActivity
    @Default(.unit) private var unit
    @Default(.sessionHistory) private var sessionHistory

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

            if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
                Section("Dexcom Sessions (Debug Info)") {
                    SessionHistoryTable(entries: sessionHistory)
                }
            }

            Section {
                Button {
                    viewModel.signOut()
                } label: {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
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

private struct SessionHistoryTable: View {
    var entries: [DexcomSessionHistoryEntry]

    private var rows: [DexcomSessionHistoryEntry] {
        entries.sorted { $0.recordedAt > $1.recordedAt }
    }

    var body: some View {
        if rows.isEmpty {
            Text("No session history yet")
                .foregroundStyle(.secondary)
        } else {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Session ID")
                    Text("Expired")
                    Text("Updated by")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Divider()
                    .gridCellColumns(3)

                ForEach(rows) { entry in
                    GridRow {
                        Text(entry.sessionID.uuidString.split(separator: "-").first!)
                            .fontDesign(.monospaced)
                            .textSelection(.enabled)

                        Text(entry.recordedAt.formatted(date: .numeric, time: .shortened))
                            .foregroundStyle(.secondary)

                        Text(entry.source)
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)

                    if entry.id != rows.last?.id {
                        Divider()
                            .gridCellColumns(3)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView().environment(RootViewModel())
    }
}
