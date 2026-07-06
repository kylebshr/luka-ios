//
//  SensorAdoptionView.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import Defaults
import DexcomKit
import SwiftUI
import TelemetryDeck

/// Guides connecting to the sensor in Direct to G7 mode.
///
/// DexcomKit is a follower — there's no pairing or bonding. The official
/// Dexcom app runs the sensor session; this screen just watches the monitor
/// adopt the sensor: scanning → connecting → authenticating → connected.
/// Adoption completes when the sensor reports an authenticated session,
/// which flips `Defaults[.directSensorAdopted]` and routes to the main app.
struct SensorAdoptionView: View {
    @Environment(\.openURL) private var openURL

    @State private var nameSuffix = Defaults[.directSensorNameSuffix] ?? ""

    private var manager: DirectToG7Manager { .shared }

    private var trimmedSuffix: String {
        nameSuffix.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Connect to your G7")
                .font(.largeTitle.weight(.bold))
                .padding(.top, 64)

            Text("Luka listens alongside the Dexcom app — there's nothing to pair. Your sensor must already be set up and running a session in the Dexcom app on this iPhone.")
                .foregroundStyle(.secondary)

            Spacer()

            if let monitor = manager.monitor {
                statusSection(for: monitor)
            } else {
                startButton
            }

            Spacer()

            Button("Use Dexcom Share instead") {
                manager.leaveDirectMode()
            }
            .font(.footnote.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .withReadableWidth()
        .padding()
        .fontDesign(.rounded)
        .animation(.default, value: manager.monitor?.connectionState)
    }

    private var startButton: some View {
        Button {
            TelemetryDeck.signal("DirectToG7.adoption.started")
            manager.startFollowing()
        } label: {
            Text("Start Listening")
                .frame(maxWidth: .infinity)
                .padding(8)
                .fontWeight(.semibold)
        }
        .modifier {
            if #available(iOS 26, *) {
                $0.buttonStyle(.glassProminent)
            } else {
                $0.buttonStyle(.borderedProminent)
            }
        }
        .buttonBorderShape(.capsule)
    }

    private func statusSection(for monitor: G7SensorMonitor) -> some View {
        VStack(alignment: .leading, spacing: .spacing6) {
            FormSection {
                FormRow(title: monitor.connectionState.text, description: guidance(for: monitor.connectionState)) {
                    HStack(spacing: .spacing4) {
                        if case .bluetoothUnavailable = monitor.connectionState {
                            EmptyView()
                        } else {
                            ProgressView()
                        }

                        Circle()
                            .fill(monitor.connectionState.indicatorColor)
                            .frame(width: 8, height: 8)
                    }
                }
            }

            if case .bluetoothUnavailable(let reason) = monitor.connectionState,
               reason == .unauthorized || reason == .poweredOff {
                Button("Open Settings") {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
                .font(.footnote.weight(.medium))
            }

            if manager.lastError == .authenticationRejected {
                Text("A nearby sensor doesn't have a running session yet. Make sure the Dexcom app on this iPhone finished setting up your sensor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            DisclosureGroup("Sensor not connecting?") {
                VStack(alignment: .leading, spacing: .spacing6) {
                    Text("If several G7 sensors are nearby, enter the last two characters of the pairing code printed on your sensor's applicator so Luka only connects to yours.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("Pairing code, e.g. 8T", text: $nameSuffix)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        Button("Apply") {
                            manager.applySensorSelection(suffix: trimmedSuffix)
                        }
                        .disabled(!trimmedSuffix.isEmpty && trimmedSuffix.count != 2)
                    }
                    .textFieldStyle(CardTextFieldStyle())
                }
                .padding(.top, .spacing4)
            }
            .font(.footnote.weight(.medium))
            .padding(.top, .spacing4)
        }
    }

    private func guidance(for state: G7ConnectionState) -> LocalizedStringKey {
        switch state {
        case .idle:
            "Not listening."
        case .bluetoothUnavailable(.poweredOff):
            "Turn on Bluetooth to connect to your sensor."
        case .bluetoothUnavailable(.unauthorized):
            "Luka needs Bluetooth access to connect to your sensor. You can allow it in Settings."
        case .bluetoothUnavailable:
            "Bluetooth is unavailable right now. This is usually temporary."
        case .scanning:
            "Looking for your sensor. Keep your iPhone close to it — the sensor announces itself every few minutes."
        case .connecting:
            "Found your sensor — connecting."
        case .authenticating:
            "Confirming the Dexcom app's session with the sensor."
        case .connected:
            "Connected! Waiting for the sensor to confirm its session."
        case .waitingForReading:
            "Connected. The sensor sends a reading about every five minutes."
        }
    }
}

#Preview {
    SensorAdoptionView().environment(RootViewModel())
}
