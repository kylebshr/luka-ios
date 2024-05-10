//
//  MainView.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/26/24.
//

import Defaults
import Dexcom
import SwiftUI
import WidgetKit

@MainActor struct MainView: View {
    @Environment(RootViewModel.self) private var viewModel

    @Default(.selectedRange) private var selectedRange
    @Default(.targetRangeLowerBound) private var lowerTargetRange
    @Default(.targetRangeUpperBound) private var upperTargetRange
    @Default(.graphUpperBound) private var upperGraphRange
    @Default(.unit) private var unit

    @State private var isPresentingSettings = false
    @State private var liveViewModel = LiveViewModel()

    private var readings: [GlucoseReading] {
        switch liveViewModel.reading {
        case .loaded(let readings, _):
            return readings
        default:
            return []
        }
    }

    private var readingText: String {
        switch liveViewModel.reading {
        case .initial, .noRecentReading, .error:
            return "100"
        case .loaded(_, let latest):
            return latest.value.formatted(.glucose(unit))
        }
    }

    private var isRedacted: Bool {
        switch liveViewModel.reading {
        case .initial:
            return true
        case .loaded(_, let latest):
            return latest.isExpired(at: .now)
        case .noRecentReading:
            return true
        case .error:
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    HStack {
                        Text(readingText)
                            .contentTransition(.numericText(value: Double(readings.last?.value ?? 0)))
                            .redacted(reason: isRedacted ? .placeholder : [])

                        readings.last?.image
                            .imageScale(.small)
                            .contentTransition(.symbolEffect(.replace))
                            .transition(.blurReplace)
                    }
                    .font(.largeTitle.bold())
                    
                    Text(liveViewModel.message)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .padding()
                .animation(.default, value: readings.last)
                
                GraphView(
                    range: selectedRange,
                    readings: readings,
                    highlight: readings.last,
                    graphUpperBound: Int(upperGraphRange),
                    targetRange: Int(lowerTargetRange)...Int(upperTargetRange),
                    roundBottomCorners: false,
                    showMarkLabels: true
                )
                .edgesIgnoringSafeArea(.leading)
                .padding(.trailing)
                
                Picker("Graph range", selection: $selectedRange) {
                    ForEach(GraphRange.allCases) {
                        Text($0.abbreviatedName)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .padding(.bottom, 20)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingSettings = true
                    } label: {
                        Image(systemName: "switch.2")
                    }
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
