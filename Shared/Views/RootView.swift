//
//  RootView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/26/24.
//

import SwiftUI

struct RootView: View {
    private let viewModel = RootViewModel()

    var body: some View {
        NavigationStack {
            if viewModel.isSignedIn {
                MainView()
            } else {
                SignInView()
            }
        }
        .environment(viewModel)
    }
}

#Preview {
    RootView()
}
