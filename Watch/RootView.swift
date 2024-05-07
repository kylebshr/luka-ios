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
        } else {
            SignInView()
        }
    }
}

#Preview {
    RootView().environment(RootViewModel())
}
