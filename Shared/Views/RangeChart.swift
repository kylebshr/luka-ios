//
//  RangeChart.swift
//  Luka
//
//  Created by Kyle Bashour on 10/17/25.
//

import SwiftUI
import Charts
import Dexcom
import Defaults
import SmoothGradient

struct RangeChart: View {
    @Default(.targetRangeLowerBound) var lowerBound
    @Default(.targetRangeUpperBound) var upperBound

    var range: ClosedRange<Date>
    var readings: [GlucoseReading]

    // Color constants for easy tweaking
    private let lowColor = Color.pink.mix(with: .red, by: 0.5)
    private let inRangeColor = Color.mint.mix(with: .green, by: 0.5)
    private let highColor = Color.yellow

    private var aggregatedReadings: [RangeData] {
        // Use a fixed number of buckets with aesthetic spacing (0.7 = 30% gap)
        readings.aggregated(intoBuckets: 24, spacingRatio: 0.7)
    }

    private var yScaleRange: ClosedRange<Int> {
        let allValues = aggregatedReadings.flatMap { [$0.minValue, $0.maxValue] }
        guard let min = allValues.min(), let max = allValues.max() else {
            return Int(lowerBound)...Int(upperBound) // Use target range as fallback
        }
        return min...max
    }

    var body: some View {
        Chart(aggregatedReadings) { reading in
            RectangleMark(
                xStart: .value("Start", reading.barStart),
                xEnd: .value("End", reading.barEnd),
                yStart: .value("Min", reading.minValue),
                yEnd: .value("Max", reading.maxValue)
            )
            .foregroundStyle(gradientForRange(min: reading.minValue, max: reading.maxValue))
            .clipShape(.capsule)
        }
        .chartYScale(domain: yScaleRange)
        .chartXAxis(.hidden)
    }

    private func gradientForRange(min: Int, max: Int) -> AnyShapeStyle {
        let minValue = Double(min)
        let maxValue = Double(max)
        let lowerBoundValue = Double(lowerBound)
        let upperBoundValue = Double(upperBound)

        // Simple cases: entire bar in one zone - use nice colors
        if maxValue <= lowerBoundValue {
            return AnyShapeStyle(lowColor.gradient)
        }
        if minValue >= upperBoundValue {
            return AnyShapeStyle(highColor.gradient)
        }
        if minValue >= lowerBoundValue && maxValue <= upperBoundValue {
            return AnyShapeStyle(inRangeColor.gradient)
        }

        // Complex case: bar spans multiple zones - create smooth transitions at boundaries
        let range = maxValue - minValue

        // Fixed transition width in glucose units for consistent visual appearance
        let transitionWidth = 20.0  // 10 mg/dL transition zone
        let transitionOffset = transitionWidth / range  // Convert to gradient location units

        var stops: [Gradient.Stop] = []

        // Start with bottom color
        stops.append(Gradient.Stop(color: colorForValue(min), location: 0))

        // Add smooth transition at lower bound if within range
        if lowerBoundValue > minValue && lowerBoundValue < maxValue {
            let location = (lowerBoundValue - minValue) / range
            let transitionStart = Swift.max(0, location - transitionOffset)
            let transitionEnd = Swift.min(1, location + transitionOffset)

            // Create a smooth transition at the boundary
            let smoothTransition = Gradient.smooth(
                from: Gradient.Stop(color: lowColor, location: 0),
                to: Gradient.Stop(color: inRangeColor, location: 1),
                curve: .easeInOut,
                steps: 8
            )

            // Map the smooth transition to our narrow transition zone
            for stop in smoothTransition.stops {
                let mappedLocation = transitionStart + (transitionEnd - transitionStart) * stop.location
                stops.append(Gradient.Stop(color: stop.color, location: mappedLocation))
            }
        }

        // Add smooth transition at upper bound if within range
        if upperBoundValue > minValue && upperBoundValue < maxValue {
            let location = (upperBoundValue - minValue) / range
            let transitionStart = Swift.max(0, location - transitionOffset)
            let transitionEnd = Swift.min(1, location + transitionOffset)

            // Create a smooth transition at the boundary
            let smoothTransition = Gradient.smooth(
                from: Gradient.Stop(color: inRangeColor, location: 0),
                to: Gradient.Stop(color: highColor, location: 1),
                curve: .easeInOut,
                steps: 8
            )

            // Map the smooth transition to our narrow transition zone
            for stop in smoothTransition.stops {
                let mappedLocation = transitionStart + (transitionEnd - transitionStart) * stop.location
                stops.append(Gradient.Stop(color: stop.color, location: mappedLocation))
            }
        }

        // End with top color
        stops.append(Gradient.Stop(color: colorForValue(max), location: 1))

        // Sort stops by location to ensure proper gradient
        stops.sort { $0.location < $1.location }

        return AnyShapeStyle(
            LinearGradient(gradient: Gradient(stops: stops), startPoint: .bottom, endPoint: .top)
        )
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

private struct RangeData: Identifiable {
    let date: Date
    let minValue: Int
    let maxValue: Int
    let barStart: Date  // For RectangleMark positioning
    let barEnd: Date    // For RectangleMark positioning

    var id: Date { date }
}

private extension [GlucoseReading] {
    func aggregated(intoBuckets bucketCount: Int, spacingRatio: Double = 0.8) -> [RangeData] {
        guard !self.isEmpty,
              bucketCount > 0,
              let firstDate = self.first?.date,
              let lastDate = self.last?.date else { return [] }

        let totalDuration = lastDate.timeIntervalSince(firstDate)
        let bucketDuration = totalDuration / Double(bucketCount)

        var result: [RangeData] = []

        for i in 0..<bucketCount {
            let bucketStart = firstDate.addingTimeInterval(Double(i) * bucketDuration)
            let bucketEnd = firstDate.addingTimeInterval(Double(i + 1) * bucketDuration)

            let readingsInBucket = self.filter {
                $0.date >= bucketStart && $0.date < bucketEnd
            }

            if let min = readingsInBucket.map(\.value).min(),
               let max = readingsInBucket.map(\.value).max() {
                // Use the midpoint of the bucket for plotting
                let midpoint = bucketStart.addingTimeInterval(bucketDuration / 2)

                // Calculate bar positions with custom spacing
                let barWidth = bucketDuration * spacingRatio
                let barOffset = (bucketDuration - barWidth) / 2
                let barStart = bucketStart.addingTimeInterval(barOffset)
                let barEnd = bucketStart.addingTimeInterval(bucketDuration - barOffset)

                result.append(RangeData(
                    date: midpoint,
                    minValue: min,
                    maxValue: max,
                    barStart: barStart,
                    barEnd: barEnd
                ))
            }
        }

        return result
    }
}

#Preview {
    RangeChart(
        range: Date.now.addingTimeInterval(-60 * 60 * 6)...Date.now,
        readings: .placeholder
    )
    .frame(height: 120)
    .padding(1)
    .border(.blue)
    .padding()
    .frame(maxHeight: .infinity, alignment: .top)
}
