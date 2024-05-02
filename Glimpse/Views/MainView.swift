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
            case .loaded(let glucoseReading):
                Text(glucoseReading.current.value.formatted())

                ChartView(
                    range: Date.now.addingTimeInterval(-60 * 60 * 3)...Date.now,
                    readings: glucoseReading.history,
                    highlight: GlucoseChartMark(glucoseReading.current),
                    chartUpperBound: UserDefaults.shared.chartUpperBound,
                    targetRange: UserDefaults.shared.targetRangeLowerBound...UserDefaults.shared.targetRangeUpperBound,
                    roundBottomCorners: false
                )
            case .noRecentReading:
                Text("No recent readings")
            case .error(let error):
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
