//
//  RootView.swift
//  Watch
//
//  Created by Kyle Bashour on 5/7/24.
//

import SwiftUI
import KeychainAccess

struct RootView: View {
    @Environment(RootViewModel.self) private var viewModel

    var body: some View {
        if viewModel.isSignedIn {
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
