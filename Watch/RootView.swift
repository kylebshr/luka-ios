//
//  RootView.swift
//  Watch
//
//  Created by Kyle Bashour on 5/7/24.
//

import Defaults
import SwiftUI
import KeychainAccess

struct RootView: View {
    @Environment(RootViewModel.self) private var viewModel

    @Default(.appMode) private var appMode

    var body: some View {
        if appMode == .direct {
            // Direct to G7: readings are relayed from the iPhone into the
            // local store; no sign-in on the watch.
            MainView()
        } else if viewModel.isSignedIn {
            MainView()
        } else if !viewModel.didLoadCredentials {
            // Keychain not yet readable (e.g. just after a reboot). Show a
            // neutral screen rather than the sign-in form while we retry.
            Rectangle().fill(.background)
                .task {
                    while !viewModel.didLoadCredentials {
                        try? await Task.sleep(for: .seconds(0.5))
                        viewModel.loadCredentials()
                    }
                }
        } else {
            SignInView()
        }
    }
}

#Preview {
    RootView().environment(RootViewModel())
}
