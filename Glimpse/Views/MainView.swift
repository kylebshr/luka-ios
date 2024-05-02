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
    @State private var isPresentingSettings = false

    var body: some View {
        ScrollView {
            
        }
        .font(.subheadline.weight(.medium))
        .navigationTitle("Luka")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingSettings = true
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                }
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        MainView().environment(RootViewModel())
    }
}
