//
//  MainView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/26/24.
//

import SwiftUI
import WidgetKit

@MainActor struct MainView: View {
    @Environment(RootViewModel.self) private var viewModel
    @State private var isPresentingSettings = false

    @State private var liveViewModel = LiveViewModel()

    var body: some View {
        ScrollView {
            switch liveViewModel.reading {
            case .initial:
                Text("Loading...")
            case .loaded(let readings):
                Text(readings.latest!.value.formatted())

                GraphView(
                    range: Date.now.addingTimeInterval(-60 * 60 * 3)...Date.now,
                    readings: readings,
                    highlight: readings.latest,
                    graphUpperBound: UserDefaults.shared.graphUpperBound,
                    targetRange: UserDefaults.shared.targetRangeLowerBound...UserDefaults.shared.targetRangeUpperBound,
                    roundBottomCorners: false
                )
            case .noRecentReading:
                Text("No recent readings")
            case .error:
                Text("Error")
            }
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
