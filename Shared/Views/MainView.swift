//
//  MainView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/26/24.
//

import SwiftUI
import WidgetKit

struct MainView: View {
    @Environment(RootViewModel.self) private var viewModel

    var body: some View {
        ScrollView {

        }
        .safeAreaInset(edge: .bottom) {
            Button {
                viewModel.signOut()
            } label: {
                Text("Sign Out")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding()
            #if os(iOS)
            .background(Material.bar)
            .overlay(alignment: .top) {
                Divider()
            }
            #endif
        }
        .navigationTitle("Glimpse")
    }
}
