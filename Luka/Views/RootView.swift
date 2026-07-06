//
//  RootView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/26/24.
//

import Defaults
import SwiftUI
import TelemetryDeck

struct RootView: View {
    @Environment(RootViewModel.self) private var viewModel

    @Default(.appMode) private var appMode
    @Default(.directSensorAdopted) private var directSensorAdopted

    init() {
        var largeTitleFont = UIFont.preferredFont(forTextStyle: .largeTitle)
        largeTitleFont = UIFont(
            descriptor:
                largeTitleFont.fontDescriptor
                .withDesign(.rounded)!
                .withSymbolicTraits(.traitBold)!,
            size: largeTitleFont.pointSize
        )

        var titleFont = UIFont.preferredFont(forTextStyle: .headline)
        titleFont = UIFont(
            descriptor:
                titleFont.fontDescriptor
                .withDesign(.rounded)!
                .withSymbolicTraits(.traitBold)!,
            size: titleFont.pointSize
        )

        UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeTitleFont]
        UINavigationBar.appearance().titleTextAttributes = [.font: titleFont]
    }

    var body: some View {
        Group {
            if viewModel.requiresForceUpgrade {
                ForceUpgradeView()
                    .transition(.blurReplace(.downUp))
                    .onAppear {
                        TelemetryDeck.signal("ForceUpgrade.viewed")
                    }
            } else if appMode == .direct {
                if directSensorAdopted {
                    MainView()
                        .transition(.blurReplace(.downUp))
                } else {
                    SensorAdoptionView()
                        .transition(.blurReplace(.downUp))
                }
            } else if viewModel.isSignedIn {
                MainView()
                    .transition(.blurReplace(.downUp))
            } else if !viewModel.didLoadCredentials {
                // Keychain not yet readable (e.g. just after a reboot). Show a
                // neutral screen rather than the sign-in form so we don't look
                // like a logout while we retry the read.
                Rectangle().fill(.background)
                    .overlay {
                        ProgressView()
                    }
            } else {
                ModeSelectionView()
                    .transition(.blurReplace(.downUp))
            }
        }
        .animation(.default, value: viewModel.username)
        .animation(.default, value: viewModel.didLoadCredentials)
        .animation(.default, value: viewModel.requiresForceUpgrade)
        .animation(.default, value: appMode)
        .animation(.default, value: directSensorAdopted)
        .task {
            await viewModel.loadBanners()
        }
        .task {
            // Retry reading the keychain until it becomes available.
            while !viewModel.didLoadCredentials {
                try? await Task.sleep(for: .seconds(0.5))
                viewModel.loadCredentials()
            }
        }
    }
}

#Preview {
    RootView()
}
