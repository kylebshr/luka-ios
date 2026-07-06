//
//  ModeSelectionView.swift
//  Luka
//
//  Created by Claude on 7/6/26.
//

import SwiftUI
import TelemetryDeck

/// First-launch chooser between the app's two data sources: Dexcom Share
/// (cloud sign-in, the classic app) and Direct to G7 (local Bluetooth).
struct ModeSelectionView: View {
    @State private var isPresentingCloudSignIn = false

    var body: some View {
        VStack(alignment: .leading) {
            (Text("Welcome to") + Text(verbatim: " ") + Text("Luka").foregroundStyle(.accent))
                .font(.largeTitle.weight(.bold))
                .padding(.top, 64)

            Text("Excellent widgets and Live Activities for Dexcom continuous glucose monitors.")
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: .spacing6) {
                Button {
                    TelemetryDeck.signal("Mode.selected", parameters: ["mode": "cloud"])
                    isPresentingCloudSignIn = true
                } label: {
                    FormSection {
                        FormRow(
                            title: "Dexcom Share",
                            description: "Sign in with your Dexcom account to get readings anywhere, on all your devices. Requires Share to be enabled with at least one follower."
                        ) {
                            Image(systemName: "chevron.right")
                        }
                    }
                }

                Button {
                    DirectToG7Manager.shared.switchToDirectMode()
                } label: {
                    FormSection {
                        FormRow(
                            title: "Direct to G7",
                            description: "Read your G7 over Bluetooth on this iPhone — no Dexcom account needed. The Dexcom app must be running your sensor session. G7 and Dexcom One+ only."
                        ) {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical)

            Text("How should Luka get your readings? You can switch anytime in settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .withReadableWidth()
        .padding()
        .fontDesign(.rounded)
        .sheet(isPresented: $isPresentingCloudSignIn) {
            SignInView()
        }
    }
}

#Preview {
    ModeSelectionView().environment(RootViewModel())
}
