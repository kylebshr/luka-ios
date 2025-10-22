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
    @Default(.graphUpperBound) var graphUpperBound

    var range: GraphRange
    var readings: [LiveActivityState.Reading]
    var lineWidth: CGFloat = 2
    var showAxisLabels: Bool = false
    var useFullYRange: Bool = false

    @State private var pulseScale: CGFloat = 1.0

    private var filteredReadings: [LiveActivityState.Reading] {
        if useFullYRange {
            return readings
        } else {
            let startDate = Date.now.addingTimeInterval(-range.timeInterval - 60 * 5)
            let endDate = Date.now
            return readings.filter { reading in
                reading.t >= startDate && reading.t <= endDate
            }
        }
    }

    private var yScaleRange: ClosedRange<Int> {
        if useFullYRange {
            return 0...Int(graphUpperBound)
        }

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
                let clampedValue = useFullYRange ? min(reading.v, Int16(graphUpperBound)) : reading.v

                // Line on top
                LineMark(
                    x: .value("Date", reading.t),
                    y: .value("Glucose", clampedValue)
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
                let clampedValue = useFullYRange ? min(lastReading.v, Int16(graphUpperBound)) : lastReading.v

                PointMark(
                    x: .value("Date", lastReading.t),
                    y: .value("Glucose", clampedValue)
                )
                .foregroundStyle(colorForValue(Int(lastReading.v)))
                .symbolSize(20)
            }
        }
        .chartYScale(domain: yScaleRange)
        .chartXScale(domain: Date.now.addingTimeInterval(-range.timeInterval)...Date.now)
        .chartXAxis {
            if showAxisLabels {
                if range.timeInterval > 60 * 60 * 2 {
                    AxisMarks(
                        format: .dateTime.hour(),
                        preset: .aligned,
                        values: .automatic(desiredCount: 4)
                    )
                } else {
                    let endDate = Date.now
                    let startDate = endDate - range.timeInterval
                    AxisMarks(
                        format: .dateTime.hour().minute(),
                        preset: .aligned,
                        values: Array(stride(from: endDate, to: startDate, by: -range.timeInterval / 4))
                    )
                }
            }
        }
        .chartYAxis {
            if showAxisLabels {
                let standardMarks = [yScaleRange.lowerBound, Int(lowerBound), Int(upperBound), yScaleRange.upperBound]

                AxisMarks(values: standardMarks) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                    AxisValueLabel(collisionResolution: .greedy(priority: 50))
                }

                AxisMarks(values: [55]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                        .foregroundStyle(Color.lowColor.secondary)
                    AxisValueLabel(collisionResolution: .greedy(priority: 100))
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let lastReading = filteredReadings.last {
                    let clampedValue = useFullYRange ? min(lastReading.v, Int16(graphUpperBound)) : lastReading.v

                    if let position = proxy.position(for: (lastReading.t, clampedValue)) {
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
        }
        .animation(.smooth.speed(1.5), value: range)
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
            return [Gradient.Stop(color: .inRangeColor, location: 0)]
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
        let bottomColor: Color = lowerBoundLocation > 0 ? .lowColor : (upperBoundLocation > 0 ? .inRangeColor : .highColor)
        stops.append(Gradient.Stop(color: bottomColor, location: 0))

        // Sharp transition to in-range (no blending between colors)
        if lowerBoundLocation > 0 && lowerBoundLocation < 1 {
            stops.append(Gradient.Stop(color: .lowColor, location: max(0, lowerBoundLocation - 0.05)))
            stops.append(Gradient.Stop(color: .inRangeColor, location: min(1, lowerBoundLocation + 0.05)))
        }

        // Sharp transition to high (no blending between colors)
        if upperBoundLocation > 0 && upperBoundLocation < 1 {
            stops.append(Gradient.Stop(color: .inRangeColor, location: max(0, upperBoundLocation - 0.05)))
            stops.append(Gradient.Stop(color: .highColor, location: min(1, upperBoundLocation + 0.05)))
        }

        // Determine color at top (location 1)
        let topColor: Color = upperBoundLocation < 1 ? .highColor : (lowerBoundLocation < 1 ? .inRangeColor : .lowColor)
        stops.append(Gradient.Stop(color: topColor, location: 1))

        return stops.sorted { $0.location < $1.location }
    }

    private func colorForValue(_ value: Int) -> Color {
        if value < Int(lowerBound) {
            return .lowColor
        } else if value > Int(upperBound) {
            return .highColor
        } else {
            return .inRangeColor
        }
    }
}

#Preview {
    VStack {
        LineChart(
            range: .eightHours,
            readings: .placeholder,
            showAxisLabels: true
        )
        .frame(height: 70)
        .padding(1)
        .border(.blue.opacity(0.5))
        .padding()

        LineChart(
            range: .eightHours,
            readings: .placeholder,
            showAxisLabels: true,
            useFullYRange: true
        )
        .frame(height: 400)
        .padding(1)
        .border(.blue.opacity(0.5))
        .padding()

        Spacer()
    }
}
