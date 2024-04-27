//
//  RootView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/26/24.
//

import SwiftUI

struct RootView: View {
    @Environment(RootViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            if viewModel.isSignedIn {
                MainView()
                    .transition(.blurReplace)
            } else {
                SignInView()
                    .transition(.blurReplace)
            }
        }
        .animation(.default, value: viewModel.username)
    }
}

#Preview {
    RootView()
}
