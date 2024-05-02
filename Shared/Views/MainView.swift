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

    @State private var lowerTargetRange = Double(UserDefaults.shared.targetRangeLowerBound)
    @State private var upperTargetRange = Double(UserDefaults.shared.targetRangeUpperBound)
    @State private var upperChartRange = Double(UserDefaults.shared.chartUpperBound)

    var body: some View {
        ScrollView {
            VStack {
                ChartSliderView(
                    title: "Chart upper bound",
                    currentValue: $upperChartRange,
                    range: 220...400
                ) {
                    UserDefaults.shared.chartUpperBound = $0
                }

                Divider()

                ChartSliderView(
                    title: "Upper target range",
                    currentValue: $upperTargetRange,
                    range: 120...220
                ) {
                    UserDefaults.shared.targetRangeUpperBound = $0
                }

                Divider()

                ChartSliderView(
                    title: "Lower target range",
                    currentValue: $lowerTargetRange,
                    range: 55...110
                ) {
                    UserDefaults.shared.targetRangeLowerBound = $0
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 20).fill(.fill.quinary)
            }
            .padding()
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

private struct ChartSliderView: View {
    var title: String
    @Binding var currentValue: Double
    var range: ClosedRange<Double>
    var update: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(currentValue.formatted())
            }

            Slider(
                value: $currentValue,
                in: range,
                step: 1,
                label: {
                    Text(title)
                },
                onEditingChanged: { bool in
                    update(Int(currentValue))
                }
            )
        }
    }
}

#Preview {
    NavigationStack {
        MainView().environment(RootViewModel())
    }
}
