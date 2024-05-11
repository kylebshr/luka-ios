//
//  MainView.swift
//  Watch
//
//  Created by Kyle Bashour on 5/6/24.
//

import Defaults
import Dexcom
import SwiftUI

@MainActor struct MainView: View {
    @State private var liveViewModel = LiveViewModel()
    @State private var isPresentingPicker = false

    @Default(.selectedRange) private var selectedRange
    @Default(.targetRangeLowerBound) private var lowerTargetRange
    @Default(.targetRangeUpperBound) private var upperTargetRange
    @Default(.graphUpperBound) private var upperGraphRange
    @Default(.unit) private var unit

    private var readings: [GlucoseReading] {
        switch liveViewModel.state {
        case .loaded(let readings, _):
            return readings
        default:
            return []
        }
    }

    private var reading: GlucoseReading? {
        readings.last
    }

    private var readingText: String {
        reading?.value.formatted(.glucose(unit)) ?? "100"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                MainGraphView(
                    selectedRange: selectedRange,
                    readings: readings,
                    highlight: reading,
                    upperGraphRange: upperGraphRange,
                    lowerTargetRange: lowerTargetRange,
                    upperTargetRange: upperTargetRange
                )

                VStack(alignment: .leading, spacing: -3) {
                    HStack(spacing: 3) {
                        Text(readingText)
                            .redacted(reason: reading == nil ? .placeholder : [])
                            .contentTransition(.numericText(value: Double(reading?.value ?? 0)))

                        if let reading {
                            reading.image
                                .imageScale(.small)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .font(.title2)
                    .animation(.default, value: reading)

                    Text(liveViewModel.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(value: liveViewModel.messageValue))
                        .animation(.default, value: liveViewModel.message)
                }
                .scenePadding(.horizontal)
                .padding(.trailing, 40) // toolbar button
            }
            .padding(.bottom)
            .padding(.bottom)
            .ignoresSafeArea(.all, edges: .bottom)
            .containerBackground((reading?.color ?? .black).gradient, for: .navigation)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Color.clear
                    Button {
                        isPresentingPicker = true
                    } label: {
                        Text(selectedRange.abbreviatedName)
                    }
                }
            }
        }
        .fontWeight(.semibold)
        .fontDesign(.rounded)
        .sheet(isPresented: $isPresentingPicker, content: {
            RangePicker(selection: $selectedRange)
        })
        .onAppear {
            liveViewModel.setUpClientAndBeginRefreshing()
        }
    }
}

private struct MainGraphView: View {
    let selectedRange: GraphRange
    let readings: [GlucoseReading]
    let highlight: GlucoseReading?
    let upperGraphRange: Double
    let lowerTargetRange: Double
    let upperTargetRange: Double

    var body: some View {
        GraphView(
            range: selectedRange,
            readings: readings,
            highlight: highlight,
            graphUpperBound: Int(upperGraphRange),
            targetRange: Int(lowerTargetRange)...Int(upperTargetRange),
            roundBottomCorners: false,
            showMarkLabels: true
        )
        .padding(.leading, -2)
    }
}

private struct RangePicker: View {
    @Binding var selection: GraphRange

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(GraphRange.allCases) { range in
                Button { 
                    selection = range
                    dismiss()
                } label: {
                    HStack {
                        Text(range.abbreviatedName)
                        Spacer()
                        if range == selection {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .fontWeight(.semibold)
        .fontDesign(.rounded)
    }
}

#Preview {
    MainView()
}
