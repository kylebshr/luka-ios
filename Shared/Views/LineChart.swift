//
//  LineChart.swift
//  Luka
//
//  Created by Kyle Bashour on 10/17/25.
//

import SwiftUI
import Charts
import Dexcom
import Defaults

struct LineChart: View {
    @Default(.targetRangeLowerBound) var lowerBound
    @Default(.targetRangeUpperBound) var upperBound

    var range: GraphRange
    var readings: [LiveActivityState.Reading]

    // Color constants for easy tweaking
    private let lowColor = Color.pink.mix(with: .red, by: 0.5)
    private let inRangeColor = Color.mint.mix(with: .green, by: 0.5)
    private let highColor = Color.yellow

    private var filteredReadings: [LiveActivityState.Reading] {
        let startDate = Date.now.addingTimeInterval(-range.timeInterval - 60 * 5)
        let endDate = Date.now
        return readings.filter { reading in
            reading.t >= startDate && reading.t <= endDate
        }
    }

    private var yScaleRange: ClosedRange<Int> {
        let allValues = filteredReadings.map(\.v)
        guard let max = allValues.max() else {
            return 0...Int(upperBound)
        }
        return 0...Int(max)
    }

    private var valueRange: ClosedRange<Int> {
        let allValues = filteredReadings.map(\.v)
        guard let min = allValues.min(), let max = allValues.max() else {
            return Int(lowerBound)...Int(upperBound)
        }
        return Int(min)...Int(max)
    }

    var body: some View {
        Chart {
            ForEach(filteredReadings, id: \.t) { reading in
                // Area fill with gradient
                AreaMark(
                    x: .value("Date", reading.t),
                    yStart: .value("Min", yScaleRange.lowerBound),
                    yEnd: .value("Glucose", Int(reading.v))
                )
                .foregroundStyle(
                    LinearGradient(
                        stops: gradientStops(yScaleRange: yScaleRange),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .interpolationMethod(.catmullRom)
                .opacity(0.3)

                // Line on top
                LineMark(
                    x: .value("Date", reading.t),
                    y: .value("Glucose", reading.v)
                )
                .foregroundStyle(
                    LinearGradient(
                        stops: gradientStops(yScaleRange: valueRange),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .chartYScale(domain: yScaleRange)
        .chartXScale(domain: Date.now.addingTimeInterval(-range.timeInterval)...Date.now)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    private func gradientStops(yScaleRange: ClosedRange<Int>) -> [Gradient.Stop] {
        let range = Double(yScaleRange.upperBound - yScaleRange.lowerBound)
        guard range > 0 else {
            return [Gradient.Stop(color: inRangeColor, location: 0)]
        }

        let lowerBoundLocation = (Double(lowerBound) - Double(yScaleRange.lowerBound)) / range
        let upperBoundLocation = (Double(upperBound) - Double(yScaleRange.lowerBound)) / range

        var stops: [Gradient.Stop] = []

        // Below target
        stops.append(Gradient.Stop(color: lowColor, location: 0))

        // Sharp transition to in-range (no blending between colors)
        if lowerBoundLocation > 0 && lowerBoundLocation < 1 {
            stops.append(Gradient.Stop(color: lowColor, location: lowerBoundLocation - 0.001))
            stops.append(Gradient.Stop(color: inRangeColor, location: lowerBoundLocation + 0.001))
        }

        // Sharp transition to high (no blending between colors)
        if upperBoundLocation > 0 && upperBoundLocation < 1 {
            stops.append(Gradient.Stop(color: inRangeColor, location: upperBoundLocation - 0.001))
            stops.append(Gradient.Stop(color: highColor, location: upperBoundLocation + 0.001))
        }

        // Above target
        stops.append(Gradient.Stop(color: highColor, location: 1))

        return stops
    }

    private func colorForValue(_ value: Int) -> Color {
        if value < Int(lowerBound) {
            return lowColor
        } else if value > Int(upperBound) {
            return highColor
        } else {
            return inRangeColor
        }
    }
}

#Preview {
    LineChart(
        range: .sixHours,
        readings: .placeholder
    )
    .frame(height: 50)
    .border(.blue)
    .padding()
}
