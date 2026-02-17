//
//  G7PairingView.swift
//  Luka
//
//  Created by Kyle Bashour on 2/16/26.
//

import SwiftUI
import WidgetKit

struct G7PairingView: View {
    @Environment(RootViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isScanning = false
    @State private var connectionStatus: G7GlucoseService.ConnectionStatus = .disconnected
    @State private var error: String?

    private var g7Service: G7GlucoseService { G7GlucoseService.shared }

    var body: some View {
        VStack(spacing: .spacing8) {
            Spacer()

            scanningContent

            Spacer()

            if case .connected = connectionStatus {
                Button {
                    viewModel.signInWithG7()
                    WidgetCenter.shared.reloadAllTimelines()
                } label: {
                    Text("Continue")
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
        }
        .withReadableWidth()
        .padding()
        .navigationTitle("Connect G7 Sensor")
        .fontDesign(.rounded)
        .onAppear {
            startScanning()
        }
        .onDisappear {
            if !viewModel.isSignedIn {
                g7Service.stop()
            }
        }
    }

    @ViewBuilder
    private var scanningContent: some View {
        switch connectionStatus {
        case .disconnected, .scanning:
            VStack(spacing: .spacing6) {
                ProgressView()
                    .controlSize(.large)
                    .padding(.bottom, .spacing4)

                Text("Scanning for G7 Sensor")
                    .font(.headline)

                Text("Make sure your Dexcom G7 sensor is active and nearby. The sensor must be paired with your phone via the Dexcom app first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

        case .warmup:
            VStack(spacing: .spacing6) {
                Image(systemName: "clock")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                    .padding(.bottom, .spacing4)

                Text("Sensor Warming Up")
                    .font(.headline)

                Text("Your sensor is still warming up. This takes about 27 minutes after insertion. You can continue — readings will appear once warmup is complete.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()

        case .connected(let sensorName):
            VStack(spacing: .spacing6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.inRangeColor)
                    .padding(.bottom, .spacing4)

                Text("Sensor Connected")
                    .font(.headline)

                Text("Connected to \(sensorName). Tap Continue to start using Luka with your G7 sensor.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private func startScanning() {
        isScanning = true
        connectionStatus = .scanning

        g7Service.onStatusChange = { [self] in
            connectionStatus = g7Service.connectionStatus
        }

        g7Service.scanForNewSensor()
    }
}

#Preview {
    NavigationStack {
        G7PairingView().environment(RootViewModel())
    }
}
