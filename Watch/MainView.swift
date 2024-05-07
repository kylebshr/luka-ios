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

    private var readings: [GlucoseReading] {
        switch liveViewModel.reading {
        case .loaded(let readings):
            return readings
        default:
            return []
        }
    }

    private var reading: GlucoseReading? {
        readings.last
    }

    private var readingText: String {
        reading?.value.formatted() ?? "100"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                GraphView(
                    range: selectedRange,
                    readings: .placeholder,
                    highlight: .placeholder,
                    graphUpperBound: Int(upperGraphRange),
                    targetRange: Int(lowerTargetRange)...Int(upperTargetRange),
                    roundBottomCorners: false,
                    showMarkLabels: true
                )
                .padding(.leading, -2)

                VStack(alignment: .leading, spacing: -2) {
                    HStack(spacing: 3) {
                        Text(readingText)
                            .redacted(reason: reading == nil ? .placeholder : [])

                        if let reading {
                            reading.image
                                .imageScale(.small)
                        }
                    }
                    .font(.title2)

                    Text(liveViewModel.message ?? "Just now")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .redacted(reason: liveViewModel.message == nil ? .placeholder : [])
                }
                .scenePadding(.horizontal)
            }
            .padding(.bottom)
            .padding(.bottom)
            .ignoresSafeArea(.all, edges: .bottom)
            .containerBackground(
                ([GlucoseReading].placeholder.last?.color ?? .black).gradient,
                for: .navigation
            )
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
