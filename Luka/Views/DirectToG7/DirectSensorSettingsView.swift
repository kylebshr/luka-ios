//
//  DirectSensorSettingsView.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import Defaults
import Dexcom
import DexcomKit
import SwiftUI

/// Sensor status and management for Direct to G7 mode, reached from
/// settings: connection state, session info, the latest reading, and
/// forgetting the sensor to adopt a replacement.
struct DirectSensorSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Default(.unit) private var unit
    @Default(.targetRangeLowerBound) private var lowerTargetRange
    @Default(.targetRangeUpperBound) private var upperTargetRange

    @State private var isConfirmingForget = false

    private var manager: DirectToG7Manager { .shared }

    var body: some View {
        List {
            if let monitor = manager.monitor {
                Section("Connection") {
                    LabeledContent("Status") {
                        HStack(spacing: .spacing4) {
                            Circle()
                                .fill(monitor.connectionState.indicatorColor)
                                .frame(width: 8, height: 8)
                            Text(monitor.connectionState.text)
                        }
                    }

                    if let session = monitor.session {
                        LabeledContent("Sensor", value: session.sensorName)

                        if session.isInWarmup(at: .now) {
                            LabeledContent(
                                "Warms up",
                                value: session.warmupEndDate.formatted(date: .omitted, time: .shortened)
                            )
                        }

                        LabeledContent(
                            "Expires",
                            value: session.expirationDate.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }

                Section {
                    if let reading = monitor.latestReading {
                        readingRow(reading)
                    } else {
                        Text("Waiting for a reading…")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Latest reading")
                } footer: {
                    Text("The sensor sends a new reading about every five minutes, and backfills readings missed while out of range.")
                }
            }

            Section {
                Button("Forget sensor", role: .destructive) {
                    isConfirmingForget = true
                }
            } footer: {
                Text("Forget the followed sensor so the next scan can adopt a new one, for example after replacing a sensor early.")
            }

            #if DEBUG
            Section {
                Button("Simulate readings") {
                    Task {
                        await manager.simulateReadings([Dexcom.GlucoseReading].placeholder)
                    }
                }
            } footer: {
                Text("Debug only: pushes 24 hours of sample readings through the local pipeline — store, widgets, Live Activity, and watch relay.")
            }
            #endif
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Sensor")
        .fontDesign(.rounded)
        .confirmationDialog(
            "Forget this sensor?",
            isPresented: $isConfirmingForget,
            titleVisibility: .visible
        ) {
            Button("Forget Sensor", role: .destructive) {
                manager.forgetSensor()
                dismiss()
            }
        } message: {
            Text("Luka will scan for a sensor to connect to. Your readings stay on this iPhone.")
        }
    }

    private func readingRow(_ reading: DexcomKit.GlucoseReading) -> some View {
        HStack {
            HStack(spacing: .spacing4) {
                if let glucose = reading.glucose {
                    Text(glucose.formatted(.glucose(unit)))
                        .foregroundStyle(color(for: glucose))

                    reading.trendArrow?.image
                } else {
                    Text(verbatim: "—")
                        .foregroundStyle(.secondary)
                }
            }
            .fontWeight(.semibold)

            Spacer()

            Text(reading.date, style: .relative)
                .foregroundStyle(.secondary)
        }
    }

    private func color(for glucose: Int) -> Color {
        // Integer-truncated bounds, consistent with GlucoseReading.color(target:).
        if glucose < Int(lowerTargetRange) {
            .lowColor
        } else if glucose > Int(upperTargetRange) {
            .highColor
        } else {
            .inRangeColor
        }
    }
}

#Preview {
    NavigationStack {
        DirectSensorSettingsView()
    }
}
