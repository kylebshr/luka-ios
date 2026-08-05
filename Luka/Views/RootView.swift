//
//  RootView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/26/24.
//

import SwiftUI
import TelemetryDeck

struct RootView: View {
    @Environment(RootViewModel.self) private var viewModel

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
            } else if viewModel.isSignedIn {
                MainView()
                    .transition(.blurReplace(.downUp))
            } else if !viewModel.didLoadCredentials {
                // Keychain not yet trustworthy (e.g. prewarmed before first
                // unlock). Show a neutral screen rather than the sign-in form
                // so we don't look like a logout; the view model retries when
                // protected data becomes available or the app becomes active.
                Rectangle().fill(.background)
                    .overlay {
                        ProgressView()
                    }
            } else {
                SignInView()
                    .transition(.blurReplace(.downUp))
            }
        }
        .animation(.default, value: viewModel.username)
        .animation(.default, value: viewModel.didLoadCredentials)
        .animation(.default, value: viewModel.requiresForceUpgrade)
        .task {
            await viewModel.loadBanners()
        }
    }
}

#Preview {
    RootView()
}
