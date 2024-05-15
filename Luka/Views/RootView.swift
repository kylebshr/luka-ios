//
//  RootView.swift
//  Luka
//
//  Created by Kyle Bashour on 4/26/24.
//

import SwiftUI

struct RootView: View {
    @Environment(RootViewModel.self) private var viewModel

    init() {
        var titleFont = UIFont.preferredFont(forTextStyle: .largeTitle)
        titleFont = UIFont(
            descriptor:
                titleFont.fontDescriptor
                .withDesign(.rounded)!
                .withSymbolicTraits(.traitBold)!,
            size: titleFont.pointSize
        )

        UINavigationBar.appearance().largeTitleTextAttributes = [.font: titleFont]
    }

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
