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
        Group {
            if viewModel.isSignedIn {
                MainView()
                    .transition(.blurReplace(.downUp))
            } else {
                SignInView()
                    .transition(.blurReplace(.downUp))
            }
        }
        .animation(.default, value: viewModel.username)
    }
}

#Preview {
    RootView()
}
