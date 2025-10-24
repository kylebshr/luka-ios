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
