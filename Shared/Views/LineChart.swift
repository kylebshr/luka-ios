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
    var lineWidth: CGFloat = 2

    // Color constants for easy tweaking
    private let lowColor = Color.pink.mix(with: .red, by: 0.5)
    private let inRangeColor = Color.mint.mix(with: .green, by: 0.5)
    private let highColor = Color.yellow

    @State private var pulseScale: CGFloat = 1.0

    private var filteredReadings: [LiveActivityState.Reading] {
        let startDate = Date.now.addingTimeInterval(-range.timeInterval - 60 * 5)
        let endDate = Date.now
        return readings.filter { reading in
            reading.t >= startDate && reading.t <= endDate
        }
    }

    private var yScaleRange: ClosedRange<Int> {
        let allValues = filteredReadings.map(\.v)
        guard let dataMin = allValues.min(), let dataMax = allValues.max() else {
            return Int(lowerBound)...Int(upperBound)
        }

        let targetRangeHeight = Int(upperBound - lowerBound)
        let dataRangeHeight = Int(dataMax - dataMin)

        // Ensure minimum height equals target range
        if dataRangeHeight < targetRangeHeight {
            let expansion = targetRangeHeight - dataRangeHeight
            let expandBottom = expansion / 2
            let expandTop = expansion - expandBottom
            return (Int(dataMin) - expandBottom)...(Int(dataMax) + expandTop)
        }

        return Int(dataMin)...Int(dataMax)
    }

    var body: some View {
        Chart {
            ForEach(filteredReadings, id: \.t) { reading in
                // Line on top
                LineMark(
                    x: .value("Date", reading.t),
                    y: .value("Glucose", reading.v)
                )
                .foregroundStyle(
                    LinearGradient(
                        stops: gradientStops,
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }

            // Pulsing dot for the current (last) reading
            if let lastReading = filteredReadings.last {
                PointMark(
                    x: .value("Date", lastReading.t),
                    y: .value("Glucose", lastReading.v)
                )
                .foregroundStyle(colorForValue(Int(lastReading.v)))
                .symbolSize(20)
            }
        }
        .chartYScale(domain: yScaleRange)
        .chartXScale(domain: Date.now.addingTimeInterval(-range.timeInterval)...Date.now)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let lastReading = filteredReadings.last,
                   let position = proxy.position(for: (lastReading.t, lastReading.v)) {

                    // Pulsing ring
                    Circle()
                        .fill(colorForValue(Int(lastReading.v)))
                        .frame(width: 5, height: 5)
                        .scaleEffect(pulseScale)
                        .opacity((4.0 - pulseScale) * 0.3)
                        .position(x: position.x, y: position.y)
                }
            }
        }
        .onAppear {
            withAnimation(
                .easeOut(duration: 2).delay(0.5)
                .repeatForever(autoreverses: false)
            ) {
                pulseScale = 4.0
            }
        }
    }

    private var gradientStops: [Gradient.Stop] {
        // Use actual data range for gradient, not extended yScaleRange
        let allValues = filteredReadings.map(\.v)
        guard let dataMin = allValues.min(), let dataMax = allValues.max() else {
            return [Gradient.Stop(color: inRangeColor, location: 0)]
        }

        let dataRange = Double(dataMax - dataMin)
        guard dataRange > 0 else {
            // All values are the same, pick appropriate color
            let value = Int(dataMin)
            let color = colorForValue(value)
            return [Gradient.Stop(color: color, location: 0)]
        }

        let lowerBoundLocation = (Double(lowerBound) - Double(dataMin)) / dataRange
        let upperBoundLocation = (Double(upperBound) - Double(dataMin)) / dataRange

        var stops: [Gradient.Stop] = []

        // Determine color at bottom (location 0)
        let bottomColor = lowerBoundLocation > 0 ? lowColor : (upperBoundLocation > 0 ? inRangeColor : highColor)
        stops.append(Gradient.Stop(color: bottomColor, location: 0))

        // Sharp transition to in-range (no blending between colors)
        if lowerBoundLocation > 0 && lowerBoundLocation < 1 {
            stops.append(Gradient.Stop(color: lowColor, location: lowerBoundLocation - 0.05))
            stops.append(Gradient.Stop(color: inRangeColor, location: lowerBoundLocation + 0.05))
        }

        // Sharp transition to high (no blending between colors)
        if upperBoundLocation > 0 && upperBoundLocation < 1 {
            stops.append(Gradient.Stop(color: inRangeColor, location: upperBoundLocation - 0.05))
            stops.append(Gradient.Stop(color: highColor, location: upperBoundLocation + 0.05))
        }

        // Determine color at top (location 1)
        let topColor = upperBoundLocation < 1 ? highColor : (lowerBoundLocation < 1 ? inRangeColor : lowColor)
        stops.append(Gradient.Stop(color: topColor, location: 1))

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
    .frame(height: 70)
    .padding(1)
    .border(.blue.opacity(0.5))
    .padding()
    .frame(maxHeight: .infinity, alignment: .top)
}
