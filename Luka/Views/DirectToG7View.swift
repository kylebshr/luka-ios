//
//  DirectToG7View.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import Defaults
import Dexcom
import DexcomKit
import SwiftUI

struct DirectToG7View: View {
    @Default(.unit) private var unit
    @Default(.targetRangeLowerBound) private var lowerTargetRange
    @Default(.targetRangeUpperBound) private var upperTargetRange

    var body: some View {
        @Bindable var manager = DirectToG7Manager.shared

        List {
            Section {
                Toggle("Direct to G7", isOn: $manager.isEnabled)
                    .tint(.accent)
            } footer: {
                Text("Listen to your G7 directly over Bluetooth, alongside the Dexcom app. The sensor must already be running a session with the Dexcom app on this phone.")
            }

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
                        LabeledContent(
                            "Expires",
                            value: session.expirationDate.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }

                Section("Latest reading") {
                    if let reading = monitor.latestReading {
                        readingRow(reading)
                    } else {
                        Text("Waiting for a reading…")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("The sensor sends a new reading about every five minutes, and backfills readings missed while out of range.")
                }

                Section {
                    Button("Forget sensor", role: .destructive) {
                        manager.forgetSensor()
                    }
                } footer: {
                    Text("Forget the followed sensor so the next scan can adopt a new one, for example after replacing a sensor early.")
                }
            }
        }
        .animation(.default, value: manager.isEnabled)
        .listStyle(.insetGrouped)
        .navigationTitle("Direct to G7")
        .fontDesign(.rounded)
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

private extension G7ConnectionState {
    var text: LocalizedStringKey {
        switch self {
        case .idle:
            "Off"
        case .bluetoothUnavailable(.poweredOff):
            "Bluetooth is off"
        case .bluetoothUnavailable(.unauthorized):
            "Bluetooth not allowed"
        case .bluetoothUnavailable(.unsupported):
            "Bluetooth unsupported"
        case .bluetoothUnavailable(.resetting), .bluetoothUnavailable(.unknown):
            "Bluetooth unavailable"
        case .scanning:
            "Scanning"
        case .connecting:
            "Connecting"
        case .authenticating:
            "Authenticating"
        case .connected:
            "Connected"
        case .waitingForReading:
            "Waiting for next reading"
        }
    }

    var indicatorColor: Color {
        switch self {
        case .idle:
            .gray
        case .bluetoothUnavailable:
            .lowColor
        case .scanning, .connecting, .authenticating:
            .highColor
        case .connected, .waitingForReading:
            .inRangeColor
        }
    }
}

private extension DexcomKit.TrendArrow {
    var image: Image {
        switch self {
        case .fallingQuickly:
            Image("arrow.down.double")
        case .falling:
            Image(systemName: "arrow.down")
        case .fallingSlightly:
            Image(systemName: "arrow.down.right")
        case .steady:
            Image(systemName: "arrow.right")
        case .risingSlightly:
            Image(systemName: "arrow.up.right")
        case .rising:
            Image(systemName: "arrow.up")
        case .risingQuickly:
            Image("arrow.up.double")
        }
    }
}

#Preview {
    NavigationStack {
        DirectToG7View()
    }
}
