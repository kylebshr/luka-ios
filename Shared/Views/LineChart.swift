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
    var selectedReading: Binding<LiveActivityState.Reading?>? = nil

    @GestureState private var isScrubbing = false

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

            if let selectedReading = selectedReading?.wrappedValue {
                let clampedValue = useFullYRange ? min(selectedReading.v, Int16(graphUpperBound)) : selectedReading.v

                RuleMark(x: .value("Date", selectedReading.t))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 0.5))

                PointMark(
                    x: .value("Date", selectedReading.t),
                    y: .value("Glucose", clampedValue)
                )
                .foregroundStyle(colorForValue(Int(selectedReading.v)))
                .symbolSize(25)
            } else if let lastReading = filteredReadings.last, Date.now.timeIntervalSince(lastReading.t) < 7 * 60 {
                let clampedValue = useFullYRange ? min(lastReading.v, Int16(graphUpperBound)) : lastReading.v

                PointMark(
                    x: .value("Date", lastReading.t),
                    y: .value("Glucose", clampedValue)
                )
                .foregroundStyle(colorForValue(Int(lastReading.v)))
                .symbolSize(25)
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
                let rangeMarks = [Int(lowerBound), Int(upperBound)].filter {
                    yScaleRange.contains($0)
                }

                AxisMarks(values: rangeMarks) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                    AxisValueLabel(collisionResolution: .greedy(priority: 50))
                }

                let boundaryMarks = [0, Int(graphUpperBound)].filter {
                    yScaleRange.contains($0)
                }

                AxisMarks(values: boundaryMarks) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                    AxisValueLabel(collisionResolution: .greedy(priority: 50))
                }

                if yScaleRange.contains(55) {
                    AxisMarks(values: [55]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                            .foregroundStyle(Color.lowColor.secondary)
                        AxisValueLabel(collisionResolution: .greedy(priority: 100))
                    }
                }
            }
        }
        .animation(.smooth.speed(1.5), value: range)
        .chartOverlay { proxy in
            if let selectedReading {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .updating($isScrubbing) { value, state, transaction in
                                    state = true

                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let frame = geometry[plotFrame]
                                    guard frame.contains(value.location) else {
                                        selectedReading.wrappedValue = nil
                                        return
                                    }

                                    let xPosition = value.location.x - frame.origin.x
                                    if let date: Date = proxy.value(atX: xPosition, as: Date.self) {
                                        selectedReading.wrappedValue = readingClosest(to: date)
                                    }
                                }
                        )
                }
                .onChange(of: isScrubbing) { oldValue, newValue in
                    if !newValue {
                        selectedReading.wrappedValue = nil
                    }
                }
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

    private func readingClosest(to date: Date) -> LiveActivityState.Reading? {
        guard !filteredReadings.isEmpty else { return nil }
        return filteredReadings.min { lhs, rhs in
            abs(lhs.t.timeIntervalSince(date)) < abs(rhs.t.timeIntervalSince(date))
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
